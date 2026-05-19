import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'feed_screen.dart';       // <-- El Feed Principal (TikTok Flow)
import 'map_screen.dart';
import 'client_profile_screen.dart';
import 'chat_list_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  final AuthService _authService = AuthService();
  Timer? _notificationTimer;
  int _lastUnreadCount = 0;
  int _selectedIndex = 0; 

  final GlobalKey<FeedScreenState> _feedKey = GlobalKey<FeedScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _startNotificationCheck();
    _screens = [
      FeedScreen(key: _feedKey),           // 0: Feed (TikTok)
      const MapScreen(),                   // 1: Mapa
      const ChatListScreen(),              // 2: Chats
      const ClientProfileScreen(),         // 3: Perfil
    ];
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationCheck() {
    _notificationTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      final newCount = await _authService.getTotalUnreadCount();
      if (newCount > _lastUnreadCount) {
        if (mounted && _selectedIndex != 2) { // 2 es el índice de Chats
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('💬 Tienes nuevos mensajes pendientes'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Ver',
                onPressed: () => setState(() => _selectedIndex = 2),
              ),
            ),
          );
        }
      }
      _lastUnreadCount = newCount;
    });
  }

  void _onItemTapped(int index) {
    if (index == 0 && _selectedIndex == 0) {
      // Si ya estamos en "Para ti" y volvemos a pulsar la casita, actualizamos el feed
      _feedKey.currentState?.refreshFeed();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, 
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Para ti',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}