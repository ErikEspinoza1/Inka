import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/ai_explore_service.dart';
import '../widgets/tiktok_feed_view.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final AiExploreService _aiService = AiExploreService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  bool _isLoading = false;
  List<Map<String, dynamic>> _resultados = [];
  
  int _uxState = 0; // 0: Feed, 1: Sugerencias, 2: Resultados

  List<String> _busquedasRecientes = [];
  List<String> _busquedasPopulares = [];

  @override
  void initState() {
    super.initState();
    _cargarFeedInicial();
    _cargarDatosDeSugerencias();

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _uxState == 0) {
        setState(() {
          _uxState = 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosDeSugerencias() async {
    // 1. Cargar historial local (Recientes)
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _busquedasRecientes = prefs.getStringList('search_history') ?? [];
    });

    // 2. Cargar populares del Backend
    final populares = await _aiService.getPopularSearches();
    if (mounted && populares.isNotEmpty) {
      setState(() {
        _busquedasPopulares = populares;
      });
    } else if (mounted) {
       // Fallback por si el backend está vacío
       setState(() {
          _busquedasPopulares = ["Blackwork", "Lobos", "Minimalista", "Neotradicional"];
       });
    }
  }

  Future<void> _guardarBusquedaLocal(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('search_history') ?? [];
    
    // Evitar duplicados seguidos y ponerlo el primero
    history.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    history.insert(0, query);
    
    // Guardar máximo 5 recientes
    if (history.length > 5) history = history.sublist(0, 5);
    
    await prefs.setStringList('search_history', history);
    setState(() {
      _busquedasRecientes = history;
    });
  }

  Future<void> _eliminarBusquedaReciente(String query) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList('search_history') ?? [];
    history.remove(query);
    await prefs.setStringList('search_history', history);
    setState(() {
      _busquedasRecientes = history;
    });
  }

  Future<void> _cargarFeedInicial() async {
    setState(() {
      _isLoading = true;
      _uxState = 0;
    });

    final resultados = await _aiService.getFeedInicial();

    if (mounted) {
      setState(() {
        _resultados = resultados;
        _isLoading = false;
      });
    }
  }

  Future<void> _buscarConIA([String? ideaSugerida]) async {
    final idea = ideaSugerida ?? _searchController.text.trim();
    if (idea.isEmpty) {
      _cargarFeedInicial();
      return;
    }

    if (ideaSugerida != null) {
      _searchController.text = ideaSugerida;
    }

    _guardarBusquedaLocal(idea); // Guardar en historial

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _uxState = 2;
    });

    final resultados = await _aiService.buscarTatuajesPorIdea(idea);

    if (mounted) {
      setState(() {
        _resultados = resultados;
        _isLoading = false;
      });
    }
  }

  Widget _buildPinterestGrid() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_resultados.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No encontramos tatuajes para esto.\n¡Intenta con otra idea!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 16),
            ),
          ],
        ),
      );
    }

    return MasonryGridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      itemCount: _resultados.length,
      itemBuilder: (context, index) {
        final tatuaje = _resultados[index];
        final heightMultiplier = (index % 3 == 0) ? 1.5 : (index % 2 == 0) ? 1.2 : 1.0;
        
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FullScreenFeedScreen(
                  posts: _resultados,
                  initialIndex: index,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 1 / heightMultiplier,
                child: Hero(
                  tag: 'post_${tatuaje['id']}',
                  child: Image.network(
                    tatuaje['image_url'] ?? 'https://via.placeholder.com/300x400',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image, color: Colors.white30, size: 40),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSugerencias() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // SECCIÓN 1: BÚSQUEDAS RECIENTES
          if (_busquedasRecientes.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recientes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('search_history');
                    setState(() {
                      _busquedasRecientes.clear();
                    });
                  },
                  child: const Text('Borrar', style: TextStyle(fontSize: 12)),
                )
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _busquedasRecientes.map((reciente) {
                return InputChip(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  label: Text(reciente),
                  avatar: const Icon(Icons.history, size: 16),
                  onPressed: () => _buscarConIA(reciente),
                  onDeleted: () => _eliminarBusquedaReciente(reciente),
                  deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
          ],

          // SECCIÓN 2: POPULARES (Top del Backend)
          Row(
            children: [
              const Icon(Icons.local_fire_department, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Populares en Inka',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _busquedasPopulares.map((popular) {
              return ActionChip(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                ),
                label: Text(popular),
                onPressed: () => _buscarConIA(popular),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        title: const Text('Descubrir'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ---
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Busca ideas, estilos, animales...',
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                prefixIcon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurfaceVariant),
                suffixIcon: _uxState != 0
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          _cargarFeedInicial();
                        },
                      )
                    : Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _buscarConIA(),
            ),
          ),

          // --- CONTENIDO PRINCIPAL ---
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _uxState == 1 
                  ? _buildSugerencias() 
                  : _buildPinterestGrid(),
            ),
          ),
        ],
      ),
    );
  }
}

// Nueva pantalla para alojar el TikTokFeedView y permitir volver atrás
class FullScreenFeedScreen extends StatelessWidget {
  final List<Map<String, dynamic>> posts;
  final int initialIndex;

  const FullScreenFeedScreen({
    super.key,
    required this.posts,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Estética oscura inmersiva
      body: Stack(
        children: [
          // 1. El Feed principal ocupando todo
          TikTokFeedView(
            posts: posts,
            initialIndex: initialIndex,
          ),
          
          // 2. Botón flotante para volver atrás
          Positioned(
            top: 50,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}