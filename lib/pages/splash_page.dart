import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tintaviva/pages/home_page.dart';
import 'package:tintaviva/pages/login_page.dart';
import 'package:tintaviva/pages/onboarding_page.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Pantalla de bienvenida (Splash Screen) de TintAviva.
///
/// Funciones principales:
/// 1. Muestra el logo y slogan con animaciones de entrada (`fade` + `scale`)
/// 2. Decide automáticamente a qué pantalla navegar según el estado del usuario:
///    - Si es la primera vez: `OnboardingPage`
///    - Si ya vio onboarding pero no está logueado: `LoginPage`
///    - Si ya vio onboarding y está logueado: `HomePage`
/// 3. Usa `Navigator.pushReplacement` para evitar que el usuario pueda volver a esta pantalla con "Atrás"
///
/// Animaciones:
/// - Duración: `1500ms` con curva `Curves.easeInOut`
/// - Efectos: opacidad (`FadeTransition`) + escala (`ScaleTransition` de 0.8 a 1.0)
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  /// Controlador para la animación principal (opacidad + escala).
  ///
  /// Gestiona el ciclo de vida de la animación: `forward()`, `dispose()`, etc.
  late AnimationController _controller;

  /// Animación curva para un movimiento más natural (`easeInOut`).
  ///
  /// Se deriva de `_controller` con `CurvedAnimation` para suavizar el inicio y fin.
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Configuración de la animación de entrada del logo.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500), // Duración total: 1.5s
      vsync: this, // Sincroniza con el refresh rate de la pantalla
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward(); // Inicia la animación

    // Llamada al método principal de navegación con lógica completa.
    _navegarSiguientePantalla();
  }

  @override
  void dispose() {
    // Liberar el controlador de animación para evitar fugas de memoria.
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (UI CON ANIMACIONES)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: Center(
        child: FadeTransition(
          // La opacidad cambia de 0 a 1 según la animación.
          opacity: _animation,
          child: ScaleTransition(
            // La escala cambia de 0.8 (ligeramente pequeño) a 1.0 (tamaño normal).
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(_animation),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo de la aplicación con bordes redondeados.
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/portada.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
                // Slogan de la marca con estilo cursivo.
                Text(
                  'Donde la tinta aviva tu mente.',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.textoNegroSuave,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NAVEGACIÓN (DECISIÓN DE RUTA)
  // ─────────────────────────────────────────────────────────────

  /// Decide la siguiente pantalla basándose en el estado de onboarding y autenticación.
  ///
  /// Flujo de decisión:
  /// 1. Espera 2 segundos para mostrar la splash screen
  /// 2. Consulta `SharedPreferences` para ver si el usuario ya vio el onboarding
  /// 3. Si NO lo vio → Navega a `OnboardingPage`
  /// 4. Si YA lo vio → Consulta `FirebaseAuth`:
  ///    - Si hay usuario logueado → Navega a `HomePage`
  ///    - Si no hay usuario → Navega a `LoginPage`
  /// 5. Usa `pushReplacement` para limpiar la pila de navegación
  ///
  /// Seguridad:
  /// - Verifica `mounted` antes y después de `await` para evitar errores si el widget se destruye
  Future<void> _navegarSiguientePantalla() async {
    // Pausa visual para que el usuario aprecie la animación de entrada.
    await Future.delayed(const Duration(seconds: 2));

    // Verificación de seguridad: si el widget fue destruido, no navegamos.
    if (!mounted) {
      return;
    }

    // Consulta asíncrona a preferencias locales.
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('hasSeenOnboarding') ?? false;

    // Consulta síncrona al estado actual de autenticación.
    final user = FirebaseAuth.instance.currentUser;

    Widget nextScreen;

    // Lógica principal de enrutamiento.
    if (!hasSeenOnboarding) {
      // Primer acceso: mostrar tutorial interactivo.
      nextScreen = const OnboardingPage();
    } else {
      // Usuario recurrente: verificar sesión.
      if (user == null) {
        nextScreen = const LoginPage();
      } else {
        nextScreen = const HomePage();
      }
    }

    // Segunda verificación de mounted antes de navegar (buena práctica).
    if (!mounted) {
      return;
    }

    // Navegación reemplazando la pila: el usuario no puede volver a Splash con "Atrás".
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }
}
