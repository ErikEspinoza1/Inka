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

  // =========================================================
  // FLUJO: Seleccionar imagen → Bottom Sheet → Subir
  // =========================================================
  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    // Mostrar el bottom sheet para que el artista añada título y descripción
    _showUploadSheet(image);
  }

  void _showUploadSheet(XFile image) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    bool isUploading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              // Ocupa hasta el 90% de la pantalla
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Indicador de arrastre
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Título del sheet
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, 
                          color: Theme.of(context).colorScheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Nuevo Post',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Añade detalles a tu trabajo. Nuestra IA validará la imagen.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Preview de la imagen
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Image.file(
                          File(image.path),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo: Estilo / Tag (style_tag)
                    TextField(
                      controller: titleController,
                      maxLength: 40,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Estilo o título',
                        hintText: 'Ej: Realismo, Neotradicional, Blackwork...',
                        prefixIcon: Icon(Icons.style, 
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                        counterStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Campo: Descripción
                    TextField(
                      controller: descriptionController,
                      maxLength: 150,
                      maxLines: 3,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Descripción',
                        hintText: 'Describe tu trabajo brevemente...',
                        alignLabelWithHint: true,
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(bottom: 44),
                          child: Icon(Icons.edit_note, 
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                        ),
                        counterStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Info sobre la IA
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, 
                            color: Theme.of(context).colorScheme.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'La IA analizará la imagen y el texto para garantizar la calidad del contenido.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Botón de subir
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isUploading
                            ? null
                            : () async {
                                setSheetState(() => isUploading = true);

                                final result = await _authService.uploadPortfolioImage(
                                  image.path,
                                  description: descriptionController.text.trim(),
                                  styleTag: titleController.text.trim(),
                                );

                                setSheetState(() => isUploading = false);

                                // Cerrar el bottom sheet
                                if (ctx.mounted) Navigator.pop(ctx);

                                if (result['success'] == true) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Imagen subida al portfolio'),
                                        backgroundColor: Color(0xFF2E7D32),
                                      ),
                                    );
                                  }
                                  _loadPortfolio();
                                } else {
                                  if (mounted) {
                                    ScaffoldMessenger.of(this.context).showSnackBar(
                                      SnackBar(
                                        content: Text(result['error'] ?? 'Error al subir imagen'),
                                        backgroundColor: Theme.of(this.context).colorScheme.error,
                                        duration: const Duration(seconds: 4),
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(isUploading ? 'Subiendo...' : 'Publicar en Portfolio'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar post'),
        content: const Text('¿Estás seguro de que quieres eliminar este tatuaje de tu portfolio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Eliminar', 
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _authService.deletePortfolioPost(postId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imagen eliminada'), backgroundColor: Color(0xFF2E7D32)),
      );
      _loadPortfolio();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Error al eliminar'), backgroundColor: Theme.of(context).colorScheme.error),
      );
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
      appBar: AppBar(
        title: const Text('Mi Portfolio'),
        actions: [
          IconButton(
            icon: Icon(Icons.add_photo_alternate, color: Theme.of(context).colorScheme.primary),
            onPressed: _pickAndUploadImage,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _portfolioImages.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.photo_library_outlined, size: 80, 
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          'Tu portfolio está vacío',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Agrega fotos de tus tatuajes para mostrar tu trabajo a clientes potenciales',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _pickAndUploadImage,
                          icon: const Icon(Icons.add_a_photo_outlined),
                          label: const Text('Subir primera foto'),
                        ),
                      ],
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _portfolioImages.length,
                  itemBuilder: (context, index) {
                    final post = _portfolioImages[index];
                    final description = post['description'] ?? '';
                    final styleTag = post['style_tag'] ?? '';
                    final hasInfo = description.isNotEmpty || styleTag.isNotEmpty;

                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Imagen
                            Image.network(
                              post['image_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surface,
                                child: const Icon(Icons.broken_image, color: Colors.white24, size: 40),
                              ),
                            ),

                            // Overlay degradado inferior con info
                            if (hasInfo)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.85),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (styleTag.isNotEmpty)
                                        Text(
                                          styleTag,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      if (description.isNotEmpty)
                                        Text(
                                          description,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.7),
                                            fontSize: 10,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                            // Botón eliminar
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: IconButton(
                                  icon: Icon(Icons.delete_outline, 
                                    color: Theme.of(context).colorScheme.error, size: 20),
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => _deletePost(post['id']),
                                ),
                              ),
                            ),
                          ],
                        ),
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