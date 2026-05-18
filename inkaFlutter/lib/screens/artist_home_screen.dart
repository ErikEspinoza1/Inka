import 'dart:async';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'portfolio_screen.dart';
import 'artist_profile_panel_screen.dart';
import 'chat_list_screen.dart';
import 'artist_booking_management_screen.dart';

class ArtistHomeScreen extends StatefulWidget {
  const ArtistHomeScreen({super.key});

  @override
  State<ArtistHomeScreen> createState() => _ArtistHomeScreenState();
}

class _ArtistHomeScreenState extends State<ArtistHomeScreen> {
  final AuthService _authService = AuthService();
  Timer? _notificationTimer;
  int _lastUnreadCount = 0;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _startNotificationCheck();
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
        if (mounted && _selectedIndex != 1) { // 1 es el índice de Chats en Artista
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('💬 Tienes nuevos mensajes de clientes'),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Ver',
                onPressed: () => setState(() => _selectedIndex = 1),
              ),
            ),
          );
        }
      }
      _lastUnreadCount = newCount;
    });
  }

  static const List<Widget> _screens = <Widget>[
    PortfolioScreen(),
    ChatListScreen(),
    ArtistBookingManagementScreen(),
    ArtistProfilePanelScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Portfolio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Reservas',
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