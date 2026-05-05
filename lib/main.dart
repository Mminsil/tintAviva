import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tintaviva/pages/login_page.dart';
import 'package:tintaviva/pages/splash_page.dart';
import 'package:tintaviva/theme/app_styles.dart'; // Importa tus estilos globales
import 'firebase_options.dart';

/// Punto de entrada principal de la aplicación TintAviva.
///
/// Inicializa los servicios necesarios (Firebase) y lanza el widget raíz.
void main() async {
  // Asegura que el entorno de Flutter esté listo antes de ejecutar código asíncrono.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa Firebase con las opciones específicas de la plataforma actual.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const TintAvivaApp());
}

/// Widget raíz de la aplicación.
///
/// Configura:
/// 1. El tema visual global (colores, tipografías, formas).
/// 2. Las rutas de navegación principales.
/// 3. El contexto necesario para el tutorial interactivo (ShowCaseWidget).
class TintAvivaApp extends StatelessWidget {
  const TintAvivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ShowCaseWidget envuelve la app para permitir los tooltips educativos en el onboarding.
    return MaterialApp(
        title: 'TintAviva',
        debugShowCheckedModeBanner:
            false, // Oculta la etiqueta "DEBUG" en la esquina.
        // --- DEFINICIÓN DEL TEMA GLOBAL ---
        // Centraliza los estilos para que toda la app sea consistente sin repetir código.
        theme: ThemeData(
          primaryColor: AppColors.morado,
          scaffoldBackgroundColor:
              AppColors.fondoClaro, // Fondo gris suave por defecto.
          // Esquema de colores derivado del morado corporativo.
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.morado,
            primary: AppColors.morado,
            secondary: AppColors.naranja,
            surface: AppColors.fondoClaro,
          ),

          // Estilo unificado para todas las AppBars de la app.
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.morado,
            elevation: 0, // Sin sombra para un look moderno y plano.
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: AppColors.morado,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          // Estilo por defecto para todos los TextFields de la app.
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.grisBorde),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.naranja, width: 2),
            ),
            labelStyle: const TextStyle(color: AppColors.morado),
          ),

          // Estilo por defecto para todos los ElevatedButtons.
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.naranja,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),

        // Pantalla inicial: Splash Screen (animación de carga).
        home: const SplashPage(),

        // Definición de rutas nombradas para navegación directa.
        routes: {
          '/login': (context) => const LoginPage(),
          // Puedes añadir más rutas aquí si necesitas navegación global específica.
        },
      );
  }
}
