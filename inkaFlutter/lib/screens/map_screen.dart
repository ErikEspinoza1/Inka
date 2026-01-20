import 'dart:ui' as ui; // Para Glassmorphism
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // Importar Geolocator
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();
  // final PageController _pageController = PageController(viewportFraction: 0.85); // YA NO SE USA
  
  // Ubicación inicial (Barcelona)
  final LatLng _defaultLocation = const LatLng(41.3879, 2.1699);
  LatLng? _currentPosition;

  // Lista MAESTRA de tatuadores
  final List<TattooArtist> _allArtists = [
    TattooArtist(
      id: '1',
      name: 'Ink Master BCN',
      specialty: 'Realismo • 1.2km',
      rating: 4.8,
      position: const LatLng(41.3879, 2.1699), 
      imageColor: Colors.purpleAccent,
    ),
    TattooArtist(
      id: '2',
      name: 'Dark Art Gràcia',
      specialty: 'Blackwork • 0.8km',
      rating: 4.5,
      position: const LatLng(41.4036, 2.1554), 
      imageColor: Colors.tealAccent, 
    ),
    TattooArtist(
      id: '3',
      name: 'Gótico Ink',
      specialty: 'Watercolor • 2.5km',
      rating: 4.9,
      position: const LatLng(41.3825, 2.1769), 
      imageColor: Colors.orangeAccent,
    ),
    TattooArtist(
      id: '4',
      name: 'Traditional Sants',
      specialty: 'Old School • 3.0km',
      rating: 4.7,
      position: const LatLng(41.3750, 2.1350), 
      imageColor: Colors.redAccent,
    ),
  ];

  List<TattooArtist> _filteredArtists = [];
  final TextEditingController _searchCtrl = TextEditingController();
  
  // ESTADO NUEVO: Artista seleccionado para mostrar la tarjeta flotante
  TattooArtist? _selectedArtist;

  @override
  void initState() {
    super.initState();
    _filteredArtists = _allArtists; 

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

  void _filterArtists(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredArtists = _allArtists.where((artist) {
        return artist.name.toLowerCase().contains(lowerQuery) || 
               artist.specialty.toLowerCase().contains(lowerQuery);
      }).toList();
      _selectedArtist = null; // Cerrar tarjeta si se busca
    });
  }

  // Al tocar marcador -> Seleccionar artista y centrar
  void _onMarkerTapped(TattooArtist artist) {
    setState(() {
      _selectedArtist = artist;
    });
    _animatedMapMove(artist.position, 15.5);
  }

  // Cerrar tarjeta al tocar el mapa vacío
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
      if (permission == LocationPermission.denied) return Future.error('Permisos denegados');
    }
    
    if (permission == LocationPermission.deniedForever) return Future.error('Permisos denegados permanentemente');
    return await Geolocator.getCurrentPosition();
  }

  void _centerOnUser() async {
    try {
      final pos = await _determinePosition();
      final userPos = LatLng(pos.latitude, pos.longitude);
      setState(() => _currentPosition = userPos);
      _mapController.move(userPos, 16.0);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
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
              initialZoom: 14.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, __) => _onMapTap(), // Cerrar tarjeta al tocar fuera
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.inka.app',
                keepBuffer: 10, 
                panBuffer: 2,   
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 300)), 
              ),
              
              MarkerLayer(
                markers: [
                  // --- MARCADORES CON ETIQUETAS ---
                  ..._filteredArtists.map((artist) {
                    final isSelected = _selectedArtist?.id == artist.id;
                    return Marker(
                      point: artist.position,
                      width: 120, // Más ancho para el texto
                      height: 100, // Más alto para incluir texto abajo
                      child: GestureDetector(
                        onTap: () => _onMarkerTapped(artist),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // 1. El Icono/Avatar
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: isSelected ? 60 : 45,
                              height: isSelected ? 60 : 45,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1A1A1A),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFF4A9DFF) : Colors.white,
                                  width: isSelected ? 3 : 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 8,
                                  )
                                ],
                              ),
                              child: CircleAvatar(
                                backgroundColor: const Color(0xFF1A1A1A),
                                child: Text(
                                  artist.name[0],
                                  style: TextStyle(
                                    color: artist.imageColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            // 2. La Etiqueta de Nombre (Siempre visible o solo en zoom alto?)
                            // Lo ponemos siempre visible como pidió el usuario.
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                artist.name,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isSelected ? const Color(0xFF4A9DFF) : Colors.white,
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
                          color: Colors.blueAccent.withOpacity(0.3),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.my_location, color: Colors.blueAccent),
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
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, color: Colors.white54)),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _filterArtists,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Buscar 'Blackwork'...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  const Icon(Icons.search, color: Color(0xFF4A9DFF)),
                  const SizedBox(width: 16),
                ],
              ),
            ),
          ),

          // 3. BOTÓN GPS
          Positioned(
            right: 16,
            bottom: _selectedArtist != null ? 300 : 50, // Se mueve sutilmente si hay card
            child: GestureDetector(
              onTap: _centerOnUser,
              child: _glassContainer(
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.my_location, color: Color(0xFF4A9DFF)),
              ),
            ),
          ),

          // 4. TARJETA DE DETALLE EXPANDIBLE (Solo aparece al clickar)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOutBack,
            bottom: _selectedArtist != null ? 30 : -400, // Se oculta abajo
            left: 16,
            right: 16,
            child: _selectedArtist != null 
                ? _buildDetailCard(_selectedArtist!) 
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(TattooArtist artist) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 20, spreadRadius: 2),
        ],
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Se ajusta al contenido
        children: [
          // Cabecera: Info Artista
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: BoxDecoration(
                    color: artist.imageColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.palette, color: artist.imageColor, size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        artist.specialty,
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Botón Cerrar (X) pequeña
                GestureDetector(
                  onTap: () => setState(() => _selectedArtist = null),
                  child: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
          ),
          
          // Galería Imágenes (Horizontal Scroll)
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 5, // 5 fotos de ejemplo
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    image: const DecorationImage(
                      image: NetworkImage('https://via.placeholder.com/150'), // Placeholder
                      fit: BoxFit.cover,
                      opacity: 0.5, // Oscurecer un poco
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.image, color: Colors.white30),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 16),

          // Botón Acción
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                   // Ir a perfil completo
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A9DFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Ver Perfil y Reservar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _glassContainer({required Widget child, EdgeInsets padding = EdgeInsets.zero}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          color: Colors.white.withOpacity(0.08), 
          child: child,
        ),
      ),
    );
  }
}

// Modelo de datos
class TattooArtist {
  final String id;
  final String name;
  final String specialty;
  final double rating;
  final LatLng position;
  final Color imageColor; 

  TattooArtist({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.position,
    this.imageColor = Colors.grey,
  });
}