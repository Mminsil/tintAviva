import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tintaviva/pages/detalle_club_page.dart';
import '../widgets/dialogo_agregar.dart';
import '../widgets/dialogo_listado.dart';
import 'detalle_libro_page.dart';
import '../services/database.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/widgets/tarjeta_libro_progreso.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Página principal de la biblioteca del usuario.
///
/// Muestra los libros en curso y permite filtrar por estanterías.
/// Diferencia visualmente entre libros personales y libros pertenecientes a un club.
class MiBibliotecaPage extends StatefulWidget {
  const MiBibliotecaPage({super.key});

  @override
  State<MiBibliotecaPage> createState() => _MiBibliotecaPageState();
}

class _MiBibliotecaPageState extends State<MiBibliotecaPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoAgregar,
        backgroundColor: AppColors.morado,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const Text(
              'Mi biblioteca',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Botones de acceso rápido a estanterías completas.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _botonFiltro(
                  "Leídos",
                  AppColors.morado,
                  () => _mostrarDialogoListado("Leído"),
                ),
                const SizedBox(width: 20),
                _botonFiltro(
                  "Por leer",
                  AppColors.morado,
                  () => _mostrarDialogoListado("Por leer"),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Stream principal: Escucha solo los libros con estado 'Leyendo'.
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('user_books')
                    .where(
                      'userId',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                    )
                    .where('shelf', isEqualTo: 'Leyendo')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error al cargar datos"));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data!.docs;

                  // Separación lógica: Libros personales vs Libros de Club.
                  // Un libro es de club si tiene el campo 'id_club' populated.
                  final personalBooks = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['id_club'] == null;
                  }).toList();

                  final clubBooks = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return data['id_club'] != null;
                  }).toList();

                  if (allDocs.isEmpty) {
                    return const Center(
                      child: Text("No tienes libros en lectura."),
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- SECCIÓN 1: LIBROS PERSONALES ---
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 25),
                          child: Text(
                            'Leyendo ahora',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (personalBooks.isNotEmpty) ...[
                          ...personalBooks.map((doc) {
                            final docId = doc.id;
                            final libro = doc.data() as Map<String, dynamic>;

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 7.5,
                              ),
                              child: Dismissible(
                                key: Key(docId),
                                direction: DismissDirection.endToStart,
                                // Confirmación antes de borrar para evitar accidentes.
                                confirmDismiss: (direction) async {
                                  final bool? confirmar =
                                      await mostrarConfirmacionBorrado(context);
                                  return confirmar ?? false;
                                },
                                onDismissed: (direction) async {
                                  try {
                                    await DatabaseService.eliminarLibro(
                                      docId,
                                      libro['shelf'],
                                    );
                                    if (context.mounted) {
                                      mostrarSnackBar(
                                        context,
                                        "Libro eliminado de tu biblioteca",
                                        AppColors.naranja,
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      mostrarSnackBar(
                                        context,
                                        "Error al eliminar: $e",
                                        Colors.red,
                                      );
                                    }
                                  }
                                },
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.white,
                                  ),
                                ),
                                child: TarjetaLibroProgreso(
                                  docId: docId,
                                  libroData: libro,
                                  colorMorado: AppColors.morado,
                                  colorNaranja: AppColors.naranja,
                                ),
                              ),
                            );
                          }),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                "No tienes libros personales en lectura.",
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // --- SECCIÓN 2: LIBROS DE CLUBES ---
                        // Estos NO son eliminables desde aquí porque dependen del estado del club.
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 25),
                          child: Text(
                            'Lectura en clubes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        if (clubBooks.isNotEmpty) ...[
                          ...clubBooks.map((doc) {
                            final docId = doc.id;
                            final libro = doc.data() as Map<String, dynamic>;
                            final idClub = (libro['id_club'] as String?)
                                ?.trim();

                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 7.5,
                              ),
                              child: TarjetaLibroProgreso(
                                docId: docId,
                                libroData: libro,
                                colorMorado: AppColors.morado,
                                colorNaranja: AppColors.naranja,
                                // onTapCustom: Si es libro de club, navegamos al detalle del CLUB, no del libro.
                                onTapCustom: () {
                                  if (idClub != null && idClub.isNotEmpty) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            DetalleClubPage(clubId: idClub),
                                      ),
                                    );
                                  } else {
                                    // Fallback de seguridad.
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => DetalleLibroPage(
                                          userBookId: docId,
                                          bookId: libro['bookId'],
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            );
                          }),
                        ] else ...[
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                "No tienes libros de clubes de lectura.",
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 30),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonFiltro(String texto, Color color, VoidCallback accion) {
    return OutlinedButton(
      onPressed: accion,
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color, width: 2),
        foregroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
        backgroundColor: Colors.white,
      ),
      child: Text(texto, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  void _mostrarDialogoAgregar() async {
    final Map<String, dynamic>? res = await showDialog(
      context: context,
      builder: (context) => const DialogoAgregar(),
    );
    if (res != null) {
      try {
        await DatabaseService.guardarLibroFirestore(
          res['titulo'] ?? "Sin título",
          res['autor'] ?? "Anónimo",
          res['estanteria'] ?? "Leyendo",
          res['progreso'] ?? 0,
          res['fechaInicio'],
          res['fechaFin'],
          res['formato'] ?? "Papel",
          res['paginasTotales'] ?? 0,
          res['paginaActual'] ?? 0,
          res['cover'] ?? "",
          res['isbn'] ?? "",
        );
        if (mounted) {
          mostrarSnackBar(
            context,
            "¡Libro agregado a tu biblioteca!",
            AppColors.naranja,
          );
        }
      } catch (e) {
        if (mounted) {
          String mensaje = e.toString().replaceFirst('Exception: ', '');
          mostrarSnackBar(
            context,
            "$mensaje \n¿Quieres editarlo? Ve a tu biblioteca y búscalo.",
            Colors.red,
          );
        }
      }
    }
  }

  void _mostrarDialogoListado(String estanteria) {
    showDialog(
      context: context,
      builder: (context) =>
          DialogoListado(titulo: "Libros $estanteria", estanteria: estanteria),
    );
  }
}
