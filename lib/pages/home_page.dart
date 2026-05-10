import 'package:flutter/material.dart';
import 'package:tintaviva/pages/clubes_page.dart';
import 'package:tintaviva/pages/perfil_page.dart';
import 'package:tintaviva/pages/mi_biblioteca_page.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Página principal de navegación de la aplicación.
///
/// Funciona como contenedor de las tres secciones principales:
/// 1. Mi Biblioteca (gestión de libros personales).
/// 2. Clubes (lectura social y metas grupales).
/// 3. Perfil (estadísticas y configuración de usuario).
///
/// Características de navegación:
/// - Permite cambiar de pestaña tocando los iconos inferiores.
/// - Permite deslizar horizontalmente (swipe) para navegar entre secciones.
/// - Mantiene el estado de cada página al cambiar de pestaña (gracias a PageView).
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // Índice de la pestaña actualmente seleccionada (0: Biblioteca, 1: Clubes, 2: Perfil).
  int _selectedIndex = 0;

  // Controlador para gestionar el PageView: permite animaciones programáticas y detectar swipes.
  final PageController _pageController = PageController();

  // Lista de widgets que representan cada sección de la app.
  // Se mantienen en memoria mientras el HomePage esté activo, preservando su estado (scroll, inputs, etc.).
  final List<Widget> _paginas = [
    const MiBibliotecaPage(),
    const ClubesPage(),
    const PerfilPage(),
  ];

  @override
  void dispose() {
    // IMPORTANTE: Liberamos el controlador para evitar fugas de memoria cuando se destruye este widget.
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El cuerpo usa PageView para permitir navegación por swipe (deslizamiento horizontal).
      body: PageView(
        controller: _pageController,
        // BouncingScrollPhysics da un efecto de "rebote" al final del scroll, más natural en móviles.
        physics: const BouncingScrollPhysics(),

        // Cuando el usuario desliza con el dedo, actualizamos el índice seleccionado para sincronizar la barra inferior.
        onPageChanged: (index) {
          setState(() => _selectedIndex = index);
        },

        // Las páginas que se mostrarán en el carrusel.
        children: _paginas,
      ),

      // Barra de navegación inferior fija.
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: AppColors.naranja,
        unselectedItemColor: Colors.grey,
        // 'fixed' asegura que los iconos y textos no se muevan/animen al cambiar de pestaña.
        type: BottomNavigationBarType.fixed,

        // Cuando el usuario toca un icono, navegamos a esa página con animación suave.
        onTap: (index) {
          setState(() => _selectedIndex = index);

          // Animación programática: movemos el PageView a la página seleccionada.
          _pageController.animateToPage(
            index,
            duration: const Duration(
              milliseconds: 300,
            ), // Duración de la animación (0.3s)
            curve:
                Curves.easeInOut, // Curva de aceleración/desaceleración suave
          );
        },

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.library_books),
            label: 'Biblioteca',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Clubes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}
