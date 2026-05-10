import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/widgets/seccion_citas_libro.dart';
import 'package:tintaviva/widgets/seccion_diario.dart';
import 'package:tintaviva/pages/editar_libro_page.dart';

/// Pantalla de detalle de un libro especifico en la biblioteca personal del usuario.
///
/// Combina dos streams de Firestore:
/// 1. user_books/{userBookId} - Datos personalizados del usuario (progreso, rating, diario, personajes)
/// 2. books/{bookId} - Datos generales del libro (titulo, autor, portada, sinopsis)
///
/// Muestra: portada, titulo, autor, rating, paginas, genero, barra de progreso,
/// sinopsis, seccion de citas, lista de personajes, diario de lectura.
/// El FAB permite editar el libro y navega a EditarLibroPage.
class DetalleLibroPage extends StatefulWidget {
  final String userBookId;
  final String bookId;

  const DetalleLibroPage({
    super.key,
    required this.userBookId,
    required this.bookId,
  });

  @override
  State<DetalleLibroPage> createState() => _DetalleLibroPageState();
}

class _DetalleLibroPageState extends State<DetalleLibroPage> {
  bool _mostrarTodoDiario = false;
  bool _mostrarTodasCitas = false;

  /// Convierte Timestamp de Firestore o DateTime a string formato dd/mm/yyyy.
  String formatearFechaLarga(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime date = (timestamp is Timestamp) ? timestamp.toDate() : timestamp;
    return "${date.day}/${date.month}/${date.year}";
  }

  /// Widget reutilizable para mostrar una metrica con icono.
  /// Usado para rating, paginas y genero en fila horizontal.
  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: AppColors.morado, size: 24),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Stream 1: Datos del usuario para este libro (progreso, estado, personajes, diario)
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_books')
          .doc(widget.userBookId)
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

        // Stream 2: Datos generales del libro (portada, sinopsis, genero, autor)
        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('books')
              .doc(widget.bookId)
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

            // Fusion de datos: userBookData tiene prioridad sobre bookData para campos editables por usuario
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

            String genreRaw = bookData['genre'] ?? "";
            String synopsisRaw = bookData['synopsis'] ?? "";
            final String notas = userBookData['notes'] ?? "";

            final String genre = genreRaw.trim().isEmpty
                ? "Sin género"
                : genreRaw;
            final String synopsis = synopsisRaw.trim().isEmpty
                ? "Sin sinopsis disponible."
                : synopsisRaw;
            final String shelf = userBookData['shelf'] ?? "Por leer";

            // Extraccion de listas anidadas desde userBookData
            final List<String> personajesList =
                (userBookData['characters'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [];

            final List<Map<String, dynamic>> diarioList =
                (userBookData['readingJournal'] as List<dynamic>?)
                    ?.map((e) => e as Map<String, dynamic>)
                    .toList() ??
                [];

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
                    // Encabezado con portada, titulo y autor
                    Container(
                      width: double.infinity,
                      decoration: const BoxDecoration(
                        color: AppColors.morado,
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
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            author,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Muestra fecha de finalizacion solo si el libro esta en estante 'Leido'
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

                    // Cuerpo principal con toda la informacion detallada
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fila de metricas: Rating, Paginas, Genero
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _infoItem(
                                Icons.star,
                                "Puntuación",
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
                          const Divider(
                            height: 40,
                            thickness: 1.5,
                            color: Colors.grey,
                          ),

                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Text(
                                "Información del libro",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.morado,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                          const Text(
                            "Sinopsis",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.morado,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextoExpandible(
                            texto: synopsis,
                            maxLength: 500,
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 30),

                          //Notas
                          if (notas.isNotEmpty) ...[
                            const Text(
                              "Notas",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.morado,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextoExpandible(
                              texto: notas,
                              maxLength: 250,
                              style: TextStyle(
                                color: Colors.grey[700],
                                height: 1.5,
                              ),
                            ),
                          ],

                          // Seccion de personajes: permite agregar y eliminar personajes
                          // La modificacion se hace directamente en Firestore desde el widget interno
                          seccionPersonajes(
                            context: context,
                            userBookId: widget.userBookId,
                            personajes: personajesList,
                            onRefresh: () {
                              setState(() {});
                            },
                          ),

                          const Divider(
                            height: 40,
                            thickness: 1.5,
                            color: Colors.grey,
                          ),

                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Text(
                                "Mi experiencia de lectura",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.morado,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),

                          const Text(
                            "Progreso",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: AppColors.morado,
                            ),
                          ),
                          const SizedBox(height: 10),
                          WidgetBarraProgreso(
                            progress: progress,
                            currentPage: currentPage,
                            totalPages: totalPages,
                            format: format,
                            height: 10,
                          ),
                          const SizedBox(height: 30),

                          // Seccion de citas destacadas del libro
                          SeccionCitasLibro(
                            tituloLibro: title,
                            onAddQuote: () async {
                              return await mostrarDialogoAgregarCitaGenerica(
                                context,
                                tituloLibro: title,
                                autorLibro: author,
                              );
                            },
                            mostrarTodo: _mostrarTodasCitas,
                            onToggleVerMas: () {
                              setState(() {
                                _mostrarTodasCitas = !_mostrarTodasCitas;
                              });
                            },
                          ),

                          // Seccion del diario personal de lectura
                          seccionDiario(
                            context: context,
                            userBookId: widget.userBookId,
                            entradas: diarioList,
                            onRefresh: () {
                              setState(() {});
                            },
                            mostrarTodo: _mostrarTodoDiario,
                            onToggleVerMas: () {
                              setState(() {
                                _mostrarTodoDiario = !_mostrarTodoDiario;
                              });
                            },
                          ),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Boton flotante para editar el libro
              floatingActionButton: FloatingActionButton(
                backgroundColor: AppColors.morado,
                onPressed: () {
                  // Fusiona userBookData y bookData para pasar todos los datos disponibles a la pantalla de edicion
                  Map<String, dynamic> todosLosDatos = {
                    ...userBookData,
                    ...bookData,
                  };
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditarLibroPage(
                        userBookId: widget.userBookId,
                        bookId: widget.bookId,
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
}
