import 'package:flutter/material.dart';
import '../services/interaction_service.dart';

/// Estado global para likes, saves y follows.
/// Cualquier pantalla puede leer y modificar estos estados,
/// y todos los listeners se actualizan automáticamente.
class InteractionProvider extends ChangeNotifier {
  final InteractionService _service = InteractionService();

  final Set<String> _likedPostIds = {};
  final Set<String> _savedPostIds = {};
  final Set<String> _followedArtistIds = {};

  // --- GETTERS ---
  bool isLiked(String postId) => _likedPostIds.contains(postId);
  bool isSaved(String postId) => _savedPostIds.contains(postId);
  bool isFollowing(String artistId) => _followedArtistIds.contains(artistId);

  // --- INICIALIZACIÓN DESDE EL FEED ---
  /// Carga los estados iniciales que vienen en la respuesta del backend
  void loadFromFeedData(List<Map<String, dynamic>> posts) {
    for (final post in posts) {
      final postId = post['id']?.toString() ?? '';
      final artistId = post['artist_id']?.toString() ?? '';
      if (postId.isEmpty) continue;

      if (post['is_liked'] == true) _likedPostIds.add(postId);
      if (post['is_saved'] == true) _savedPostIds.add(postId);
      if (post['is_following_artist'] == true && artistId.isNotEmpty) {
        _followedArtistIds.add(artistId);
      }
    }
    notifyListeners();
  }

  /// Marca un artista como seguido (desde el endpoint del perfil)
  void setFollowState(String artistId, bool following) {
    if (following) {
      _followedArtistIds.add(artistId);
    } else {
      _followedArtistIds.remove(artistId);
    }
    notifyListeners();
  }

  // --- TOGGLE ACTIONS ---
  Future<void> toggleLike(String postId) async {
    if (_likedPostIds.contains(postId)) {
      _likedPostIds.remove(postId);
    } else {
      _likedPostIds.add(postId);
    }
    notifyListeners();
    await _service.toggleLike(postId);
  }

  Future<void> toggleSave(String postId) async {
    if (_savedPostIds.contains(postId)) {
      _savedPostIds.remove(postId);
    } else {
      _savedPostIds.add(postId);
    }
    notifyListeners();
    await _service.toggleFavorite(postId);
  }

  Future<void> toggleFollow(String artistId) async {
    if (_followedArtistIds.contains(artistId)) {
      _followedArtistIds.remove(artistId);
    } else {
      _followedArtistIds.add(artistId);
    }
    notifyListeners();
    await _service.toggleFollow(artistId);
  }
}
