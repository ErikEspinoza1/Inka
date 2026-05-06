import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'menu_inicio.dart';

class ClientProfileScreen extends StatefulWidget {
  const ClientProfileScreen({super.key});

  @override
  State<ClientProfileScreen> createState() => _ClientProfileScreenState();
}

class _ClientProfileScreenState extends State<ClientProfileScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _authService.getCurrentUserProfile();
    setState(() {
      _profileData = data;
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

    setState(() => _isLoading = false);

    if (success) {
      setState(() => _isEditing = false);
      _loadProfile(); // Recargar datos
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Perfil actualizado correctamente'), backgroundColor: Colors.green),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Error al actualizar perfil'), backgroundColor: Theme.of(context).colorScheme.error),
      );
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
    return Scaffold(
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
              icon: Icon(Icons.save, color: Colors.green),
              onPressed: _saveProfile,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
              ? const Center(
                  child: Text('Error al cargar perfil', style: TextStyle(color: Colors.white)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar y nombre
                      Center(
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: Text(
                                _profileData!['full_name']?.substring(0, 1).toUpperCase() ?? 'U',
                                style: TextStyle(fontSize: 40, color: Theme.of(context).colorScheme.onPrimary),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _profileData!['full_name'] ?? 'Usuario',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            Text(
                              _profileData!['role'] ?? 'Cliente',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Información editable
                      _buildProfileSection(),

                      const SizedBox(height: 40),

                      // Botón cerrar sesión
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _logout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Cerrar Sesión'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).colorScheme.error),
                            foregroundColor: Theme.of(context).colorScheme.error,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
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