import 'package:flutter/material.dart';

import 'screens/perfil_screen.dart';
import 'screens/explorar_screen.dart';
import 'screens/diccionario_screen.dart';
import 'screens/estudiar_screen.dart';

void main() {
  runApp(const MedTerminoApp());
}

class MedTerminoApp extends StatelessWidget {
  const MedTerminoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MedTermino',
      debugShowCheckedModeBanner: false, // Oculta la etiqueta roja de "DEBUG"
      theme: ThemeData(
        // Paleta base extraída de tus imágenes
        scaffoldBackgroundColor: const Color(0xFFF4F6F9), // Fondo gris claro
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D9488), // Verde Azulado Médico (Teal)
          primary: const Color(0xFF0D9488),
          surface: Colors.white,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto', // Fuente limpia sin patines
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Iniciamos en el índice 1 ("Explorar") según tu diseño
  int _selectedIndex = 1;

  // Las 4 pantallas principales (el orden debe coincidir con los items del BottomNavigationBar)
  static const List<Widget> _modulos = <Widget>[
    DiccionarioScreen(),
    ExplorarScreen(),
    EstudiarScreen(),
    PerfilScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // SafeArea evita que el contenido choque con la muesca o barra de estado del iPhone
      // IndexedStack mantiene vivas las 4 pantallas: cambiar de pestaña ya no
      // reinicia la sesión de Estudiar ni la posición del Diccionario.
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: _modulos),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: Icon(Icons.menu_book),
              label: 'Diccionario',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view),
              label: 'Explorar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.school),
              label: 'Estudiar',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'Perfil',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF0D9488), // El color de acento
          unselectedItemColor: Colors.grey,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          onTap: _onItemTapped,
        ),
      ),
    );
  }
}
