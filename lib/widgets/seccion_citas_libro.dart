import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/services/database.dart';

/// Widget que muestra la lista de citas guardadas por el usuario para un libro especifico.
///
/// Caracteristicas:
/// - Muestra hasta 3 citas inicialmente, con boton "Ver mas" si hay mas.
/// - Cada cita muestra: texto entre comillas, autor, boton eliminar.
/// - Permite agregar nuevas citas mediante callback onAddQuote.
/// - La lista se recarga automaticamente despues de agregar o eliminar.
///
/// El widget se reconstruye cambiando su Key cuando se modifica una cita,
/// forzando al FutureBuilder a volver a consultar la base de datos.
class SeccionCitasLibro extends StatefulWidget {
  final String tituloLibro;
  final Future<bool?> Function()? onAddQuote;
  final bool mostrarTodo;
  final VoidCallback? onToggleVerMas;

  const SeccionCitasLibro({
    super.key,
    required this.tituloLibro,
    this.onAddQuote,
    this.mostrarTodo = false,
    this.onToggleVerMas,
  });

  @override
  State<SeccionCitasLibro> createState() => _SeccionCitasLibroState();
}

class _SeccionCitasLibroState extends State<SeccionCitasLibro> {
  Key _refreshKey = UniqueKey();

  /// Recarga la lista de citas cambiando la clave del KeyedSubtree.
  /// Esto fuerza al FutureBuilder a ejecutar su future nuevamente.
  void _recargarCitas() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),

        // Cabecera con titulo y boton de agregar
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Citas Favoritas", style: AppTextStyles.sectionTitle),
            if (widget.onAddQuote != null)
              IconButton(
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.naranja,
                  size: 28,
                ),
                tooltip: 'Agregar nueva cita',
                onPressed: () async {
                  final bool? guardado = await widget.onAddQuote!();
                  if (guardado == true) {
                    _recargarCitas();
                  }
                },
              ),
          ],
        ),

        const SizedBox(height: 15),

        // FutureBuilder envuelto con clave dinamica para forzar recarga
        KeyedSubtree(
          key: _refreshKey,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseService.obtenerCitasDeLibro(widget.tituloLibro),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final citas = snapshot.data ?? [];

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
                                Icon(
                                  Icons.format_quote,
                                  color: AppColors.naranja,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: AppColors.morado,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () =>
                                      _abrirDialogoEditarCita(cita),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final bool?
                                    confirmar = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text("¿Eliminar cita?"),
                                        content: const Text(
                                          "Esta acción no se puede deshacer.",
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text("Cancelar"),
                                          ),
                                          ElevatedButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red,
                                            ),
                                            child: const Text(
                                              "Eliminar",
                                              style: TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirmar == true) {
                                      try {
                                        await DatabaseService.eliminarCitaFavorita(
                                          texto: cita['text'],
                                          libroTitulo: cita['bookTitle'],
                                          autor: cita['author'],
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text("Cita eliminada"),
                                              backgroundColor:
                                                  AppColors.naranja,
                                            ),
                                          );
                                          _recargarCitas();
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text("Error: $e"),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
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
        ),
      ],
    );
  }

  void _abrirDialogoEditarCita(Map<String, dynamic> cita) {
    final controller = TextEditingController(text: cita['text'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Editar cita"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          autocorrect: true,
          decoration: const InputDecoration(hintText: "Texto de la cita..."),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                // 👇 Actualizar cita (necesitas crear esta función en DatabaseService)
                await DatabaseService.actualizarCitaFavorita(
                  textoAntiguo: cita['text'],
                  textoNuevo: controller.text.trim(),
                  libroTitulo: cita['bookTitle'],
                  autor: cita['author'],
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  _recargarCitas();
                }
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}
