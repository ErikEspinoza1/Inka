import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/ai_explore_service.dart';
import '../widgets/tiktok_feed_view.dart';
import '../providers/interaction_provider.dart';
import 'explore_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final AiExploreService _aiService = AiExploreService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _posts = [];

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    final resultados = await _aiService.getFeedInicial();
    if (mounted) {
      // Inyectar estados del backend al provider global
      context.read<InteractionProvider>().loadFromFeedData(resultados);
      setState(() {
        _posts = resultados;
        _isLoading = false;
      });
    }
  }

  // Método público para recargar (cuando se pulsa la "casita" otra vez)
  void refreshFeed() {
    setState(() {
      _isLoading = true;
      _posts = [];
    });
    _loadFeed();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0, // <-- Elimina el sombreado al scrollear por debajo
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white, size: 30),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExploreScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: TikTokFeedView(posts: _posts),
    );
  }
}
