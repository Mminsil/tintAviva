import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tintaviva/pages/editar_libro_page.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Pantalla de detalles de un libro específico en la biblioteca del usuario.
///
/// Combina datos generales del libro (título, autor, portada) con datos personales
/// (progreso, notas, rating, estantería). Permite editar la entrada.
class DetalleLibroPage extends StatelessWidget {
  // IDs necesarios para consultar las dos colecciones relacionadas.
  final String userBookId;
  final String bookId;

  const DetalleLibroPage({
    super.key,
    required this.userBookId,
    required this.bookId,
  });

  @override
  Widget build(BuildContext context) {
    // Stream 1: Datos personalizados del usuario para este libro.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_books')
          .doc(userBookId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Text("Error: ${snapshot.error}");
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.data!.exists) {
          return const Center(
            child: Text("El libro no existe o fue eliminado."),
          );
        }

        final userBookData = snapshot.data!.data() as Map<String, dynamic>;

        // Stream 2: Datos generales del libro (para asegurar que tenemos la portada/sinopsis más reciente).
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('books')
              .doc(bookId)
              .snapshots(),
          builder: (context, bookSnapshot) {
            if (bookSnapshot.hasError) {
              return Text("Error: ${bookSnapshot.error}");
            }
            if (!bookSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!bookSnapshot.data!.exists) {
              return const Center(
                child: Text("El libro no existe o fue eliminado."),
              );
            }

            final bookData = bookSnapshot.data!.data() as Map<String, dynamic>;

            // Fusión de datos: Priorizamos los datos del usuario si existen, sino los generales.
            final String title =
                userBookData['title'] ?? bookData['title'] ?? "Sin título";
            final String author =
                userBookData['author'] ??
                bookData['author'] ??
                "Autor desconocido";

            final int progress = (userBookData['progress'] ?? 0).toInt();
            final int totalPages =
                (userBookData['totalPages'] ?? bookData['pages'] ?? 0).toInt();
            final int currentPage = (userBookData['currentPage'] ?? 0).toInt();
            final String format = userBookData['format'] ?? 'Digital';

            final double rating = (userBookData['rating'] ?? 0.0).toDouble();

            // Limpieza de strings para evitar vacíos en la UI.
            String genreRaw = bookData['genre'] ?? "";
            String synopsisRaw = bookData['synopsis'] ?? "";
            final String genre = genreRaw.trim().isEmpty
                ? "Sin género"
                : genreRaw;
            final String synopsis = synopsisRaw.trim().isEmpty
                ? "Sin sinopsis disponible."
                : synopsisRaw;

            final String notes = userBookData['notes'] ?? "";
            final String shelf = userBookData['shelf'] ?? "Por leer";

            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: const IconThemeData(color: Colors.white),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    // ENCABEZADO: Portada y título sobre fondo morado.
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5D3B82),
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(height: 50),
                          Container(
                            height: 240,
                            width: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 10,
                                  offset: Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child:
                                  (bookData['bookCover'] != null &&
                                      bookData['bookCover']
                                          .toString()
                                          .isNotEmpty)
                                  ? Image.network(
                                      bookData['bookCover'],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Image.asset(
                                                'assets/sin_portada.png',
                                                fit: BoxFit.cover,
                                              ),
                                    )
                                  : Image.asset(
                                      'assets/sin_portada.png',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            author,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),

                          // Fecha de finalización si el libro está en la estantería "Leído".
                          if (shelf == 'Leído' &&
                              userBookData['dateFinished'] != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 8.0,
                                bottom: 8.0,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.naranja,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    formatearFechaLarga(
                                      userBookData['dateFinished'],
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 14,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // DETALLES: Cuerpo de la página.
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bloque de estadísticas rápidas.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoItem(
                                Icons.star,
                                "Rating",
                                rating.toStringAsFixed(1),
                              ),
                              _infoItem(
                                Icons.menu_book,
                                "Páginas",
                                totalPages > 0 ? totalPages.toString() : "-",
                              ),
                              _infoItem(Icons.category, "Género", genre),
                            ],
                          ),
                          const Divider(height: 40),

                          Text(
                            "Mi Progreso",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.morado,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Widget personalizado para la barra de progreso.
                          WidgetBarraProgreso(
                            progress: progress,
                            currentPage: currentPage,
                            totalPages: totalPages,
                            format: format,
                            height: 10,
                          ),

                          const SizedBox(height: 30),
                          const Text(
                            "Sinopsis",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            synopsis,
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),

                          const SizedBox(height: 30),
                          const Text(
                            "Mis Notas",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Text(
                              notes.isEmpty ? 'Sin notas personales.' : notes,
                              style: const TextStyle(
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // FAB para editar los datos del libro.
              floatingActionButton: FloatingActionButton(
                backgroundColor: AppColors.morado,
                onPressed: () {
                  // Combinamos todos los datos para pasarlos a la pantalla de edición.
                  Map<String, dynamic> todosLosDatos = {
                    ...userBookData,
                    ...bookData,
                  };
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditarLibroPage(
                        userBookId: userBookId,
                        bookId: bookId,
                        datosActuales: todosLosDatos,
                      ),
                    ),
                  );
                },
                child: const Icon(Icons.edit, color: Colors.white),
              ),
            );
          },
        );
      },
    );
  }

  /// Widget auxiliar para mostrar ítems de información (Rating, Páginas, Género).
  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.morado, size: 28),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
