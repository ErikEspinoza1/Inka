import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import '../services/auth_service.dart';

class ArtistProfileScreen extends StatefulWidget {
  const ArtistProfileScreen({super.key});

  @override
  State<ArtistProfileScreen> createState() => _ArtistProfileScreenState();
}

class _ArtistProfileScreenState extends State<ArtistProfileScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // Controladores Generales
  final _shopNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _instaCtrl = TextEditingController();

  // Controladores Dirección
  final _streetCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _zipCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();

  // Estado
  bool _hasPhysicalShop = true; // Switch para Local vs Furgo/Casa
  String _certificateStatus = "Pendiente"; // "Verificado", "Rechazado"

  @override
  void initState() {
    super.initState();
    _loadCurrentData();
  }

  void _loadCurrentData() async {
    setState(() => _isLoading = true);

    final data = await _authService.getArtistProfile();

    if (data != null) {
      // 1. Rellenar textos simples
      _shopNameCtrl.text = data['shop_name'] ?? '';
      _bioCtrl.text = data['bio'] ?? '';
      _instaCtrl.text = data['instagram_handle'] ?? '';

      // 2. Configurar Switch
      String type = data['workspace_type'] ?? 'shop';
      setState(() {
        _hasPhysicalShop = (type == 'shop');
      });

      // 3. Truco para "Desempaquetar" la dirección
      // Suponemos que guardamos: "Calle Falsa 123, 08020, Barcelona"
      String fullAddress = data['address'] ?? '';
      if (fullAddress.isNotEmpty) {
        if (_hasPhysicalShop) {
          // Intentamos separar por comas
          List<String> parts = fullAddress.split(',');

          if (parts.length >= 3) {
            // "Calle Falsa 123" -> parts[0]
            // " 08020" -> parts[1]
            // " Barcelona" -> parts[2]
            _streetCtrl.text = parts[0].trim();
            _zipCtrl.text = parts[1].trim();
            _cityCtrl.text = parts
                .sublist(2)
                .join(',')
                .trim(); // Por si la ciudad tiene comas
          } else {
            // Si el formato no cuadra, ponemos todo en calle para que no se pierda
            _streetCtrl.text = fullAddress;
          }
        } else {
          // Si es móvil, guardamos "Ciudad, CP"
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

  Future<void> _saveProfile() async {
    setState(() => _isLoading = true);

// 1. Construir dirección (CON COMAS)
    String finalAddress;
    if (_hasPhysicalShop) {
      // Formato: Calle + num, CP, Ciudad
      finalAddress =
          "${_streetCtrl.text} ${_numberCtrl.text}, ${_zipCtrl.text}, ${_cityCtrl.text}";
    } else {
      // Formato: Ciudad, CP
      finalAddress = "${_cityCtrl.text}, ${_zipCtrl.text}";
    }

    // 2. Geolocalizar (Geocoding)
    double lat = 0.0, lng = 0.0;
    try {
      List<Location> locations = await locationFromAddress(finalAddress);
      if (locations.isNotEmpty) {
        lat = locations.first.latitude;
        lng = locations.first.longitude;
      }
    } catch (e) {
      print("Error geo: $e");
    }

    // 3. Preparar JSON
    final data = {
      if (_shopNameCtrl.text.isNotEmpty) 'shop_name': _shopNameCtrl.text,
      if (_bioCtrl.text.isNotEmpty) 'bio': _bioCtrl.text,
      if (_instaCtrl.text.isNotEmpty) 'instagram_handle': _instaCtrl.text,

      'address': finalAddress,
      'latitude': lat,
      'longitude': lng,
      'workspace_type': _hasPhysicalShop ? 'shop' : 'mobile',
      'show_exact_location':
          _hasPhysicalShop, // Si es móvil, ocultamos ubicación exacta
    };

    // 4. Enviar
    final success = await _authService.updateArtistProfile(data);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado correctamente ✅')),
      );
      Navigator.pop(context); // Volver atrás
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Error al guardar'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Editar Perfil Artista"),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.purpleAccent),
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
                  _inputField("Nombre del Estudio / Artista", _shopNameCtrl,
                      Icons.store),
                  _inputField(
                      "Instagram (@usuario)", _instaCtrl, Icons.camera_alt),
                  _inputField("Biografía corta", _bioCtrl, Icons.text_fields,
                      maxLines: 3),

                  const SizedBox(height: 30),
                  _sectionTitle("Ubicación & Tipo"),

                  // SWITCH TIPO DE ESPACIO
                  SwitchListTile(
                    title: const Text("¿Tienes un local físico fijo?",
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      _hasPhysicalShop
                          ? "La dirección exacta será pública"
                          : "Modo Viajero/Privado (Solo se muestra ciudad)",
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    value: _hasPhysicalShop,
                    activeColor: Colors.purpleAccent,
                    onChanged: (val) => setState(() => _hasPhysicalShop = val),
                  ),

                  const SizedBox(height: 10),

                  // FORMULARIO DIRECCIÓN (CONDICIONAL)
                  if (_hasPhysicalShop) ...[
                    Row(
                      children: [
                        Expanded(
                            flex: 2,
                            child:
                                _inputField("Calle", _streetCtrl, Icons.map)),
                        const SizedBox(width: 10),
                        Expanded(
                            flex: 1,
                            child: _inputField(
                                "Nº", _numberCtrl, Icons.home_filled)),
                      ],
                    ),
                  ],
                  Row(
                    children: [
                      Expanded(
                          child: _inputField(
                              "Ciudad", _cityCtrl, Icons.location_city)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _inputField(
                              "CP", _zipCtrl, Icons.mark_as_unread)),
                    ],
                  ),

                  const SizedBox(height: 30),
                  _sectionTitle("Certificación Higiénico Sanitaria"),

                  // TARJETA DE AVISO LEGAL
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      border: Border.all(color: Colors.redAccent),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber,
                            color: Colors.redAccent, size: 30),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            "IMPORTANTE: Al subir tu certificado, declaras bajo juramento que es original y vigente. La falsificación de documentos sanitarios conlleva expulsión inmediata y reporte a las autoridades. Inka almacena este documento por seguridad.",
                            style:
                                TextStyle(color: Colors.red[100], fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // SIMULACIÓN DE SUBIDA E IA
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white24, style: BorderStyle.solid),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.document_scanner,
                            color: Colors.white54, size: 40),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            // AQUÍ IRÁ LA LÓGICA DE IMAGE_PICKER Y GOOGLE ML KIT
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text("Simulando escaneo IA... 🤖")),
                            );
                          },
                          child: const Text("Subir y Verificar con IA",
                              style: TextStyle(color: Colors.purpleAccent)),
                        ),
                        Text("Estado: $_certificateStatus",
                            style: const TextStyle(color: Colors.grey)),
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
      child: Text(title,
          style: const TextStyle(
              color: Colors.tealAccent,
              fontSize: 16,
              fontWeight: FontWeight.bold)),
    );
  }

  Widget _inputField(String label, TextEditingController ctrl, IconData icon,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.white54),
          labelStyle: const TextStyle(color: Colors.white54),
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
