import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';
import 'package:tintaviva/widgets/tarjeta_libro_progreso.dart';
import 'package:tintaviva/widgets/widget_cita_del_dia.dart';
import 'package:tintaviva/widgets/dialogo_agregar_libro.dart';
import 'package:tintaviva/pages/detalle_libro_page.dart';
import 'package:tintaviva/pages/detalle_club_page.dart';

/// Página principal de la biblioteca del usuario.
///
/// Características principales:
/// 1. Muestra libros filtrables por estantería: `'Leyendo'`, `'Leído'`, `'Por leer'`, `'Clubes'`
/// 2. Búsqueda local en tiempo real por título o autor
/// 3. Diferencia visual y funcional entre libros personales y de clubes:
///    - Libros de club: no eliminables, navegan a `DetalleClubPage`
///    - Libros personales: eliminables con swipe, navegan a `DetalleLibroPage`
/// 4. Incluye `WidgetCitaDelDia` para inspiración diaria
/// 5. Usa `AutomaticKeepAliveClientMixin` para preservar estado al cambiar de pestaña
class MiBibliotecaPage extends StatefulWidget {
  const MiBibliotecaPage({super.key});

  @override
  State<MiBibliotecaPage> createState() => _MiBibliotecaPageState();
}

class _MiBibliotecaPageState extends State<MiBibliotecaPage>
    with AutomaticKeepAliveClientMixin {
  /// Indica a Flutter que preserve el estado de este widget cuando se oculta.
  ///
  /// Esto evita reconstrucciones innecesarias al cambiar de pestaña en `HomePage`,
  /// manteniendo en memoria: filtro activo, búsqueda y posición de scroll.
  @override
  bool get wantKeepAlive => true;

  /// Filtro activo de estantería: `'Leyendo'` | `'Leído'` | `'Por leer'` | `'Clubes'`
  String _filtroActivo = 'Leyendo';

  /// Texto de búsqueda para filtrar localmente por título o autor (case-insensitive).
  String _query = "";

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (ÍNDICE LEGIBLE)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      floatingActionButton: _buildFAB(),
      body: SafeArea(child: _buildBody()),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye el cuerpo principal con header, búsqueda, filtros, cita y lista de libros.
  Widget _buildBody() {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildHeader(),
        const SizedBox(height: 15),
        _buildSearchBar(),
        const SizedBox(height: 15),
        _buildFilterChips(),
        const WidgetCitaDelDia(),
        Expanded(child: _buildLibrosList()),
      ],
    );
  }

  /// Construye el título de la sección con estilo consistente.
  Widget _buildHeader() {
    return const Text('Mi Biblioteca', style: AppTextStyles.sectionTitle);
  }

  /// Construye el campo de búsqueda con filtrado en tiempo real.
  ///
  /// Actualiza `_query` en cada cambio para filtrar localmente los resultados del stream.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _query = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'Buscar por título o autor...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: Colors.grey[100],
        ),
      ),
    );
  }

  /// Construye los chips de filtro horizontales para cambiar la vista de libros.
  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _buildChip('Leyendo'),
            const SizedBox(width: 8),
            _buildChip('Leído'),
            const SizedBox(width: 8),
            _buildChip('Por leer'),
            const SizedBox(width: 8),
            _buildChip('Clubes'),
          ],
        ),
      ),
    );
  }

  /// Construye un `FilterChip` para los filtros de estantería.
  ///
  /// Estiliza el chip seleccionado con color naranja y negrita para mejor visibilidad.
  Widget _buildChip(String label) {
    final bool isSelected = _filtroActivo == label;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _filtroActivo = label;
        });
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

  /// Construye el botón flotante para agregar nuevo libro.
  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: _mostrarDialogoAgregar,
      backgroundColor: AppColors.morado,
      child: const Icon(Icons.add, color: Colors.white, size: 30),
    );
  }

  /// Widget mostrado cuando no hay libros que coincidan con los filtros.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text(
            "No hay libros en esta vista.",
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LISTA PRINCIPAL CON STREAMBUILDER Y FILTRADO
  // ─────────────────────────────────────────────────────────────

  /// Construye la lista de libros con `StreamBuilder` y filtrado en memoria.
  ///
  /// Flujo:
  /// 1. Escucha `user_books` del usuario actual
  /// 2. Filtra por estantería + estado de club (`_filterByShelf`)
  /// 3. Filtra por búsqueda de texto (`_filterBySearch`)
  /// 4. Renderiza `TarjetaLibroProgreso` con soporte para swipe-to-delete
  Widget _buildLibrosList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_books')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar"));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final allDocs = snapshot.data!.docs;
        final librosFiltrados = _filterByShelf(allDocs);
        final librosFinales = _filterBySearch(librosFiltrados);

        if (librosFinales.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: librosFinales.length,
          itemBuilder: (context, index) {
            final doc = librosFinales[index];
            return _buildLibroCard(doc);
          },
        );
      },
    );
  }

  /// Filtra documentos por estantería y estado de club según `_filtroActivo`.
  ///
  /// Reglas:
  /// - `'Leyendo'`: solo personales (`!esClub`) con `shelf == 'Leyendo'`
  /// - `'Leído'`: todos con `shelf == 'Leído'` (personales o de club)
  /// - `'Por leer'`: solo personales con `shelf == 'Por leer'`
  /// - `'Clubes'`: solo libros con `id_club` válido
  List<QueryDocumentSnapshot> _filterByShelf(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final shelf = data['shelf'] ?? '';
      final idClub = (data['id_club'] as String?)?.trim();
      final esClub = idClub != null && idClub.isNotEmpty;

      switch (_filtroActivo) {
        case 'Leyendo':
          return !esClub && shelf == 'Leyendo';
        case 'Leído':
          return shelf == 'Leído';
        case 'Por leer':
          return !esClub && shelf == 'Por leer';
        case 'Clubes':
          return esClub;
        default:
          return false;
      }
    }).toList();
  }

  /// Filtra documentos por búsqueda de texto en título o autor (case-insensitive).
  List<QueryDocumentSnapshot> _filterBySearch(
    List<QueryDocumentSnapshot> docs,
  ) {
    if (_query.isEmpty) {
      return docs;
    }
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final titulo = (data['title'] ?? '').toString().toLowerCase();
      final autor = (data['author'] ?? '').toString().toLowerCase();
      return titulo.contains(_query) || autor.contains(_query);
    }).toList();
  }

  /// Construye la tarjeta de libro con soporte para swipe-to-delete.
  ///
  /// - Libros de club: no eliminables, navegan a `DetalleClubPage`
  /// - Libros personales: eliminables con confirmación, navegan a `DetalleLibroPage`
  Widget _buildLibroCard(QueryDocumentSnapshot doc) {
    final docId = doc.id;
    final libro = doc.data() as Map<String, dynamic>;
    final idClub = (libro['id_club'] as String?)?.trim();
    final esClub = idClub != null && idClub.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7.5),
      child: Dismissible(
        key: Key(docId),
        direction: DismissDirection.endToStart,
        confirmDismiss: (direction) => _onConfirmDismiss(esClub, direction),
        background: _buildSwipeBackground(esClub),
        onDismissed: (direction) => _onBookDismissed(docId, libro, esClub),
        child: TarjetaLibroProgreso(
          docId: docId,
          libroData: libro,
          esClub: esClub,
          onTapCustom: () => _onBookTap(esClub, idClub, docId, libro),
        ),
      ),
    );
  }

  /// Construye el fondo visual del swipe: gris con candado (clubes) o rojo (personales).
  Widget _buildSwipeBackground(bool esClub) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: esClub ? Colors.grey[400] : Colors.redAccent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        esClub ? Icons.lock_outline : Icons.delete,
        color: Colors.white,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HANDLERS: SWIPE Y NAVEGACIÓN
  // ─────────────────────────────────────────────────────────────

  /// Maneja la confirmación de eliminación: bloqueada para clubes, diálogo para personales.
  Future<bool> _onConfirmDismiss(
    bool esClub,
    DismissDirection direction,
  ) async {
    if (esClub) {
      return false;
    }
    final bool? confirmar = await mostrarConfirmacionBorrado(context);
    return confirmar ?? false;
  }

  /// Maneja la acción de eliminar un libro personal tras completar el swipe.
  Future<void> _onBookDismissed(
    String docId,
    Map<String, dynamic> libro,
    bool esClub,
  ) async {
    if (esClub) {
      return;
    }
    try {
      await DatabaseService.eliminarLibro(docId, libro['shelf']);
      if (!mounted) return;
      mostrarSnackBar(context, "Libro eliminado", AppColors.naranja);
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(context, "Error: $e", Colors.red);
      }
    }
  }

  /// Maneja el toque en una tarjeta: navega a club o libro según corresponda.
  void _onBookTap(
    bool esClub,
    String? idClub,
    String docId,
    Map<String, dynamic> libro,
  ) {
    if (esClub && idClub != null) {
      _navigateToClubDetail(idClub);
    } else {
      _navigateToBookDetail(docId, libro['bookId']);
    }
  }

  /// Navega a `DetalleClubPage` con el `clubId` especificado.
  void _navigateToClubDetail(String clubId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalleClubPage(clubId: clubId)),
    );
  }

  /// Navega a `DetalleLibroPage` con `userBookId` y `bookId`.
  void _navigateToBookDetail(String userBookId, String bookId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            DetalleLibroPage(userBookId: userBookId, bookId: bookId),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIÁLOGO DE AGREGAR LIBRO (LÓGICA CON LOADER)
  // ─────────────────────────────────────────────────────────────

  /// Muestra el diálogo para agregar un nuevo libro y maneja la operación asíncrona con loader.
  ///
  /// Flujo seguro:
  /// 1. Abre `DialogoAgregarLibro` y espera resultados
  /// 2. Si hay datos, muestra loader fullscreen para indicar proceso en curso
  /// 3. Guarda el `NavigatorState` ANTES del `await` para uso seguro posterior
  /// 4. Llama a `DatabaseService.guardarLibroFirestore` con todos los datos
  /// 5. Cierra loader y muestra feedback (éxito o error)
  ///
  /// Manejo de errores:
  /// - Limpia el mensaje (`Exception: ` → texto legible)
  /// - Sugiere editar el libro si falla la creación
  Future<void> _mostrarDialogoAgregar() async {
    final Map<String, dynamic>? res = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const DialogoAgregarLibro(),
    );

    if (res == null || !mounted) {
      return;
    }

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

      if (mounted) {
        navigator.pop();
        mostrarSnackBar(
          context,
          "¡Libro agregado a tu biblioteca!",
          AppColors.naranja,
        );
      }
    } catch (e) {
      if (mounted) {
        navigator.pop();
        final String mensaje = e.toString().replaceFirst('Exception: ', '');
        mostrarSnackBar(
          context,
          "$mensaje \n¿Quieres editarlo? Ve a tu biblioteca y búscalo.",
          Colors.red,
        );
      }
    }
  }
}
