import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

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
          SnackBar(content: const Text('Cliente contactado'), backgroundColor: Colors.green),
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

  Future<void> _addToCalendar(Map<String, dynamic> booking) async {
    final idea = booking['idea_description']?.toString() ?? 'Sesión de Tatuaje';
    final part = booking['body_part']?.toString() ?? 'Cuerpo';
    final price = booking['price_quote']?.toString() ?? '0';
    final dateStr = booking['booking_date']?.toString();
    
    if (dateStr == null || dateStr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La reserva no tiene una fecha válida')),
        );
      }
      return;
    }
    
    final startDate = DateTime.parse(dateStr).toLocal();
    final duration = double.tryParse(booking['duration_hours']?.toString() ?? '2') ?? 2.0;
    final endDate = startDate.add(Duration(minutes: (duration * 60).toInt()));

    final clientName = _clientNames[booking['client_id']] ?? 'Cliente';
    final Event event = Event(
      title: 'Tatuaje de $clientName',
      description: 'Zona: $part\nIdea: $idea\nPrecio Estimado: $price €\nGestion desde Inka',
      location: 'Estudio de Tatuajes',
      startDate: startDate,
      endDate: endDate,
      iosParams: IOSParams(reminder: const Duration(hours: 1)),
      androidParams: AndroidParams(emailInvites: []),
    );

    try {
      await Add2Calendar.addEvent2Cal(event);
    } catch (e) {
      print('Error al agregar al calendario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el calendario: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Reservas'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _bookings.isEmpty
                ? Center(
                    child: Text(
                      'No tienes reservas pendientes',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
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
                        color: Theme.of(context).colorScheme.surface,
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
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              const SizedBox(height: 8),

                              // Detalles del tatuaje
                                Text(
                                  'Idea: ${booking['idea_description']}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                                Text(
                                  'Parte del cuerpo: ${booking['body_part']}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                ),
                                if (booking['size_cm'] != null)
                                  Text(
                                    'Tamaño: ${booking['size_cm']} cm',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                  ),
                                  Text(
                                    'Fecha preferida: ${_formatDate(booking['booking_date'])}',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                  ),
                                if (booking['duration_hours'] != null)
                                  Text(
                                    'Duración estimada: ${booking['duration_hours']} h',
                                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
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
                                  ),
                                ),
                              ),
                              if (status == 'aceptado' && booking['booking_date'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _addToCalendar(booking),
                                      icon: const Icon(Icons.calendar_today, size: 18),
                                      label: const Text('Agregar al Calendario'),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(color: Theme.of(context).colorScheme.primary),
                                        foregroundColor: Theme.of(context).colorScheme.primary,
                                      ),
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
    final date = DateTime.parse(dateString).toLocal();
    final time = '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    return '${date.day}/${date.month}/${date.year} a las $time';
  }
}