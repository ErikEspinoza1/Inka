import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class BookingScreen extends StatefulWidget {
  final String artistId;
  final String artistName;

  const BookingScreen({super.key, required this.artistId, required this.artistName});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _ideaCtrl = TextEditingController();
  final TextEditingController _bodyPartCtrl = TextEditingController();
  final TextEditingController _sizeCtrl = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  Map<String, dynamic>? _artistData;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    final data = await _authService.getArtistById(widget.artistId);
    if (mounted) {
      setState(() {
        _artistData = data;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );

    if (picked != null) {
      // Validar contra el horario del artista si está disponible
      if (_artistData != null) {
        final startStr = _artistData!['working_hours_start'] ?? "09:00";
        final endStr = _artistData!['working_hours_end'] ?? "18:00";
        
        final start = TimeOfDay(
          hour: int.parse(startStr.split(":")[0]),
          minute: int.parse(startStr.split(":")[1]),
        );
        final end = TimeOfDay(
          hour: int.parse(endStr.split(":")[0]),
          minute: int.parse(endStr.split(":")[1]),
        );

        final pickedMinutes = picked.hour * 60 + picked.minute;
        final startMinutes = start.hour * 60 + start.minute;
        final endMinutes = end.hour * 60 + end.minute;

        if (pickedMinutes < startMinutes || pickedMinutes > endMinutes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('El artista trabaja de $startStr a $endStr. Por favor elige una hora válida.'),
                backgroundColor: Colors.orangeAccent,
              ),
            );
          }
          return;
        }
      }

      setState(() {
        _selectedTime = picked;
      });
    }
  }

  @override
  void dispose() {
    _ideaCtrl.dispose();
    _bodyPartCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitBooking() async {
    if (_ideaCtrl.text.isEmpty || _bodyPartCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor completa todos los campos obligatorios')),
      );
      return;
    }

    setState(() => _isLoading = true);

    DateTime? finalDate = _selectedDate;
    if (finalDate != null && _selectedTime != null) {
      finalDate = DateTime(
        finalDate.year,
        finalDate.month,
        finalDate.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    // Llamar a la API para enviar la reserva
    final success = await _authService.submitBooking(
      artistId: widget.artistId,
      ideaDescription: _ideaCtrl.text.trim(),
      bodyPart: _bodyPartCtrl.text.trim(),
      sizeCm: _sizeCtrl.text.isNotEmpty ? _sizeCtrl.text.trim() : null,
      bookingDate: finalDate,
    );

    setState(() => _isLoading = false);

    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Error al enviar la reserva'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Reserva enviada correctamente. El artista se pondrá en contacto contigo.'),
            backgroundColor: Colors.green,
          ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text('Reservar con ${widget.artistName}'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Información del artista
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        widget.artistName.substring(0, 1).toUpperCase(),
                        style: TextStyle(fontSize: 24, color: Theme.of(context).colorScheme.onPrimary),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.artistName,
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Artista Profesional',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Formulario de reserva
              Text(
                'Detalles del Tatuaje',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildTextField('Idea del tatuaje *', _ideaCtrl, Icons.lightbulb, maxLines: 3),
              const SizedBox(height: 16),
              _buildTextField('Parte del cuerpo *', _bodyPartCtrl, Icons.accessibility),
              const SizedBox(height: 16),
              _buildTextField('Tamaño aproximado (cm)', _sizeCtrl, Icons.straighten),

              const SizedBox(height: 24),

              // Selector de fecha y hora
              Text(
                'Fecha y Hora preferida',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : 'Fecha',
                              style: TextStyle(
                                color: _selectedDate != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: () => _selectTime(context),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Theme.of(context).colorScheme.primary),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              _selectedTime != null
                                  ? _selectedTime!.format(context)
                                  : 'Hora',
                              style: TextStyle(
                                color: _selectedTime != null ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Información adicional
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.orangeAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: Colors.orangeAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'El artista revisará tu solicitud y te contactará para confirmar la fecha y discutir detalles adicionales.',
                        style: TextStyle(color: Colors.orange[100], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Botón de envío
              Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitBooking,
                    child: _isLoading
                        ? const CircularProgressIndicator()
                        : const Text(
                            'Enviar Solicitud de Reserva',
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }
}