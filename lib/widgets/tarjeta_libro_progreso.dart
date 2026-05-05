import 'package:flutter/material.dart';
import 'package:tintaviva/pages/detalle_libro_page.dart'; // Ajusta la ruta si es necesario
import 'package:tintaviva/utils/ui_helpers.dart'; // Para importar abrirDialogoEdicionRapida y WidgetBarraProgreso

/// Tarjeta reutilizable para mostrar un libro con su progreso y botón de edición rápida.
///
/// Se utiliza principalmente en:
/// 1. MiBibliotecaPage (lista de libros leyendo).
/// 2. DetalleClubPage (para mostrar el libro actual del club).
///
/// Características:
/// - Muestra portada, título, autor y barra de progreso adaptativa.
/// - Permite navegación al detalle del libro (o club, si se usa onTapCustom).
/// - Incluye acceso rápido a la edición de progreso mediante un icono de lápiz.
class TarjetaLibroProgreso extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> libroData;
  final Color colorMorado;
  final Color colorNaranja;

  /// Callback opcional para sobrescribir la acción al tocar la tarjeta.
  /// Por defecto, navega a DetalleLibroPage.
  final VoidCallback? onTapCustom;

  const TarjetaLibroProgreso({
    super.key,
    required this.docId,
    required this.libroData,
    required this.colorMorado,
    required this.colorNaranja,
    this.onTapCustom,
  });

  @override
  Widget build(BuildContext context) {
    // Lógica para determinar si hay una portada válida (URL http/https).

    

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        // Acción al tocar la tarjeta: usa la custom o la por defecto (ir a detalle).
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
              // --- IMAGEN DEL LIBRO ---
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

              // --- INFORMACIÓN Y PROGRESO ---
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
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),

                    // Widget personalizado que muestra la barra y el texto (Pág X/Y o %).
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

              // --- BOTÓN DE EDICIÓN RÁPIDA ---
              // Permite actualizar progreso sin entrar al detalle completo.
              IconButton(
                icon: Icon(
                  Icons.edit_note,
                  color: colorMorado.withValues(alpha: 0.6),
                  size: 26,
                ),
                onPressed: () =>
                    abrirDialogoEdicionRapida(context, docId, libroData),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
