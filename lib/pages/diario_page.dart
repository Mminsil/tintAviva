import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/widgets/entrada_card.dart';
import 'package:tintaviva/pages/detalle_libro_page.dart';
import 'package:tintaviva/widgets/dialogo_guardar_entrada.dart';

/// Página principal del diario de lectura.
///
/// Muestra las entradas (reflexiones y citas) del usuario con:
/// - Búsqueda por título de libro
/// - Filtros por tipo (entradas/citas)
/// - CRUD completo de entradas
/// - Navegación al detalle del libro
class DiarioPage extends StatefulWidget {
  const DiarioPage({super.key});

  @override
  State<DiarioPage> createState() => _DiarioPageState();
}

class _DiarioPageState extends State<DiarioPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  /// Filtro activo: 'entradas' | 'citas'
  String _filtroActual = 'entradas';

  /// Controlador para el campo de búsqueda por título
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (ÍNDICE LEGIBLE)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
            const SizedBox(height: 16),
            _buildFilterChips(),
            const SizedBox(height: 16),
            Expanded(child: _buildListaEntradas()),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye el título de la sección.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Text('Mi Diario de Lectura', style: AppTextStyles.sectionTitle),
    );
  }

  /// Construye el campo de búsqueda con filtrado en tiempo real.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _busquedaController,
        decoration: AppInputStyles.inputDecoration('Buscar por título...'),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  /// Construye los chips de filtro con scroll horizontal.
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildChip('📝 Entradas', 'entradas'),
            const SizedBox(width: 8),
            _buildChip('💬 Citas', 'citas'),
          ],
        ),
      ),
    );
  }

  /// Construye un chip de filtro individual.
  Widget _buildChip(String label, String valor) {
    final bool seleccionado = _filtroActual == valor;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: seleccionado,
        onSelected: (_) => setState(() => _filtroActual = valor),
        backgroundColor: Colors.grey[200],
        selectedColor: AppColors.naranja.withValues(alpha: 0.2),
        checkmarkColor: AppColors.naranja,
        labelStyle: TextStyle(
          color: seleccionado ? AppColors.naranja : Colors.black87,
          fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  /// Construye el botón flotante para agregar nueva entrada.
  Widget _buildFAB() {
    return FloatingActionButton(
      heroTag: 'fab_diario',
      onPressed: _abrirSelectorLibros,
      backgroundColor: AppColors.naranja,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  /// Widget para mostrar cuando no hay entradas.
  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text(
          'Aún no tienes entradas en tu diario.\n¡Empieza a escribir!',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LISTA PRINCIPAL CON STREAMBUILDER
  // ─────────────────────────────────────────────────────────────

  /// Construye la lista de entradas con StreamBuilder.
  ///
  /// Escucha cambios en tiempo real en la colección 'entries' del usuario,
  /// aplica filtros y búsqueda, y renderiza cada entrada con EntradaCard.
  Widget _buildListaEntradas() {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      return const Center(child: Text('Debes iniciar sesión'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('entries')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final entries = snapshot.data?.docs ?? [];
        final entradasFiltradas = _aplicarFiltros(entries);
        final entradasFinales = _aplicarBusqueda(entradasFiltradas);

        if (entradasFinales.isEmpty) return _buildEmptyState();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: entradasFinales.length,
          itemBuilder: (context, index) {
            final doc = entradasFinales[index];
            final entrada = doc.data() as Map<String, dynamic>;
            return EntradaCard(
              entrada: entrada,
              docId: doc.id,
              onEdit: () => _abrirDialogoEditar(entrada, doc.id),
              onDelete: () => _confirmarEliminar(doc.id),
              onBookTap: (userBookId) => _navegarADetalleLibro(userBookId),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO Y NAVEGACIÓN
  // ─────────────────────────────────────────────────────────────

  /// Navega al detalle del libro usando userBookId.
  ///
  /// Obtiene el bookId desde user_books y navega a DetalleLibroPage.
  Future<void> _navegarADetalleLibro(String userBookId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('user_books')
          .doc(userBookId)
          .get();

      if (doc.exists && mounted) {
        final data = doc.data()!;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleLibroPage(
              userBookId: userBookId,
              bookId: data['bookId'],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(context, "No se pudo abrir el libro", Colors.orange);
      }
    }
  }

  /// Función maestra: Abre el diálogo y guarda el resultado en Firebase.
  ///
  /// [libro] Objeto completo del libro para tener contexto (título, autor, IDs).
  Future<void> guardarEntradaDesdeDialogo(Map<String, dynamic> libro) async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => DialogoGuardarEntrada(
        tituloLibro: libro['title'],
        autorLibro: libro['author'],
      ),
    );

    if (resultado == null) return;

    try {
      await DatabaseService.agregarEntradaGlobal(
        userId: FirebaseAuth.instance.currentUser!.uid,
        userBookId: libro['id'],
        bookId: libro['bookId'],
        bookTitle: libro['title'],
        text: resultado['text'],
        type: resultado['type'],
        mood: resultado['mood'],
        author: resultado['author'],
      );
      if (!mounted) return;
      mostrarSnackBar(context, "Guardado correctamente", Colors.green);
    } catch (e) {
      if (!mounted) return;
      mostrarSnackBar(context, "Error al guardar: $e", Colors.red);
    }
  }

  /// Aplica el filtro seleccionado (entradas/citas) a la lista.
  List<QueryDocumentSnapshot> _aplicarFiltros(
    List<QueryDocumentSnapshot> entries,
  ) {
    switch (_filtroActual) {
      case 'entradas':
        return entries.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'diary';
        }).toList();
      case 'citas':
        return entries.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['type'] == 'quote';
        }).toList();
      default:
        return entries;
    }
  }

  /// Aplica la búsqueda por título de libro (case-insensitive).
  List<QueryDocumentSnapshot> _aplicarBusqueda(
    List<QueryDocumentSnapshot> entries,
  ) {
    if (_busquedaController.text.isEmpty) return entries;
    final query = _busquedaController.text.toLowerCase();
    return entries.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final titulo = (data['bookTitle'] ?? '').toString().toLowerCase();
      return titulo.contains(query);
    }).toList();
  }

  /// Abre el diálogo para seleccionar un libro y agregar entrada.
  ///
  /// Muestra lista filtrable de libros en estado 'Leyendo' o 'Leído'.
  void _abrirSelectorLibros() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('user_books')
        .where('userId', isEqualTo: userId)
        .get();

    if (!mounted) return;

    final libros = snapshot.docs.where((doc) {
      final data = doc.data();
      final shelf = data['shelf'] ?? '';
      return shelf == 'Leyendo' || shelf == 'Leído';
    }).toList();

    final busquedaController = TextEditingController();
    List<Map<String, dynamic>> librosFiltrados = libros
        .map((d) => {...d.data(), 'id': d.id})
        .toList();

    if (!mounted) return;

    final libroSeleccionado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('¿Sobre qué libro quieres escribir?'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: Column(
              children: [
                TextField(
                  controller: busquedaController,
                  decoration: InputDecoration(
                    hintText: 'Buscar libro...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  onChanged: (valor) {
                    setDialogState(() {
                      librosFiltrados = libros
                          .where(
                            (l) => (l['title'] ?? '')
                                .toString()
                                .toLowerCase()
                                .contains(valor.toLowerCase()),
                          )
                          .map((d) => {...d.data(), 'id': d.id})
                          .toList();
                    });
                  },
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: librosFiltrados.isEmpty
                      ? const Center(child: Text('No se encontraron libros'))
                      : ListView.builder(
                          itemCount: librosFiltrados.length,
                          itemBuilder: (context, index) {
                            final data = librosFiltrados[index];
                            return ListTile(
                              title: Text(data['title'] ?? 'Sin título'),
                              subtitle: Text(data['author'] ?? ''),
                              trailing: Text(
                                data['shelf'] == 'Leyendo' ? '📖' : '✅',
                                style: const TextStyle(fontSize: 16),
                              ),
                              onTap: () => Navigator.pop(context, data),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );

    busquedaController.dispose();
    if (libroSeleccionado != null && mounted) {
      guardarEntradaDesdeDialogo(libroSeleccionado);
    }
  }

  /// Abre el diálogo para editar una entrada existente.
  ///
  /// [entrada] Datos actuales de la entrada a editar.
  /// [docId] ID del documento en Firestore.
  void _abrirDialogoEditar(Map<String, dynamic> entrada, String docId) {
    final esCita = entrada['type'] == 'quote';
    final textController = TextEditingController(text: entrada['text']);
    final authorController = TextEditingController(
      text: entrada['author'] ?? '',
    );
    String tipoSeleccionado = entrada['type'];
    String moodSeleccionado = entrada['mood'] ?? '';
    final List<String> moods = ['😍', '🤔', '😢', '😡', '😲', '😊', '😐'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Editar ${esCita ? 'cita' : 'reflexión'}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.morado,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ToggleButtons(
                    isSelected: [
                      tipoSeleccionado == 'diary',
                      tipoSeleccionado == 'quote',
                    ],
                    onPressed:
                        null, // Deshabilitado al editar para evitar cambios de tipo
                    borderRadius: BorderRadius.circular(12),
                    selectedColor: Colors.white,
                    fillColor: AppColors.naranja,
                    color: AppColors.morado,
                    borderColor: Colors.grey.shade300,
                    children: const [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Reflexión',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'Cita',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: textController,
                    maxLines: esCita ? 3 : 4,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: esCita ? 'Frase...' : 'Tu reflexión...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                  if (!esCita) ...[
                    const SizedBox(height: 20),
                    const Text(
                      '¿Cómo te sientes?',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: moods.map((mood) {
                        final isSelected = moodSeleccionado == mood;
                        return GestureDetector(
                          onTap: () =>
                              setDialogState(() => moodSeleccionado = mood),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.naranja.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.naranja
                                    : Colors.grey.shade300,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              mood,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Autor',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: authorController,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'Nombre del autor',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final texto = textController.text.trim();
                if (texto.isEmpty) {
                  Navigator.pop(dialogContext);
                  return;
                }
                try {
                  final userId = FirebaseAuth.instance.currentUser!.uid;
                  await DatabaseService.actualizarEntradaGlobal(
                    userId: userId,
                    docId: docId,
                    text: texto,
                    type: tipoSeleccionado,
                    mood: tipoSeleccionado == 'diary' ? moodSeleccionado : null,
                    author: tipoSeleccionado == 'quote'
                        ? authorController.text.trim()
                        : null,
                  );
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    mostrarSnackBar(
                      context,
                      "Actualizado correctamente",
                      Colors.green,
                    );
                  }
                } catch (e) {
                  if (dialogContext.mounted) {
                    mostrarSnackBar(context, "Error: $e", Colors.red);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.morado,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra confirmación y elimina una entrada de Firebase.
  ///
  /// [docId] ID del documento a eliminar.
  void _confirmarEliminar(String docId) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          '¿Eliminar entrada?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        final userId = FirebaseAuth.instance.currentUser!.uid;
        await DatabaseService.eliminarEntradaGlobal(
          userId: userId,
          docId: docId,
        );
        if (mounted) {
          mostrarSnackBar(context, "Entrada eliminada", AppColors.naranja);
        }
      } catch (e) {
        if (mounted) {
          mostrarSnackBar(context, "Error al eliminar: $e", Colors.red);
        }
      }
    }
  }
}
