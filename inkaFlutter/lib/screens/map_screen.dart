import 'dart:convert'; // Para decodificar el JSON
import 'dart:ui' as ui; // Para Glassmorphism
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http; // Para hacer la petición a la API
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importar
import '../services/auth_service.dart';
import 'artist_profile_view_screen.dart';
import 'booking_screen.dart';
import 'chat_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  final AuthService _authService = AuthService();

  // ⚠️ CAMBIA ESTO POR TU IP LOCAL SI CAMBIA
  final String _apiUrl = '${dotenv.env['API_URL']}/artists/';
  
  // Ubicación inicial (Barcelona)
  final LatLng _defaultLocation = const LatLng(41.3879, 2.1699);
  LatLng? _currentPosition;

  // Estado de los datos
  List<TattooArtist> _allArtists = []; // Lista vacía al inicio
  List<TattooArtist> _filteredArtists = [];
  bool _isLoading = true; // Para mostrar carga al inicio

  final TextEditingController _searchCtrl = TextEditingController();
  TattooArtist? _selectedArtist;

  @override
  void initState() {
    super.initState();
    // 1. Cargar artistas de la API
    _fetchArtists();

    // 2. Obtener ubicación del usuario
    _determinePosition().then((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
      }
    }).catchError((e) {
      debugPrint('Error obteniendo ubicación: $e');
    });
  }

  // --- NUEVA FUNCIÓN: CARGAR DATOS REALES ---
  Future<void> _fetchArtists() async {
    try {
      final response = await http.get(Uri.parse(_apiUrl));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        // Convertimos el JSON a objetos TattooArtist
        final List<TattooArtist> loadedArtists = data.map((json) {
          return TattooArtist.fromJson(json);
        }).toList();

        if (mounted) {
          setState(() {
            _allArtists = loadedArtists;
            _filteredArtists = loadedArtists; // Al principio mostramos todos
            _isLoading = false;
          });
        }
      } else {
        debugPrint("Error API: ${response.statusCode}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error conexión: $e");
      setState(() => _isLoading = false);
    }
  }

  void _filterArtists(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredArtists = _allArtists.where((artist) {
        // Buscamos por nombre o por estilo
        return artist.name.toLowerCase().contains(lowerQuery) ||
            artist.specialty.toLowerCase().contains(lowerQuery);
      }).toList();
      _selectedArtist = null;
    });
  }

  Future<void> _onMarkerTapped(TattooArtist artist) async {
    setState(() => _selectedArtist = artist);
    _animatedMapMove(artist.position, 15.5);
    await _showArtistBottomSheet(artist);
    if (mounted) {
      setState(() => _selectedArtist = null);
    }
  }

  Future<void> _showArtistBottomSheet(TattooArtist artist) async {
    final portfolio = await _authService.getArtistPortfolio(artist.id);

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          height: 4,
                          width: 48,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  artist.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  artist.specialty,
                                  style: const TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.verified, color: Colors.green),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (portfolio != null && portfolio.isNotEmpty) ...[
                        SizedBox(
                          height: 170,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: portfolio.length,
                            itemBuilder: (context, index) {
                              final item = portfolio[index];
                              return Container(
                                width: 140,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  image: DecorationImage(
                                    image: NetworkImage(item['image_url']),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else ...[
                        const Text(
                          'Este artista aún no tiene fotos en su portfolio.',
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArtistProfileViewScreen(artistId: artist.id),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                              ),
                              child: const Text('Ver perfil'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingScreen(
                                      artistId: artist.id,
                                      artistName: artist.name,
                                    ),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.tealAccent),
                              ),
                              child: const Text('Reservar'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  artistId: artist.id,
                                  artistName: artist.name,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message, color: Colors.tealAccent),
                          label: const Text('Chatear con el artista', style: TextStyle(color: Colors.tealAccent)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.tealAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onMapTap() {
    if (_selectedArtist != null) {
      setState(() {
        _selectedArtist = null;
      });
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    _mapController.move(destLocation, destZoom);
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('GPS desactivado');

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Permisos denegados');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Permisos denegados permanentemente');
    }
    return await Geolocator.getCurrentPosition();
  }

  void _centerOnUser() async {
    try {
      final pos = await _determinePosition();
      final userPos = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentPosition = userPos);
      _mapController.move(userPos, 16.0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: Stack(
        children: [
          // 1. EL MAPA
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _defaultLocation,
              initialZoom: 13.0,
              interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, __) => _onMapTap(),
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.inka.app',
                keepBuffer: 10,
                panBuffer: 2,
                tileDisplay: const TileDisplay.fadeIn(
                    duration: Duration(milliseconds: 300)),
              ),
              MarkerLayer(
                markers: [
                  // --- MARCADORES ARTISTAS (REALES) ---
                  ..._filteredArtists.map((artist) {
                    final isSelected = _selectedArtist?.id == artist.id;
                    return Marker(
                      point: artist.position,
                      width: 120,
                      height: 100,
                      child: GestureDetector(
                        onTap: () => _onMarkerTapped(artist),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Icono/Avatar
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isSelected ? 60 : 45,
                              height: isSelected ? 60 : 45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1A1A1A),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF4A9DFF)
                                      : Colors.white,
                                  width: isSelected ? 3 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor: const Color(0xFF1A1A1A),
                                child: Text(
                                  artist.name.isNotEmpty
                                      ? artist.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: artist.imageColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                            // Etiqueta Nombre
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                artist.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF4A9DFF)
                                      : Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // --- MARCADOR USUARIO ---
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 60,
                      height: 60,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.my_location,
                            color: Colors.blueAccent),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. SEARCH BAR
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _glassContainer(
              child: Row(
                children: [
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.arrow_back, color: Colors.white54)),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _filterArtists,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Buscar por nombre o estilo...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)))
                      : const Icon(Icons.search, color: Color(0xFF4A9DFF)),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),

          // 3. BOTÓN GPS
          Positioned(
            right: 16,
            bottom: _selectedArtist != null ? 300 : 50,
            child: GestureDetector(
              onTap: _centerOnUser,
              child: _glassContainer(
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.my_location, color: Color(0xFF4A9DFF)),
              ),
            ),
          ),

        ],
      ),
    );
  }

  Widget _glassContainer(
      {required Widget child, EdgeInsets padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          color: Colors.white.withValues(alpha: 0.08),
          child: child,
        ),
      ),
    );
  }
}

// ==========================================
// 4. MODELO ACTUALIZADO PARA TU BASE DE DATOS
// ==========================================
class TattooArtist {
  final String id;
  final String name; // Mapped from 'shop_name'
  final String specialty; // Mapped from 'styles'
  final LatLng position; // Mapped from lat/lng
  final Color imageColor; // Generado aleatoriamente para UI

  TattooArtist({
    required this.id,
    required this.name,
    required this.specialty,
    required this.position,
    this.imageColor = Colors.purpleAccent, // Color por defecto
  });

  // Factory para convertir el JSON de la API en Objeto Dart
  factory TattooArtist.fromJson(Map<String, dynamic> json) {
    // 1. Manejar estilos (vienen como lista, cogemos el primero o un string unido)
    String stylesText = "Sin estilo definido";
    if (json['styles'] != null && (json['styles'] as List).isNotEmpty) {
      stylesText = (json['styles'] as List).join(" • ");
    }

    // 2. Determinar un color aleatorio o basado en el ID para que no sean todos iguales
    // Esto es puramente estético para el mapa
    final colors = [
      Colors.purpleAccent,
      Colors.tealAccent,
      Colors.orangeAccent,
      Colors.redAccent,
      Colors.blueAccent
    ];
    final colorIndex = (json['shop_name'] ?? "").length % colors.length;

    return TattooArtist(
      id: json['id'].toString(),
      name: json['shop_name'] ?? "Artista Desconocido",
      specialty: stylesText,
      // 3. Mapear coordenadas
      position: LatLng(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      ),
      imageColor: colors[colorIndex],
    );
  }
}
