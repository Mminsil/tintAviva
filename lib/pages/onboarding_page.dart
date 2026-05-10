import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tintaviva/pages/login_page.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Página de introducción (Onboarding) que se muestra la primera vez que el usuario abre la app.
///
/// Propósito:
/// 1. Presentar las funcionalidades clave de TintAviva mediante tarjetas deslizables.
/// 2. Guiar al usuario sobre cómo usar la biblioteca, clubes, diario de lectura, etc.
/// 3. Guardar en preferencias locales que el usuario ya vio el tutorial para no mostrarlo de nuevo.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  // Controlador para manejar el deslizamiento manual o programático del PageView.
  final PageController _pageController = PageController();
  
  // Índice de la página actual visible (para actualizar los indicadores de puntos).
  int _currentPage = 0;

  /// Lista de datos que define el contenido de cada tarjeta del onboarding.
  /// 
  /// Estructura de cada mapa:
  /// - 'isLogo': Si es true, muestra el logo de la app en lugar de un icono.
  /// - 'icon': IconData a mostrar (si isLogo es false).
  /// - 'color': Color del icono o acento visual.
  /// - 'title': Título principal de la tarjeta.
  /// - 'description': Texto descriptivo explicando la funcionalidad.
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
      'description': 'Guarda tus reflexiones, emociones y momentos clave de cada libro. Crea un registro personal de tu viaje literario con fechas y estados de ánimo.',
    },
    {
      'icon': Icons.local_fire_department,
      'color': Colors.redAccent,
      'title': 'Racha de Lectura',
      'description':
          'Mantén la motivación diaria. Gana días consecutivos leyendo y recibe mensajes de ánimo para convertir la lectura en un hábito imparable.',
    },
    {
      'icon': Icons.format_quote,
      'color': AppColors.naranja,
      'title': 'Citas Favoritas',
      'description':
          'Captura la inspiración. Guarda las frases que más te gusten de tus libros y recíbelas al azar cada vez que abras la app para empezar el día con energía.',
    },
    {
      'isLogo': true,
      'color': AppColors.naranja,
      'title': 'Tu próxima aventura te espera',
      'description':
          'Ya sea solo o con amigos, cada página es un nuevo comienzo. Bienvenido a TintAviva, donde la lectura cobra vida y la tinta aviva tu mente..',
    },
  ];

  /// Avanza a la siguiente página del onboarding o finaliza si es la última.
  void _nextPage() {
    // Si no estamos en la última página, animamos el scroll a la siguiente.
    if (_currentPage < _onboardingData.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    } else {
      // Si es la última, guardamos que el usuario ya vio el tutorial y navegamos al Home.
      _finishOnboarding();
    }
  }

  /// Finaliza el onboarding: guarda el estado en SharedPreferences y navega a la página principal.
  Future<void> _finishOnboarding() async {
    // Obtenemos la instancia de preferencias compartidas (persistencia local simple).
    final prefs = await SharedPreferences.getInstance();
    
    // Marcamos como true para que la próxima vez que se abra la app, no se muestre este onboarding.
    await prefs.setBool('hasSeenOnboarding', true);

    // Navegamos reemplazando la pila para que el usuario no pueda volver al onboarding con el botón "Atrás".
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: SafeArea(
        child: Column(
          children: [
            // Área principal con las tarjetas deslizables.
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                // Actualizamos el índice de página actual cuando el usuario desliza manualmente.
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _onboardingData.length,
                itemBuilder: (context, index) {
                  final data = _onboardingData[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Lógica condicional: mostrar Logo o Icono según el tipo de tarjeta.
                        if (data['isLogo'] == true)
                          Container(
                            width: 150,
                            height: 200,
                            padding: EdgeInsets.all(20),
                            child: Image.asset(
                              'assets/logo.png', 
                              fit: BoxFit.cover,
                            ),
                          )
                        else
                          Icon(
                            data['icon'] as IconData,
                            size: 100,
                            color: data['color'] as Color,
                          ),

                        const SizedBox(height: 40),

                        // Título de la tarjeta.
                        Text(
                          data['title'] as String,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.morado,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        
                        // Descripción detallada de la funcionalidad.
                        Text(
                          data['description'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Indicadores visuales de posición (puntos en la parte inferior).
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _onboardingData.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  // El punto activo es más grande y de color naranja.
                  width: _currentPage == index ? 12 : 8,
                  height: _currentPage == index ? 12 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentPage == index
                        ? AppColors.naranja
                        : Colors.grey.shade300,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Botón de acción principal: "Siguiente" o "Empezar a Leer".
            Padding(
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
                  // Cambiamos el texto del botón si es la última tarjeta.
                  _currentPage == _onboardingData.length - 1
                      ? "Empezar a Leer"
                      : "Siguiente",
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}