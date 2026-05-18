import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'artist_profile_view_screen.dart';

class ChatScreen extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String? bookingId; // Optional booking to show in chat

  const ChatScreen({
    super.key,
    required this.artistId,
    required this.artistName,
    this.bookingId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isUploadingImage = false;
  bool _isArtist = false;
  Timer? _pollingTimer;
  
  // Controladores dinámicos para los campos en las tarjetas de oferta
  final Map<String, Map<String, TextEditingController>> _bookingControllers = {};
  final Map<String, DateTime?> _selectedDates = {};

  String? _otherUserAvatarUrl;
  bool _avatarLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Iniciar polling cada 3 segundos
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadMessages(quietly: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _messageCtrl.dispose();
    _scrollController.dispose();
    for (var innerMap in _bookingControllers.values) {
      for (var ctrl in innerMap.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadMessages({bool quietly = false}) async {
    if (!quietly) setState(() => _isLoading = true);

    final role = await _authService.getUserRole();
    if (mounted) {
      _isArtist = role == 'artista';
      if (!_avatarLoaded && !_isArtist) {
        _avatarLoaded = true;
        _authService.getArtistById(widget.artistId).then((data) {
          if (mounted && data != null && data['avatar_url'] != null) {
            setState(() {
              _otherUserAvatarUrl = data['avatar_url'];
            });
          }
        });
      }
    }

    final currentUserId = await _authService.getCurrentUserId();
    final messages = await _authService.getMessagesWithArtist(widget.artistId);

    if (messages != null && currentUserId != null) {
      final newMessages = messages.map((m) {
        return {
          'id': m['id'],
          'content': m['content'],
          'sender_id': m['sender_id'],
          'created_at': DateTime.parse(m['created_at']),
          'is_mine': m['sender_id'] == currentUserId,
          'is_read': m['is_read'],
        };
      }).toList();

      // Solo actualizar si hay cambios (para evitar saltos visuales)
      if (newMessages.length != _messages.length || 
          newMessages.last['id'] != _messages.last['id'] ||
          newMessages.any((m) => m['is_read'] == true) != _messages.any((m) => m['is_read'] == true)) {
        setState(() {
          _messages = newMessages;
        });
        if (!quietly) {
           WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        } else {
           // Si es en background y hay mensaje nuevo de la otra persona, hacer scroll
           if (newMessages.length > _messages.length && !newMessages.last['is_mine']) {
             _scrollToBottom();
           }
        }
      }
    }

    if (!quietly) {
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _sendMessage() async {
    if (_messageCtrl.text.trim().isEmpty) return;

    final content = _messageCtrl.text.trim();

    // Añadimos localmente para respuesta rápida
    setState(() {
      _messages.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'content': content,
        'sender_id': 'me',
        'created_at': DateTime.now(),
        'is_mine': true,
      });
      _messageCtrl.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    // Enviar mensaje a la API
    final success = await _authService.sendMessageToArtist(widget.artistId, content);
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error enviando mensaje'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(Icons.photo_camera, color: Theme.of(context).colorScheme.primary),
              title: Text('Cámara', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Theme.of(context).colorScheme.primary),
              title: Text('Galería', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    
    if (pickedFile == null) return;
    
    setState(() => _isUploadingImage = true);
    
    final imageUrl = await _authService.uploadChatImage(pickedFile.path);
    
    setState(() => _isUploadingImage = false);
    
    if (imageUrl != null) {
      final jsonMsg = jsonEncode({"type": "chat_image", "url": imageUrl});
      
      setState(() {
        _messages.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'content': jsonMsg,
          'sender_id': 'me',
          'created_at': DateTime.now(),
          'is_mine': true,
        });
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
      
      final success = await _authService.sendMessageToArtist(widget.artistId, jsonMsg);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error enviando imagen'), backgroundColor: Colors.red),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error subiendo imagen'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _updateBookingProposal(
    String bookingId, {
    required String idea,
    required String part,
    required String size,
    required String priceText,
    required String durationText,
    DateTime? date,
  }) async {
    final price = double.tryParse(priceText);
    final duration = double.tryParse(durationText);
    
    final Map<String, dynamic> updateData = {
      'idea_description': idea,
      'body_part': part,
      'size_cm': size,
      'price_quote': price,
      'duration_hours': duration,
      'artist_accepted': true,
      'client_accepted': false,
    };

    if (date != null) {
      updateData['booking_date'] = date.toUtc().toIso8601String();
    }

    final success = await _authService.updateBooking(bookingId, updateData);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Propuesta enviada'), backgroundColor: Colors.green),
        );
      }
      _loadMessages(); // Recargar para ver el nuevo mensaje
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al enviar propuesta'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _acceptBooking(String bookingId) async {
    final success = await _authService.updateBooking(bookingId, {
      if (_isArtist) 'artist_accepted': true,
      if (!_isArtist) 'client_accepted': true,
    });
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Propuesta aceptada'), backgroundColor: Colors.green),
        );
      }
      _loadMessages();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al aceptar'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _addToCalendar(Map<String, dynamic> data) async {
    final idea = data['idea_description']?.toString() ?? 'Sesión de Tatuaje';
    final part = data['body_part']?.toString() ?? 'Cuerpo';
    final price = data['price_quote']?.toString() ?? '0';
    final dateStr = data['booking_date']?.toString();
    
    if (dateStr == null || dateStr.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La reserva no tiene una fecha válida')),
        );
      }
      return;
    }
    
    final startDate = DateTime.parse(dateStr).toLocal();
    final duration = double.tryParse(data['duration_hours']?.toString() ?? '2') ?? 2.0;
    
    // Calcular fin basado en la duración (convertir horas a minutos)
    final endDate = startDate.add(Duration(minutes: (duration * 60).toInt()));

    final Event event = Event(
      title: 'Tatuaje de ${widget.artistName}',
      description: 'Zona: $part\nIdea: $idea\nPrecio Estimado: $price €\nGestion desde Inka',
      location: 'Estudio de Tatuajes',
      startDate: startDate,
      endDate: endDate,
      iosParams: const IOSParams(
        reminder: Duration(hours: 1),
      ),
      androidParams: const AndroidParams(
        emailInvites: [], // Lista de invitados si fuera necesario
      ),
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            if (!_isArtist) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistProfileViewScreen(artistId: widget.artistId),
                ),
              );
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primary,
                radius: 18,
                backgroundImage: _otherUserAvatarUrl != null ? NetworkImage(_otherUserAvatarUrl!) : null,
                child: _otherUserAvatarUrl == null
                    ? Text(
                        widget.artistName.isNotEmpty ? widget.artistName[0].toUpperCase() : 'A',
                        style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.artistName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Lista de mensajes
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay mensajes aún',
                            style: TextStyle(color: Colors.white),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16),
                          reverse: true, // Para que los mensajes nuevos aparezcan abajo
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                             // Invertimos el orden
                            final message = _messages[_messages.length - 1 - index];
                            return _buildMessageBubble(message);
                          },
                        ),
            ),

            // Input para enviar mensajes
            Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                top: 12,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.attach_file, color: Theme.of(context).colorScheme.primary),
                    onPressed: _isUploadingImage ? null : _showImageSourceDialog,
                  ),
                  if (_isUploadingImage)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                      ),
                    ),
                   Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Escribe un mensaje...',
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                     backgroundColor: Theme.of(context).colorScheme.primary,
                     foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    child: IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = message['is_mine'] as bool;
    final content = message['content'] as String;
    final timestamp = message['created_at'] as DateTime;
    final msgId = message['id'] as String;
    final isRead = message['is_read'] as bool? ?? false;

    // Verificar si es un mensaje de sistema (JSON de oferta o imagen)
    bool isSystemJson = false;
    bool isChatImage = false;
    Map<String, dynamic>? jsonData;
    try {
       jsonData = jsonDecode(content);
       if (jsonData != null) {
         if (jsonData['type'] == 'booking_update') {
            isSystemJson = true;
         } else if (jsonData['type'] == 'chat_image') {
            isChatImage = true;
         }
       }
    } catch (_) {
       // No es JSON, continuamos
    }

    if (isSystemJson && jsonData != null) {
      return _buildBookingCard(jsonData, isMine, timestamp, msgId);
    }

    // Burbuja normal
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMine ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.only(
             topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMine ? const Radius.circular(16) : const Radius.circular(4),
            bottomRight: isMine ? const Radius.circular(4) : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isChatImage && jsonData != null)
              GestureDetector(
                onTap: () => _showFullScreenImage(jsonData!['url']),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    jsonData['url'],
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              )
            else
              Text(
                content,
                style: TextStyle(
                  color: isMine ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isMine 
                        ? Theme.of(context).colorScheme.onPrimary.withOpacity(0.7)
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.5)
                  ),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: isRead 
                        ? Colors.blueAccent 
                        : Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.6),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

   Widget _buildBookingCard(Map<String, dynamic> data, bool isMine, DateTime timestamp, String msgId) {
    final bId = data['booking_id']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pendiente';
    final idea = data['idea_description']?.toString() ?? '';
    final part = data['body_part']?.toString() ?? '';
    final size = data['size_cm']?.toString() ?? '';
    final price = data['price_quote'];
    final duration = data['duration_hours'];
    final dateStr = data['booking_date']?.toString();
    DateTime? bookingDate = dateStr != null ? DateTime.parse(dateStr).toLocal() : null;
    
    final clientAcc = data['client_accepted'] as bool? ?? false;
    final artistAcc = data['artist_accepted'] as bool? ?? false;
    
    // Inicializar controladores para este mensaje si es artista
    if (_isArtist && !_bookingControllers.containsKey(msgId)) {
      _bookingControllers[msgId] = {
        'idea': TextEditingController(text: idea),
        'part': TextEditingController(text: part),
        'size': TextEditingController(text: size),
        'price': TextEditingController(text: price?.toString() ?? ''),
        'duration': TextEditingController(text: duration?.toString() ?? '2'),
      };
      _selectedDates[msgId] = bookingDate;
    }
    
    final ctrls = _bookingControllers[msgId];
    final selectedDate = _selectedDates[msgId];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Propuesta de Tattoo',
                style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 12),

          if (_isArtist && status != 'aceptado') ...[
            // VISTA EDICIÓN ARTISTA
            _buildEditField('Idea:', ctrls?['idea']),
            _buildEditField('Zona:', ctrls?['part']),
            _buildEditField('Tamaño (cm):', ctrls?['size']),
            
            const Text('Fecha:', style: TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: selectedDate ?? DateTime.now().add(const Duration(days: 7)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() => _selectedDates[msgId] = picked);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  selectedDate != null ? '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}' : 'Seleccionar fecha',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildEditField('Precio (€):', ctrls?['price'], isNumber: true),
            _buildEditField('Duración estimada (h):', ctrls?['duration'], isNumber: true),
            
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _updateBookingProposal(
                bId,
                idea: ctrls?['idea']?.text ?? '',
                part: ctrls?['part']?.text ?? '',
                size: ctrls?['size']?.text ?? '',
                priceText: ctrls?['price']?.text ?? '0',
                durationText: ctrls?['duration']?.text ?? '2',
                date: selectedDate,
              ),
              child: const Text('Enviar Propuesta Actualizada'),
            ),
            
            if (clientAcc && !artistAcc) ...[
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => _acceptBooking(bId),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text('Confirmar Trato con estos datos'),
              )
            ]
          ] else ...[
            // VISTA LECTURA (PARA CLIENTE O TRATO CERRADO)
            Text('Idea: $idea'),
            Text('Zona: $part'),
            if (size.isNotEmpty) Text('Tamaño: $size cm'),
            if (bookingDate != null) 
              Text('Fecha: ${bookingDate.day}/${bookingDate.month}/${bookingDate.year} a las ${_formatTimeOnly(bookingDate)}'),
            if (duration != null)
              Text('Duración: $duration h'),
            
            const Divider(height: 24),
            
            if (price != null) ...[
              Text('$price €', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (status != 'aceptado') ...[
                if (!_isArtist && !clientAcc)
                  ElevatedButton(
                    onPressed: () => _acceptBooking(bId),
                    child: const Text('Aceptar Oferta'),
                  )
                else if (!_isArtist)
                  Text('Has aceptado. Esperando confirmación del artista...', style: TextStyle(color: Theme.of(context).colorScheme.secondary))
                else if (_isArtist && clientAcc && !artistAcc)
                  ElevatedButton(
                    onPressed: () => _acceptBooking(bId),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    child: const Text('Confirmar Trato'),
                  )
              ] else ...[
                const Text('¡Trato cerrado!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _addToCalendar(data),
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: const Text('Agregar al Calendario'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[800],
                    foregroundColor: Colors.white,
                  ),
                ),
              ]
            ] else ...[
              Text('Esperando oferta del artista...', style: TextStyle(color: Theme.of(context).colorScheme.secondary, fontStyle: FontStyle.italic)),
            ]
          ],

          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(_formatTime(timestamp), style: const TextStyle(color: Colors.white54, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController? ctrl, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${time.day}/${time.month} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inHours > 0) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} min';
    } else {
      return 'Ahora';
    }
  }

  String _formatTimeOnly(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showFullScreenImage(String imageUrl) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (ctx) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: InteractiveViewer(
            panEnabled: true,
            minScale: 0.5,
            maxScale: 4,
            child: Image.network(imageUrl),
          ),
        ),
      ),
    ));
  }
}