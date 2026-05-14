import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/widgets/dialogo_guardar_entrada.dart';

/// Widget que muestra la sección de citas favoritas de un libro específico.
///
/// Propósito:
/// - Mostrar citas guardadas por el usuario para un libro (`bookId`)
/// - Permitir agregar, editar y eliminar citas sin salir de la pantalla actual
/// - Ofrecer toggle para ver/ocultar citas antiguas (límite: 3 por defecto)
///
/// Fuente de datos:
/// - Colección: `users/{uid}/entries`
/// - Filtros: `type == 'quote'` AND `bookId == widget.bookId`
/// - Orden: `timestamp` descendente (más recientes primero)
///
/// Estructura esperada de cada documento en `entries`:
/// ```dart
/// {
///   'text': String,        // Texto de la cita
///   'author': String?,     // Autor de la cita (opcional)
///   'bookId': String,      // ID del libro en colección 'books'
///   'bookTitle': String,   // Título del libro
///   'type': 'quote',       // Tipo de entrada (fijo para esta sección)
///   'timestamp': Timestamp,// Fecha de creación
///   'docId': String,       // ID del documento (añadido en memoria para edición)
/// }
/// ```
///
/// Parámetros:
/// - [tituloLibro]: Título del libro para contexto en diálogos
/// - [userBookId]: ID del documento en `'user_books'` para vincular nuevas citas
/// - [bookId]: ID del libro en `'books'` para filtrar citas en Firestore
/// - [mostrarTodo]: Si `true`, muestra todas las citas; si `false`, limita a 3
/// - [onToggleVerMas]: Callback opcional para alternar entre ver/ocultar citas antiguas
///
/// Ejemplo de uso:
/// ```dart
/// // En DetalleLibroPage:
/// SeccionCitasLibro(
///   tituloLibro: libro['title'],
///   userBookId: docId,
///   bookId: libro['bookId'],
///   mostrarTodo: _mostrarTodasCitas,
///   onToggleVerMas: () => setState(() => _mostrarTodasCitas = !_mostrarTodasCitas),
/// )
/// ```
class SeccionCitasLibro extends StatefulWidget {
  /// Título del libro para contexto en diálogos de agregar/editar.
  final String tituloLibro;

  /// ID del documento en `'user_books'` para vincular nuevas citas al libro personal del usuario.
  final String userBookId;

  /// ID del libro en `'books'` para filtrar citas en la colección `entries`.
  final String bookId;

  /// Si `true`, muestra todas las citas; si `false`, limita a las 3 más recientes.
  final bool mostrarTodo;

  /// Callback opcional para alternar entre ver/ocultar citas antiguas.
  ///
  /// Típicamente usado para actualizar el estado del padre y reconstruir el widget.
  final VoidCallback? onToggleVerMas;

  const SeccionCitasLibro({
    super.key,
    required this.tituloLibro,
    required this.userBookId,
    required this.bookId,
    this.mostrarTodo = false,
    this.onToggleVerMas,
  });

  @override
  State<SeccionCitasLibro> createState() => _SeccionCitasLibroState();
}

class _SeccionCitasLibroState extends State<SeccionCitasLibro> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Cabecera: título + botón para agregar nueva cita
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Citas Favoritas", style: AppTextStyles.sectionTitle),
            IconButton(
              icon: const Icon(
                Icons.add_circle_outline,
                color: AppColors.naranja,
                size: 28,
              ),
              tooltip: 'Agregar nueva cita',
              onPressed: _agregarCita,
            ),
          ],
        ),
        const SizedBox(height: 15),

        // StreamBuilder: escucha cambios en tiempo real en la colección 'entries'
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .collection('entries')
              .where('type', isEqualTo: 'quote')
              .where('bookId', isEqualTo: widget.bookId)
              .orderBy('timestamp', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];
            // Añadimos 'docId' en memoria para facilitar edición/eliminación
            final citas = docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              data['docId'] = doc.id;
              return data;
            }).toList();

            if (citas.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(10),
                child: Center(
                  child: Text(
                    "No has guardado citas de este libro aún.",
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }

            // Limita a 3 citas si no se está mostrando todo
            final citasVisibles = widget.mostrarTodo
                ? citas
                : citas.take(3).toList();

            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // Lista de citas visibles con acciones de editar/eliminar
                  ...List.generate(citasVisibles.length, (index) {
                    final cita = citasVisibles[index];
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.format_quote,
                                color: AppColors.naranja,
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "\"${cita['text']}\"",
                                      style: const TextStyle(
                                        fontStyle: FontStyle.italic,
                                        fontSize: 14,
                                        height: 1.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "— ${cita['author']}",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Botón editar cita
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: AppColors.morado,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _abrirDialogoEditarCita(cita),
                              ),
                              const SizedBox(width: 4),
                              // Botón eliminar cita
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () =>
                                    _confirmarEliminar(cita['docId']),
                              ),
                            ],
                          ),
                        ),
                        // Divider entre citas (excepto la última)
                        if (index < citasVisibles.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade200,
                            indent: 16,
                            endIndent: 16,
                          ),
                      ],
                    );
                  }),
                  // Botón toggle para ver/ocultar citas antiguas (solo si hay más de 3)
                  if (citas.length > 3 && widget.onToggleVerMas != null)
                    InkWell(
                      onTap: widget.onToggleVerMas,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.mostrarTodo
                                    ? "Ocultar citas antiguas"
                                    : "Ver todas las citas (${citas.length})",
                                style: TextStyle(
                                  color: AppColors.morado,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Icon(
                                widget.mostrarTodo
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: AppColors.morado,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACCIONES: AGREGAR, EDITAR, ELIMINAR CITAS
  // ─────────────────────────────────────────────────────────────

  /// Agrega una nueva cita usando el diálogo unificado `DialogoGuardarEntrada`.
  ///
  /// Flujo:
  /// 1. Abre `DialogoGuardarEntrada` con `tipoInicial: 'quote'` forzado
  /// 2. Si el usuario confirma, llama a `DatabaseService.agregarEntradaGlobal`
  /// 3. Muestra feedback con `SnackBar` según el resultado
  ///
  /// Seguridad:
  /// - Verifica `mounted` antes de mostrar `SnackBar` para evitar errores si el widget fue destruido
  /// - Maneja excepciones de red/Firestore con mensaje de error amigable
  Future<void> _agregarCita() async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogoGuardarEntrada(
        tituloLibro: widget.tituloLibro,
        tipoInicial: 'quote', // ← Forzado a cita
      ),
    );

    if (resultado == null) {
      return;
    }

    try {
      await DatabaseService.agregarEntradaGlobal(
        userId: FirebaseAuth.instance.currentUser!.uid,
        userBookId: widget.userBookId,
        bookId: widget.bookId,
        bookTitle: widget.tituloLibro,
        text: resultado['text'],
        type: resultado['type'],
        mood: resultado['mood'],
        author: resultado['author'],
      );
      if (mounted) {
        mostrarSnackBar(
          context,
          resultado['type'] == 'quote'
              ? "Cita guardada ✨"
              : "Entrada guardada 📝",
          AppColors.naranja,
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(context, "Error: $e", Colors.red);
      }
    }
  }

  /// Abre diálogo para editar una cita existente.
  ///
  /// Parámetros:
  /// - [cita]: `Map<String, dynamic>` con datos de la cita a editar, incluyendo `'docId'`
  ///
  /// Flujo:
  /// 1. Pre-carga `text` y `author` en `TextEditingController`
  /// 2. Muestra `AlertDialog` con campos editables
  /// 3. Al guardar, llama a `DatabaseService.actualizarEntradaGlobal`
  /// 4. Cierra el diálogo y muestra feedback si hay error
  ///
  /// Validaciones:
  /// - El texto no puede estar vacío (`trim().isEmpty`)
  /// - Verifica `dialogContext.mounted` antes de navegar o mostrar `SnackBar`
  void _abrirDialogoEditarCita(Map<String, dynamic> cita) {
    final controller = TextEditingController(text: cita['text']);
    final authorController = TextEditingController(text: cita['author'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Editar cita"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: "Texto de la cita...",
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: authorController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(hintText: "Autor"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) {
                return;
              }
              try {
                await DatabaseService.actualizarEntradaGlobal(
                  userId: FirebaseAuth.instance.currentUser!.uid,
                  docId: cita['docId'],
                  text: controller.text.trim(),
                  type: 'quote',
                  author: authorController.text.trim(),
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  mostrarSnackBar(dialogContext, "Error: $e", Colors.red);
                }
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  /// Elimina una cita con confirmación explícita del usuario.
  ///
  /// Parámetros:
  /// - [docId]: ID del documento en `'entries'` a eliminar
  ///
  /// Flujo:
  /// 1. Muestra `AlertDialog` de confirmación con mensaje de irreversibilidad
  /// 2. Si el usuario confirma, llama a `DatabaseService.eliminarEntradaGlobal`
  /// 3. Muestra feedback con `SnackBar` según el resultado
  ///
  /// Seguridad:
  /// - Verifica `mounted` antes y después de `await` para evitar errores si el widget fue destruido
  /// - Maneja excepciones de Firestore con mensaje de error amigable
  Future<void> _confirmarEliminar(String docId) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¿Eliminar cita?"),
        content: const Text("Esta acción no se puede deshacer."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "Eliminar",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      try {
        await DatabaseService.eliminarEntradaGlobal(
          userId: FirebaseAuth.instance.currentUser!.uid,
          docId: docId,
        );

        // Si llegas aquí y el widget sigue montado, muestra el SnackBar
        if (mounted) {
          mostrarSnackBar(context, "Cita eliminada", AppColors.naranja);
        }
      } catch (e) {
        if (mounted) {
          mostrarSnackBar(context, "Error: $e", Colors.red);
        }
      }
    }
  }
}
