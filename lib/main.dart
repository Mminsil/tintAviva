import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:tintaviva/firebase_options.dart';
import 'package:tintaviva/pages/login_page.dart';
import 'package:tintaviva/pages/splash_page.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Punto de entrada principal de la aplicación TintAviva.
///
/// Flujo de inicialización (orden crítico):
/// 1. `WidgetsFlutterBinding.ensureInitialized()` - Prepara el entorno Flutter para operaciones asíncronas
/// 2. `dotenv.load(fileName: ".env")` - Carga variables de entorno (ej: `GOOGLE_BOOKS_API_KEY`)
/// 3. `Firebase.initializeApp(options: ...)` - Configura Firebase con opciones específicas de plataforma
/// 4. `runApp(const TintAvivaApp())` - Inicia el árbol de widgets de la aplicación
///
/// Nota sobre el orden:
/// - `ensureInitialized()` debe llamarse antes de cualquier `await` en `main()`
/// - `dotenv.load()` debe completarse antes de que cualquier servicio acceda a `dotenv.env`
/// - `Firebase.initializeApp()` debe completarse antes de que cualquier widget use `FirebaseAuth` o `FirebaseFirestore`
///
/// Ejemplo de variables en `.env`:
/// ```env
/// GOOGLE_BOOKS_API_KEY=tu_api_key_aqui
/// ```
void main() async {
  // Inicializar Flutter para permitir operaciones asíncronas antes de runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Cargar el archivo .env para acceder a variables de entorno seguras
  await dotenv.load(fileName: ".env");

  // Inicializar Firebase con las opciones generadas para la plataforma actual
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Inicia la aplicación con el widget raíz
  runApp(const TintAvivaApp());
}

/// Widget raíz de la aplicación TintAviva.
///
/// Configuraciones globales aplicadas en este nivel:
/// - **Tema visual**: colores corporativos (`AppColors.morado`, `AppColors.naranja`), tipografías, formas de inputs y botones
/// - **Rutas de navegación**: definición de rutas nombradas para acceso directo (ej: `'/login'`)
/// - **Debug banner**: deshabilitado con `debugShowCheckedModeBanner: false` para builds de producción
///
/// Estructura del tema (`ThemeData`):
/// - `primaryColor`: Color principal para widgets que usan el tema primario
/// - `scaffoldBackgroundColor`: Fondo por defecto para todas las pantallas (`Scaffold`)
/// - `colorScheme`: Esquema de colores derivado de `seedColor` para consistencia en componentes Material 3
/// - `appBarTheme`: Estilo unificado para todas las `AppBar` de la aplicación
/// - `inputDecorationTheme`: Estilo base para todos los `TextField` y `TextFormField`
/// - `elevatedButtonTheme`: Estilo base para todos los `ElevatedButton`
///
/// Navegación:
/// - Pantalla inicial: `SplashPage` (maneja redirección a `OnboardingPage`, `LoginPage` o `HomePage`)
/// - Rutas nombradas: `'/login'` → `LoginPage` (para redirecciones programáticas)
///
/// Nota sobre `ShowCaseWidget`:
/// Si en el futuro se necesita onboarding con tooltips guiados, se puede envolver `MaterialApp`
/// con `ShowCaseWidget` tras agregar la dependencia `showcaseview` en `pubspec.yaml`.
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

        // Esquema de colores derivado para consistencia en componentes Material 3
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.morado,
          primary: AppColors.morado,
          secondary: AppColors.naranja,
          surface: AppColors.fondoClaro,
        ),

        // Estilo unificado para AppBars en toda la aplicación
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

        // Estilo por defecto para TextFields: bordes redondeados, colores corporativos
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

        // Estilo por defecto para ElevatedButtons: naranja, texto blanco, bordes redondeados
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

      // Pantalla inicial: SplashPage maneja la lógica de redirección según estado de usuario
      home: const SplashPage(),

      // Rutas nombradas para navegación programática (ej: tras logout)
      routes: {'/login': (context) => const LoginPage()},
    );
  }
}
