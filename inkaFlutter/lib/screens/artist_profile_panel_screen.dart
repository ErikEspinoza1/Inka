import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import 'artist_profile_screen.dart';
import 'menu_inicio.dart';
import '../widgets/feedback_modal.dart';

class ArtistProfilePanelScreen extends StatefulWidget {
  const ArtistProfilePanelScreen({super.key});

  @override
  State<ArtistProfilePanelScreen> createState() => _ArtistProfilePanelScreenState();
}

class _ArtistProfilePanelScreenState extends State<ArtistProfilePanelScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await _authService.getArtistProfile();
    setState(() {
      _profileData = data;
      _isLoading = false;
    });
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
        await _loadProfile(); // Recargar el perfil para mostrar la nueva foto
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Foto de perfil actualizada'), backgroundColor: Colors.green),
          );
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text('Error al subir la foto'), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profileData == null
              ? const Center(child: Text('Error al cargar perfil', style: TextStyle(color: Colors.white)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Foto de perfil o avatar
                      Center(
                        child: GestureDetector(
                          onTap: _pickAndUploadAvatar,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 50,
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                backgroundImage: _profileData!['avatar_url'] != null ? NetworkImage(_profileData!['avatar_url']) : null,
                                child: _profileData!['avatar_url'] == null
                                  ? Text(
                                      _profileData!['shop_name']?.substring(0, 1).toUpperCase() ?? 'A',
                                      style: TextStyle(fontSize: 40, color: Theme.of(context).colorScheme.onPrimary),
                                    )
                                  : null,
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.black, width: 2),
                                ),
                                child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Información del perfil
                      _infoTile('Nombre del Estudio', _profileData!['shop_name'] ?? 'No especificado'),
                      _infoTile('Instagram', _profileData!['instagram_handle'] ?? 'No especificado'),
                      _infoTile('CIF / DNI', _profileData!['business_license_id'] ?? 'No especificado'),
                      _infoTile('Biografía', _profileData!['bio'] ?? 'No especificada'),
                      _infoTile('Dirección', _profileData!['address'] ?? 'No especificada'),
                      _infoTile('Horario Laboral', '${_profileData!['working_hours_start'] ?? '09:00'} - ${_profileData!['working_hours_end'] ?? '18:00'}'),
                      _infoTile('Estado de Verificación',
                          _profileData!['is_verified'] == true ? '✅ Verificado' : '⏳ Pendiente'),

                      const SizedBox(height: 40),
                      // Botones de acción
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ArtistProfileScreen()),
                            ).then((_) => _loadProfile()); // Recargar al volver
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Editar Perfil'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
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
                      const SizedBox(height: 16),
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

  Widget _infoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
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
}