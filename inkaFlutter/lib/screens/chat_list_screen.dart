import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchCtrl = TextEditingController();

  List<dynamic> _artists = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadArtists();
  }

  Future<void> _loadArtists() async {
    setState(() => _isLoading = true);
    final contacts = await _authService.getMessageContacts();
    if (mounted) {
      setState(() {
        _artists = contacts ?? [];
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _filteredArtists {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _artists;
    return _artists.where((contact) {
      // Buscar por nombre (shop_name si es artista, full_name si es cliente)
      final shopName = (contact['shop_name'] ?? '').toString().toLowerCase();
      final fullName = (contact['full_name'] ?? '').toString().toLowerCase();
      final name = shopName.isNotEmpty ? shopName : fullName;
      
      // Buscar por estilos si es artista
      final styles = (contact['styles'] ?? []).join(' ').toString().toLowerCase();
      
      return name.contains(query) || styles.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Buscar artista...',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredArtists.isEmpty
                      ? const Center(
                          child: Text(
                            'No se encontraron artistas.\nIntenta con otra búsqueda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredArtists.length,
                          itemBuilder: (context, index) {
                            final contact = _filteredArtists[index];
                            final isArtist = contact['shop_name'] != null;
                            final name = isArtist 
                                ? contact['shop_name'] ?? 'Artista' 
                                : contact['full_name'] ?? 'Usuario';
                            final styles = (contact['styles'] as List?) ?? [];
                            final specialty = styles.isNotEmpty ? styles.join(' • ') : '';
                            final unreadCount = contact['unread_count'] ?? 0;

                            return Card(
                              child: ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                title: Text(
                                  name,
                                  style: TextStyle(
                                      fontWeight: unreadCount > 0 ? FontWeight.w900 : FontWeight.bold),
                                ),
                                subtitle: isArtist && specialty.isNotEmpty
                                    ? Text(
                                        specialty,
                                        style: TextStyle(
                                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      )
                                    : null,
                                trailing: unreadCount > 0
                                    ? Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Text(
                                          unreadCount.toString(),
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onPrimary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Icon(Icons.chat, color: Theme.of(context).colorScheme.primary),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ChatScreen(
                                        artistId: contact['id'].toString(),
                                        artistName: name,
                                      ),
                                    ),
                                  );
                                  // Recargar al volver para quitar el globo rojo si se han leído
                                  _loadArtists();
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
