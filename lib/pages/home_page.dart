import 'package:flutter/material.dart';
import 'package:tintaviva/pages/clubes_page.dart';
import 'package:tintaviva/pages/diario_page.dart';
import 'package:tintaviva/pages/mi_biblioteca_page.dart';
import 'package:tintaviva/pages/perfil_page.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Página principal de navegación de la aplicación.
///
/// Funciona como contenedor de las secciones principales:
/// 1. `MiBibliotecaPage` (gestión de libros personales)
/// 2. `DiarioPage` (reflexiones y citas)
/// 3. `ClubesPage` (lectura social y metas grupales)
/// 4. `PerfilPage` (estadísticas y configuración)
///
/// Características de navegación:
/// - Cambio de pestaña por toque en `BottomNavigationBar`
/// - Navegación por swipe horizontal con `PageView`
/// - Preservación de estado por página gracias a `PageController`
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Índice de la pestaña actualmente seleccionada.
  ///
  /// Valores: `0` = Biblioteca, `1` = Diario, `2` = Clubes, `3` = Perfil
  int _selectedIndex = 0;

  /// Controlador para gestionar el `PageView`.
  ///
  /// Permite:
  /// - Animaciones programáticas con `animateToPage()`
  /// - Detectar cambios por swipe del usuario
  final PageController _pageController = PageController();

  /// Lista de widgets que representan cada sección de la app.
  ///
  /// Se mantienen en memoria mientras `HomePage` esté activo,
  /// preservando su estado interno (scroll, inputs, etc.).
  final List<Widget> _paginas = const [
    MiBibliotecaPage(),
    DiarioPage(),
    ClubesPage(),
    PerfilPage(),
  ];

  @override
  void dispose() {
    // Liberamos el controlador para evitar fugas de memoria.
    _pageController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL 
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildPageView(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye el `PageView` principal con navegación por swipe.
  ///
  /// - Usa `_pageController` para sincronizar con la barra inferior
  /// - `BouncingScrollPhysics` da efecto de rebote al final del scroll
  /// - `onPageChanged` actualiza `_selectedIndex` al deslizar
  Widget _buildPageView() {
    return PageView(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      onPageChanged: _onPageChanged,
      children: _paginas,
    );
  }

  /// Construye la barra de navegación inferior fija.
  ///
  /// - `type: fixed` evita animaciones de iconos/texto al cambiar
  /// - `onTap` navega con animación suave vía `_pageController`
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      selectedItemColor: AppColors.naranja,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      onTap: _onNavItemTapped,
      items: _buildNavItems(),
    );
  }

  /// Construye la lista de ítems para `BottomNavigationBar`.
  List<BottomNavigationBarItem> _buildNavItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.library_books),
        label: 'Biblioteca',
      ),
      BottomNavigationBarItem(icon: Icon(Icons.edit_note), label: 'Diario'),
      BottomNavigationBarItem(icon: Icon(Icons.groups), label: 'Clubes'),
      BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
    ];
  }

  // ─────────────────────────────────────────────────────────────
  // HANDLERS DE EVENTOS (LÓGICA DE NAVEGACIÓN)
  // ─────────────────────────────────────────────────────────────

  /// Maneja el cambio de página por swipe del usuario.
  ///
  /// Actualiza `_selectedIndex` para sincronizar la barra inferior.
  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Maneja el toque en un ítem de la barra de navegación.
  ///
  /// Navega a la página seleccionada con animación suave:
  /// - `duration: 300ms` para transición fluida
  /// - `curve: easeInOut` para aceleración/desaceleración natural
  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
