import 'package:flutter/material.dart';

// --- COLORES CORPORATIVOS ---
/// Definición centralizada de la paleta de colores de Tintaviva.
class AppColors {
  static const Color morado = Color(0xFF5D3B82); // Color principal (Marca)
  static const Color naranja = Color(0xFFFF6B35); // Color de acción/acento
  static const Color fondoClaro = Color(
    0xFFF8F9FA,
  ); // Fondo general de pantallas
  static const Color textoNegroSuave = Color(
    0xFF333333,
  ); // Texto principal (no negro puro)
  static const Color grisBorde = Color(
    0xFFE0E0E0,
  ); // Bordes de inputs y divisores
  static const Color blanco = Colors.white; // Fondos de tarjetas/inputs
}

// --- ESTILOS DE INPUTS (TEXT FIELDS) ---
/// Estilos reutilizables para campos de texto, asegurando consistencia visual.
class AppInputStyles {
  /// Devuelve un InputDecoration estandarizado con bordes redondeados y colores corporativos.
  static InputDecoration inputDecoration(String label, {IconData? prefixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.morado,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: AppColors.morado)
          : null,
      // Borde por defecto (gris suave)
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.grisBorde),
      ),
      // Borde cuando está habilitado pero no enfocado
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.grisBorde),
      ),
      // Borde cuando el usuario hace clic (enfocado) -> Naranja
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.naranja, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}

// --- ESTILOS DE BOTONES ---
/// Estilos predefinidos para botones elevados y de texto.
class AppButtonStyles {
  // Botón Principal: Naranja, texto blanco, sombra suave.
  static ButtonStyle primaryElevatedButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.naranja,
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    elevation: 2,
  );

  // Botón Secundario: Texto morado, sin fondo.
  static ButtonStyle secondaryTextButton = TextButton.styleFrom(
    foregroundColor: AppColors.morado,
    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  );
}

// --- ESTILOS DE TÍTULOS ---
/// Tipografía estandarizada para encabezados y diálogos.
class AppTextStyles {
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.morado,
  );

  static const TextStyle dialogTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.morado,
  );
}

// --- SNACKBAR ---
/// Muestra una notificación flotante temporal en la parte inferior.
void mostrarSnackBar(BuildContext context, String mensaje, Color color) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating, // Flota sobre el contenido
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(10),
    ),
  );
}
