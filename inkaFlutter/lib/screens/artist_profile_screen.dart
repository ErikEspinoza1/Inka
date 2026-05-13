import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';
import 'package:image_picker/image_picker.dart'; 
import 'dart:io';

class ArtistProfileScreen extends StatefulWidget {
  const ArtistProfileScreen({super.key});

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isLoading = false;

  // Controladores Generales
  final _shopNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _instaCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();

  // Controladores Dirección
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Estado
  bool _hasPhysicalShop = true; 
  String _certificateStatus = "Pendiente"; 
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  // Cargar datos existentes desde la API
  void _loadCurrentData() async {
    setState(() => _isLoading = true);

    final data = await _authService.getArtistProfile();

    if (data != null) {
      // 1. Rellenar textos simples
      _shopNameCtrl.text = data['shop_name'] ?? '';
      _bioCtrl.text = data['bio'] ?? '';
      _instaCtrl.text = data['instagram_handle'] ?? '';
      _licenseCtrl.text = data['business_license_id'] ?? '';
      
      // 2. Estado de verificación inicial
      if (data['is_verified'] == true) {
        _certificateStatus = "✅ Verificado";
      } else if (data['business_document_url'] != null) {
        _certificateStatus = "⏳ Pendiente de revisión";
      }

      // 3. Configurar Switch
      String type = data['workspace_type'] ?? 'shop';
      setState(() {
        _hasPhysicalShop = (type == 'shop');
      });

      // 4. Truco para "Desempaquetar" la dirección
      String fullAddress = data['address'] ?? '';
      if (fullAddress.isNotEmpty) {
        if (_hasPhysicalShop) {
          List<String> parts = fullAddress.split(',');
          if (parts.length >= 3) {
            _streetCtrl.text = parts[0].trim();
            _zipCtrl.text = parts[1].trim();
            _cityCtrl.text = parts.sublist(2).join(',').trim();
          } else {
            _streetCtrl.text = fullAddress;
          }
        } else {
          // Si es móvil
          List<String> parts = fullAddress.split(',');
          if (parts.length >= 2) {
             _cityCtrl.text = parts[0].trim();
             _zipCtrl.text = parts[1].trim();
          } else {
             _cityCtrl.text = fullAddress;
          }
        }
      }
    }

    setState(() => _isLoading = false);
  }

  // Guardar Cambios (PATCH)
  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

    // 1. Construir dirección
    String finalAddress;
    if (_hasPhysicalShop) {
      finalAddress = "${_streetCtrl.text} ${_numberCtrl.text}, ${_zipCtrl.text}, ${_cityCtrl.text}";
    } else {
      finalAddress = "${_cityCtrl.text}, ${_zipCtrl.text}";
    }

    // 2. Geolocalizar
    double lat = 0.0, lng = 0.0;
    try {
      List<Location> locations = await locationFromAddress(finalAddress);
      if (locations.isNotEmpty) {
        lat = locations.first.latitude;
        lng = locations.first.longitude;
      }
    } catch (e) {
      debugPrint("Error geo: $e");
    }

    // 3. JSON Data
    final data = {
      if (_shopNameCtrl.text.isNotEmpty) 'shop_name': _shopNameCtrl.text,
      if (_bioCtrl.text.isNotEmpty) 'bio': _bioCtrl.text,
      if (_instaCtrl.text.isNotEmpty) 'instagram_handle': _instaCtrl.text,
      if (_licenseCtrl.text.isNotEmpty) 'business_license_id': _licenseCtrl.text,
      
      'address': finalAddress,
      'latitude': lat,
      'longitude': lng,
      'workspace_type': _hasPhysicalShop ? 'shop' : 'mobile',
      'show_exact_location': _hasPhysicalShop,
    };

    // 4. Enviar
    final success = await _authService.updateArtistProfile(data);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente ✅'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Error al guardar'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  // Seleccionar foto y subir (IA)
  Future<void> _pickAndUploadCertificate() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _selectedImage = File(image.path);
      _certificateStatus = "Subiendo y Analizando con IA...";
      _isLoading = true;
    });

    final response = await _authService.uploadCertificate(image.path);

    setState(() {
      _isLoading = false;
      
      if (response != null && response['status'] == 'success') {
        final analysisText = response['ai_analysis'];
        final verified = response['is_verified'] == true;
        
        _certificateStatus = verified 
            ? "✅ $analysisText" 
            : "⚠️ $analysisText";
            
        if (verified) _loadCurrentData(); // Recargar si se aprobó
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Resultado IA: $analysisText"),
              backgroundColor: verified ? Colors.green : Theme.of(context).colorScheme.secondary,
            ),
          );
        }
      } else {
        _certificateStatus = "❌ Error al subir";
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text("Error al subir imagen"), backgroundColor: Theme.of(context).colorScheme.error),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Perfil Artista"),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: Theme.of(context).colorScheme.primary),
            onPressed: _saveProfile,
          )
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle("Datos del Estudio"),
                _inputField("Nombre del Estudio / Artista", _shopNameCtrl, Icons.store),
                _inputField("Instagram (@usuario)", _instaCtrl, Icons.camera_alt),
                _inputField("CIF / DNI del Titular", _licenseCtrl, Icons.badge_outlined),
                _inputField("Biografía corta", _bioCtrl, Icons.text_fields, maxLines: 3),

                const SizedBox(height: 30),
                _sectionTitle("Ubicación & Tipo"),
                
                SwitchListTile(
                  title: const Text("¿Tienes un local físico fijo?"),
                  subtitle: Text(
                    _hasPhysicalShop ? "La dirección exacta será pública" : "Modo Viajero/Privado (Solo se muestra ciudad)",
                  ),
                  value: _hasPhysicalShop,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) => setState(() => _hasPhysicalShop = val),
                ),
                
                const SizedBox(height: 10),
                
                if (_hasPhysicalShop) ...[
                  Row(
                    children: [
                      Expanded(flex: 2, child: _inputField("Calle", _streetCtrl, Icons.map)),
                      const SizedBox(width: 10),
                      Expanded(flex: 1, child: _inputField("Nº", _numberCtrl, Icons.home_filled)),
                    ],
                  ),
                ],
                Row(
                  children: [
                    Expanded(child: _inputField("Ciudad", _cityCtrl, Icons.location_city)),
                    const SizedBox(width: 10),
                    Expanded(child: _inputField("CP", _zipCtrl, Icons.mark_as_unread)),
                  ],
                ),

                const SizedBox(height: 30),
                _sectionTitle("Certificación Higiénico Sanitaria"),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.redAccent),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "IMPORTANTE: Al subir tu certificado, declaras bajo juramento que es original y vigente. La falsificación conlleva expulsión inmediata. La IA validará el documento automáticamente.",
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 180),
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _certificateStatus.contains("✅") ? Colors.green : Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), 
                        style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_selectedImage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(_selectedImage!, height: 60, width: 60, fit: BoxFit.cover),
                          ),
                        )
                      else
                        Icon(Icons.document_scanner, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 40),
                      
                      const SizedBox(height: 8),
                      
                      TextButton.icon(
                        onPressed: _pickAndUploadCertificate,
                        icon: Icon(Icons.upload_file, color: Theme.of(context).colorScheme.primary),
                        label: Text("Subir y Verificar con IA", style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          "Estado: $_certificateStatus",
                          style: TextStyle(
                            color: _certificateStatus.contains("✅") ? Colors.green : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 50),
              ],
            ),
          ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, IconData icon, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
        ),
      ),
    );
  }
}