import 'package:flutter/material.dart';
import 'package:tintaviva/pages/detalle_libro_page.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Tarjeta reutilizable para mostrar un libro con su progreso y opciones de edicion rapida.
///
/// Usos principales:
/// 1. MiBibliotecaPage: lista de libros en biblioteca personal
/// 2. DetalleClubPage: muestra el libro actual del club con borde de color distintivo
///
/// Caracteristicas:
/// - Muestra portada, titulo, autor y barra de progreso adaptativa (Papel/Digital)
/// - Navegacion al detalle del libro al tocar la tarjeta
/// - Menu contextual (tres puntos) con opciones:
///   - Editar progreso (abre DialogoEdicionRapida)
///   - Guardar cita (abre dialogo para agregar cita)
/// - Borde de color: naranja para biblioteca personal, morado para clubes
class TarjetaLibroProgreso extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> libroData;
  final VoidCallback? onTapCustom;
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

                // Informacion del libro y barra de progreso
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

                      // Barra de progreso adaptativa (Papel muestra paginas, Digital muestra porcentaje)
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
