import 'package:flutter/material.dart';
import 'package:tintaviva/pages/detalle_libro_page.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/widgets/app_book_cover.dart';



/// Tarjeta reutilizable para mostrar un libro con su progreso y opciones de edición rápida.
///
/// Soporta tres formatos:
/// - `'Papel'`: muestra `"Pág. X de Y (progress%)"`
/// - `'Digital'`: muestra `"{progress}% leído"`
/// - `'Audio'`: muestra `"MM:SS / HH:MM:SS (progress%)"`
///
/// Usos principales:
/// 1. `MiBibliotecaPage`: lista de libros en biblioteca personal (borde naranja)
/// 2. `DetalleClubPage`: muestra el libro actual del club (borde morado)
///
/// Características visuales:
/// - Portada con sombra y bordes redondeados (`AppBookCover`)
/// - Título (2 líneas máx.) y autor (1 línea) con `TextOverflow.ellipsis`
/// - Barra de progreso adaptativa (`WidgetBarraProgreso`)
/// - Borde de color: `AppColors.naranja` (personal) | `AppColors.morado` (club)
/// - Sombra sutil para profundidad visual
///
/// Interacciones:
/// - **Tap en tarjeta**: navega a `DetalleLibroPage` o ejecuta `onTapCustom`
/// - **Botón editar** (`Icons.edit_note`): abre `abrirDialogoEdicionRapida`
///
/// Estructura de datos esperada en `libroData`:
/// ```dart
/// {
///   'title': String,            // Título del libro
///   'author': String,           // Autor del libro
///   'bookCover': String?,       // URL de portada (puede ser null)
///   'bookId': String,           // ID del libro en colección 'books'
///   'progress': int,            // Porcentaje de progreso (0-100)
///   'format': String,           // 'Digital' | 'Papel' | 'Audio'
///   // Para formato 'Papel':
///   'currentPage': int,         // Página actual
///   'totalPages': int,          // Total de páginas
///   // Para formato 'Audio':
///   'currentSeconds': int?,     // Segundos reproducidos (null si no es Audio)
///   'totalSeconds': int?,       // Duración total en segundos (null si no es Audio)
/// }
/// ```
///
/// Ejemplo de uso:
/// ```dart
/// // Libro en formato Audio:
/// TarjetaLibroProgreso(
///   docId: doc.id,
///   libroData: {
///     'title': 'Mi audiolibro',
///     'author': 'Autor X',
///     'format': 'Audio',
///     'progress': 22,
///     'currentSeconds': 1845,   // 30:45
///     'totalSeconds': 57853,    // 16:04:13
///   },
/// )
/// ```
class TarjetaLibroProgreso extends StatelessWidget {
  /// ID del documento en la colección `'user_books'`.
  final String docId;

  /// Mapa con los datos del libro a mostrar.
  /// Debe contener las claves documentadas en la descripción de la clase.
  final Map<String, dynamic> libroData;

  /// Callback opcional para personalizar la navegación al tocar la tarjeta.
  final VoidCallback? onTapCustom;

  /// Indica si la tarjeta representa un libro de club (cambia el color del borde).
  final bool esClub;

  const TarjetaLibroProgreso({
    super.key,
    required this.docId,
    required this.libroData,
    this.onTapCustom,
    this.esClub = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: esClub
              ? AppColors.morado.withValues(alpha: 0.8)
              : AppColors.naranja.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        color: Colors.transparent,
        child: InkWell(
          onTap:
              onTapCustom ??
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalleLibroPage(
                      userBookId: docId,
                      bookId: libroData['bookId'],
                    ),
                  ),
                );
              },
          borderRadius: BorderRadius.circular(15),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Portada del libro
                Container(
                  width: 70,
                  height: 105,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: AppBookCover(
                    imageUrl: libroData['bookCover'],
                    width: 70,
                    height: 105,
                    borderRadius: 8.0,
                  ),
                ),
                const SizedBox(width: 15),

                // Información del libro + barra de progreso
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        libroData['title'] ?? 'Sin título',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        libroData['author'] ?? 'Autor desconocido',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),

                      // Barra de progreso adaptativa (Papel/Digital/Audio)
                      WidgetBarraProgreso(
                        progress: libroData['progress'] ?? 0,
                        currentPage: libroData['currentPage'] ?? 0,
                        totalPages: libroData['totalPages'] ?? 0,
                        currentSeconds: libroData['currentSeconds'],
                        totalSeconds: libroData['totalSeconds'],
                        format: libroData['format'] ?? 'Digital',
                        height: 6,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),

                // Botón de edición rápida
                IconButton(
                  icon: Icon(
                    Icons.edit_note,
                    color: AppColors.morado.withValues(alpha: 0.6),
                    size: 24,
                  ),
                  onPressed: () {
                    abrirDialogoEdicionRapida(context, docId, libroData);
                  },
                  tooltip: 'Editar progreso',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Widget que muestra una barra de progreso lineal con texto descriptivo adaptado al formato.
///
/// Formatos soportados:
/// - `'Digital'`: `"{progress}% leído"`
/// - `'Papel'`: `"Pág. X de Y (progress%)"`
/// - `'Audio'`: `"MM:SS / HH:MM:SS (progress%)"`
class WidgetBarraProgreso extends StatelessWidget {
  /// Porcentaje de progreso completado (0-100).
  final int progress;

  /// Página actual (solo para formato `'Papel'`).
  final int currentPage;

  /// Total de páginas (solo para formato `'Papel'`).
  final int totalPages;

  /// Segundos reproducidos (solo para formato `'Audio'`).
  /// Puede ser `null` si el formato no es Audio.
  final int? currentSeconds;

  /// Duración total en segundos (solo para formato `'Audio'`).
  /// Puede ser `null` si el formato no es Audio.
  final int? totalSeconds;

  /// Formato del libro: `'Digital'`, `'Papel'` o `'Audio'`.
  final String format;

  /// Altura de la barra en píxeles.
  final double height;

  const WidgetBarraProgreso({
    super.key,
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    this.currentSeconds,
    this.totalSeconds,
    required this.format,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final Color colorNaranja = const Color(0xFFFF6B35);
    String textoDescriptivo = "$progress% leído";

    if (format == 'Papel' && totalPages > 0) {
      final int paginaMostrar = currentPage > 0
          ? currentPage
          : (progress * totalPages / 100).round();
      textoDescriptivo = "Pág. $paginaMostrar de $totalPages ($progress%)";
    } else if (format == 'Audio' &&
        totalSeconds != null &&
        currentSeconds != null) {
      // Mostrar tiempos formateados solo si ambos valores están presentes
      final actual = segundosATiempo(currentSeconds!);
      final total = segundosATiempo(totalSeconds!);
      textoDescriptivo = "$actual / $total ($progress%)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[200],
            color: colorNaranja,
            minHeight: height,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          textoDescriptivo,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
