import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
// COLORES CORPORATIVOS
// ─────────────────────────────────────────────────────────────

/// Definición centralizada de la paleta de colores de Tintaviva.
///
/// Propósito:
/// - Garantizar consistencia visual en toda la aplicación
/// - Facilitar cambios de tema modificando un solo archivo
/// - Documentar el significado semántico de cada color
///
/// Uso recomendado:
/// ```dart
/// // ✅ Correcto:
/// color: AppColors.morado
///
/// // ❌ Evitar:
/// color: Color(0xFF5D3B82) // Hardcodear valores hex
/// ```
class AppColors {
  /// Color principal de marca (morado).
  ///
  /// Usado en:
  /// - Títulos de sección (`AppTextStyles.sectionTitle`)
  /// - Iconos destacados
  /// - Bordes de elementos activos
  static const Color morado = Color(0xFF5D3B82);

  /// Color de acción/acento (naranja).
  ///
  /// Usado en:
  /// - Botones primarios (`AppButtonStyles.primaryElevatedButton`)
  /// - Estados de progreso activo
  /// - Feedback visual de acciones importantes
  static const Color naranja = Color(0xFFFF6B35);

  /// Fondo general de pantallas (gris muy claro).
  ///
  /// Usado como `backgroundColor` en `Scaffold` para:
  /// - `MiBibliotecaPage`
  /// - `PerfilPage`
  /// - `DetalleClubPage`
  static const Color fondoClaro = Color(0xFFF8F9FA);

  /// Texto principal (gris oscuro, no negro puro).
  ///
  /// Mejora la legibilidad vs `Colors.black` puro, reduciendo fatiga visual.
  /// Usado en:
  /// - Nombres de usuario
  /// - Títulos de libros
  /// - Texto de párrafos principales
  static const Color textoNegroSuave = Color(0xFF333333);

  /// Color para bordes de inputs y divisores (gris medio).
  ///
  /// Usado en:
  /// - `InputDecoration.border` (estado no enfocado)
  /// - `Divider` entre secciones
  /// - Bordes de tarjetas secundarias
  static const Color grisBorde = Color(0xFFE0E0E0);

  /// Blanco puro para fondos de tarjetas e inputs.
  ///
  /// Alias de `Colors.white` para consistencia semántica.
  static const Color blanco = Colors.white;
}

// ─────────────────────────────────────────────────────────────
// ESTILOS DE INPUTS (TEXT FIELDS)
// ─────────────────────────────────────────────────────────────

/// Estilos reutilizables para campos de texto, asegurando consistencia visual.
///
/// Propósito:
/// - Centralizar la configuración de `InputDecoration`
/// - Aplicar la paleta de `AppColors` automáticamente
/// - Reducir código repetitivo en formularios
class AppInputStyles {
  /// Devuelve un `InputDecoration` estandarizado con bordes redondeados y colores corporativos.
  ///
  /// Parámetros:
  /// - [label]: Texto que aparece como etiqueta flotante (`labelText`)
  /// - [prefixIcon]: Icono opcional que aparece a la izquierda del input
  ///
  /// Características del estilo:
  /// - **Bordes**: `BorderRadius.circular(10)` para suavidad visual
  /// - **Colores**:
  ///   - No enfocado: `AppColors.grisBorde`
  ///   - Enfocado: `AppColors.naranja` con `width: 2` para feedback táctil
  /// - **Fondo**: `Colors.white` con `filled: true` para contraste
  /// - **Label**: `AppColors.morado` con `FontWeight.w500` para jerarquía
  ///
  /// Ejemplo de uso:
  /// ```dart
  /// TextField(
  ///   decoration: AppInputStyles.inputDecoration(
  ///     'Buscar libro...',
  ///     prefixIcon: Icons.search,
  ///   ),
  /// )
  /// ```
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

// ─────────────────────────────────────────────────────────────
// ESTILOS DE BOTONES
// ─────────────────────────────────────────────────────────────

/// Estilos predefinidos para botones elevados y de texto.
///
/// Propósito:
/// - Centralizar la configuración de `ButtonStyle`
/// - Aplicar la paleta de `AppColors` automáticamente
/// - Reducir código repetitivo en acciones de UI
class AppButtonStyles {
  /// Botón Principal: Naranja, texto blanco, sombra suave.
  ///
  /// Usado para acciones primarias:
  /// - "Guardar cambios" en `EditarLibroPage`
  /// - "Finalizar Club" en `DetalleClubPage`
  /// - "Empezar a Leer" en `OnboardingPage`
  ///
  /// Características:
  /// - `backgroundColor`: `AppColors.naranja` para destacar
  /// - `foregroundColor`: `Colors.white` para contraste AAA
  /// - `elevation: 2`: sombra sutil para profundidad
  /// - `borderRadius: 10`: coherencia con inputs
  static ButtonStyle primaryElevatedButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.naranja,
    foregroundColor: Colors.white,
    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    elevation: 2,
  );

  /// Botón Secundario: Texto morado, sin fondo.
  ///
  /// Usado para acciones secundarias o de navegación:
  /// - "Cancelar" en diálogos
  /// - "Ver más" en listas
  /// - Enlaces de texto como "¿Olvidaste tu contraseña?"
  ///
  /// Características:
  /// - `foregroundColor`: `AppColors.morado` para jerarquía visual
  /// - Sin fondo: para no competir con botones primarios
  static ButtonStyle secondaryTextButton = TextButton.styleFrom(
    foregroundColor: AppColors.morado,
    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
  );
}

// ─────────────────────────────────────────────────────────────
// ESTILOS DE TÍTULOS
// ─────────────────────────────────────────────────────────────

/// Tipografía estandarizada para encabezados y diálogos.
///
/// Propósito:
/// - Centralizar estilos de texto para consistencia visual
/// - Aplicar `AppColors.morado` automáticamente en títulos
/// - Reducir código repetitivo en widgets de texto
class AppTextStyles {
  /// Estilo para títulos de sección dentro de pantallas.
  ///
  /// Usado en:
  /// - "Mi Biblioteca" en `MiBibliotecaPage`
  /// - "Mis Estanterías" en `PerfilPage`
  /// - "Comentarios y Debate" en `DetalleClubPage`
  ///
  /// Características:
  /// - `fontSize: 18`: legible sin dominar la pantalla
  /// - `fontWeight: FontWeight.bold`: jerarquía visual clara
  /// - `color: AppColors.morado`: coherencia de marca
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: AppColors.morado,
  );

  /// Estilo para títulos de diálogos modales.
  ///
  /// Usado en:
  /// - "¿Eliminar cuenta?" en `PerfilPage`
  /// - "Editar Club" en `DetalleClubPage`
  /// - "Definir Nueva Meta" en gestión de clubes
  ///
  /// Diferencias con `sectionTitle`:
  /// - `fontSize: 20`: ligeramente más grande para foco modal
  /// - Mismo color y peso para consistencia de marca
  static const TextStyle dialogTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: AppColors.morado,
  );
}

// ─────────────────────────────────────────────────────────────
// HELPERS DE UI
// ─────────────────────────────────────────────────────────────

/// Muestra una notificación flotante temporal en la parte inferior.
///
/// Parámetros:
/// - [context]: `BuildContext` actual para mostrar el `SnackBar`
/// - [mensaje]: Texto a mostrar en la notificación
/// - [color]: Color de fondo del `SnackBar` (ej: `Colors.green`, `Colors.red`)
///
/// Características del estilo:
/// - `behavior: SnackBarBehavior.floating`: flota sobre el contenido con margen
/// - `shape: BorderRadius.circular(10)`: coherencia con inputs y botones
/// - `margin: EdgeInsets.all(10)`: espaciado visual respecto a los bordes
/// - Texto en `Colors.white` para contraste sobre cualquier color de fondo
///
/// Seguridad:
/// - Verifica `context.mounted` antes de mostrar para evitar errores si el widget fue destruido
///
/// Ejemplo de uso:
/// ```dart
/// // ✅ Éxito:
/// mostrarSnackBar(context, "Libro guardado", Colors.green);
///
/// // ❌ Error:
/// mostrarSnackBar(context, "Error de conexión", Colors.red);
///
/// // ⚠️ Advertencia:
/// mostrarSnackBar(context, "Revisa tu conexión", AppColors.naranja);
/// ```
void mostrarSnackBar(BuildContext context, String mensaje, Color color) {
  if (!context.mounted) {
    return;
  }
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
