import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:tintaviva/pages/detalle_club_page.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';
import 'package:tintaviva/widgets/dialogo_crear_club.dart';
import 'package:tintaviva/widgets/dialogo_unirse_club.dart';

/// Pantalla principal que muestra los clubes de lectura del usuario autenticado.
///
/// Diferencia entre clubes activos (grid) y finalizados (lista horizontal).
/// Las acciones de administración (editar, finalizar, reactivar, eliminar) solo
/// aparecen si el usuario es el owner del club.
class ClubesPage extends StatefulWidget {
  const ClubesPage({super.key});

  @override
  State<ClubesPage> createState() => _ClubesPageState();
}

class _ClubesPageState extends State<ClubesPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (ÍNDICE LEGIBLE)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: SafeArea(child: _buildBody()),
      floatingActionButton: _buildSpeedDial(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye el cuerpo principal con StreamBuilder.
  ///
  /// Verifica autenticación, escucha cambios en 'clubs' donde el usuario es miembro,
  /// separa activos/finalizados y renderiza con CustomScrollView + Slivers.
  Widget _buildBody() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return _buildNotAuthenticated();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .where('members', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) => _buildStreamBody(snapshot, user),
    );
  }

  /// Widget mostrado cuando el usuario no está autenticado.
  Widget _buildNotAuthenticated() {
    return const Center(
      child: Text("Por favor, inicia sesión para ver los clubes."),
    );
  }

  /// Construye la respuesta del StreamBuilder según su estado.
  ///
  /// Maneja: error, carga, vacío, o datos con separación activos/finalizados.
  Widget _buildStreamBody(AsyncSnapshot<QuerySnapshot> snapshot, User user) {
    if (snapshot.hasError) return _buildErrorState(snapshot.error);
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
      return _buildEmptyClubsState();
    }

    final allDocs = snapshot.data!.docs;
    final activos = _filterActiveClubs(allDocs);
    final finalizados = _filterFinishedClubs(allDocs);

    return _buildClubsScrollView(activos, finalizados, user);
  }

  /// Widget de error de conexión con mensaje descriptivo.
  Widget _buildErrorState(dynamic error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          "Error de conexión: $error",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.red),
        ),
      ),
    );
  }

  /// Widget mostrado cuando el usuario no está en ningún club.
  Widget _buildEmptyClubsState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Text(
          "No estás en ningún club.\n¡Únete o crea uno!",
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ),
    );
  }

  /// Filtra la lista de documentos para obtener solo clubes activos.
  List<QueryDocumentSnapshot> _filterActiveClubs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] != 'finalizado';
    }).toList();
  }

  /// Filtra la lista de documentos para obtener solo clubes finalizados.
  List<QueryDocumentSnapshot> _filterFinishedClubs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'finalizado';
    }).toList();
  }

  /// Construye el CustomScrollView con SliverGrid (activos) y SliverList (finalizados).
  Widget _buildClubsScrollView(
    List<QueryDocumentSnapshot> activos,
    List<QueryDocumentSnapshot> finalizados,
    User user,
  ) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSectionTitle("Mis Clubes de Lectura"),
        _buildActiveClubsGrid(activos, user),
        if (finalizados.isNotEmpty) ...[
          const SliverToBoxAdapter(child: Divider(height: 40, indent: 20, endIndent: 20)),
          _buildSectionTitle("Clubes Finalizados", isSubtitle: true),
          _buildFinishedClubsList(finalizados),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  /// Construye el título de sección con estilo consistente.
  Widget _buildSectionTitle(String title, {bool isSubtitle = false}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, isSubtitle ? 0 : 20, 20, isSubtitle ? 15 : 10),
        child: Center(
          child: Text(
            title,
            style: isSubtitle
                ? TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black54)
                : AppTextStyles.sectionTitle,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  /// Construye la grilla de clubes activos (2 columnas).
  Widget _buildActiveClubsGrid(List<QueryDocumentSnapshot> activos, User user) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 15,
          mainAxisSpacing: 20,
          childAspectRatio: 0.65,
        ),
        delegate: SliverChildBuilderDelegate((context, index) {
          final clubData = activos[index].data() as Map<String, dynamic>;
          final String idDoc = activos[index].id;
          final bool esAdmin = clubData['ownerId'] == user.uid;
          return _tarjetaClub(context, clubData, idDoc, esAdmin);
        }, childCount: activos.length),
      ),
    );
  }

  /// Construye la lista horizontal de clubes finalizados.
  Widget _buildFinishedClubsList(List<QueryDocumentSnapshot> finalizados) {
    return SliverToBoxAdapter(
      child: SizedBox(
        height: 240,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemCount: finalizados.length,
          itemBuilder: (context, index) {
            final clubDoc = finalizados[index];
            final clubData = clubDoc.data() as Map<String, dynamic>;
            return _tarjetaClubFinalizado(context, clubData, clubDoc.id);
          },
        ),
      ),
    );
  }

  /// Construye el SpeedDial con acciones 'Unirse' y 'Crear club'.
  Widget? _buildSpeedDial() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: AppColors.morado,
      foregroundColor: Colors.white,
      overlayColor: Colors.black,
      overlayOpacity: 0.4,
      spacing: 12,
      children: [
        SpeedDialChild(
          child: const Icon(Icons.group_add_outlined),
          label: 'Unirse',
          labelStyle: const TextStyle(fontWeight: FontWeight.w500),
          onTap: () async {
            await showDialog(context: context, builder: (context) => const DialogoUnirseClub());
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.edit),
          label: 'Crear club',
          onTap: () {
            showDialog(context: context, builder: (context) => const DialogoCrearClub());
          },
        ),
      ],
    );
  }

  /// Placeholder visual cuando falla la carga de una imagen.
  ///
  /// Muestra `assets/imagen_app.jpg` sobre fondo morado con opacidad 0.1.
  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.morado.withValues(alpha: 0.1),
      child: Image.asset('assets/imagen_app.jpg', fit: BoxFit.cover),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TARJETAS DE CLUB (UI COMPLEJA EXTRAÍDA)
  // ─────────────────────────────────────────────────────────────

  /// Tarjeta para club activo.
  ///
  /// Muestra imagen (clubImageUrl o bookCover fallback), nombre, contador de miembros.
  /// Si esAdmin, muestra PopupMenuButton con opciones: editar, finalizar, eliminar.
  /// Al tocar navega a DetalleClubPage.
  Widget _tarjetaClub(BuildContext context, Map<String, dynamic> data, String id, bool esAdmin) {
    final String imageUrl = data['clubImageUrl'] ?? data['bookCover'] ?? '';
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleClubPage(clubId: id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildClubImageStack(imageUrl, esAdmin, data, id, context, isFinished: false)),
          const SizedBox(height: 8),
          _buildClubInfo(data),
        ],
      ),
    );
  }

  /// Tarjeta para club finalizado (formato compacto para lista horizontal).
  ///
  /// Prioriza bookCover sobre clubImageUrl. Si es admin, menú: editar, reactivar, eliminar.
  Widget _tarjetaClubFinalizado(BuildContext context, Map<String, dynamic> data, String id) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool esAdmin = data['ownerId'] == currentUserId;
    final String imageUrl = data['bookCover'] ?? data['clubImageUrl'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetalleClubPage(clubId: id))),
      child: Container(
        width: 130,
        height: 180,
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildClubImageStack(imageUrl, esAdmin, data, id, context, isFinished: true)),
            const SizedBox(height: 8),
            _buildClubInfo(data, isCompact: true),
          ],
        ),
      ),
    );
  }

  /// Construye el stack de imagen con overlay de menú admin si corresponde.
  Widget _buildClubImageStack(
    String imageUrl,
    bool esAdmin,
    Map<String, dynamic> data,
    String id,
    BuildContext context, {
    required bool isFinished,
  }) {
    return Stack(
      children: [
        _buildClubImage(imageUrl),
        if (esAdmin) _buildAdminMenuOverlay(data, id, context, isFinished: isFinished),
      ],
    );
  }

  /// Construye la imagen del club con fallback y bordes redondeados.
  Widget _buildClubImage(String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: imageUrl.isNotEmpty
            ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => _buildPlaceholder())
            : _buildPlaceholder(),
      ),
    );
  }

  /// Construye el menú de administración (PopupMenuButton) sobre la imagen.
  Widget _buildAdminMenuOverlay(Map<String, dynamic> data, String id, BuildContext context, {required bool isFinished}) {
    return Positioned(
      top: isFinished ? 5 : 8,
      right: 8,
      child: Material(
        color: Colors.transparent,
        child: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
          tooltip: 'Opciones de admin',
          onSelected: (value) => _handleAdminMenuAction(value, data, id, context, isFinished: isFinished),
          itemBuilder: (context) => _buildAdminMenuItems(data, isFinished: isFinished),
        ),
      ),
    );
  }

  /// Construye la lista de items del menú admin según el estado del club.
  List<PopupMenuEntry<String>> _buildAdminMenuItems(Map<String, dynamic> data, {required bool isFinished}) {
    return [
      const PopupMenuItem(value: 'edit_club', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Editar')])),
      if (!isFinished)
        const PopupMenuItem(value: 'finish_club', child: Row(children: [Icon(Icons.flag, size: 20, color: AppColors.naranja), SizedBox(width: 8), Text('Finalizar club')])),
      if (isFinished)
        const PopupMenuItem(value: 'reactivate_club', child: Row(children: [Icon(Icons.refresh, size: 20, color: AppColors.morado), SizedBox(width: 8), Text('Reactivar club')])),
      const PopupMenuItem(value: 'delete_club', child: Row(children: [Icon(Icons.delete_outline, color: Colors.red, size: 20), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))])),
    ];
  }

  /// Maneja la acción seleccionada del menú admin.
  void _handleAdminMenuAction(String value, Map<String, dynamic> data, String id, BuildContext context, {required bool isFinished}) {
    switch (value) {
      case 'edit_club':
        _mostrarDialogoEditarClub(context, id, data);
        break;
      case 'finish_club':
        if (!isFinished) _confirmarFinalizarClub(context, id);
        break;
      case 'reactivate_club':
        if (isFinished) _confirmarReactivarClub(context, id);
        break;
      case 'delete_club':
        _confirmarEliminarClub(context, id);
        break;
    }
  }

  /// Construye la información textual de la tarjeta (nombre + miembros o descripción).
  Widget _buildClubInfo(Map<String, dynamic> data, {bool isCompact = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['name'] ?? 'Sin nombre',
          maxLines: isCompact ? 2 : 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
        ),
        if (!isCompact)
          Text(
            "${(data['members'] as List? ?? []).length}/${data['maxMembers'] ?? 7} miembros",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          )
        else if (data['description'] != null && data['description'].toString().isNotEmpty)
          Text(
            data['description'],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO: ACCIONES DE ADMINISTRACIÓN
  // ─────────────────────────────────────────────────────────────

  /// Muestra diálogo de confirmación y elimina un club permanentemente.
  ///
  /// La eliminación borra: club, metas, comentarios e historial. Irreversible.
  void _confirmarEliminarClub(BuildContext context, String clubId) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Eliminar club permanentemente?",
      contenido: "Esta acción NO se puede deshacer. Se eliminará el club, metas, comentarios e historial.",
      textoAccion: "Sí, eliminar todo",
      colorAccion: Colors.red,
    );
    if (confirmar != true) return;

    try {
      await DatabaseService.eliminarClub(clubId);
      if (!context.mounted) return;
      mostrarSnackBar(context, "Club eliminado permanentemente.", Colors.red);
    } catch (e) {
      if (!context.mounted) return;
      mostrarSnackBar(context, "Error al eliminar club: $e", Colors.red);
    }
  }

  /// Finaliza un club: cierra la meta actual y asigna libros a bibliotecas personales.
  void _confirmarFinalizarClub(BuildContext context, String clubId) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Finalizar club?",
      contenido: "Al finalizar el club, se cerrará la meta actual y los libros pasarán a la biblioteca personal de los miembros según su progreso.",
      textoAccion: "Sí, finalizar",
      colorAccion: AppColors.naranja,
    );
    if (confirmar != true) return;

    try {
      await DatabaseService.finalizarClub(clubId);
      if (!context.mounted) return;
      mostrarSnackBar(context, "Club finalizado correctamente", AppColors.naranja);
    } catch (e) {
      if (!context.mounted) return;
      mostrarSnackBar(context, "Error al finalizar club: $e", Colors.red);
    }
  }

  /// Reactiva un club finalizado: restaura estado activo y meta actual.
  void _confirmarReactivarClub(BuildContext context, String clubId) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Reactivar club?",
      contenido: "Esto volverá a abrir el club para todos los miembros. La meta actual se restablecerá.",
      textoAccion: "Sí, reactivar",
      colorAccion: AppColors.morado,
    );
    if (confirmar != true) return;

    try {
      await DatabaseService.reactivarClub(clubId);
      if (!context.mounted) return;
      mostrarSnackBar(context, "Club reactivado correctamente", AppColors.morado);
    } catch (e) {
      if (!context.mounted) return;
      mostrarSnackBar(context, "Error al reactivar club: $e", Colors.red);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // DIÁLOGOS Y UI INTERACTIVA
  // ─────────────────────────────────────────────────────────────

  /// Muestra diálogo para editar nombre y descripción de un club.
  ///
  /// Pre-carga valores actuales y actualiza directamente en Firestore.
  void _mostrarDialogoEditarClub(BuildContext context, String clubId, Map<String, dynamic> currentData) {
    final nameController = TextEditingController(text: currentData['name'] ?? '');
    final descController = TextEditingController(text: currentData['description'] ?? '');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Editar Club", style: AppTextStyles.dialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: AppInputStyles.inputDecoration("")),
            const SizedBox(height: 10),
            TextField(controller: descController, decoration: AppInputStyles.inputDecoration("Descripción"), maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text("Cancelar", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: AppButtonStyles.primaryElevatedButton,
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await FirebaseFirestore.instance.collection('clubs').doc(clubId).update({
                  'name': nameController.text.trim(),
                  'description': descController.text.trim(),
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) mostrarSnackBar(context, "Club actualizado", AppColors.naranja);
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) mostrarSnackBar(context, "Error al actualizar club: $e", Colors.red);
              }
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}