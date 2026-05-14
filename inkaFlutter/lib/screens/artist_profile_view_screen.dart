// lib/screens/artist_profile_view_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'booking_screen.dart';
import 'ar_tattoo_screen.dart';

class ArtistProfileViewScreen extends StatefulWidget {
  final String artistId;
  const ArtistProfileViewScreen({super.key, required this.artistId});

  @override
  State<ArtistProfileViewScreen> createState() => _ArtistProfileViewScreenState();
}

class _ArtistProfileViewScreenState extends State<ArtistProfileViewScreen> {
  final AuthService _authService = AuthService();
  Map<String, dynamic>? _artistData;
  List<dynamic> _portfolioImages = [];
  bool _isLoading = true;
  String? _loadingPostId;

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    final artistData = await _authService.getArtistById(widget.artistId);
    final portfolio  = await _authService.getArtistPortfolio(widget.artistId);
    setState(() {
      _artistData      = artistData;
      _portfolioImages = portfolio ?? [];
      _isLoading       = false;
    });
  }

  Future<void> _tryTattooAR(Map<String, dynamic> post) async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La prueba AR solo está disponible en la app móvil'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final postId      = post['id'] as String?;
    final cleanUrl    = post['clean_image_url'] as String?;
    final originalUrl = post['image_url'] as String?;

    setState(() => _loadingPostId = postId);
    Uint8List? imageBytes;

    if (cleanUrl != null && cleanUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(cleanUrl)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) imageBytes = res.bodyBytes;
      } catch (_) {}
    }

    if (imageBytes == null && originalUrl != null && originalUrl.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse(originalUrl)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200) imageBytes = res.bodyBytes;
      } catch (_) {}
    }

    setState(() => _loadingPostId = null);

    if (imageBytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cargar el diseño'), backgroundColor: Colors.red),
      );
      return;
    }

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ArTattooScreen(tattooBytes: imageBytes),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_artistData == null) {
      return const Scaffold(
        body: Center(
          child: Text('Error al cargar el perfil'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_artistData!['shop_name'] ?? 'Perfil Artista'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildArtistInfo(),
            const SizedBox(height: 20),
            if (_portfolioImages.isNotEmpty) ...[
              Text(
                'Portfolio',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              _buildPortfolioSlider(),
            ] else ...[
              Text(
                'Este artista aún no tiene fotos en su portfolio',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)),
              ),
            ],

            const SizedBox(height: 30),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Theme.of(context).colorScheme.primary,
                child: Text(
                  _artistData!['shop_name']?.substring(0, 1).toUpperCase() ?? 'A',
                  style: TextStyle(fontSize: 24, color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _artistData!['shop_name'] ?? 'Sin nombre',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _artistData!['styles']?.join(' • ') ?? 'Sin especialidad',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7)
                      ),
                    ),
                  ],
                ),
              ),
              if (_artistData!['is_verified'] == true)
                Icon(Icons.verified, color: Theme.of(context).colorScheme.secondary, size: 24),
            ],
          ),
          const SizedBox(height: 16),
          if (_artistData!['bio'] != null && _artistData!['bio'].isNotEmpty) ...[
            Text(
              'Sobre mí',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _artistData!['bio'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
          ],
          _buildContactInfo(),
        ],
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_artistData!['instagram_handle'] != null) ...[
          Row(
            children: [
              Icon(Icons.camera_alt, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                '@${_artistData!['instagram_handle']}',
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_artistData!['address'] != null) ...[
          Row(
            children: [
              Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _artistData!['address'],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPortfolioSlider() {
    return CarouselSlider(
      options: CarouselOptions(
        height: 360,
        enlargeCenterPage: true,
        enableInfiniteScroll: false,
        viewportFraction: 0.8,
      ),
      items: _portfolioImages.map((image) {
        final post        = image as Map<String, dynamic>;
        final postId      = post['id'] as String?;
        final bgRemoved   = post['bg_removed'] as bool? ?? false;
        final isLoadingThis = _loadingPostId == postId;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 5.0),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Column(
            children: [
              // Imagen
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: Image.network(
                        post['image_url'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[900],
                          child: const Icon(Icons.broken_image, color: Colors.white38, size: 48),
                        ),
                      ),
                    ),
                    // Info texto
                    Positioned(
                      bottom: 0, left: 0, right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter, end: Alignment.topCenter,
                            colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                          ),
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (post['description'] != null && post['description'].isNotEmpty)
                              Text(post['description'],
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                            if (post['style_tag'] != null && post['style_tag'].isNotEmpty)
                              Text(post['style_tag'],
                                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                    // Badge AR
                    if (bgRemoved)
                      Positioned(
                        top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: Colors.tealAccent, borderRadius: BorderRadius.circular(6)),
                          child: const Text('AR',
                              style: TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
              // Botón Probar AR
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: isLoadingThis ? null : () => _tryTattooAR(post),
                    icon: isLoadingThis
                        ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.camera_alt, size: 16),
                    label: Text(isLoadingThis ? 'Cargando…' : 'Probar tatuaje en AR',
                        style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ChatScreen(
                artistId: widget.artistId,
                artistName: _artistData!['shop_name'] ?? 'Artista',
              ),
            )),
            icon: const Icon(Icons.message),
            label: const Text('Contactar Artista'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => BookingScreen(
                artistId: widget.artistId,
                artistName: _artistData!['shop_name'] ?? 'Artista',
              ),
            )),
            icon: const Icon(Icons.calendar_today),
            label: const Text('Reservar Cita'),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).colorScheme.primary),
              foregroundColor: Theme.of(context).colorScheme.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 60),
      ],
    );
  }
}