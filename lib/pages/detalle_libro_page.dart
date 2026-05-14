import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/widgets/seccion_citas_libro.dart';
import 'package:tintaviva/widgets/widget_personajes.dart';
import 'package:tintaviva/pages/editar_libro_page.dart';

/// Pantalla de detalle de un libro específico en la biblioteca personal del usuario.
///
/// Combina dos streams de Firestore:
/// 1. `user_books/{userBookId}` - Datos personalizados (progreso, rating, diario, personajes)
/// 2. `books/{bookId}` - Datos generales del libro (título, autor, portada, sinopsis)
///
/// Muestra: portada, título, autor, rating, páginas, género, barra de progreso,
/// sinopsis, sección de citas, lista de personajes y notas personales.
/// El FAB permite editar el libro y navega a `EditarLibroPage`.
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
  bool _mostrarTodasCitas = false;

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL 
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye la AppBar transparente con iconos blancos.
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  /// Construye el cuerpo principal con los dos streams anidados.
  ///
  /// Stream 1: `user_books` (datos del usuario)
  /// Stream 2: `books` (datos generales del catálogo)
  Widget _buildBody() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_books')
          .doc(widget.userBookId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorState(snapshot.error);
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildNotFoundState("El libro no existe o fue eliminado.");
        }

        final userBookData = snapshot.data!.data() as Map<String, dynamic>;

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('books')
              .doc(widget.bookId)
              .snapshots(),
          builder: (context, bookSnapshot) {
            if (bookSnapshot.hasError) {
              return _buildErrorState(bookSnapshot.error);
            }
            if (!bookSnapshot.hasData || !bookSnapshot.data!.exists) {
              return _buildNotFoundState("El libro no existe o fue eliminado.");
            }

            final bookData = bookSnapshot.data!.data() as Map<String, dynamic>;
            return _buildContent(userBookData, bookData);
          },
        );
      },
    );
  }

  /// Widget de error genérico con mensaje descriptivo.
  Widget _buildErrorState(dynamic error) {
    return Center(child: Text("Error: $error"));
  }

  /// Widget mostrado cuando el documento no existe.
  Widget _buildNotFoundState(String message) {
    return const Center(child: Text("El libro no existe o fue eliminado."));
  }

  /// Construye el contenido principal una vez cargados ambos streams.
  ///
  /// Fusiona `userBookData` y `bookData`, priorizando los datos editables del usuario.
  Widget _buildContent(
    Map<String, dynamic> userBookData,
    Map<String, dynamic> bookData,
  ) {
    final String title =
        userBookData['title'] ?? bookData['title'] ?? "Sin título";
    final String author =
        userBookData['author'] ?? bookData['author'] ?? "Autor desconocido";
    final int totalPages =
        (userBookData['totalPages'] ?? bookData['pages'] ?? 0).toInt();
    final double rating = (userBookData['rating'] ?? 0.0).toDouble();
    final String genre = _sanitizeField(bookData['genre'], "Sin género");
    final String synopsis = _sanitizeField(
      bookData['synopsis'],
      "Sin sinopsis disponible.",
    );
    final String notas = userBookData['notes'] ?? "";
    final String shelf = userBookData['shelf'] ?? "Por leer";
    final List<String> personajesList = _extractStringList(
      userBookData['characters'],
    );

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(title, author, bookData, shelf, userBookData),
          _buildBodyContent(
            rating,
            totalPages,
            genre,
            synopsis,
            notas,
            personajesList,
            title,
          ),
        ],
      ),
    );
  }

  /// Limpia y valida un campo de texto: si está vacío o null, devuelve el fallback.
  String _sanitizeField(dynamic value, String fallback) {
    final String raw = (value ?? "").toString().trim();
    return raw.isEmpty ? fallback : raw;
  }

  /// Extrae una lista de strings desde un campo que puede ser null o `List<dynamic>`.
  List<String> _extractStringList(dynamic field) {
    if (field == null) {
      return [];
    }
    return (field as List<dynamic>).map((e) => e.toString()).toList();
  }

  /// Construye el encabezado con portada, título, autor y fecha de finalización (si aplica).
  Widget _buildHeader(
    String title,
    String author,
    Map<String, dynamic> bookData,
    String shelf,
    Map<String, dynamic> userBookData,
  ) {
    return Container(
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
          _buildBookCover(bookData),
          const SizedBox(height: 20),
          _buildTitleAndAuthor(title, author),
          if (shelf == 'Leído' && userBookData['dateFinished'] != null)
            _buildFinishedDateBadge(userBookData['dateFinished']),
        ],
      ),
    );
  }

  /// Construye la portada del libro con fallback a asset local.
  Widget _buildBookCover(Map<String, dynamic> bookData) {
    final String? coverUrl = bookData['bookCover'];
    final bool hasCover = coverUrl != null && coverUrl.toString().isNotEmpty;

    return Container(
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
        child: hasCover
            ? Image.network(
                coverUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholderCover();
                },
              )
            : _buildPlaceholderCover(),
      ),
    );
  }

  /// Widget placeholder cuando falla la carga de la portada.
  Widget _buildPlaceholderCover() {
    return Image.asset('assets/sin_portada.png', fit: BoxFit.cover);
  }

  /// Construye el título y autor del libro con estilos diferenciados.
  Widget _buildTitleAndAuthor(String title, String author) {
    return Column(
      children: [
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
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }

  /// Badge con fecha de finalización (solo para libros en estante 'Leído').
  Widget _buildFinishedDateBadge(dynamic timestamp) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
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
            formatearFechaLarga(timestamp),
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye el cuerpo principal con métricas, sinopsis, notas, personajes y citas.
  Widget _buildBodyContent(
    double rating,
    int totalPages,
    String genre,
    String synopsis,
    String notas,
    List<String> personajesList,
    String title,
  ) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMetricsRow(rating, totalPages, genre),
          const Divider(height: 40, thickness: 1.5, color: Colors.grey),
          _buildSynopsisSection(synopsis),
          if (notas.isNotEmpty) _buildNotesSection(notas),

          _buildCharactersSection(personajesList),
          _buildQuotesSection(title),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  /// Fila horizontal con métricas: Rating, Páginas, Género.
  Widget _buildMetricsRow(double rating, int totalPages, String genre) {
    return Row(
      children: [
        Expanded(
          child: _infoItem(Icons.star, "Puntuación", rating.toStringAsFixed(1)),
        ),
        Expanded(
          child: _infoItem(
            Icons.menu_book,
            "Páginas",
            totalPages > 0 ? totalPages.toString() : "-",
          ),
        ),
        Expanded(
          child: _infoItem(Icons.category, "Género", genre, isGenre: true),
        ),
      ],
    );
  }

  /// Widget reutilizable para mostrar una métrica con icono.
  ///
  /// [isGenre] permite ajustar el estilo para textos largos (género).
  Widget _infoItem(
    IconData icon,
    String label,
    String value, {
    bool isGenre = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.morado, size: 24),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textAlign: TextAlign.center,
          maxLines: isGenre ? 2 : 1,
          overflow: isGenre ? TextOverflow.ellipsis : TextOverflow.visible,
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  /// Sección de sinopsis con componente expandible.
  Widget _buildSynopsisSection(String synopsis) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          maxLength: 250,
          style: TextStyle(color: Colors.grey[700], height: 1.5),
        ),
      ],
    );
  }

  /// Sección de notas personales (solo si existen).
  Widget _buildNotesSection(String notas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
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
          style: TextStyle(color: Colors.grey[700], height: 1.5),
        ),
        const SizedBox(height: 5),
      ],
    );
  }

  /// Sección de personajes con widget interactivo para agregar/eliminar.
  Widget _buildCharactersSection(List<String> personajesList) {
    return seccionPersonajes(
      context: context,
      userBookId: widget.userBookId,
      personajes: personajesList,
      onRefresh: () {
        setState(() {});
      },
    );
  }

  /// Sección de citas destacadas del libro con toggle "Ver más".
  Widget _buildQuotesSection(String title) {
    return Column(
      children: [
        const SizedBox(height: 20),
        SeccionCitasLibro(
          tituloLibro: title,
          userBookId: widget.userBookId,
          bookId: widget.bookId,
          mostrarTodo: _mostrarTodasCitas,
          onToggleVerMas: () {
            setState(() {
              _mostrarTodasCitas = !_mostrarTodasCitas;
            });
          },
        ),
      ],
    );
  }

  /// Construye el FAB para editar el libro.
  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'fab_detalle',
      backgroundColor: AppColors.morado,
      onPressed: _navigateToEditPage,
      child: const Icon(Icons.edit, color: Colors.white),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO Y NAVEGACIÓN
  // ─────────────────────────────────────────────────────────────

  /// Navega a EditarLibroPage fusionando datos de user_books y books.
  void _navigateToEditPage() async {
    final userBookSnap = await FirebaseFirestore.instance
        .collection('user_books')
        .doc(widget.userBookId)
        .get();
    final bookSnap = await FirebaseFirestore.instance
        .collection('books')
        .doc(widget.bookId)
        .get();

    if (!mounted || !userBookSnap.exists || !bookSnap.exists) {
      return;
    }

    final userBookData = userBookSnap.data() as Map<String, dynamic>;
    final bookData = bookSnap.data() as Map<String, dynamic>;

    // Fusión: userBookData tiene prioridad para campos editables
    final Map<String, dynamic> todosLosDatos = {...bookData, ...userBookData};

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
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS DE UTILIDAD
  // ─────────────────────────────────────────────────────────────

  /// Convierte Timestamp de Firestore o DateTime a string formato dd/mm/yyyy.
  String formatearFechaLarga(dynamic timestamp) {
    if (timestamp == null) {
      return '';
    }
    final DateTime date = (timestamp is Timestamp)
        ? timestamp.toDate()
        : timestamp;
    return "${date.day}/${date.month}/${date.year}";
  }
}
