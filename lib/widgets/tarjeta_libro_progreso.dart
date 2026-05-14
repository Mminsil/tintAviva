import 'package:flutter/material.dart';
import 'package:tintaviva/pages/detalle_libro_page.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/widgets/app_book_cover.dart';

/// Tarjeta reutilizable para mostrar un libro con su progreso y opciones de edición rápida.
///
/// Usos principales:
/// 1. `MiBibliotecaPage`: lista de libros en biblioteca personal (borde naranja)
/// 2. `DetalleClubPage`: muestra el libro actual del club (borde morado)
///
/// Características visuales:
/// - Portada con sombra y bordes redondeados (`AppBookCover`)
/// - Título (2 líneas máx.) y autor (1 línea) con `TextOverflow.ellipsis`
/// - Barra de progreso adaptativa (`WidgetBarraProgreso`):
///   - `'Digital'`: muestra `"{progress}% leído"`
///   - `'Papel'`: muestra `"Pág. X de Y (progress%)"`
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
///   'title': String,        // Título del libro
///   'author': String,       // Autor del libro
///   'bookCover': String?,   // URL de portada (puede ser null)
///   'bookId': String,       // ID del libro en colección 'books'
///   'progress': int,        // Porcentaje de progreso (0-100)
///   'currentPage': int,     // Página actual (solo relevante para 'Papel')
///   'totalPages': int,      // Total de páginas del libro
///   'format': String,       // 'Digital' | 'Papel'
/// }
/// ```
///
/// Ejemplo de uso:
/// ```dart
/// // En MiBibliotecaPage:
/// TarjetaLibroProgreso(
///   docId: doc.id,
///   libroData: libro,
///   esClub: false, // Borde naranja
/// )
///
/// // En DetalleClubPage:
/// TarjetaLibroProgreso(
///   docId: userBookDoc.id,
///   libroData: userBookData,
///   esClub: true, // Borde morado
/// )
/// ```
class TarjetaLibroProgreso extends StatelessWidget {
  /// ID del documento en la colección `'user_books'`.
  ///
  /// Usado para:
  /// - Navegación a `DetalleLibroPage(userBookId: docId)`
  /// - Actualizar progreso vía `abrirDialogoEdicionRapida(context, docId, ...)`
  final String docId;

  /// Mapa con los datos del libro a mostrar.
  ///
  /// Debe contener las claves documentadas en la descripción de la clase.
  /// Valores `null` se manejan con fallbacks visuales (`'Sin título'`, `'Autor desconocido'`, etc.)
  final Map<String, dynamic> libroData;

  /// Callback opcional para personalizar la navegación al tocar la tarjeta.
  ///
  /// Si se proporciona, se ejecuta en lugar de la navegación por defecto a `DetalleLibroPage`.
  ///
  /// Caso de uso típico:
  /// - En `DetalleClubPage`, para navegar a `DetalleClubPage` en lugar de `DetalleLibroPage`
  ///   cuando el libro pertenece a un club.
  final VoidCallback? onTapCustom;

  /// Indica si la tarjeta representa un libro de club.
  ///
  /// Efecto visual:
  /// - `false` (por defecto): borde `AppColors.naranja.withValues(alpha: 0.8)`
  /// - `true`: borde `AppColors.morado.withValues(alpha: 0.8)`
  ///
  /// Propósito:
  /// - Diferenciar visualmente libros personales vs. libros de club en listas mixtas
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
          // Navegación: usa onTapCustom si existe, sino navega a DetalleLibroPage por defecto
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
                // Portada del libro con sombra y AppBookCover para fallback automático
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

                      // Barra de progreso adaptativa (Papel/Digital)
                      WidgetBarraProgreso(
                        progress: libroData['progress'] ?? 0,
                        currentPage: libroData['currentPage'] ?? 0,
                        totalPages: libroData['totalPages'] ?? 0,
                        format: libroData['format'] ?? 'Digital',
                        height: 6,
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),

                // Botón de edición rápida de progreso
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
