import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/interaction_service.dart';

class TikTokFeedView extends StatefulWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;

  const TikTokFeedView({
    super.key,
    required this.posts,
    this.initialIndex = 0,
  });

  @override
  State<TikTokFeedView> createState() => _TikTokFeedViewState();
}

class _TikTokFeedViewState extends State<TikTokFeedView> {
  late PageController _pageController;
  final InteractionService _interactionService = InteractionService();

  // Mantenemos un estado local para saber si dio like/guardó rápido
  // En producción esto debería inicializarse verificando el estado real del backend.
  final Map<String, bool> _likedPosts = {};
  final Map<String, bool> _savedPosts = {};
  
  // Para mostrar el icono gigante de corazón al hacer doble tap
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

  void _handleDoubleTap(String postId) async {
    setState(() {
      _showHeartAnimId = postId;
      _likedPosts[postId] = true;
    });

    // Petición al backend
    await _interactionService.toggleLike(postId);

    // Ocultar corazón después de 800ms
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _showHeartAnimId = null;
        });
      }
    });
  }

  void _toggleLike(String postId) async {
    final isLiked = _likedPosts[postId] ?? false;
    setState(() {
      _likedPosts[postId] = !isLiked;
    });
    await _interactionService.toggleLike(postId);
  }

  void _toggleSave(String postId) async {
    final isSaved = _savedPosts[postId] ?? false;
    setState(() {
      _savedPosts[postId] = !isSaved;
    });
    await _interactionService.toggleFavorite(postId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(!isSaved ? 'Guardado en favoritos' : 'Eliminado de favoritos'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _sharePost(String imageUrl) {
    // Usamos el paquete share_plus para compartir nativo (iOS/Android)
    Share.share('¡Mira este increíble tatuaje en Inka! $imageUrl');
  }

  @override
  Widget build(BuildContext context) {
    if (widget.posts.isEmpty) {
      return const Center(
        child: Text('No hay tatuajes para mostrar', style: TextStyle(color: Colors.white)),
      );
    }

    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      itemCount: widget.posts.length,
      itemBuilder: (context, index) {
        final post = widget.posts[index];
        final postId = post['id'] ?? index.toString();
        final imageUrl = post['image_url'] ?? '';
        final desc = post['description'] ?? '';
        
        final isLiked = _likedPosts[postId] ?? false;
        final isSaved = _savedPosts[postId] ?? false;
        final showHeart = _showHeartAnimId == postId;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Imagen de Fondo a Pantalla Completa
            GestureDetector(
              onDoubleTap: () => _handleDoubleTap(postId),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover, // Estilo TikTok
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

            // 2. Gradiente Oscuro inferior para que la UI resalte
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 300,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.9),
                      Colors.black.withOpacity(0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 3. Corazón animado gigante en el centro (Doble Tap)
            if (showHeart)
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut, // Efecto rebote fluido
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0), // Se desvanece al inicio
                        child: const Icon(
                          Icons.favorite, 
                          color: Colors.redAccent, // Rojo estilo Insta
                          size: 140,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 20)], // Sombra para resaltar
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 4. Panel Izquierdo/Inferior: Descripción
            Positioned(
              bottom: 20,
              left: 16,
              right: 80, // Dejamos espacio para los botones
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Aquí iría el @artista si lo tenemos en el post
                  const Text(
                    '@artista_inka',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
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

            // 5. Panel Derecho: Botones (Overlay)
            Positioned(
              bottom: 20,
              right: 16,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildSideButton(
                    icon: isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    label: 'Like',
                    onTap: () => _toggleLike(postId),
                  ),
                  const SizedBox(height: 16),
                  _buildSideButton(
                    icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
                    color: isSaved ? Colors.yellow : Colors.white,
                    label: 'Guardar',
                    onTap: () => _toggleSave(postId),
                  ),
                  const SizedBox(height: 16),
                  _buildSideButton(
                    icon: Icons.share,
                    color: Colors.white,
                    label: 'Compartir',
                    onTap: () => _sharePost(imageUrl),
                  ),
                  const SizedBox(height: 24),
                  
                  // Botón especial AR
                  GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Abriendo Realidad Aumentada...')),
                      );
                      // TODO: Navegar a la vista AR
                    },
                    child: Container(
                      width: 50,
                      height: 50,
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
        );
      },
    );
  }

  Widget _buildSideButton({
    required IconData icon, 
    required Color color, 
    required String label, 
    required VoidCallback onTap
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
