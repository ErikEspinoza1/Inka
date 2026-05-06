import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'dart:io';
import '../services/auth_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();
  final List<Map<String, dynamic>> _portfolioImages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPortfolio();
  }

  Future<void> _loadPortfolio() async {
    setState(() => _isLoading = true);
    final posts = await _authService.getPortfolioPosts();
    if (posts != null) {
      setState(() {
        _portfolioImages.clear();
        _portfolioImages.addAll(posts.map((post) => post as Map<String, dynamic>));
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _pickAndUploadImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() => _isLoading = true);

    final success = await _authService.uploadPortfolioImage(image.path);
    
    setState(() => _isLoading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Imagen subida al portfolio'), backgroundColor: Colors.green),
      );
      _loadPortfolio(); // Recargar lista
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Error al subir imagen'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  }

  Future<void> _deletePost(String postId) async {
    final success = await _authService.deletePortfolioPost(postId);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Imagen eliminada'), backgroundColor: Colors.green),
      );
      _loadPortfolio();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text('Error al eliminar'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library, size: 80, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(height: 16),
                      Text(
                        'Tu portfolio está vacío',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Agrega fotos de tus tatuajes para mostrar tu trabajo',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _pickAndUploadImage,
                        icon: const Icon(Icons.upload),
                        label: const Text('Subir primera foto'),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: _portfolioImages.length,
                  itemBuilder: (context, index) {
                    final post = _portfolioImages[index];
                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(12),
                            image: DecorationImage(
                              image: NetworkImage(post['image_url']),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                            onPressed: () => _deletePost(post['id']),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}