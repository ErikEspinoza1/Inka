import 'package:flutter/material.dart';
import 'explore_screen.dart'; // <-- ¡Aquí importamos nuestra IA!
import 'map_screen.dart';
import 'client_profile_screen.dart';
import 'chat_list_screen.dart';

class ClientHomeScreen extends StatefulWidget {
  const ClientHomeScreen({super.key});

  @override
  State<ClientHomeScreen> createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  int _selectedIndex = 0; // Empieza en la pantalla 0 (Explorar)

  static const List<Widget> _screens = <Widget>[
    ExploreScreen(),        // 0: Explorar (NUEVO)
    MapScreen(),            // 1: Mapa
    ChatListScreen(),       // 2: Chats
    ClientProfileScreen(),  // 3: Perfil
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
        // Añadimos el tipo 'fixed' para que no se vuelva loco al tener 4 items
        type: BottomNavigationBarType.fixed, 
        items: const <BottomNavigationBarItem>[
          // Nuestro nuevo botón de Explorar
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome), // Icono de IA/Destellos
            label: 'Explorar',
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