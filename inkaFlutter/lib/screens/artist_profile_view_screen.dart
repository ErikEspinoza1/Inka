import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../services/auth_service.dart';
import 'chat_screen.dart';
import 'booking_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadArtistData();
  }

  Future<void> _loadArtistData() async {
    // Cargar datos del artista
    final artistData = await _authService.getArtistById(widget.artistId);
    // Cargar portfolio
    final portfolio = await _authService.getArtistPortfolio(widget.artistId);

    setState(() {
      _artistData = artistData;
      _portfolioImages = portfolio ?? [];
      _isLoading = false;
    });
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
            // Información básica del artista
            _buildArtistInfo(),

            const SizedBox(height: 20),

            // Portfolio slider
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

            // Botones de acción
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
        height: 300,
        enlargeCenterPage: true,
        enableInfiniteScroll: false,
        viewportFraction: 0.8,
      ),
      items: _portfolioImages.map((image) {
        return Container(
          width: MediaQuery.of(context).size.width,
          margin: const EdgeInsets.symmetric(horizontal: 5.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: NetworkImage(image['image_url']),
              fit: BoxFit.cover,
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (image['description'] != null && image['description'].isNotEmpty)
                    Text(
                      image['description'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (image['style_tag'] != null && image['style_tag'].isNotEmpty)
                    Text(
                      image['style_tag'],
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                ],
              ),
            ),
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    artistId: widget.artistId,
                    artistName: _artistData!['shop_name'] ?? 'Artista',
                  ),
                ),
              );
            },
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
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingScreen(
                    artistId: widget.artistId,
                    artistName: _artistData!['shop_name'] ?? 'Artista',
                  ),
                ),
              );
            },
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