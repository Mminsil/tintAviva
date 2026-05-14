import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/services/google_books_api.dart';
import 'package:tintaviva/theme/app_styles.dart';
import '../widgets/dialogo_edicion_rapida_libro.dart';

// ─────────────────────────────────────────────────────────────
// DIÁLOGOS DE GESTIÓN DE LIBROS Y PROGRESO
// ─────────────────────────────────────────────────────────────

/// Abre un diálogo para editar rápidamente el progreso de un libro.
///
/// Flujo:
/// 1. Muestra `DialogoEdicionRapida` para obtener nuevos valores
/// 2. Si el usuario intenta disminuir el progreso, pide confirmación explícita
/// 3. Llama a `DatabaseService.actualizarProgresoBiblioteca` con los nuevos valores
/// 4. Muestra feedback visual (`SnackBar`) del resultado
///
/// Parámetros:
/// - [context]: `BuildContext` para navegación y mostrar dialogs/snackbars
/// - [docId]: El ID del documento en `'user_books'` (`userBookId`)
/// - [libro]: `Map<String, dynamic>` con datos actuales del libro
///
/// Lógica de prevención de errores:
/// - Si el formato es `'Papel'` y la nueva página < página anterior → confirma
/// - Si el formato es `'Digital'` y el nuevo progreso < progreso anterior → confirma
/// - Si no hay cambios → sale sin hacer nada (evita llamadas innecesarias a la BD)
Future<void> abrirDialogoEdicionRapida(
  BuildContext context,
  String docId,
  Map<String, dynamic> libro,
) async {
  final String formato = libro['format'] ?? 'Digital';
  final int progresoAnterior = libro['progress'] ?? 0;
  final int totalPaginas = libro['totalPages'] ?? 0;
  final int paginaAnterior = libro['currentPage'] ?? 0;

  final Map<String, int>? res = await showDialog<Map<String, int>>(
    context: context,
    builder: (context) => DialogoEdicionRapida(
      tituloLibro: libro['title'] ?? "Sin título",
      progresoActual: progresoAnterior,
      formato: formato,
      paginasTotales: totalPaginas,
      paginaActual: paginaAnterior,
    ),
  );

  if (res == null || !context.mounted) {
    return;
  }

  int nuevoProgreso = res['progreso']!;
  int nuevaPagina = res['pagina']!;
  bool haDisminuido = false;
  String mensajeConfirmacion = "";

  if (formato == 'Papel') {
    if (nuevaPagina == paginaAnterior) {
      return;
    }
    if (nuevaPagina < paginaAnterior) {
      haDisminuido = true;
      mensajeConfirmacion =
          "Has indicado la página $nuevaPagina, menor a la actual ($paginaAnterior). ¿Seguro?";
    }
  } else {
    if (nuevoProgreso == progresoAnterior) {
      return;
    }
    if (nuevoProgreso < progresoAnterior) {
      haDisminuido = true;
      mensajeConfirmacion =
          "Has indicado $nuevoProgreso%, menor al actual ($progresoAnterior%). ¿Seguro?";
    }
  }

  if (haDisminuido) {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "¿Disminuir progreso?",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(mensajeConfirmacion),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "Sí, disminuir",
              style: TextStyle(
                color: AppColors.naranja,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) {
      return;
    }
  }

  try {
    await DatabaseService.actualizarProgresoBiblioteca(
      userBookId: docId,
      formato: formato,
      porcentaje: formato == 'Digital' ? nuevoProgreso.toDouble() : null,
      paginaActual: formato == 'Papel' ? nuevaPagina : null,
      totalPaginas: totalPaginas,
    );

    if (context.mounted) {
      mostrarSnackBar(context, "¡Progreso actualizado!", AppColors.naranja);
    }
  } catch (e) {
    if (context.mounted) {
      mostrarSnackBar(context, "Error al actualizar: $e", Colors.red);
    }
  }
}

/// Diálogo estandarizado para confirmar borrado de libros.
///
/// Retorna:
/// - `Future<bool?>` → `true` si el usuario confirmó, `false` si canceló
///
/// Características visuales:
/// - Fondo blanco, bordes redondeados (`borderRadius: 15`)
/// - Botones: "Cancelar" (gris) y "Eliminar" (rojo)
Future<bool?> mostrarConfirmacionBorrado(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("¿Eliminar libro?"),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: const Text(
        "Se quitará de tu biblioteca y de tus estadísticas permanentemente.",
        style: TextStyle(color: Colors.black87, fontSize: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

/// Diálogo genérico de confirmación con colores personalizables.
///
/// Parámetros:
/// - [context]: `BuildContext` para mostrar el diálogo
/// - [titulo]: Texto del título del diálogo
/// - [contenido]: Texto del cuerpo del diálogo
/// - [textoCancelar]: Texto del botón de cancelar (por defecto: `"Cancelar"`)
/// - [textoAccion]: Texto del botón de acción (por defecto: `"Eliminar"`)
/// - [colorAccion]: Color del botón de acción (por defecto: `Colors.red`)
/// - [pesoTextoAccion]: `FontWeight` del texto del botón de acción
///
/// Retorna:
/// - `Future<bool?>` → `true` si se confirmó, `false` si se canceló
Future<bool?> mostrarDialogoConfirmacion({
  required BuildContext context,
  required String titulo,
  required String contenido,
  String textoCancelar = "Cancelar",
  String textoAccion = "Eliminar",
  Color colorAccion = Colors.red,
  FontWeight pesoTextoAccion = FontWeight.bold,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        titulo,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.morado,
        ),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: Text(
        contenido,
        style: const TextStyle(
          color: AppColors.textoNegroSuave,
          fontSize: 15,
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(
            textoCancelar,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(
            textoAccion,
            style: TextStyle(color: colorAccion, fontWeight: pesoTextoAccion),
          ),
        ),
      ],
    ),
  );
}

/// Diálogo específico para reactivar (usa color verde para acción positiva).
///
/// Parámetros:
/// - [context]: `BuildContext` para mostrar el diálogo
/// - [titulo]: Texto del título del diálogo
/// - [contenido]: Texto del cuerpo del diálogo
///
/// Retorna:
/// - `Future<bool?>` → `true` si se confirmó la reactivación, `false` si se canceló
Future<bool?> mostrarDialogoReactivar({
  required BuildContext context,
  required String titulo,
  required String contenido,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        titulo,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.morado,
        ),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: Text(
        contenido,
        style: const TextStyle(color: AppColors.textoNegroSuave, fontSize: 15),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(
            "Reactivar",
            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// BÚSQUEDA HÍBRIDA DE LIBROS (Firestore + Google Books API)
// ─────────────────────────────────────────────────────────────

/// Diálogo de búsqueda de libros con normalización de texto para Firestore.
///
/// Características:
/// 1. Búsqueda en tiempo real en catálogo local (`Firestore`) mientras se escribe
/// 2. Botón "Buscar" en teclado para consultar API externa (`GoogleBooksApi`)
/// 3. Muestra resultados de ambas fuentes en la misma lista
/// 4. Devuelve `Map<String, dynamic>` con datos completos del libro seleccionado
///
/// Parámetros:
/// - [context]: `BuildContext` para mostrar el diálogo
///
/// Retorna:
/// - `Future<Map<String, dynamic>?>` con los datos del libro seleccionado, o `null` si canceló
Future<Map<String, dynamic>?> mostrarDialogoBusquedaLibros(
  BuildContext context,
) async {
  final TextEditingController searchController = TextEditingController();

  bool isSearchingApi = false;
  String? apiErrorMessage;
  List<Map<String, dynamic>> apiResults = [];

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        void triggerApiSearch() async {
          if (searchController.text.trim().isEmpty) {
            return;
          }

          setDialogState(() {
            isSearchingApi = true;
            apiResults = [];
            apiErrorMessage = null;
          });

          try {
            final results = await GoogleBooksApi.searchBooks(
              searchController.text,
            );

            if (context.mounted) {
              setDialogState(() {
                apiResults = results;
                isSearchingApi = false;
              });
            }
          } catch (e) {
            if (context.mounted) {
              setDialogState(() {
                isSearchingApi = false;
                apiErrorMessage = "No se pudo conectar con Google Books.";
              });
            }
          }
        }

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxHeight: 500),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Buscar libro', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 15),

                TextField(
                  textCapitalization: TextCapitalization.sentences,
                  enableInteractiveSelection: true,
                  autocorrect: true,
                  controller: searchController,
                  decoration:
                      AppInputStyles.inputDecoration(
                        'Escribe título o autor...',
                        prefixIcon: Icons.search,
                      ).copyWith(
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {
                                    apiResults = [];
                                    isSearchingApi = false;
                                  });
                                },
                              )
                            : null,
                      ),
                  onSubmitted: (_) => triggerApiSearch(),
                  onChanged: (_) => setDialogState(() {
                    apiErrorMessage = null;
                  }),
                ),
                if (apiErrorMessage != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            apiErrorMessage!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () =>
                              setDialogState(() => apiErrorMessage = null),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 15),

                Expanded(
                  child: isSearchingApi
                      ? const Center(child: CircularProgressIndicator())
                      : apiResults.isNotEmpty
                      ? _buildApiList(apiResults)
                      : StreamBuilder<QuerySnapshot>(
                          stream: _buildBooksStream(searchController.text),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                            if (snapshot.hasData &&
                                snapshot.data!.docs.isNotEmpty) {
                              return _buildLocalList(snapshot.data!.docs);
                            }
                            return const Center(
                              child: Text(
                                "No encontrado en tu catálogo.\nPulsa 'Buscar' en el teclado para Internet.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          },
                        ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

/// Widget auxiliar para listar resultados de la API de Google Books.
Widget _buildApiList(List<Map<String, dynamic>> books) {
  return ListView.builder(
    itemCount: books.length,
    itemBuilder: (context, index) {
      final book = books[index];
      return ListTile(
        leading: book['thumbnail'].isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  book['thumbnail'],
                  width: 40,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.menu_book, size: 40),
                ),
              )
            : const Icon(Icons.menu_book, size: 40),
        title: Text(
          book['title'],
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(book['authors']),
        onTap: () {
          Navigator.pop<Map<String, dynamic>>(context, {
            'titulo': book['title'],
            'autor': book['authors'],
            'bookId': null,
            'cover': book['thumbnail'],
            'pages': book['pageCount'],
            'isbn': book['isbn'],
            'sinopsis': book['description'],
            'genre': book['genre'] ?? 'Sin género',
          });
        },
      );
    },
  );
}

/// Widget auxiliar para listar resultados del catálogo local (Firestore).
Widget _buildLocalList(List<QueryDocumentSnapshot> docs) {
  return ListView.builder(
    itemCount: docs.length,
    itemBuilder: (context, index) {
      final data = docs[index].data() as Map<String, dynamic>;
      final String titulo = (data['title'] ?? '').toString();
      final String autor = (data['author'] ?? '').toString();
      final String cover = (data['bookCover'] ?? '').toString();
      final int pages = (data['pages'] ?? 0).toInt();

      return ListTile(
        leading: cover.isNotEmpty && cover.startsWith('http')
            ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  cover,
                  width: 40,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.menu_book, size: 40),
                ),
              )
            : const Icon(Icons.menu_book, size: 40),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: autor.isNotEmpty ? Text(autor) : null,
        onTap: () {
          Navigator.pop<Map<String, dynamic>>(context, {
            'titulo': titulo,
            'autor': autor,
            'bookId': docs[index].id,
            'cover': cover,
            'pages': pages,
            'isbn': data['isbn'] ?? '',
            'sinopsis': data['synopsis'] ?? '',
            'genre': data['genre'] ?? 'Sin género',
          });
        },
      );
    },
  );
}

/// Construye el stream de búsqueda para el catálogo local (Firestore).
///
/// Lógica:
/// - Si la consulta está vacía → devuelve los primeros 50 libros ordenados por título
/// - Si hay consulta → normaliza el texto y usa `range queries` para búsqueda eficiente por prefijo
Stream<QuerySnapshot> _buildBooksStream(String query) {
  final String q = query.trim();
  if (q.trim().isEmpty) {
    return FirebaseFirestore.instance
        .collection('books')
        .orderBy('title')
        .limit(50)
        .snapshots();
  }

  final String normalizedQuery = q.isNotEmpty
      ? q[0].toUpperCase() + q.substring(1).toLowerCase()
      : q;

  return FirebaseFirestore.instance
      .collection('books')
      .where('title', isGreaterThanOrEqualTo: normalizedQuery.trim())
      .where('title', isLessThanOrEqualTo: '${normalizedQuery.trim()}\uf8ff')
      .orderBy('title')
      .limit(20)
      .snapshots();
}
