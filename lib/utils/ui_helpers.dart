import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tintaviva/theme/app_styles.dart';
import '../widgets/dialogo_edicion.dart';

// --- COLORES CORPORATIVOS ---
const Color kColorMorado = Color(0xFF5D3B82);
const Color kColorNaranja = Color(0xFFFF6B35);
const Color kColorFondo = Color(0xFFF8F9FA);
const Color kColorTexto = Color(0xFF333333);

/// Abre un diálogo para editar rápidamente el progreso de un libro.
/// Maneja la lógica de confirmación si el usuario intenta disminuir el progreso.
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
    builder: (context) => DialogoEdicion(
      tituloLibro: libro['title'] ?? "Sin título",
      progresoActual: progresoAnterior,
      formato: formato,
      paginasTotales: totalPaginas,
      paginaActual: paginaAnterior,
    ),
  );

  if (res == null || !context.mounted) return;

  int nuevoProgreso = res['progreso']!;
  int nuevaPagina = res['pagina']!;
  bool haDisminuido = false;
  String mensajeConfirmacion = "";

  // Detección de retroceso en el progreso.
  if (formato == 'Papel') {
    if (nuevaPagina == paginaAnterior) return;
    if (nuevaPagina < paginaAnterior) {
      haDisminuido = true;
      mensajeConfirmacion =
          "Has indicado la página $nuevaPagina, menor a la actual ($paginaAnterior). ¿Seguro?";
    }
  } else {
    if (nuevoProgreso == progresoAnterior) return;
    if (nuevoProgreso < progresoAnterior) {
      haDisminuido = true;
      mensajeConfirmacion =
          "Has indicado $nuevoProgreso%, menor al actual ($progresoAnterior%). ¿Seguro?";
    }
  }

  // Confirmación explícita si se reduce el progreso.
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
              "CANCELAR",
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "SÍ, DISMINUIR",
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  Map<String, dynamic> datosActualizar = {
    'progress': nuevoProgreso,
    'currentPage': nuevaPagina,
  };

  // Si llega al 100%, actualizar estantería y stats automáticamente.
  if (nuevoProgreso >= 100 && libro['shelf'] != 'Leído') {
    datosActualizar['progress'] = 100;
    datosActualizar['shelf'] = 'Leído';
    datosActualizar['dateFinished'] = FieldValue.serverTimestamp();
    if (formato == 'Papel') datosActualizar['currentPage'] = totalPaginas;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'stats.inProgress': FieldValue.increment(-1),
      'stats.read': FieldValue.increment(1),
    });
  }

  try {
    await FirebaseFirestore.instance
        .collection('user_books')
        .doc(docId)
        .update(datosActualizar);
    if (context.mounted) {
      mostrarSnackBar(context, "¡Progreso actualizado!", AppColors.naranja);
    }
  } catch (e) {
    if (context.mounted) mostrarSnackBar(context, "Error: $e", Colors.red);
  }
}

/// Diálogo estandarizado para confirmar borrado de libros.
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

/// Widget visual para barras de progreso. Adapta el texto según sea Digital (%) o Papel (Pág X/Y).
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
    int mesIndex = fecha.month >= 1 && fecha.month <= 12 ? fecha.month : 1;
    return "${fecha.day} ${meses[mesIndex]}";
  } catch (e) {
    return "";
  }
}

/// Formatea Timestamp o DateTime a formato largo ("Leído en enero de 2026").
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
    int mesIndex = (fecha.month - 1);
    if (mesIndex < 0 || mesIndex >= 12) mesIndex = 0;
    return "Leído en ${meses[mesIndex]} de ${fecha.year}";
  } catch (e) {
    return "";
  }
}

/// Diálogo genérico de confirmación con colores personalizables.
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
          color: kColorMorado,
        ),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: Text(
        contenido,
        style: const TextStyle(color: kColorTexto, fontSize: 15, height: 1.4),
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

/// Diálogo específico para reactivar (color verde).
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
          color: kColorMorado,
        ),
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      content: Text(
        contenido,
        style: const TextStyle(color: kColorTexto, fontSize: 15),
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

/// Diálogo de búsqueda de libros con normalización de texto para Firestore.
Future<Map<String, dynamic>?> mostrarDialogoBusquedaLibros(
  BuildContext context,
) async {
  final TextEditingController searchController = TextEditingController();

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
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
                  controller: searchController,
                  decoration:
                      AppInputStyles.inputDecoration(
                        'Escribe para buscar...',
                        prefixIcon: Icons.search,
                      ).copyWith(
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {});
                                },
                              )
                            : null,
                      ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _buildBooksStream(searchController.text),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            searchController.text.isEmpty
                                ? 'Escribe para buscar libros...'
                                : 'No se encontraron resultados',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        );
                      }
                      final libros = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: libros.length,
                        itemBuilder: (context, index) {
                          final data =
                              libros[index].data() as Map<String, dynamic>;
                          final titulo = (data['title'] ?? '').toString();
                          final autor = (data['author'] ?? '').toString();
                          final cover = (data['bookCover'] ?? '').toString();
                          final pages = (data['pages'] ?? 0).toInt();

                          return ListTile(
                            leading: AppBookCover(
                              imageUrl: cover,
                              width: 40,
                              height: 60,
                              borderRadius: 4.0,
                            ),
                            title: Text(
                              titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: autor.isNotEmpty ? Text(autor) : null,
                            onTap: () {
                              Navigator.pop<Map<String, dynamic>>(context, {
                                'titulo': titulo,
                                'autor': autor,
                                'bookId': libros[index].id,
                                'cover': cover,
                                'pages': pages,
                              });
                            },
                          );
                        },
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

/// Construye el stream de búsqueda normalizando la consulta (Case-insensitive range query).
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

  return FirebaseFirestore.instance
      .collection('books')
      .where('title', isGreaterThanOrEqualTo: normalizedQuery.trim())
      .where('title', isLessThanOrEqualTo: '${normalizedQuery.trim()}\uf8ff')
      .orderBy('title')
      .limit(20)
      .snapshots();
}

/// Widget universal para mostrar portadas de libros o imágenes con fallback.
/// 
/// - Si la URL es válida, intenta cargarla.
/// - Si falla la carga o la URL es nula, muestra 'assets/sin_portada1.png'.
/// - Permite personalizar tamaño y bordes.
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
    // Validación básica de URL
    bool isValidUrl = imageUrl != null && 
                      imageUrl!.isNotEmpty && 
                      imageUrl!.startsWith('http');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isValidUrl
          ? Image.network(
              imageUrl!,
              width: width,
              height: height,
              fit: fit,
              // Si la red falla o la imagen está corrupta, mostramos fallback
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            )
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
    return Image.asset(
      'assets/sin_portada.png', 
      width: width,
      height: height,
      fit: fit,
    );
  }
}