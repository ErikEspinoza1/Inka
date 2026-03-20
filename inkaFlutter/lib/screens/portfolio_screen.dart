// lib/screens/portfolio_screen.dart
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import 'ar_tattoo_screen.dart';

class PortfolioScreen extends StatefulWidget {
  final String? artistId;
  final bool isOwnPortfolio;

  const PortfolioScreen({
    super.key,
    this.artistId,
    this.isOwnPortfolio = true,
  });

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  final List<Map<String, dynamic>> _portfolioImages = [];
  bool _isLoading = false;
  String? _loadingPostId;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);
    List<dynamic>? posts;
    if (widget.isOwnPortfolio) {
      posts = await _authService.getPortfolioPosts();
    } else if (widget.artistId != null) {
      posts = await _authService.getArtistPortfolio(widget.artistId!);
    }
    if (posts != null) {
      setState(() {
        _portfolioImages.clear();
        _portfolioImages.addAll(posts!.map((p) => p as Map<String, dynamic>));
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Subiendo y procesando imagen con IA…'),
        duration: Duration(seconds: 60),
      ),
    );

    final success = await _authService.uploadPortfolioImage(image.path);
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('¡Imagen subida!'), backgroundColor: Colors.green),
      );
      _loadPortfolio();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al subir imagen'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    final success = await _authService.deletePortfolioPost(postId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen eliminada'), backgroundColor: Colors.green),
      );
      _loadPortfolio();
    }
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

    final postId    = post['id'] as String?;
    final cleanUrl  = post['clean_image_url'] as String?;
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.isOwnPortfolio ? 'Mi Portfolio' : 'Portfolio'),
        backgroundColor: Colors.transparent,
        actions: [
          if (widget.isOwnPortfolio)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate, color: Colors.purpleAccent),
              onPressed: _pickAndUploadImage,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _portfolioImages.isEmpty
              ? _buildEmpty()
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: _portfolioImages.length,
                  itemBuilder: (context, index) {
                    final post = _portfolioImages[index];
                    final postId = post['id'] as String?;
                    final bgRemoved = post['bg_removed'] as bool? ?? false;
                    final isLoadingThis = _loadingPostId == postId;

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      color: Colors.grey[900],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  post['image_url'] ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                      Icons.broken_image, color: Colors.white38, size: 48),
                                ),
                                if (bgRemoved)
                                  Positioned(
                                    top: 6, left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.tealAccent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text('AR',
                                          style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                if (widget.isOwnPortfolio && postId != null)
                                  Positioned(
                                    top: 4, right: 4,
                                    child: GestureDetector(
                                      onTap: () => _deletePost(postId),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                        child: const Icon(Icons.close, color: Colors.red, size: 16),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                            child: SizedBox(
                              height: 34,
                              child: ElevatedButton.icon(
                                onPressed: isLoadingThis ? null : () => _tryTattooAR(post),
                                icon: isLoadingThis
                                    ? const SizedBox(width: 14, height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                    : const Icon(Icons.camera_alt, size: 16),
                                label: Text(isLoadingThis ? 'Cargando…' : 'Probar AR',
                                    style: const TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.tealAccent,
                                  foregroundColor: Colors.black,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.photo_library, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            widget.isOwnPortfolio ? 'Tu portfolio está vacío' : 'Este artista no tiene diseños aún',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          if (widget.isOwnPortfolio) ...[
            const SizedBox(height: 8),
            const Text('Agrega fotos de tus tatuajes',
                style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _pickAndUploadImage,
              icon: const Icon(Icons.upload),
              label: const Text('Subir primera foto'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}