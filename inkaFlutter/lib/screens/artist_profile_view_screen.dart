import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/interaction_provider.dart';
import 'chat_screen.dart';
import 'booking_screen.dart';
import 'explore_screen.dart'; // Para FullScreenFeedScreen

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
    final artistData = await _authService.getArtistById(widget.artistId);
    final portfolio = await _authService.getArtistPortfolio(widget.artistId);

    if (mounted) {
      // Sincronizar el estado de follow desde el backend al Provider
      if (artistData != null && artistData['is_following'] == true) {
        context.read<InteractionProvider>().setFollowState(widget.artistId, true);
      }
      setState(() {
        _artistData = artistData;
        _portfolioImages = portfolio ?? [];
        _isLoading = false;
      });
    }
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
        body: Center(child: Text('Error al cargar el perfil')),
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

            // Portfolio
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
              _buildPortfolioGrid(),
            ] else ...[
              Text(
                'Este artista aún no tiene fotos en su portfolio',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
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
    final avatarUrl = _artistData!['avatar_url'];

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
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                  ? Text(
                      _artistData!['shop_name']?.substring(0, 1).toUpperCase() ?? 'A',
                      style: TextStyle(fontSize: 24, color: Theme.of(context).colorScheme.onPrimary),
                    )
                  : null,
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
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
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
          const SizedBox(height: 20),
          _buildFollowButton(),
        ],
      ),
    );
  }

  Widget _buildFollowButton() {
    return Consumer<InteractionProvider>(
      builder: (context, provider, _) {
        final isFollowing = provider.isFollowing(widget.artistId);
        return SizedBox(
          width: double.infinity,
          height: 50, // Aumentado de 45 a 50 para evitar recortes
          child: ElevatedButton(
            onPressed: () => provider.toggleFollow(widget.artistId),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? Colors.transparent : Theme.of(context).colorScheme.primary,
              foregroundColor: isFollowing ? Colors.white : Colors.black,
              elevation: isFollowing ? 0 : 2,
              side: isFollowing ? const BorderSide(color: Colors.grey, width: 1.5) : null,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: EdgeInsets.zero, // Quitamos el padding interno del tema para centrar bien el texto
            ),
            child: Text(
              isFollowing ? 'Siguiendo' : 'Seguir',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        );
      },
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
              Text('@${_artistData!['instagram_handle']}'),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_artistData!['address'] != null) ...[
          Row(
            children: [
              Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(_artistData!['address'])),
            ],
          ),
          const SizedBox(height: 8),
        ],
        // Horario
        Row(
          children: [
            Icon(Icons.access_time, color: Theme.of(context).colorScheme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Horario: ${_artistData!['working_hours_start'] ?? '09:00'} - ${_artistData!['working_hours_end'] ?? '18:00'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  /// Grid de portfolio - al tocar una foto, abre TikTok Style en esa posición
  Widget _buildPortfolioGrid() {
    // Convertir a List<Map<String, dynamic>> para pasarlo al TikTokFeedView
    final postsList = _portfolioImages.map<Map<String, dynamic>>((img) {
      return {
        'id': img['id']?.toString() ?? '',
        'artist_id': widget.artistId,
        'image_url': img['image_url'] ?? '',
        'description': img['description'] ?? '',
        'style_tag': img['style_tag'] ?? '',
        'ar_image_url': img['ar_image_url'],
        'artist_avatar': _artistData!['avatar_url'],
      };
    }).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: _portfolioImages.length,
      itemBuilder: (context, index) {
        final image = _portfolioImages[index];
        return GestureDetector(
          onTap: () {
            // Abrir TikTok Style empezando en esta foto exacta
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenFeedScreen(
                  posts: postsList,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              image['image_url'] ?? '',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.broken_image, color: Colors.white30),
              ),
            ),
          ),
        );
      },
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