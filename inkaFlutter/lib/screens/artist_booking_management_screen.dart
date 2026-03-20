import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class ArtistBookingManagementScreen extends StatefulWidget {
  const ArtistBookingManagementScreen({super.key});

  @override
  State<ArtistBookingManagementScreen> createState() => _ArtistBookingManagementScreenState();
}

class _ArtistBookingManagementScreenState extends State<ArtistBookingManagementScreen> {
  final AuthService _authService = AuthService();
  List<dynamic> _bookings = [];
  bool _isLoading = true;
  final Map<String, String> _clientNames = {}; // Cache para nombres de clientes

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);
    final bookings = await _authService.getMyBookings();
    if (mounted) {
      setState(() {
        _bookings = bookings ?? [];
        _isLoading = false;
      });
      // Cargar nombres de clientes después de cargar las reservas
      await _loadClientNames();
    }
  }

  Future<void> _loadClientNames() async {
    for (final booking in _bookings) {
      final clientId = booking['client_id'];
      if (!_clientNames.containsKey(clientId)) {
        final userData = await _authService.getUserById(clientId);
        if (userData != null && mounted) {
          setState(() {
            _clientNames[clientId] = userData['full_name'] ?? 'Cliente desconocido';
          });
        }
      }
    }
  }

  Future<void> _contactClient(String bookingId, String clientId, String clientName) async {
    // Primero cambiar el status a contactado si no lo está ya
    final booking = _bookings.firstWhere((b) => b['id'] == bookingId);
    if (booking['status'] == 'pendiente') {
      final success = await _authService.updateBooking(bookingId, {'status': 'contactado'});
      if (success && mounted) {
        // Actualizar el status localmente
        setState(() {
          booking['status'] = 'contactado';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cliente contactado'), backgroundColor: Colors.green),
        );
      }
    }

    // Abrir el chat
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            artistId: clientId,
            artistName: clientName,
            bookingId: bookingId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Gestión de Reservas'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _bookings.isEmpty
                ? const Center(
                    child: Text(
                      'No tienes reservas pendientes',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) {
                      final booking = _bookings[index];
                      final status = booking['status'] as String;
                      final clientAccepted = booking['client_accepted'] as bool;
                      final artistAccepted = booking['artist_accepted'] as bool;

                      return Card(
                        color: const Color(0xFF1A1A1A),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Estado de la reserva
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              // Información del cliente
                              Text(
                                'Cliente: ${_clientNames[booking['client_id']] ?? 'Cargando...'}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),

                              // Detalles del tatuaje
                              Text(
                                'Idea: ${booking['idea_description']}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              Text(
                                'Parte del cuerpo: ${booking['body_part']}',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              if (booking['size_cm'] != null)
                                Text(
                                  'Tamaño: ${booking['size_cm']} cm',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                              if (booking['booking_date'] != null)
                                Text(
                                  'Fecha preferida: ${_formatDate(booking['booking_date'])}',
                                  style: const TextStyle(color: Colors.white70),
                                ),

                              const SizedBox(height: 16),

                              // Estado de aceptación
                              Row(
                                children: [
                                  Icon(
                                    clientAccepted ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: clientAccepted ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Cliente aceptó',
                                    style: TextStyle(
                                      color: clientAccepted ? Colors.green : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    artistAccepted ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: artistAccepted ? Colors.green : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Tú aceptaste',
                                    style: TextStyle(
                                      color: artistAccepted ? Colors.green : Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // Botón de acción
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _contactClient(
                                    booking['id'],
                                    booking['client_id'],
                                    _clientNames[booking['client_id']] ?? 'Cliente ${booking['client_id']}',
                                  ),
                                  icon: const Icon(Icons.chat),
                                  label: const Text('Contactar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.tealAccent,
                                    foregroundColor: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pendiente':
        return Colors.orange;
      case 'contactado':
        return Colors.blue;
      case 'aceptado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pendiente':
        return 'Pendiente';
      case 'contactado':
        return 'Contactado';
      case 'aceptado':
        return 'Aceptado';
      case 'rechazado':
        return 'Rechazado';
      case 'finalizado':
        return 'Finalizado';
      default:
        return status;
    }
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    return '${date.day}/${date.month}/${date.year}';
  }
}