import 'dart:ui';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../providers/interaction_provider.dart';
import '../screens/artist_profile_view_screen.dart';
import '../screens/ar_tattoo_screen.dart';

class TikTokFeedView extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;

  const TikTokFeedView({
    super.key,
    required this.posts,
    this.initialIndex = 0,
    this.onPageChanged,
  });

  @override
  State<TikTokFeedView> createState() => _TikTokFeedViewState();
}

class _TikTokFeedViewState extends State<TikTokFeedView> {
  late PageController _pageController;
  String? _showHeartAnimId;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(String postId) {
    final provider = context.read<InteractionProvider>();
    if (!provider.isLiked(postId)) {
      provider.toggleLike(postId);
    }
    setState(() => _showHeartAnimId = postId);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showHeartAnimId = null);
    });
  }

  Future<void> _sharePost(String imageUrl) async {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preparando imagen para compartir...')),
        );
      }
      
      final response = await http.get(Uri.parse(imageUrl));
      final documentDirectory = await getTemporaryDirectory();
      final file = File('${documentDirectory.path}/compartir_inka_tattoo.png');
      file.writeAsBytesSync(response.bodyBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '¡Descárgate Inka para ver más fotos como esta!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al compartir la imagen'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return const Center(
        child: Text('No hay tatuajes para mostrar', style: TextStyle(color: Colors.white)),
      );
    }

    return Consumer<InteractionProvider>(
      builder: (context, provider, _) {
        return PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          physics: const BouncingScrollPhysics(),
          itemCount: widget.posts.length,
          onPageChanged: widget.onPageChanged,
          itemBuilder: (context, index) {
            final post = widget.posts[index];
            final postId = post['id']?.toString() ?? index.toString();
            final imageUrl = post['image_url'] ?? '';
            final desc = post['description'] ?? '';
            final artistId = post['artist_id']?.toString() ?? '';

            final isLiked = provider.isLiked(postId);
            final isSaved = provider.isSaved(postId);
            final isFollowing = provider.isFollowing(artistId);
            final showHeart = _showHeartAnimId == postId;

            return GestureDetector(
              onDoubleTap: () => _handleDoubleTap(postId),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. FONDO BLUR
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
                  ),
                  Positioned.fill(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(color: Colors.black.withValues(alpha: 0.4)),
                    ),
                  ),

                  // 2. IMAGEN PRINCIPAL (Sin recorte)
                  Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator(color: Colors.white));
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[900],
                        child: const Center(child: Icon(Icons.broken_image, size: 50, color: Colors.white54)),
                      ),
                    ),
                  ),

                  // 3. GRADIENTE INFERIOR
                  Positioned(
                    bottom: 0, left: 0, right: 0, height: 280,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.85),
                            Colors.black.withValues(alpha: 0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 4. CORAZÓN ANIMADO
                  if (showHeart)
                    Center(
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.scale(
                            scale: value,
                            child: Opacity(
                              opacity: value.clamp(0.0, 1.0),
                              child: const Icon(
                                Icons.favorite,
                                color: Colors.redAccent,
                                size: 140,
                                shadows: [Shadow(color: Colors.black45, blurRadius: 20)],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // 5. DESCRIPCIÓN (Abajo izquierda)
                  Positioned(
                    bottom: 20, left: 16, right: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (artistId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ArtistProfileViewScreen(artistId: artistId),
                                ),
                              );
                            }
                          },
                          child: Text(
                            '@${post['shop_name'] ?? 'artista'}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          desc.isNotEmpty ? desc : 'Impresionante tatuaje. #ink #tattoo',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // 6. PANEL LATERAL DERECHO
                  Positioned(
                    bottom: 20, right: 16,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Avatar + Follow
                        GestureDetector(
                          onTap: () {
                            if (artistId.isNotEmpty) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ArtistProfileViewScreen(artistId: artistId),
                                ),
                              );
                            }
                          },
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 50, height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  image: post['artist_avatar'] != null
                                    ? DecorationImage(image: NetworkImage(post['artist_avatar']), fit: BoxFit.cover)
                                    : null,
                                ),
                                child: post['artist_avatar'] == null
                                  ? const Center(child: Icon(Icons.person, color: Colors.white, size: 30))
                                  : null,
                              ),
                              if (!isFollowing)
                                Positioned(
                                  bottom: -8, left: 13,
                                  child: GestureDetector(
                                    onTap: () => provider.toggleFollow(artistId),
                                    child: Container(
                                      width: 24, height: 24,
                                      decoration: BoxDecoration(
                                        color: Colors.redAccent,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: const Icon(Icons.add, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Like
                        _buildSideButton(
                          icon: isLiked ? Icons.favorite : Icons.favorite_border,
                          color: isLiked ? Colors.redAccent : Colors.white,
                          label: 'Like',
                          onTap: () => provider.toggleLike(postId),
                        ),
                        const SizedBox(height: 16),

                        // Save
                        _buildSideButton(
                          icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                          color: isSaved ? Colors.amber : Colors.white,
                          label: 'Guardar',
                          onTap: () => provider.toggleSave(postId),
                        ),
                        const SizedBox(height: 16),

                        // Share
                        _buildSideButton(
                          icon: Icons.share,
                          color: Colors.white,
                          label: 'Compartir',
                          onTap: () => _sharePost(imageUrl),
                        ),
                        const SizedBox(height: 24),

                        // AR
                        GestureDetector(
                          onTap: () {
                            final arUrl = post['ar_image_url'] ?? imageUrl;
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ArTattooScreen(imageUrl: arUrl)),
                            );
                          },
                          child: Container(
                            width: 50, height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [Theme.of(context).colorScheme.primary, Colors.purple],
                              ),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.view_in_ar, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSideButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 36),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }
}
