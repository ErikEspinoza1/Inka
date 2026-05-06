import 'package:flutter/material.dart';
import '../services/ai_explore_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // Conectamos con nuestro cerebro de Gemini
  final AiExploreService _aiService = AiExploreService();
  
  // Controlador para leer lo que escribe el usuario
  final TextEditingController _searchController = TextEditingController();
  
  // Variables para controlar la pantalla
  bool _isLoading = false;
  List<Map<String, dynamic>> _resultados = [];

  // Función que se ejecuta al darle al botón de buscar
  Future<void> _buscarConIA() async {
    final idea = _searchController.text.trim();
    if (idea.isEmpty) return;

    // Quitamos el teclado y mostramos la ruedita de carga
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
    });

    // ¡Aquí ocurre la magia! Llamamos a Gemini y a Supabase
    final resultados = await _aiService.buscarTatuajesPorIdea(idea);

    // Actualizamos la pantalla con los resultados
    setState(() {
      _resultados = resultados;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar Ideas'),
      ),
      body: Column(
        children: [
          // --- BARRA DE BÚSQUEDA ---
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Theme.of(context).colorScheme.background,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Ej: "Algo que represente libertad y el mar"',
                prefixIcon: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.secondary), // Icono de IA
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _buscarConIA,
                ),
              ),
              onSubmitted: (_) => _buscarConIA(), // Buscar al darle al "Intro" en el teclado
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(), // Cargando...
                  )
                : _resultados.isEmpty
                    ? Center(
                        child: Text(
                          'Escribe una idea y la IA buscará los mejores tatuajes para ti.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7), fontSize: 16),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, // 2 columnas
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.8, // Proporción de las tarjetas
                        ),
                        itemCount: _resultados.length,
                        itemBuilder: (context, index) {
                          final tatuaje = _resultados[index];
                          
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Imagen del tatuaje (suponiendo que en tu BD la columna se llama 'image_url')
                                Expanded(
                                  child: Image.network(
                                    tatuaje['image_url'] ?? 'https://via.placeholder.com/150', 
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 50),
                                  ),
                                ),
                                // Título o descripción
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    tatuaje['description'] ?? 'Sin descripción',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}