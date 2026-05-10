import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tintaviva/pages/detalle_club_page.dart';
import 'package:tintaviva/widgets/cita_del_dia.dart';
import '../widgets/dialogo_agregar_libro.dart';
import 'detalle_libro_page.dart';
import '../services/database.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/widgets/tarjeta_libro_progreso.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Página principal de la biblioteca del usuario.
///
/// Características principales:
/// 1. Muestra libros filtrables por estantería ('Leyendo', 'Leído', 'Por leer', 'Clubes').
/// 2. Búsqueda local en tiempo real por título o autor.
/// 3. Diferencia visual y funcional entre libros personales y libros de clubes:
///    - Libros de club: no se pueden eliminar, navegan a DetalleClubPage.
///    - Libros personales: se pueden eliminar con swipe, navegan a DetalleLibroPage.
/// 4. Incluye widget de "Cita del día" para inspiración diaria.
/// 5. Usa AutomaticKeepAliveClientMixin para preservar el estado al cambiar de pestaña en HomePage.
class MiBibliotecaPage extends StatefulWidget {
  const MiBibliotecaPage({super.key});

  @override
  State<MiBibliotecaPage> createState() => _MiBibliotecaPageState();
}

class _MiBibliotecaPageState extends State<MiBibliotecaPage>
    with AutomaticKeepAliveClientMixin {
  /// Indica a Flutter que debe preservar el estado de este widget cuando se oculta.
  /// Esto evita que la página se reconstruya cada vez que el usuario cambia de pestaña,
  /// manteniendo así el filtro activo, la búsqueda y el scroll en memoria.
  @override
  bool get wantKeepAlive => true;

  // Filtros disponibles: 'Leyendo', 'Leído', 'Por leer', 'Clubes'
  String _filtroActivo = 'Leyendo';

  // Texto de búsqueda para filtrar localmente por título o autor.
  String _query = "";

  @override
  Widget build(BuildContext context) {
    // Llamada obligatoria cuando se usa AutomaticKeepAliveClientMixin.
    super.build(context);

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarDialogoAgregar,
        backgroundColor: AppColors.morado,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text('Mi Biblioteca', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 15),

            // Buscador local: filtra en memoria los resultados del stream.
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
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
              ),
            ),

            const SizedBox(height: 15),

            // Chips de filtro horizontales para cambiar la vista de libros.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildChip('Leyendo'), // Personales leyendo
                  const SizedBox(width: 8),
                  _buildChip('Leído'), // Todos los leídos (personales + clubes)
                  const SizedBox(width: 8),
                  _buildChip('Por leer'), // Personales por leer
                  const SizedBox(width: 8),
                  _buildChip('Clubes'), // Solo los vinculados a un club
                ],
              ),
            ),

            // Widget de cita inspiradora diaria.
            const WidgetCitaDelDia(),

            // 👇 STREAM Y LÓGICA DE FILTRADO EN MEMORIA
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                // Traemos TODOS los libros del usuario para filtrar en memoria.
                // Esto nos da flexibilidad total para combinar filtros (estantería + club + búsqueda)
                // sin necesidad de múltiples consultas a Firestore.
                stream: FirebaseFirestore.instance
                    .collection('user_books')
                    .where(
                      'userId',
                      isEqualTo: FirebaseAuth.instance.currentUser?.uid,
                    )
                    .snapshots(),

                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error al cargar"));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allDocs = snapshot.data!.docs;

                  // LÓGICA DE FILTRADO SEGÚN EL CHIP SELECCIONADO
                  // Filtramos en memoria para combinar múltiples criterios fácilmente.
                  final librosFiltrados = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final shelf = data['shelf'] ?? '';
                    // Verificamos si el libro está vinculado a un club.
                    final idClub = (data['id_club'] as String?)?.trim();
                    final esClub = idClub != null && idClub.isNotEmpty;

                    switch (_filtroActivo) {
                      case 'Leyendo':
                        // Solo personales que estén leyendo (excluimos clubes).
                        return !esClub && shelf == 'Leyendo';
                      case 'Leído':
                        // Todos los que estén leídos (personales o de club).
                        return shelf == 'Leído';
                      case 'Por leer':
                        // Solo personales que estén por leer.
                        return !esClub && shelf == 'Por leer';
                      case 'Clubes':
                        // Solo los que tengan ID de club (independientemente del estado).
                        return esClub;
                      default:
                        return false;
                    }
                  }).toList();

                  // Filtrado adicional por búsqueda de texto (título o autor).
                  final librosFinales = librosFiltrados.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final titulo = (data['title'] ?? '')
                        .toString()
                        .toLowerCase();
                    final autor = (data['author'] ?? '')
                        .toString()
                        .toLowerCase();
                    return titulo.contains(_query) || autor.contains(_query);
                  }).toList();

                  // Mensaje cuando no hay resultados.
                  if (librosFinales.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.book_outlined,
                            size: 60,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "No hay libros en esta vista.",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  }

                  // Lista de tarjetas de libros con soporte para swipe-to-delete.
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    itemCount: librosFinales.length,
                    itemBuilder: (context, index) {
                      final doc = librosFinales[index];
                      final docId = doc.id;
                      final libro = doc.data() as Map<String, dynamic>;
                      final idClub = (libro['id_club'] as String?)?.trim();
                      final esClub = idClub != null && idClub.isNotEmpty;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7.5),
                        child: Dismissible(
                          key: Key(docId),
                          direction: DismissDirection.endToStart,

                          // Lógica condicional para eliminación:
                          // - Libros de club: no se pueden eliminar desde aquí (retornamos false).
                          // - Libros personales: muestran diálogo de confirmación.
                          confirmDismiss: esClub
                              ? (direction) async => false
                              : (direction) async {
                                  final bool? confirmar =
                                      await mostrarConfirmacionBorrado(context);
                                  return confirmar ?? false;
                                },

                          // Fondo visual del swipe: gris con candado para clubes, rojo para personales.
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: esClub
                                  ? Colors.grey[400]
                                  : Colors.redAccent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Icon(
                              esClub ? Icons.lock_outline : Icons.delete,
                              color: Colors.white,
                            ),
                          ),

                          // Acción al completar el swipe: eliminar libro personal.
                          onDismissed: (direction) async {
                            if (esClub){
                              return; // Seguridad: no eliminar clubes.
                            }
                            try {
                              await DatabaseService.eliminarLibro(
                                docId,
                                libro['shelf'],
                              );
                              if (context.mounted) {
                                mostrarSnackBar(
                                  context,
                                  "Libro eliminado",
                                  AppColors.naranja,
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                mostrarSnackBar(
                                  context,
                                  "Error: $e",
                                  Colors.red,
                                );
                              }
                            }
                          },

                          // Tarjeta reutilizable que muestra el progreso del libro.
                          child: TarjetaLibroProgreso(
                            docId: docId,
                            libroData: libro,
                            esClub:
                                esClub, // Para ajustar visualmente si es de club.
                            // Navegación condicional según tipo de libro.
                            onTapCustom: () {
                              if (esClub) {
                                // Libros de club navegan al detalle del club.
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        DetalleClubPage(clubId: idClub),
                                  ),
                                );
                              } else {
                                // Libros personales navegan al detalle del libro.
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
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye un FilterChip para los filtros de estantería.
  ///
  /// Estiliza el chip seleccionado con color naranja y negrita para mejor visibilidad.
  Widget _buildChip(String label) {
    final bool isSelected = _filtroActivo == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() => _filtroActivo = label);
      },
      backgroundColor: Colors.grey[200],
      selectedColor: AppColors.naranja.withValues(alpha: 0.2),
      checkmarkColor: AppColors.naranja,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.naranja : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  /// Muestra el diálogo para agregar un nuevo libro y maneja la operación asíncrona con loader.
  ///
  /// Flujo seguro:
  /// 1. Abre DialogoAgregarLibro y espera resultados.
  /// 2. Si hay datos, muestra un loader fullscreen para indicar proceso en curso.
  /// 3. Guarda el NavigatorState ANTES del await para usarlo de forma segura después.
  /// 4. Llama a DatabaseService.guardarLibroFirestore con todos los datos.
  /// 5. Cierra el loader y muestra feedback (éxito o error).
  ///
  /// Manejo de errores:
  /// - Si hay excepción, se muestra el mensaje limpio (sin "Exception: ") y se sugiere editar.
  void _mostrarDialogoAgregar() async {
    // 1. Abrir diálogo y esperar datos.
    final Map<String, dynamic>? res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const DialogoAgregarLibro(),
    );

    // Si el usuario canceló o la página se destruyó, salimos inmediatamente.
    if (res == null || !mounted) return;

    // 2. Mostrar loader: guardamos el NavigatorState antes del await para uso seguro posterior.
    final navigator = Navigator.of(context);

    navigator.push(
      MaterialPageRoute(
        builder: (_) => const Scaffold(
          backgroundColor: Colors.black54,
          body: Center(child: CircularProgressIndicator(color: Colors.white)),
        ),
        fullscreenDialog: true,
      ),
    );

    try {
      // 3. Llamar a la BD con todos los datos del formulario.
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
        res['sinopsis'] ?? '',
        res['genero'] ?? 'Sin género',
      );

      // 4. Cerrar loader y mostrar éxito.
      if (mounted) {
        navigator.pop(); // Cierra el loader.

        // Usamos el contexto actual del State (que sabemos que está montado gracias al if anterior).
        mostrarSnackBar(
          context,
          "¡Libro agregado a tu biblioteca!",
          AppColors.naranja,
        );
      }
    } catch (e) {
      // 5. Cerrar loader y mostrar error.
      if (mounted) {
        if (mounted) {
          navigator.pop();

          // Limpiamos el mensaje de error para hacerlo más legible al usuario.
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
}
