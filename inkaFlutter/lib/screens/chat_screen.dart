import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

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
  bool _isArtist = false;
  
  // Controladores dinámicos para el precio en las tarjetas de oferta
  final Map<String, TextEditingController> _priceControllers = {};

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollController.dispose();
    for (var ctrl in _priceControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    final role = await _authService.getUserRole();
    if (mounted) {
      _isArtist = role == 'artista';
    }

    final currentUserId = await _authService.getCurrentUserId();
    final messages = await _authService.getMessagesWithArtist(widget.artistId);

    if (messages != null && currentUserId != null) {
      setState(() {
        _messages = messages.map((m) {
          return {
            'id': m['id'],
            'content': m['content'],
            'sender_id': m['sender_id'],
            'created_at': DateTime.parse(m['created_at']),
            'is_mine': m['sender_id'] == currentUserId,
          };
        }).toList();
      });
    }

    setState(() => _isLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error enviando mensaje'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _updateBookingPrice(String bookingId, String priceText) async {
    final price = double.tryParse(priceText);
    if (price == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Precio inválido'), backgroundColor: Colors.red),
      );
      return;
    }

    final success = await _authService.updateBooking(bookingId, {'price_quote': price, 'artist_accepted': true, 'client_accepted': false});
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Oferta enviada'), backgroundColor: Colors.green),
      );
      _loadMessages(); // Recargar para ver el nuevo mensaje
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al enviar oferta'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _acceptBooking(String bookingId) async {
    final success = await _authService.updateBooking(bookingId, {
      if (_isArtist) 'artist_accepted': true,
      if (!_isArtist) 'client_accepted': true,
    });
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Propuesta aceptada'), backgroundColor: Colors.green),
      );
      _loadMessages();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al aceptar'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Chat con ${widget.artistName}'),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone, color: Colors.tealAccent),
            onPressed: () {
              // TODO: Implementar llamada
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Función de llamada próximamente')),
              );
            },
          ),
        ],
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
                   Expanded(
                    child: TextField(
                      controller: _messageCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: const TextStyle(color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white10,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                     backgroundColor: Colors.tealAccent,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black),
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

    // Verificar si es un mensaje de sistema (JSON de oferta)
    bool isSystemJson = false;
    Map<String, dynamic>? jsonData;
    try {
       jsonData = jsonDecode(content);
       if (jsonData != null && jsonData['type'] == 'booking_update') {
          isSystemJson = true;
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
          color: isMine ? Colors.tealAccent : Colors.white10,
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
            Text(
              content,
              style: TextStyle(
                color: isMine ? Colors.black : Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
               _formatTime(timestamp),
              style: TextStyle(
                color: isMine ? Colors.black54 : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> data, bool isMine, DateTime timestamp, String msgId) {
    // Si la alineación debe coincidir con el diseño, centramos la carta de "Booking" 
    // al medio del chat u opcionalmente lado derecho/izquierdo. 
    // Para estilo Vinted, suele estar centrado o en función del autor.
    final autorEsIsMine = isMine;
    
    final bId = data['booking_id']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pendiente';
    final idea = data['idea_description']?.toString() ?? '';
    final part = data['body_part']?.toString() ?? '';
    final size = data['size_cm']?.toString();
    final price = data['price_quote'];
    final clientAcc = data['client_accepted'] as bool? ?? false;
    final artistAcc = data['artist_accepted'] as bool? ?? false;
    
    // Obtener un controlador solo si es artista y el estado lo permite o para crear oferta
    if (_isArtist && price != null && !_priceControllers.containsKey(msgId)) {
        _priceControllers[msgId] = TextEditingController(text: price.toString());
    } else if (_isArtist && !_priceControllers.containsKey(msgId)) {
        _priceControllers[msgId] = TextEditingController();
    }
    
    final ctrl = _priceControllers[msgId];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Un gris más oscuro para diferenciarlo
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.tealAccent.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Propuesta de Tattoo',
                style: TextStyle(color: Colors.tealAccent, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Container(
                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                child: Text(status.toUpperCase(), style: const TextStyle(color: Colors.white70, fontSize: 10)),
              )
            ],
          ),
          const SizedBox(height: 12),
          Text('Idea: $idea', style: const TextStyle(color: Colors.white)),
          Text('Zona: $part', style: const TextStyle(color: Colors.white70)),
          if (size != null && size.isNotEmpty) Text('Tamaño: $size cm', style: const TextStyle(color: Colors.white70)),
          
          const Divider(color: Colors.white24, height: 24),
          
          // Lógica de Renderizado del Precio / Acciones
          if (_isArtist) ...[
            // ARTISTA Ve input de precio si no está completado
            if (status != 'aceptado') ...[
              const Text('Precio propuesto (€):', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                         filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                     onPressed: () => _updateBookingPrice(bId, ctrl?.text ?? '0'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                    child: const Text('Enviar Oferta'),
                  )
                ],
              ),
              if (clientAcc && !artistAcc) ...[
                 const SizedBox(height: 12),
                 ElevatedButton(
                   onPressed: () => _acceptBooking(bId),
                   style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                   child: const Text('Confirmar Trato'),
                 )
              ]
            ] else ...[
               Text('Precio fijado: ${price ?? 'No especificado'} €', style: const TextStyle(color: Colors.tealAccent, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 8),
               const Text('¡Trato cerrado!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ]
          ] else ...[
             // CLIENTE ve el precio o "Esperando..."
             const Text('Precio ofrecido por Artista:', style: TextStyle(color: Colors.white70, fontSize: 12)),
             const SizedBox(height: 4),
             if (price != null) ...[
                 Text('${price} €', style: const TextStyle(color: Colors.tealAccent, fontSize: 22, fontWeight: FontWeight.bold)),
                 const SizedBox(height: 12),
                 if (status != 'aceptado') ...[
                     if (!clientAcc)
                       ElevatedButton(
                          onPressed: () => _acceptBooking(bId),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
                          child: const Text('Aceptar Oferta'),
                       )
                     else
                       const Text('Has aceptado. Esperando confirmación del artista...', style: TextStyle(color: Colors.orange)),
                 ] else ...[
                     const Text('¡Trato cerrado!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                 ]
             ] else ...[
                  const Text('Esperando oferta del artista...', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
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
}