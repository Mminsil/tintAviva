import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tintaviva/theme/app_styles.dart';
import '../pages/detalle_libro_page.dart';
import '../services/database.dart';
import 'package:tintaviva/utils/ui_helpers.dart'; // Para mostrar el diálogo de confirmación de borrado

/// Diálogo modal que muestra el listado completo de libros de una estantería específica.
///
/// Características principales:
/// 1. Filtrado en tiempo real desde Firestore por estantería ('Leído' o 'Por leer').
/// 2. Búsqueda local por título o autor.
/// 3. Eliminación de libros mediante deslizamiento (Dismissible) con confirmación.
/// 4. Navegación al detalle del libro al tocar la tarjeta.
class DialogoListado extends StatefulWidget {
  final String titulo;
  final String estanteria; // Recibe 'Leído' o 'Por leer'

  const DialogoListado({
    super.key,
    required this.titulo,
    required this.estanteria,
  });

  @override
  State<DialogoListado> createState() => _DialogoListadoState();
}

class _DialogoListadoState extends State<DialogoListado> {
  // Variable para filtrar el listado localmente según lo que escribe el usuario.
  String _query = "";

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 40),
      child: Column(
        children: [
          // CABECERA DEL DIÁLOGO
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(
                  width: 48,
                ), // Espaciador para centrar el título visualmente.
                if (widget.estanteria == "Leído")
                  Text(
                    "Estantería de libros leídos",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.morado,
                    ),
                  ),
                if (widget.estanteria == "Por leer")
                  Text(
                    "Estantería libros por leer",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.morado,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // BUSCADOR LOCAL
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              onChanged: (value) =>
                  setState(() => _query = value.toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Buscar por título o autor...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          const SizedBox(height: 15),

          // --- LISTADO EN TIEMPO REAL (STREAM) ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('user_books')
                  .where(
                    'userId',
                    isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                  )
                  .where('shelf', isEqualTo: widget.estanteria)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text("Error al cargar"));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                // Filtrado local: aplicamos la búsqueda sobre los datos ya obtenidos de Firebase.
                final librosDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final titulo = data['title'].toString().toLowerCase();
                  final autor = data['author'].toString().toLowerCase();
                  return titulo.contains(_query) || autor.contains(_query);
                }).toList();

                if (librosDocs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "No hay libros en esta estantería",
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  // PageStorageKey mantiene la posición del scroll si el diálogo se reconstruye.
                  key: const PageStorageKey('lista-leidos'),
                  itemCount: librosDocs.length,
                  itemBuilder: (context, index) {
                    final doc = librosDocs[index];
                    final libro = doc.data() as Map<String, dynamic>;
                    final String docId = doc.id;

                    // Dismissible permite eliminar el libro deslizando hacia la izquierda.
                    return Dismissible(
                      key: Key(docId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      // Confirmación antes de eliminar para evitar accidentes.
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
                          if (!mounted) return;
                          mostrarSnackBar(
                            this.context,
                            "${libro['title']} eliminado",
                            AppColors.naranja,
                          );
                        } catch (e) {
                          mostrarSnackBar(
                            this.context,
                            "Error al eliminar el libro ${libro['title']}",
                            Colors.red,
                          );
                        }
                      },
                      child: Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetalleLibroPage(
                                  userBookId: docId,
                                  bookId: libro['bookId'],
                                ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                // --- PORTADA DEL LIBRO ---
                                 AppBookCover(
                                  imageUrl: libro['bookCover'] ?? libro['coverURL'],
                                  width: 50,
                                  height: 75,
                                  borderRadius: 8.0,
                                ),
                                const SizedBox(width: 15),

                                // --- TÍTULO Y AUTOR ---
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        libro['title'] ?? 'Sin título',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        libro['author'] ?? 'Autor desconocido',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),

                                // Indicador visual de navegación.
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  size: 14,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }



}
