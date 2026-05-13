import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/interaction_service.dart';
import 'menu_inicio.dart';
import 'explore_screen.dart'; // Para importar FullScreenFeedScreen

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
  bool _isLoading = true;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await _authService.getCurrentUserProfile();
    final favs = await _interactionService.getMyFavorites();

    setState(() {
      _profileData = data;
      _favorites = favs;
      if (data != null) {
        _nameCtrl.text = data['full_name'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
      }
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    final success = await _authService.updateUserProfile({
      'full_name': _nameCtrl.text,
      'email': _emailCtrl.text,
    });

    if (success) {
      setState(() => _isEditing = false);
      await _loadData(); 
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente'), backgroundColor: Colors.green),
        );
      }
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Error al actualizar perfil'), backgroundColor: Theme.of(context).colorScheme.error),
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_profileData == null) {
      return const Scaffold(body: Center(child: Text('Error al cargar perfil')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mi Perfil'),
          actions: [
            if (!_isEditing)
              IconButton(
                icon: Icon(Icons.edit, color: Theme.of(context).colorScheme.primary),
                onPressed: () => setState(() => _isEditing = true),
              )
            else
              IconButton(
                icon: const Icon(Icons.save, color: Colors.green),
                onPressed: _saveProfile,
              ),
            IconButton(
              icon: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
              onPressed: _logout,
            )
          ],
        ),
        body: Column(
          children: [
            // --- HEADER DEL PERFIL ---
            const SizedBox(height: 16),
            CircleAvatar(
              radius: 40,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                _profileData!['full_name']?.substring(0, 1).toUpperCase() ?? 'U',
                style: TextStyle(fontSize: 32, color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _profileData!['full_name'] ?? 'Usuario',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              _profileData!['role'] ?? 'Cliente',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
              ),
            ),
            const SizedBox(height: 16),
            
            // --- TABS ---
            const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.person), text: "Info"),
                Tab(icon: Icon(Icons.bookmark), text: "Guardados"),
              ],
            ),
            
            // --- CONTENIDO DE LAS TABS ---
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Info Personal
                  _buildProfileInfoTab(),
                  // Tab 2: Favoritos
                  _buildFavoritesTab(),
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
              _buildTextField('Nombre completo', _nameCtrl, Icons.person, _isEditing),
              const SizedBox(height: 16),
              _buildTextField('Email', _emailCtrl, Icons.email, _isEditing),
              const SizedBox(height: 16),
              _buildInfoTile('Tipo de cuenta', _profileData!['role'] ?? 'Cliente'),
              _buildInfoTile('Fecha de registro', _formatDate(_profileData!['created_at'])),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    if (_favorites.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 60, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
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
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final post = _favorites[index];
        return GestureDetector(
          onTap: () {
            // Abrir vista TikTok
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenFeedScreen(
                  posts: _favorites,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Image.network(
            post['image_url'] ?? '',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Theme.of(context).colorScheme.surfaceVariant,
              child: const Icon(Icons.broken_image, color: Colors.white30),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, bool enabled) {
    return TextField(
      controller: controller,
      enabled: enabled,
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
            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
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