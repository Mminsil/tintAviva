import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tintaviva/pages/login_page.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Página de introducción (Onboarding) que se muestra la primera vez que el usuario abre la app.
///
/// Propósito:
/// 1. Presentar las funcionalidades clave de TintAviva mediante tarjetas deslizables
/// 2. Guiar al usuario sobre cómo usar: biblioteca, clubes, diario, racha y citas
/// 3. Guardar en `SharedPreferences` que el usuario ya vio el tutorial para no repetirlo
///
/// Navegación:
/// - Al finalizar, reemplaza la pila con `LoginPage` para evitar volver atrás
class OnboardingPage extends StatefulWidget {
  final VoidCallback? onComplete;
  const OnboardingPage({super.key, this.onComplete});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  /// Controlador para manejar el deslizamiento manual o programático del `PageView`.
  final PageController _pageController = PageController();

  /// Índice de la página actual visible (para actualizar los indicadores de puntos).
  int _currentPage = 0;

  /// Lista de datos que define el contenido de cada tarjeta del onboarding.
  ///
  /// Estructura de cada `Map<String, dynamic>`:
  /// - `'isLogo'`: `bool` → si es `true`, muestra el logo en lugar de un icono
  /// - `'icon'`: `IconData` → icono a mostrar (si `isLogo` es `false`)
  /// - `'color'`: `Color` → color del icono o acento visual
  /// - `'title'`: `String` → título principal de la tarjeta
  /// - `'description'`: `String` → texto descriptivo de la funcionalidad
  final List<Map<String, dynamic>> _onboardingData = [
    {
      'isLogo': true,
      'title': 'Bienvenido a TintAviva',
      'description':
          'Tu compañero definitivo para organizar lecturas, compartir con amigos y mantener la motivación diaria.',
    },
    {
      'icon': Icons.library_books,
      'color': AppColors.morado,
      'title': 'Tu Biblioteca Personal',
      'description':
          'Organiza tus lecturas en estanterías inteligentes. Lleva el control de tu progreso página a página y gestiona tus libros personales con facilidad.',
    },
    {
      'icon': Icons.groups,
      'color': AppColors.naranja,
      'title': 'Clubs de Lectura Privados',
      'description':
          'Crea un club, elige un libro y comparte el código con tus amigos. Pueden leer el libro al mismo ritmo siguiendo las metas, compartir tus reflexiones en cada tramo y consultar el historial de conversaciones pasadas para revivir los mejores momentos del club.',
    },
    {
      'icon': Icons.edit_note,
      'color': AppColors.morado,
      'title': 'Diario de Lectura',
      'description':
          'Guarda tus reflexiones, emociones (😍 🤔 😢) y momentos clave de cada libro. Crea un registro personal de tu viaje literario.',
    },
    {
      'icon': Icons.format_quote,
      'color': AppColors.naranja,
      'title': 'Citas Favoritas',
      'description':
          'Captura la inspiración. Guarda las frases que más te gusten de tus libros y recíbelas al azar cada vez que abras la app para empezar el día con energía.',
    },
    {
      'icon': Icons.local_fire_department,
      'color': Colors.redAccent,
      'title': 'Racha de Lectura',
      'description':
          'Mantén la motivación diaria. Gana días consecutivos leyendo y recibe mensajes de ánimo para convertir la lectura en un hábito imparable.',
    },
    {
      'isLogo': true,
      'color': AppColors.naranja,
      'title': 'Tu próxima aventura te espera',
      'description':
          'Ya sea solo o con amigos, cada página es un nuevo comienzo. Bienvenido a TintAviva, donde la lectura cobra vida y la tinta aviva tu mente.',
    },
  ];

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (ÍNDICE LEGIBLE)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: SafeArea(child: _buildBody()),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye el cuerpo principal con `PageView`, indicadores y botón de acción.
  Widget _buildBody() {
    return Column(
      children: [
        Expanded(child: _buildPageView()),
        _buildPageIndicators(),
        const SizedBox(height: 40),
        _buildNextButton(),
      ],
    );
  }

  /// Construye el `PageView` con las tarjetas de onboarding deslizables.
  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      itemCount: _onboardingData.length,
      itemBuilder: (context, index) => _buildPageViewItem(index),
    );
  }

  /// Construye una tarjeta individual del onboarding con padding y contenido centrado.
  Widget _buildPageViewItem(int index) {
    final data = _onboardingData[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildMediaElement(data),
          const SizedBox(height: 40),
          _buildTitle(data['title'] as String),
          const SizedBox(height: 20),
          _buildDescription(data['description'] as String),
        ],
      ),
    );
  }

  /// Construye el elemento visual principal: logo o icono según el tipo de tarjeta.
  Widget _buildMediaElement(Map<String, dynamic> data) {
    if (data['isLogo'] == true) {
      return _buildLogoCard();
    } else {
      return _buildIconCard(data['icon'] as IconData, data['color'] as Color);
    }
  }

  /// Construye la tarjeta con el logo de la app.
  Widget _buildLogoCard() {
    return Container(
      width: 150,
      height: 200,
      padding: const EdgeInsets.all(20),
      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
    );
  }

  /// Construye la tarjeta con un icono temático y color personalizado.
  Widget _buildIconCard(IconData icon, Color color) {
    return Icon(icon, size: 100, color: color);
  }

  /// Construye el título de la tarjeta con estilo consistente.
  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.morado,
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Construye la descripción detallada con espaciado mejorado para legibilidad.
  Widget _buildDescription(String description) {
    return Text(
      description,
      style: TextStyle(fontSize: 16, color: Colors.grey[700], height: 1.5),
      textAlign: TextAlign.center,
    );
  }

  /// Construye la fila de indicadores visuales (puntos) para la posición actual.
  Widget _buildPageIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _onboardingData.length,
        (index) => _buildPageIndicator(index),
      ),
    );
  }

  /// Construye un indicador individual (punto) con tamaño y color según si está activo.
  Widget _buildPageIndicator(int index) {
    final bool isActive = _currentPage == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 12 : 8,
      height: isActive ? 12 : 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isActive ? AppColors.naranja : Colors.grey.shade300,
      ),
    );
  }

  /// Construye el botón de acción principal: "Siguiente" o "Empezar a Leer".
  Widget _buildNextButton() {
    final bool isLastPage = _currentPage == _onboardingData.length - 1;
    return Padding(
      padding: const EdgeInsets.only(bottom: 40, left: 40, right: 40),
      child: ElevatedButton(
        onPressed: _nextPage,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.morado,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
        ),
        child: Text(
          isLastPage ? "Empezar a Leer" : "Siguiente",
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NAVEGACIÓN Y ESTADO
  // ─────────────────────────────────────────────────────────────

  /// Maneja el cambio de página cuando el usuario desliza manualmente.
  ///
  /// Actualiza `_currentPage` para sincronizar los indicadores visuales.
  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  /// Avanza a la siguiente página del onboarding o finaliza si es la última.
  void _nextPage() {
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      _finishOnboarding();
    }
  }

  /// Finaliza el onboarding: ejecuta `onComplete` si existe, sino navega a `LoginPage`.
  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;

    // Si hay callback, lo ejecuta; sino, navega a login
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
