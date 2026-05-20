import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/interaction_service.dart';
import '../providers/interaction_provider.dart';
import 'menu_inicio.dart';
import 'explore_screen.dart';
import 'artist_profile_view_screen.dart';
import '../widgets/feedback_modal.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final AuthService _authService = AuthService();
  final InteractionService _interactionService = InteractionService();

  Map<String, dynamic>? _profileData;
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _following = [];
  bool _isLoading = true;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _authService.getCurrentUserProfile();
    final favs = await _interactionService.getMyFavorites();
    final follows = await _interactionService.getMyFollowing();

    setState(() {
      _profileData = data;
      _favorites = favs;
      _following = follows;
      if (data != null) {
        _nameCtrl.text = data['full_name'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _unsaveFavorite(String postId) async {
    // Actualizar el Provider global para que se refleje en todas las pantallas
    context.read<InteractionProvider>().toggleSave(postId);

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Eliminado de favoritos'),
            duration: Duration(seconds: 2)),
      );
    }
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    final success = await _authService.updateUserProfile({
      'full_name': _nameCtrl.text,
      // El email ya no lo enviamos porque es solo lectura según el usuario
      if (_newPassCtrl.text.isNotEmpty)
        'current_password': _currentPassCtrl.text,
      if (_newPassCtrl.text.isNotEmpty) 'new_password': _newPassCtrl.text,
    });

    if (success) {
      setState(() {
        _isEditing = false;
        _currentPassCtrl.clear();
        _newPassCtrl.clear();
      });
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Perfil actualizado correctamente'),
              backgroundColor: Colors.green),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text(
                  'Error al actualizar perfil. Verifica los datos o la contraseña actual.'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MenuInicio()),
        (route) => false,
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() => _isLoading = true);

      final success = await _authService.uploadAvatar(pickedFile.path);

      if (success) {
        await _loadData(); // Recargar el perfil para mostrar la nueva foto
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Foto de perfil actualizada'),
                backgroundColor: Colors.green),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: const Text('Error al subir la foto'),
                backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profileData == null) {
      return const Scaffold(
          body: Center(child: Text('Error al cargar perfil')));
    }

    final avatarUrl = _profileData!['avatar_url'];

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Perfil'),
          actions: [
            if (!_isEditing)
              IconButton(
                icon: Icon(Icons.edit,
                    color: Theme.of(context).colorScheme.primary),
                onPressed: () => setState(() => _isEditing = true),
              )
            else
              IconButton(
                icon: const Icon(Icons.save, color: Colors.green),
                onPressed: _saveProfile,
              ),
            IconButton(
              icon: Icon(Icons.logout,
                  color: Theme.of(context).colorScheme.error),
              onPressed: _logout,
            )
          ],
        ),
        body: Column(
          children: [
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickAndUploadAvatar,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Text(
                            _profileData!['full_name']
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: TextStyle(
                                fontSize: 32,
                                color: Theme.of(context).colorScheme.onPrimary),
                          )
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.secondary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt,
                        size: 16, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _profileData!['full_name'] ?? 'Usuario',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              _profileData!['role'] ?? 'Cliente',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.person), text: "Info"),
                Tab(icon: Icon(Icons.bookmark), text: "Guardados"),
                Tab(icon: Icon(Icons.people), text: "Siguiendo"),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildProfileInfoTab(),
                  _buildFavoritesTab(),
                  _buildFollowingTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Información Personal',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildTextField(
                  'Nombre completo', _nameCtrl, Icons.person, _isEditing),
              const SizedBox(height: 16),
              _buildTextField('Email', _emailCtrl, Icons.email,
                  false), // Siempre false (lectura)
              if (_isEditing) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Cambiar Contraseña',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildTextField('Contraseña Actual', _currentPassCtrl,
                    Icons.lock_outline, true,
                    isPassword: true),
                const SizedBox(height: 12),
                _buildTextField(
                    'Nueva Contraseña', _newPassCtrl, Icons.lock, true,
                    isPassword: true),
              ],
              const SizedBox(height: 24),
              _buildInfoTile('Fecha de registro', _formatDate(_profileData!['created_at'])),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => showFeedbackModal(context),
                  icon: const Icon(Icons.lightbulb_outline),
                  label: const Text('Enviar Sugerencia o Reportar Fallo'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    return Consumer<InteractionProvider>(
      builder: (context, provider, _) {
        final activeFavorites = _favorites.where((post) {
          final postId = post['id']?.toString() ?? '';
          return provider.isSaved(postId);
        }).toList();

        if (activeFavorites.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 60, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text('Aún no has guardado ningún tatuaje.'),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: activeFavorites.length,
          itemBuilder: (context, index) {
            final post = activeFavorites[index];
            final postId = post['id']?.toString() ?? '';
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FullScreenFeedScreen(
                      posts: activeFavorites,
                      initialIndex: index,
                    ),
                  ),
                );
              },
              onLongPress: () => _showUnsaveDialog(postId),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    post['image_url'] ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image, color: Colors.white30),
                    ),
                  ),
                  const Positioned(
                    top: 4, right: 4,
                    child: Icon(Icons.bookmark, color: Colors.amber, size: 20),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showUnsaveDialog(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar de guardados?'),
        content: const Text('Este tatuaje desaparecerá de tu colección.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _unsaveFavorite(postId);
            },
            child: Text('Eliminar',
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowingTab() {
    // Filtrar la lista localmente usando el Provider para reactividad
    return Consumer<InteractionProvider>(
      builder: (context, provider, _) {
        // Filtrar artistas que ya no se siguen (por si se dejó de seguir desde el perfil)
        final activeFollowing = _following.where((a) {
          final id = a['id']?.toString() ?? '';
          return provider.isFollowing(id);
        }).toList();

        if (activeFollowing.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline,
                    size: 60,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                const Text('Aún no sigues a ningún artista.'),
                const SizedBox(height: 8),
                const Text('Pulsa el + en el feed para seguir tatuadores.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: activeFollowing.length,
          itemBuilder: (context, index) {
            final artist = activeFollowing[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  backgroundImage: artist['avatar_url'] != null
                      ? NetworkImage(artist['avatar_url'])
                      : null,
                  child: artist['avatar_url'] == null
                      ? Text(
                          artist['shop_name']?.substring(0, 1).toUpperCase() ??
                              'A',
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimary,
                              fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        artist['shop_name'] ?? 'Artista',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (artist['is_verified'] == true)
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified,
                            size: 18,
                            color: Theme.of(context).colorScheme.secondary),
                      ),
                  ],
                ),
                subtitle: Text(
                  (artist['styles'] as List?)?.join(' · ') ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ArtistProfileViewScreen(artistId: artist['id']),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      IconData icon, bool enabled,
      {bool isPassword = false}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
          const Divider(),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Desconocida';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Desconocida';
    }
  }
}
