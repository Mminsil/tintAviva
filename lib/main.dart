import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:tintaviva/pages/login_page.dart';
import 'package:tintaviva/pages/splash_page.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Punto de entrada principal de la aplicacion TintAviva.
///
/// Inicializa Firebase y lanza el widget raiz.
/// El orden es importante:
/// 1. WidgetsFlutterBinding.ensureInitialized() - Prepara el entorno Flutter
/// 2. Firebase.initializeApp() - Configura Firebase con las opciones de plataforma
/// 3. runApp() - Inicia la aplicacion
void main() async {
  // Inicializar Flutter
  WidgetsFlutterBinding.ensureInitialized();
  // Cargar el archivo .env
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Inicia la app
  runApp(const TintAvivaApp());
}

/// Widget raiz de la aplicacion.
///
/// Configuraciones globales:
/// - Tema visual (colores, tipografias, formas de inputs y botones)
/// - Rutas de navegacion
/// - Debug banner deshabilitado
///
/// Nota: El widget ShowCaseWidget que aparece comentado en el codigo original
/// fue removido porque no esta importado. Si se necesita onboarding con tooltips,
/// debe agregarse la dependencia y envolver el MaterialApp.
class TintAvivaApp extends StatelessWidget {
  const TintAvivaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TintAviva',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.morado,
        scaffoldBackgroundColor: AppColors.fondoClaro,

        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.morado,
          primary: AppColors.morado,
          secondary: AppColors.naranja,
          surface: AppColors.fondoClaro,
        ),

        // Estilo unificado para AppBars
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.morado,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: AppColors.morado,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Estilo por defecto para TextFields
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

        // Estilo por defecto para ElevatedButtons
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

      // Pantalla inicial: Splash screen
      home: const SplashPage(),

      // Rutas nombradas para navegacion
      routes: {'/login': (context) => const LoginPage()},
    );
  }
}
