import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/services/google_books_api.dart';
import 'package:tintaviva/theme/app_styles.dart';
import '../widgets/dialogo_edicion_rapida_libro.dart';

// --- COLORES CORPORATIVOS (Constants) ---
// Definición centralizada de colores para consistencia visual en helpers.

/// Abre un diálogo para editar rápidamente el progreso de un libro.
///
/// Flujo:
/// 1. Muestra DialogoEdicionRapida para obtener nuevos valores.
/// 2. Si el usuario intenta disminuir el progreso, pide confirmación explícita.
/// 3. Llama a DatabaseService.actualizarProgresoBiblioteca con los nuevos valores.
/// 4. Muestra feedback visual (SnackBar) del resultado.
///
/// Parámetros:
/// - [context]: Para navegación y mostrar dialogs/snackbars.
/// - [docId]: El ID del documento en 'user_books' (userBookId).
/// - [libro]: Mapa con datos actuales del libro (formato, progreso, páginas, etc.).
Future<void> abrirDialogoEdicionRapida(
  BuildContext context,
  String docId, // Este es el userBookId
  Map<String, dynamic> libro,
) async {
  final String formato = libro['format'] ?? 'Digital';
  final int progresoAnterior = libro['progress'] ?? 0;
  final int totalPaginas = libro['totalPages'] ?? 0;
  final int paginaAnterior = libro['currentPage'] ?? 0;

  // Mostrar diálogo de edición y esperar resultado.
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

  // Si el usuario canceló o el contexto no está montado, salir.
  if (res == null || !context.mounted) return;

  int nuevoProgreso = res['progreso']!;
  int nuevaPagina = res['pagina']!;
  bool haDisminuido = false;
  String mensajeConfirmacion = "";

  // Detección de retroceso en el progreso (Lógica de UI para prevenir errores).
  if (formato == 'Papel') {
    if (nuevaPagina == paginaAnterior) return; // Sin cambios, salir.
    if (nuevaPagina < paginaAnterior) {
      haDisminuido = true;
      mensajeConfirmacion =
          "Has indicado la página $nuevaPagina, menor a la actual ($paginaAnterior). ¿Seguro?";
    }
  } else {
    if (nuevoProgreso == progresoAnterior) return; // Sin cambios, salir.
    if (nuevoProgreso < progresoAnterior) {
      haDisminuido = true;
      mensajeConfirmacion =
          "Has indicado $nuevoProgreso%, menor al actual ($progresoAnterior%). ¿Seguro?";
    }
  }

  // Confirmación explícita si se reduce el progreso (prevención de errores).
  if (haDisminuido) {
    bool? confirmar = await showDialog<bool>(
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
    if (confirmar != true || !context.mounted) return;
  }

  try {
    // Llamar al servicio para actualizar progreso (lógica de negocio centralizada).
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

/// Diálogo genérico para agregar una cita favorita desde cualquier pantalla.
///
/// Parámetros:
/// - [tituloLibro], [autorLibro]: Para asociar la cita al libro correcto.
///
/// Retorna:
/// - true si se guardó exitosamente.
/// - false si se canceló o hubo error.
Future<bool?> mostrarDialogoAgregarCitaGenerica(
  BuildContext context, {
  required String tituloLibro,
  required String autorLibro,
}) async {
  final TextEditingController citaController = TextEditingController();

  final bool? result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      // Usamos dialogContext para evitar cerrar la página padre accidentalmente.
      title: const Text("Guardar Cita Favorita"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            textCapitalization: TextCapitalization.sentences,
            enableInteractiveSelection: true,
            autocorrect: true,
            controller: citaController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: "Escribe la frase...",
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Del libro: $tituloLibro",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.pop(dialogContext, false), // Cancelar devuelve false
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.morado),
          onPressed: () async {
            if (citaController.text.trim().isNotEmpty) {
              try {
                await DatabaseService.agregarCitaFavorita(
                  texto: citaController.text.trim(),
                  libroTitulo: tituloLibro,
                  autor: autorLibro,
                );

                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: const Text("✨ Cita guardada en tu perfil"),
                      backgroundColor: AppColors.naranja,
                    ),
                  );
                  Navigator.pop(dialogContext, true); // Guardar devuelve true
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                  Navigator.pop(dialogContext, false);
                }
              }
            }
          },
          child: const Text("Guardar", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  return result;
}

/// Diálogo estandarizado para confirmar borrado de libros.
///
/// Retorna:
/// - true si el usuario confirmó.
/// - false si canceló.
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

/// Widget visual reutilizable para barras de progreso.
///
/// Adapta el texto descriptivo según el formato:
/// - Digital: Muestra "% leído".
/// - Papel: Muestra "Pág. X de Y (%)".
class WidgetBarraProgreso extends StatelessWidget {
  final int progress;
  final int currentPage;
  final int totalPages;
  final String format;
  final double height;

  const WidgetBarraProgreso({
    super.key,
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.format,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    Color colorNaranja = const Color(0xFFFF6B35);
    String textoDescriptivo = "$progress% leído";

    // Lógica condicional para formato Papel.
    if (format == 'Papel' && totalPages > 0) {
      int paginaMostrar = currentPage > 0
          ? currentPage
          : (progress * totalPages / 100).round();
      textoDescriptivo = "Pág. $paginaMostrar de $totalPages ($progress%)";
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

/// Formatea Timestamp o DateTime a formato corto ("15 Ene").
///
/// Útil para mostrar fechas en listas compactas o tarjetas.
String formatearFechaCorta(dynamic timestamp) {
  if (timestamp == null) return "";
  try {
    DateTime fecha;
    if (timestamp is Timestamp) {
      fecha = timestamp.toDate();
    } else if (timestamp is DateTime) {
      fecha = timestamp;
    } else {
      return "";
    }

    const meses = [
      "",
      "Ene",
      "Feb",
      "Mar",
      "Abr",
      "May",
      "Jun",
      "Jul",
      "Ago",
      "Sep",
      "Oct",
      "Nov",
      "Dic",
    ];
    // Validación de rango de mes para evitar IndexOutOfRange.
    int mesIndex = fecha.month >= 1 && fecha.month <= 12 ? fecha.month : 1;
    return "${fecha.day} ${meses[mesIndex]}";
  } catch (e) {
    return "";
  }
}

/// Formatea Timestamp o DateTime a formato largo ("Leído en enero de 2026").
///
/// Útil para mostrar fechas de finalización en detalles de libro.
String formatearFechaLarga(dynamic timestamp) {
  if (timestamp == null) return "";
  try {
    DateTime fecha;
    if (timestamp is Timestamp) {
      fecha = timestamp.toDate();
    } else if (timestamp is DateTime) {
      fecha = timestamp;
    } else {
      return "";
    }

    const meses = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    // Ajuste de índice (meses en Dart son 1-12, lista es 0-11).
    int mesIndex = (fecha.month - 1);
    if (mesIndex < 0 || mesIndex >= 12) mesIndex = 0;
    return "Leído en ${meses[mesIndex]} de ${fecha.year}";
  } catch (e) {
    return "";
  }
}

/// Diálogo genérico de confirmación con colores personalizables.
///
/// Parámetros:
/// - [colorAccion]: Color del botón de acción (por defecto rojo para eliminar).
/// - [textoAccion], [textoCancelar]: Textos personalizables para los botones.
///
/// Retorna:
/// - true si se confirmó la acción.
/// - false si se canceló.
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

/// Widget universal para mostrar portadas de libros o imágenes con fallback.
///
/// Características:
/// - Si la URL es válida (https), intenta cargar la imagen de red.
/// - Si falla la carga o la URL es nula/inválida, muestra 'assets/sin_portada.png'.
/// - Procesa URLs de Google Books para mejorar calidad (&zoom=5) y forzar HTTPS.
/// - Permite personalizar tamaño, bordes y modo de ajuste (fit).
class AppBookCover extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const AppBookCover({
    super.key,
    this.imageUrl,
    this.width = 70,
    this.height = 105,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Procesar la URL para asegurar HTTPS y mejor calidad.
    String? processedUrl = imageUrl;

    if (processedUrl != null && processedUrl.isNotEmpty) {
      // Forzar HTTPS si es HTTP (evita errores de mixed content).
      if (processedUrl.startsWith('http://')) {
        processedUrl = processedUrl.replaceFirst('http://', 'https://');
      }

      // Si es de Google Books, intentar mejorar el zoom para mejor resolución.
      if (processedUrl.contains('google.com/books')) {
        processedUrl = processedUrl.replaceFirst('&zoom=1', '&zoom=5');
      }
    }

    // Validación básica de URL: debe ser https y no vacía.
    bool isValidUrl =
        processedUrl != null &&
        processedUrl.isNotEmpty &&
        processedUrl.startsWith('https');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isValidUrl
          ? Image.network(
              processedUrl,
              width: width,
              height: height,
              fit: fit,
              // Mostrar indicador de carga mientras se descarga la imagen.
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              // Si hay error de red o imagen corrupta, mostrar fallback.
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            )
          : _buildFallback(), // URL inválida -> mostrar fallback inmediato.
    );
  }

  /// Widget de fallback: muestra imagen de asset cuando no hay portada válida.
  Widget _buildFallback() {
    return Image.asset(
      'assets/sin_portada.png',
      width: width,
      height: height,
      fit: fit,
    );
  }
}

/// Crea un campo de texto numérico estricto con validación automática.
///
/// Características:
/// - Solo acepta dígitos (FilteringTextInputFormatter.digitsOnly).
/// - Valida que no sea negativo.
/// - Si [isTotalField] es true, valida que sea > 0.
/// - Si [maxPages] está definido, valida que no lo supere.
Widget buildNumberField({
  required String label,
  required TextEditingController controller,
  int? maxPages, // Para validar contra el total (opcional)
  bool isTotalField = false, // Si es true, valida que sea > 0
  void Function(String)? onChanged,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: AppInputStyles.inputDecoration(label),
    onChanged: onChanged,
    validator: (value) {
      if (value == null || value.isEmpty) return "Requerido";

      final n = int.tryParse(value);
      if (n == null) return "Solo números";
      if (n < 0) return "No negativo";

      // Validaciones específicas según el tipo de campo.
      if (isTotalField && n <= 0) return "Debe ser mayor a 0";
      if (!isTotalField && maxPages != null && maxPages > 0 && n > maxPages) {
        return "Mayor que el total ($maxPages)";
      }

      return null;
    },
  );
}

/// Formateador que bloquea la entrada si el número supera un máximo definido.
///
/// Útil para campos como "página actual" que no deben exceder "total de páginas".
class MaxNumberInputFormatter extends TextInputFormatter {
  final int? max;

  MaxNumberInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Si no hay máximo definido o el campo está vacío, permite el cambio.
    if (max == null || newValue.text.isEmpty) {
      return newValue;
    }

    final int? newInt = int.tryParse(newValue.text);

    // Si no es un número válido (ej: borrando), permite el cambio.
    if (newInt == null) {
      return newValue;
    }

    // Si el nuevo valor es menor o igual al máximo, permítelo.
    if (newInt <= max!) {
      return newValue;
    }

    // Si supera el máximo, devuelve el valor anterior (bloquea la tecla).
    return oldValue;
  }
}

// ------------------------------------------------------------------
// BÚSQUEDA DE LIBROS (Híbrida: Local Firestore + API Google Books)
// ------------------------------------------------------------------

/// Diálogo de búsqueda de libros con normalización de texto para Firestore.
///
/// Características:
/// 1. Búsqueda en tiempo real en catálogo local (Firestore) mientras se escribe.
/// 2. Botón "Buscar" en teclado para consultar API externa (Google Books).
/// 3. Muestra resultados de ambas fuentes en la misma lista.
/// 4. Devuelve mapa con datos completos del libro seleccionado.
Future<Map<String, dynamic>?> mostrarDialogoBusquedaLibros(
  BuildContext context,
) async {
  final TextEditingController searchController = TextEditingController();

  // Estado local para saber si estamos buscando en la API.
  bool isSearchingApi = false;
  List<Map<String, dynamic>> apiResults = [];

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        // Función interna para lanzar la búsqueda en API externa.
        void triggerApiSearch() async {
          if (searchController.text.trim().isEmpty) return;

          setDialogState(() {
            isSearchingApi = true;
            apiResults = []; // Limpiar resultados anteriores.
          });

          try {
            final results = await GoogleBooksApi.searchBooks(
              searchController.text,
            );

            // Verificamos si el contexto sigue siendo válido antes de actualizar UI.
            if (context.mounted) {
              setDialogState(() {
                apiResults = results;
                isSearchingApi = false;
              });
            }
          } catch (e) {
            // Si hubo error, también verificamos montado.
            if (context.mounted) {
              setDialogState(() {
                isSearchingApi = false;
              });
              // Mostramos el error solo si el diálogo sigue abierto.
              mostrarSnackBar(context, "Error API: $e", Colors.red);
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
                  // Detectar cuando el usuario pulsa Intro o Buscar en teclado.
                  onSubmitted: (_) => triggerApiSearch(),
                  onChanged: (_) => setDialogState(
                    () {},
                  ), // Para actualizar el icono de borrar.
                ),
                const SizedBox(height: 15),

                Expanded(
                  child: isSearchingApi
                      ? const Center(child: CircularProgressIndicator())
                      : apiResults.isNotEmpty
                      ? _buildApiList(apiResults) // Mostrar resultados de API.
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
          // Devolver datos del libro seleccionado al padre.
          Navigator.pop<Map<String, dynamic>>(context, {
            'titulo': book['title'],
            'autor': book['authors'],
            'bookId':
                null, // null indica que viene de API, no de Firestore local.
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
      final titulo = (data['title'] ?? '').toString();
      final autor = (data['author'] ?? '').toString();
      final cover = (data['bookCover'] ?? '').toString();
      final pages = (data['pages'] ?? 0).toInt();

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
          // Devolver datos del libro local seleccionado al padre.
          Navigator.pop<Map<String, dynamic>>(context, {
            'titulo': titulo,
            'autor': autor,
            'bookId': docs[index].id, // ID de Firestore para referencia.
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
/// - Si la consulta está vacía, devuelve los primeros 50 libros ordenados por título.
/// - Si hay consulta, normaliza el texto (primera letra mayúscula) y usa range queries
///   para búsqueda eficiente por prefijo (isGreaterThanOrEqualTo / isLessThanOrEqualTo).
Stream<QuerySnapshot> _buildBooksStream(String query) {
  final String q = query.trim();
  if (q.trim().isEmpty) {
    return FirebaseFirestore.instance
        .collection('books')
        .orderBy('title')
        .limit(50)
        .snapshots();
  }

  // Normalización: Primera letra mayúscula, resto minúsculas para coincidir con cómo se guardan los títulos.
  String normalizedQuery = q.isNotEmpty
      ? q[0].toUpperCase() + q.substring(1).toLowerCase()
      : q;

  // Range query para búsqueda por prefijo eficiente en Firestore.
  // \uf8ff es un carácter Unicode alto que marca el final del rango para el prefijo.
  return FirebaseFirestore.instance
      .collection('books')
      .where('title', isGreaterThanOrEqualTo: normalizedQuery.trim())
      .where('title', isLessThanOrEqualTo: '${normalizedQuery.trim()}\uf8ff')
      .orderBy('title')
      .limit(20)
      .snapshots();
}

// ============================================================================
// WIDGET DE CONFETTI REUTILIZABLE
// ============================================================================

/// Widget de confetti celebratorio reutilizable.
///
/// Muestra una explosión de partículas centrada, ideal para celebrar
/// logros como completar un libro, alcanzar una racha, etc.
///
/// Uso típico:
/// ```dart
/// Stack(
///   clipBehavior: Clip.none,
///   children: [
///     // Tu widget principal (diálogo, pantalla, etc.)
///     MiDialogo(),
///     // Overlay de confetti
///     ConfettiCelebration(controller: _confettiController),
///   ],
/// )
/// ```
class ConfettiCelebration extends StatelessWidget {
  /// Controlador que gestiona la animación (play/pause/dispose).
  final ConfettiController controller;

  /// Colores de las partículas. Por defecto usa colores festivos variados.
  final List<Color> colors;

  /// Número de partículas a emitir. Por defecto: 50.
  final int numberOfParticles;

  /// Gravedad aplicada a las partículas (0.0 = flotan, 1.0 = caen rápido).
  final double gravity;

  /// Fuerza máxima de la explosión. Por defecto: 100.
  final double maxBlastForce;

  /// Fuerza mínima de la explosión. Por defecto: 20.
  final double minBlastForce;

  /// Frecuencia de emisión de partículas. Por defecto: 0.05.
  final double emissionFrequency;

  /// Dirección de la explosión. Por defecto: explosiva radial.
  final BlastDirectionality blastDirectionality;

  /// Si la animación debe repetirse en bucle. Por defecto: false.
  final bool shouldLoop;

  const ConfettiCelebration({
    super.key,
    required this.controller,
    this.colors = const [
      Colors.green,
      Colors.blue,
      Colors.pink,
      Colors.orange,
      Colors.purple,
    ],
    this.numberOfParticles = 50,
    this.gravity = 0.1,
    this.maxBlastForce = 100,
    this.minBlastForce = 20,
    this.emissionFrequency = 0.05,
    this.blastDirectionality = BlastDirectionality.explosive,
    this.shouldLoop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center, // 👈 Centrado perfecto
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: blastDirectionality,
          shouldLoop: shouldLoop,
          colors: colors,
          numberOfParticles: numberOfParticles,
          gravity: gravity,
          emissionFrequency: emissionFrequency,
          maxBlastForce: maxBlastForce,
          minBlastForce: minBlastForce,
          particleDrag: 0.05, // Resistencia al aire para movimiento natural
        ),
      ),
    );
  }
}

class TextoExpandible extends StatefulWidget {
  final String texto;
  final int maxLength;
  final TextStyle? style;

  const TextoExpandible({
    super.key,
    required this.texto,
    this.maxLength = 250,
    this.style,
  });

  @override
  State<TextoExpandible> createState() => _TextoExpandibleState();
}

class _TextoExpandibleState extends State<TextoExpandible> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Si el texto es corto o ya está expandido, mostramos todo sin botón
    if (widget.texto.length <= widget.maxLength || _expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.texto,
            style:
                widget.style ??
                const TextStyle(color: Colors.grey, height: 1.5),
          ),
          if (widget.texto.length > widget.maxLength)
            TextButton(
              onPressed: () => setState(() => _expanded = false),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Leer menos',
                style: TextStyle(
                  color: AppColors.morado,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      );
    }

    // Si está contraído y es largo, mostramos recortado + botón "Leer más"
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.texto.substring(0, widget.maxLength)}...',
          style:
              widget.style ?? const TextStyle(color: Colors.grey, height: 1.5),
        ),
        TextButton(
          onPressed: () => setState(() => _expanded = true),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Leer más',
            style: TextStyle(
              color: AppColors.morado,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
