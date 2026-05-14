import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';
import 'package:tintaviva/widgets/tarjeta_libro_progreso.dart';

/// Pantalla de detalle de un club de lectura.
///
/// Muestra:
/// - Información del club (imagen, nombre, descripción, miembros)
/// - Libro actual con progreso personal (`TarjetaLibroProgreso`)
/// - Gestión de metas (solo admin): crear, finalizar, reactivar
/// - Sistema de comentarios por meta (`club_goals/comments`)
/// - Semáforo de progreso grupal o lista finalizada
///
/// Estados posibles: `'activo'` (con meta vigente) | `'finalizado'` (solo lectura)
class DetalleClubPage extends StatefulWidget {
  final String clubId;
  const DetalleClubPage({super.key, required this.clubId});

  @override
  State<DetalleClubPage> createState() => _DetalleClubPageState();
}

class _DetalleClubPageState extends State<DetalleClubPage> {
  /// Controla si ya se mostró el diálogo de selección de formato.
  ///
  /// Evita mostrar el diálogo múltiples veces al reconstruir el widget.
  bool _mostrandoDialogoFormato = false;

  @override
  void initState() {
    super.initState();
    _sincronizarMetaAlEntrar();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (ÍNDICE LEGIBLE)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye la AppBar con botón de retroceso y estilo personalizado.
  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      foregroundColor: AppColors.morado,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  /// Construye el cuerpo principal con `StreamBuilder` para datos del club.
  ///
  /// Escucha cambios en tiempo real en `clubs/{clubId}` y renderiza:
  /// - Estados de carga/error
  /// - Contenido principal con header, libro, metas, semáforo y comentarios
  Widget _buildBody() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("El club no existe."));
        }
        if (snapshot.hasError) {
          return const Center(child: Text("Error al cargar."));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        data['id'] = snapshot.data!.id;
        return _buildClubContent(data);
      },
    );
  }

  /// Construye el contenido principal una vez cargados los datos del club.
  ///
  /// Extrae variables locales, determina estado (admin/finalizado) y construye la UI.
  Widget _buildClubContent(Map<String, dynamic> data) {
    final String nombreClub = data['name'] ?? "Sin nombre";
    final String libro = data['book'] ?? "Libro no especificado";
    final String autor = data['bookAuthor'] ?? "Autor desconocido";
    final String descripcion = data['description'] ?? "";
    final String ownerId = data['ownerId'] ?? "";
    final String clubBookId = data['bookId'] ?? "";
    final String clubImageUrl = data['clubImageUrl'] ?? "";
    final bool clubFinalizado = data['status'] == 'finalizado';
    final String metaActual = data['currentGoalName'] ?? "Meta no definida";
    final Map<String, dynamic> clubMembers = data['club_members'] ?? {};
    final List<dynamic> membersIds = data['members'] ?? [];
    final String fechaFormateada = data['limitDate'] != null
        ? formatearFechaCorta(data['limitDate'])
        : "";
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";
    final bool esAdmin = ownerId == currentUserId;

    // Datos del usuario actual en el club
    final datosUsuarioActual =
        clubMembers[currentUserId] as Map<String, dynamic>?;
    final userNameActual =
        datosUsuarioActual?['userName'] ??
        FirebaseAuth.instance.currentUser?.displayName ??
        "Usuario";
    final userPhotoActual =
        datosUsuarioActual?['userPhoto'] ??
        FirebaseAuth.instance.currentUser?.photoURL ??
        "";
    final goalReachedUsuario = datosUsuarioActual?['goalReached'] ?? false;
    final isReadingUsuario = datosUsuarioActual?['isReading'] ?? false;

    // Clasificación de miembros para el semáforo
    final List<dynamic> confirmados = [], leyendo = [], inactivos = [];
    clubMembers.forEach((uid, info) {
      if (info['goalReached'] ?? false) {
        confirmados.add(uid);
      } else if (info['isReading'] ?? false) {
        leyendo.add(uid);
      } else {
        inactivos.add(uid);
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildClubHeader(
            nombreClub,
            descripcion,
            clubImageUrl,
            esAdmin,
            membersIds,
            clubMembers,
            currentUserId,
          ),
          const SizedBox(height: 30),
          _buildCurrentBookSection(libro, autor, clubBookId),
          const SizedBox(height: 30),
          if (esAdmin) _buildAdminPanel(data, clubFinalizado),
          const SizedBox(height: 20),
          clubFinalizado
              ? _buildBannerFinalizado(data, libro)
              : _buildSeccionMeta(
                  metaActual,
                  fechaFormateada,
                  esAdmin,
                  data,
                  currentUserId,
                  goalReachedUsuario,
                  isReadingUsuario,
                ),
          const SizedBox(height: 25),
          clubFinalizado
              ? _buildListaProgresoFinal(clubMembers)
              : _buildSemaforo(confirmados, leyendo, inactivos, clubMembers),
          const SizedBox(height: 25),
          clubFinalizado
              ? _buildSeccionComentariosArchivado(
                  widget.clubId,
                  data['currentGoalId'] ?? "meta_inicial",
                )
              : _buildSeccionComentarios(
                  widget.clubId,
                  data['currentGoalId'] ?? "meta_inicial",
                  userNameActual,
                  userPhotoActual,
                  currentUserId,
                ),
          const SizedBox(height: 30),
          clubFinalizado ? _buildFooterHistorial() : _buildExitButton(esAdmin),
        ],
      ),
    );
  }

  /// Construye el header del club: imagen, nombre, descripción y resumen de miembros.
  Widget _buildClubHeader(
    String nombreClub,
    String descripcion,
    String clubImageUrl,
    bool esAdmin,
    List<dynamic> membersIds,
    Map<String, dynamic> clubMembers,
    String currentUserId,
  ) {
    return Center(
      child: Column(
        children: [
          _buildClubImage(clubImageUrl, esAdmin),
          const SizedBox(height: 15),
          Text(
            nombreClub,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.morado,
            ),
            textAlign: TextAlign.center,
          ),
          if (descripcion.isNotEmpty && descripcion != "Sin descripción")
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
              child: Text(
                descripcion,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[700]),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const SizedBox(height: 10),
          _buildMiembrosResumen(
            membersIds,
            esAdmin,
            () => _mostrarListaMiembros(
              context,
              clubMembers,
              currentUserId,
              esAdmin,
              widget.clubId,
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la imagen del club con fallback y botón de edición para admin.
  Widget _buildClubImage(String clubImageUrl, bool esAdmin) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.morado, width: 3),
          ),
          child: ClipOval(
            child: clubImageUrl.isNotEmpty
                ? Image.network(
                    clubImageUrl,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) =>
                        _buildImageFallback(),
                  )
                : _buildImageFallback(),
          ),
        ),
        if (esAdmin) _buildEditImageButton(),
      ],
    );
  }

  /// Widget fallback cuando falla la carga de la imagen del club.
  Widget _buildImageFallback() {
    return Image.asset(
      'assets/imagen_app.jpg',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppColors.morado.withValues(alpha: 0.1),
          child: const Icon(Icons.menu_book, color: AppColors.morado, size: 40),
        );
      },
    );
  }

  /// Botón de edición de imagen para admin (sobrepuesto en la esquina).
  Widget _buildEditImageButton() {
    return Positioned(
      bottom: 0,
      right: 10,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: InkWell(
          onTap: () => _mostrarDialogoCambiarImagenClub(context, widget.clubId),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(Icons.edit, color: AppColors.morado, size: 20),
          ),
        ),
      ),
    );
  }

  /// Construye la sección del libro actual con `StreamBuilder` anidado.
  Widget _buildCurrentBookSection(
    String libro,
    String autor,
    String clubBookId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 8),
            Text("Leyendo ahora", style: AppTextStyles.sectionTitle),
          ],
        ),
        const SizedBox(height: 10),
        _buildUserBookStream(clubBookId, libro, autor),
      ],
    );
  }

  /// StreamBuilder anidado para datos del libro en la biblioteca personal del usuario.
  Widget _buildUserBookStream(String clubBookId, String libro, String autor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_books')
          .where('userId', isEqualTo: FirebaseAuth.instance.currentUser?.uid)
          .where('bookId', isEqualTo: clubBookId.isNotEmpty ? clubBookId : '')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildBookNotAddedCard(libro, autor);
        }

        final userBookDoc = snapshot.data!.docs.first;
        final userBookData = userBookDoc.data() as Map<String, dynamic>;
        final String docId = userBookDoc.id;
        final String formatoActual = userBookData['format'] ?? '';

        if (formatoActual.isEmpty && !_mostrandoDialogoFormato && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _mostrandoDialogoFormato = true);
              _mostrarDialogoSeleccionarFormato(
                docId,
                userBookData['totalPages'] ?? 0,
              );
            }
          });
        }

        return TarjetaLibroProgreso(docId: docId, libroData: userBookData);
      },
    );
  }

  /// Tarjeta mostrada cuando el usuario aún no ha agregado el libro a su biblioteca.
  Widget _buildBookNotAddedCard(String libro, String autor) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 70,
              height: 105,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[200],
              ),
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    libro,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    autor,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Añade este libro a tu biblioteca para ver el progreso",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Panel de administración: código de invitación y acciones (finalizar, reactivar, eliminar).
  Widget _buildAdminPanel(Map<String, dynamic> data, bool clubFinalizado) {
    return Column(
      children: [
        if (!clubFinalizado) _buildActiveAdminPanel(data),
        if (clubFinalizado) ...[
          _buildReactivateButton(),
          _buildDeleteClubButton(),
        ],
      ],
    );
  }

  /// Panel de admin para club activo: código de invitación + botón finalizar.
  Widget _buildActiveAdminPanel(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.morado.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.morado.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // 👇 BLOQUE DEL CÓDIGO COMPLETAMENTE CLICABLE
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: data['code'] ?? ""));
              mostrarSnackBar(context, "¡Código copiado!", AppColors.naranja);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Código de invitación",
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data['code'] ?? "---",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.morado,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                // Icono de copiar (ahora visual, pero también clicable por el GestureDetector padre)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.morado.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.copy,
                    size: 18,
                    color: AppColors.morado,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 👇 BOTÓN DE FINALIZAR
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _confirmarFinalizarClub,
              icon: const Icon(Icons.check_circle, size: 18),
              label: const Text(
                "Finalizar Club",
                style: TextStyle(fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.naranja,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón para reactivar un club finalizado.
  Widget _buildReactivateButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      child: ElevatedButton.icon(
        onPressed: _confirmarReactivarClub,
        icon: const Icon(Icons.refresh),
        label: const Text("Activar Club"),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Botón para eliminar un club permanentemente.
  Widget _buildDeleteClubButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 15),
      child: OutlinedButton.icon(
        onPressed: () => _confirmarEliminarClub(context, widget.clubId),
        icon: const Icon(Icons.delete_forever, color: Colors.red),
        label: const Text("Eliminar club", style: TextStyle(color: Colors.red)),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  /// Botón de salida/eliminación al final de la página.
  Widget _buildExitButton(bool esAdmin) {
    return Center(
      child: OutlinedButton.icon(
        onPressed: esAdmin
            ? () => _confirmarEliminarClub(context, widget.clubId)
            : _confirmarSalidaDelClub,
        icon: Icon(
          esAdmin ? Icons.delete_forever : Icons.exit_to_app,
          size: 18,
        ),
        label: Text(esAdmin ? "Eliminar club" : "Salir del club"),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }

  /// Footer para club finalizado: botón para volver a la lista de clubes.
  Widget _buildFooterHistorial() {
    return Center(
      child: ElevatedButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back),
        label: const Text("Volver a mis clubes"),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.morado,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO: SINCRONIZACIÓN Y ACCIONES
  // ─────────────────────────────────────────────────────────────

  /// Al entrar, verifica si el usuario ya completó el libro en su biblioteca.
  ///
  /// Si es así, marca automáticamente `goalReached` en el club para sincronizar estados.
  Future<void> _sincronizarMetaAlEntrar() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    try {
      final clubDoc = await FirebaseFirestore.instance
          .collection('clubs')
          .doc(widget.clubId)
          .get();
      if (!clubDoc.exists || !mounted) {
        return;
      }

      final clubData = clubDoc.data() as Map<String, dynamic>;
      final String? bookId = clubData['bookId'];
      final Map<String, dynamic> members = clubData['club_members'] ?? {};

      if (bookId == null || bookId.isEmpty) {
        return;
      }

      final userBookSnapshot = await FirebaseFirestore.instance
          .collection('user_books')
          .where('userId', isEqualTo: user.uid)
          .where('bookId', isEqualTo: bookId)
          .limit(1)
          .get();

      if (userBookSnapshot.docs.isEmpty) {
        return;
      }

      final userBookData = userBookSnapshot.docs.first.data();
      final double progress = (userBookData['progress'] ?? 0).toDouble();
      final String shelf = userBookData['shelf'] ?? 'Leyendo';

      if (progress >= 100 || shelf == 'Leído') {
        final Map<String, dynamic>? myMemberInfo =
            members[user.uid] as Map<String, dynamic>?;
        final bool goalReached = myMemberInfo?['goalReached'] ?? false;

        if (!goalReached && mounted) {
          await DatabaseService.confirmarLlegadaMeta(widget.clubId, user.uid);
        }
      }
    } catch (e) {
      debugPrint("Error sync: $e");
    }
  }

  /// Muestra diálogo de confirmación y finaliza el club.
  void _confirmarFinalizarClub() {
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Finalizar Club"),
        content: const Text("Esta acción cerrará el club definitivamente."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              await DatabaseService.finalizarClub(widget.clubId);
              if (dialogContext.mounted) {
                mostrarSnackBar(
                  dialogContext,
                  "Club finalizado.",
                  AppColors.naranja,
                );
                Navigator.pop(dialogContext);
              }
              navigator.pop();
            },
            child: const Text("Finalizar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Muestra diálogo de confirmación y reactiva el club.
  void _confirmarReactivarClub() async {
    final bool? confirmar = await mostrarDialogoReactivar(
      context: context,
      titulo: "¿Reactivar Club?",
      contenido:
          "Esto volverá a abrir el club para todos los miembros. La meta actual se mantendrá.",
    );
    if (confirmar == true) {
      await DatabaseService.reactivarClub(widget.clubId);
      if (!mounted) {
        return;
      }
      if (mounted) {
        Navigator.pop(context);
      }
      mostrarSnackBar(
        context,
        "Club reactivado correctamente.",
        AppColors.naranja,
      );
    }
  }

  /// Muestra diálogo de confirmación y elimina el club permanentemente.
  void _confirmarEliminarClub(BuildContext context, String clubId) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Eliminar club permanentemente?",
      contenido:
          "Esta acción NO se puede deshacer. Se eliminará el club, metas, comentarios e historial.",
      textoAccion: "Sí, eliminar todo",
      colorAccion: Colors.red,
    );
    if (confirmar == true) {
      try {
        await DatabaseService.eliminarClub(clubId);
        if (!context.mounted) {
          return;
        }
        mostrarSnackBar(context, "Club eliminado permanentemente", Colors.red);
        Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          mostrarSnackBar(context, "Error al eliminar el club: $e", Colors.red);
        }
      }
    }
  }

  /// Muestra diálogo de confirmación y permite al usuario salir del club.
  void _confirmarSalidaDelClub() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Salir del club"),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Dejarás de ser miembro y perderás tu progreso en este club."),
            SizedBox(height: 12),
            Text(
              "El libro permanecerá en tu biblioteca personal.",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar"),
          ),
          TextButton(
            onPressed: () async {
              try {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  return;
                }
                await DatabaseService.eliminarUsuarioDelClub(
                  widget.clubId,
                  user.uid,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (mounted) {
                  mostrarSnackBar(
                    context,
                    "Has salido del club. El libro sigue en tu biblioteca personal",
                    AppColors.naranja,
                  );
                  Navigator.pop(context);
                }
              } catch (e) {
                if (mounted) {
                  mostrarSnackBar(
                    context,
                    "Error al salir del club: $e",
                    Colors.red,
                  );
                }
              }
            },
            child: const Text(
              "Salir",
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS DE UI (MÉTODOS AUXILIARES)
  // ─────────────────────────────────────────────────────────────

  /// Texto resumen de miembros que abre el diálogo de lista completa.
  Widget _buildMiembrosResumen(
    List<dynamic> fotos,
    bool esAdmin,
    VoidCallback? onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "+${fotos.length} miembros",
            style: TextStyle(
              fontSize: 14,
              color: AppColors.morado,
              decoration: TextDecoration.underline,
            ),
          ),
          Icon(Icons.arrow_drop_down, color: AppColors.morado),
        ],
      ),
    );
  }

  /// Tarjeta de meta actual con gradiente dinámico según estado del usuario.
  ///
  /// Estados visuales:
  /// - 🟢 Verde: `goalReached == true` (meta lograda)
  /// - 🟠 Naranja: `isReading == true` (en progreso)
  /// - 🔴 Rojo: pendiente de empezar
  Widget _buildSeccionMeta(
    String meta,
    String fechaLimite,
    bool esAdmin,
    Map<String, dynamic> clubData,
    String currentUserId,
    bool goalReached,
    bool isReading,
  ) {
    final bool estaTerminado = goalReached;
    final bool estaLeyendo = isReading;
    final Color colorEstado = estaTerminado
        ? Colors.green
        : estaLeyendo
        ? Colors.orange
        : Colors.red;
    final IconData iconoEstado = estaTerminado
        ? Icons.check_circle
        : estaLeyendo
        ? Icons.play_circle
        : Icons.circle_outlined;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: estaTerminado
                  ? [Colors.green.shade50, Colors.green.shade100]
                  : estaLeyendo
                  ? [Colors.orange.shade50, Colors.orange.shade100]
                  : [Colors.red.shade50, Colors.red.shade100],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: colorEstado.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: colorEstado.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(iconoEstado, color: colorEstado, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          "Meta actual",
                          style: TextStyle(
                            color: colorEstado,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (fechaLimite.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize
                              .min, // 👈 Clave: no expandir innecesariamente
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 12,
                              color: colorEstado.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              // 👈 Permite que el texto se encoja si no hay espacio
                              child: Text(
                                fechaLimite,
                                style: TextStyle(
                                  color: colorEstado.withValues(alpha: 0.8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1, // 👈 Una sola línea
                                overflow: TextOverflow
                                    .ellipsis, // 👈 Muestra "..." si no cabe
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    meta,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildBotonEstadoMeta(
                  clubData['id'] ?? "",
                  currentUserId,
                  goalReached,
                  isReading,
                ),
              ],
            ),
          ),
        ),
        if (esAdmin)
          Padding(
            padding: const EdgeInsets.only(top: 15),
            child: Center(
              child: OutlinedButton.icon(
                onPressed: () => _mostrarDialogoNuevaMeta(context, clubData),
                icon: const Icon(Icons.add_circle_outline, size: 18),
                label: const Text("Nueva meta"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.morado,
                  side: BorderSide(
                    color: AppColors.morado.withValues(alpha: 0.3),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Botón de acción de la meta: cambiar estados (empezar, marcar llegada, deshabilitado si ya llegó).
  Widget _buildBotonEstadoMeta(
    String clubId,
    String userId,
    bool goalReached,
    bool isReading,
  ) {
    if (goalReached) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 24),
            SizedBox(width: 10),
            Text(
              "¡META LOGRADA!",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    final Color naranjaBoton = const Color(0xFFFFB800);
    if (isReading) {
      return ElevatedButton(
        onPressed: () async {
          await DatabaseService.confirmarLlegadaMeta(clubId, userId);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: naranjaBoton,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, size: 24),
            SizedBox(width: 10),
            Text(
              "¡HE LLEGADO A LA META!",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    return ElevatedButton(
      onPressed: () async {
        await DatabaseService.marcarMetaComoEmpezada(clubId, userId);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.redAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.play_arrow, size: 24),
          SizedBox(width: 10),
          Text(
            "EMPEZAR A LEER",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Semáforo de progreso grupal: tres filas con chips de nombres.
  ///
  /// Colores:
  /// - 🟢 Verde: `goalReached` (llegaron a la meta)
  /// - 🟠 Naranja: `isReading` (leyendo el tramo actual)
  /// - 🔴 Rojo: inactivos (aún no han empezado)
  Widget _buildSemaforo(
    List<dynamic> confirmados,
    List<dynamic> leyendo,
    List<dynamic> inactivos,
    Map<String, dynamic> clubMembers,
  ) {
    if (confirmados.isEmpty && leyendo.isEmpty && inactivos.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Cómo progresamos", style: AppTextStyles.sectionTitle),
        const SizedBox(height: 15),
        if (confirmados.isNotEmpty) ...[
          _rowSemaforo(
            Icons.check_circle,
            Colors.green,
            confirmados,
            "Llegaron a la meta",
            clubMembers,
          ),
          const SizedBox(height: 10),
        ],
        if (leyendo.isNotEmpty) ...[
          _rowSemaforo(
            Icons.play_circle_filled,
            Colors.orange,
            leyendo,
            "Leyendo el tramo",
            clubMembers,
          ),
          const SizedBox(height: 10),
        ],
        if (inactivos.isNotEmpty) ...[
          _rowSemaforo(
            Icons.warning_amber_rounded,
            Colors.red,
            inactivos,
            "No han leído la nueva meta",
            clubMembers,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  /// Fila individual del semáforo con icono, etiqueta y chips de nombres.
  Widget _rowSemaforo(
    IconData icon,
    Color color,
    List<dynamic> ids,
    String etiqueta,
    Map<String, dynamic> clubMembers,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              etiqueta,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ids.isEmpty
                ? [
                    const Text(
                      "Nadie todavía",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ]
                : ids.map((id) {
                    final String nombre =
                        clubMembers[id.toString()]?['userName'] ?? "Usuario";
                    return _chipNombreUsuario(nombre, color);
                  }).toList(),
          ),
        ),
      ],
    );
  }

  /// Chip visual para nombre de usuario en el semáforo.
  Widget _chipNombreUsuario(String nombre, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        nombre,
        style: TextStyle(
          fontSize: 12,
          color: color.withValues(alpha: 0.9),
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Sección de comentarios activa: muestra últimos 3 comentarios + botón para abrir muro completo.
  /// Sección de comentarios activa: muestra últimos 3 comentarios con scroll interno.
  Widget _buildSeccionComentarios(
    String clubId,
    String? currentGoalId,
    String userNameActual,
    String userPhotoActual,
    String currentUserId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Comentarios y Debate", style: AppTextStyles.sectionTitle),
        const SizedBox(height: 10),
        Container(
          // ✅ Altura aumentada + scroll interno
          height: 200, // 👈 Más espacio para ver 3 comentarios completos
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
              ),
            ],
          ),
          child: Stack(
            children: [
              // ✅ ListView con scroll interno
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .collection('club_goals')
                    .doc(currentGoalId)
                    .collection('comments')
                    .orderBy('createdAt', descending: true)
                    .limit(3)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "Se el primero en comentar esta meta!",
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    // ✅ Scroll habilitado para ver comentarios largos
                    physics:
                        const ScrollPhysics(), // 👈 Cambiado de NeverScrollableScrollPhysics
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      var data = docs[index].data() as Map<String, dynamic>;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundImage: NetworkImage(
                              data['userPhoto'] ?? '',
                            ),
                            backgroundColor: Colors.grey[200],
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['userName'] ?? 'Usuario',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  data['text'] ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 13,
                                    height:
                                        1.3, // 👈 Mejor espaciado entre líneas
                                  ),
                                  // ✅ Eliminado maxLines y overflow → texto completo visible
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: FloatingActionButton.small(
                  onPressed: () => _abrirMuroCompletos(
                    context,
                    clubId,
                    currentGoalId,
                    userName: userNameActual,
                    userPhoto: userPhotoActual,
                    userId: currentUserId,
                  ),
                  backgroundColor: AppColors.morado,
                  elevation: 2,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Center(
          child: OutlinedButton.icon(
            onPressed: () =>
                _mostrarHistorialMetas(context, clubId, currentGoalId),
            icon: const Icon(Icons.history, size: 18),
            label: const Text("Ver Historial de Metas"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.morado,
              side: BorderSide(color: AppColors.morado.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Diálogo modal con lista completa de comentarios y campo para escribir nuevos.
  void _abrirMuroCompletos(
    BuildContext context,
    String clubId,
    String? goalId, {
    bool lecturaSolo = false,
    required String userName,
    required String userPhoto,
    required String userId,
  }) {
    final String idReferencia = (goalId == null || goalId.isEmpty)
        ? "sin_meta"
        : goalId;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    lecturaSolo ? "Resumen del Debate" : "Debate de la Meta",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  flex: 1,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: _buildListaComentariosCompleta(clubId, idReferencia),
                  ),
                ),
                if (!lecturaSolo)
                  _buildInputComentario(
                    clubId,
                    idReferencia,
                    userName,
                    userPhoto,
                    userId,
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    color: Colors.grey[50],
                    child: const Text(
                      "Meta finalizada. Solo lectura.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      lecturaSolo ? "Volver al Historial" : "Cerrar",
                      style: TextStyle(
                        color: AppColors.morado,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Input de texto para enviar comentarios en el muro del club.
  Widget _buildInputComentario(
    String clubId,
    String goalId,
    String userName,
    String userPhoto,
    String userId,
  ) {
    final TextEditingController controller = TextEditingController();
    return Container(
      padding: const EdgeInsets.only(top: 15, left: 15, right: 15, bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "Escribe un comentario...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          CircleAvatar(
            backgroundColor: AppColors.morado,
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () async {
                final String texto = controller.text.trim();
                if (texto.isEmpty) {
                  return;
                }
                try {
                  await DatabaseService.enviarComentario(
                    clubId: clubId,
                    goalId: goalId,
                    texto: texto,
                    userId: userId,
                    userName: userName,
                    userPhoto: userPhoto,
                  );
                  controller.clear();
                  if (mounted) {
                    FocusScopeNode currentFocus = FocusScope.of(context);
                    if (!currentFocus.hasPrimaryFocus &&
                        currentFocus.focusedChild != null) {
                      currentFocus.focusedChild!.unfocus();
                    }
                  }
                } catch (e) {
                  debugPrint("Error enviando comentario: $e");
                  if (mounted) {
                    mostrarSnackBar(
                      context,
                      "Error al enviar comentario.",
                      Colors.red,
                    );
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Lista completa de comentarios para el muro del club.
  Widget _buildListaComentariosCompleta(String clubId, String goalId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .doc(clubId)
          .collection('club_goals')
          .doc(goalId)
          .collection('comments')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text("No hay comentarios aún."));
        }
        return ListView.builder(
          shrinkWrap: false,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final bool esMio =
                data['userId'] == FirebaseAuth.instance.currentUser?.uid;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: esMio
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!esMio)
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(data['userPhoto'] ?? ''),
                    ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: esMio
                            ? AppColors.morado.withValues(alpha: 0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(15),
                          topRight: const Radius.circular(15),
                          bottomLeft: Radius.circular(esMio ? 15 : 0),
                          bottomRight: Radius.circular(esMio ? 0 : 15),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!esMio)
                            Text(
                              data['userName'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          Text(
                            data['text'] ?? '',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Diálogo para ver historial de metas pasadas y sus debates (solo lectura).
  void _mostrarHistorialMetas(
    BuildContext context,
    String clubId,
    String? currentGoalId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 40,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    top: 25,
                    bottom: 10,
                    left: 20,
                    right: 20,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: AppColors.morado),
                      const SizedBox(width: 10),
                      const Text(
                        "Metas Anteriores",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                Flexible(
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('clubs')
                          .doc(clubId)
                          .collection('club_goals')
                          .orderBy('createdAt', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        final metas = snapshot.data!.docs
                            .where((doc) => doc.id != currentGoalId)
                            .toList();
                        if (metas.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Text(
                                "No hay metas anteriores finalizadas.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          );
                        }
                        return ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          itemCount: metas.length,
                          itemBuilder: (context, index) {
                            final m =
                                metas[index].data() as Map<String, dynamic>;
                            return ListTile(
                              leading: const Icon(
                                Icons.check_circle,
                                color: Colors.green,
                              ),
                              title: Text(m['goalName'] ?? "Sin nombre"),
                              subtitle: const Text("Toca para ver el debate"),
                              onTap: () {
                                _abrirMuroCompletos(
                                  context,
                                  clubId,
                                  metas[index].id,
                                  lecturaSolo: true,
                                  userName: "",
                                  userPhoto: "",
                                  userId: "",
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "Cerrar",
                    style: TextStyle(
                      color: AppColors.morado,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Diálogo para que el admin cree una nueva meta (nombre y fecha límite).
  void _mostrarDialogoNuevaMeta(
    BuildContext context,
    Map<String, dynamic> clubData,
  ) {
    final TextEditingController metaController = TextEditingController();
    DateTime? fechaSeleccionada;
    final String clubId = clubData['id'] ?? "";
    final List<String> miembrosIds = List<String>.from(
      clubData['members'] ?? [],
    );
    final int totalPaginas = clubData['totalPaginas'] ?? 0;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(25),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Definir Nueva Meta",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppColors.morado,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "El libro tiene $totalPaginas páginas.",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 25),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: TextField(
                          controller: metaController,
                          cursorColor: AppColors.morado,
                          decoration: InputDecoration(
                            icon: const Icon(
                              Icons.flag_circle_outlined,
                              color: Colors.orange,
                            ),
                            hintText: "Ej: Página 150 o Capítulo 10",
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now().add(
                              const Duration(days: 7),
                            ),
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: AppColors.morado,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.black,
                                  ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.morado,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null) {
                            setState(() => fechaSeleccionada = picked);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_month,
                                color: Colors.orange,
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  fechaSeleccionada == null
                                      ? "Fecha límite"
                                      : "${fechaSeleccionada!.day}/${fechaSeleccionada!.month}/${fechaSeleccionada!.year}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.morado,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            if (metaController.text.isEmpty ||
                                fechaSeleccionada == null) {
                              return;
                            }
                            try {
                              await DatabaseService.actualizarMetaClub(
                                clubId: clubId,
                                nombreMeta: metaController.text,
                                fecha: fechaSeleccionada!,
                                todosLosUids: miembrosIds,
                              );
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (!context.mounted) {
                                return;
                              }
                              mostrarSnackBar(
                                context,
                                "Error al guardar",
                                Colors.red,
                              );
                            }
                          },
                          child: const Text(
                            "Publicar Meta",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            "Cancelar",
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Banner mostrado cuando el club está finalizado.
  Widget _buildBannerFinalizado(Map<String, dynamic> data, String libro) {
    String fechaFin = "Fecha desconocida";
    if (data['endDate'] != null) {
      final DateTime fecha = (data['endDate'] as Timestamp).toDate();
      const List<String> meses = [
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
      fechaFin = "${fecha.day} ${meses[fecha.month]} ${fecha.year}";
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700, size: 40),
          const SizedBox(height: 10),
          Text(
            "Club Finalizado",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            "Finalizado: $fechaFin",
            style: TextStyle(color: Colors.grey[700]),
          ),
          Text(
            "Leyendo: $libro",
            style: TextStyle(
              color: Colors.grey[700],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  /// Lista detallada de progreso individual para clubs finalizados.
  ///
  /// Ordenada por progreso descendente. Incluye frases aleatorias para gamificar.
  Widget _buildListaProgresoFinal(Map<String, dynamic> clubMembers) {
    final List<MapEntry<String, dynamic>> miembrosList = clubMembers.entries
        .toList();
    miembrosList.sort((a, b) {
      final double progA = (a.value['progress'] ?? 0).toDouble();
      final double progB = (b.value['progress'] ?? 0).toDouble();
      return progB.compareTo(progA);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Resumen final de lectura",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 15),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: miembrosList.map((entry) {
              final Map<String, dynamic> info = entry.value;
              final String nombre = info['userName'] ?? "Usuario";
              final double progreso = (info['progress'] ?? 0).toDouble().clamp(
                0.0,
                100.0,
              );
              final bool esAdmin = info['role'] == 'admin';
              final IconData iconoEstado;
              final Color colorEstado;
              final String textoPorcentaje;
              final String textoAnimado;
              if (progreso >= 100) {
                iconoEstado = Icons.check_circle;
                colorEstado = Colors.green;
                textoPorcentaje = "100%";
                textoAnimado = _obtenerFraseFinalizada();
              } else if (progreso > 0) {
                iconoEstado = Icons.play_circle;
                colorEstado = Colors.orange;
                textoPorcentaje = "${progreso.toInt()}%";
                textoAnimado = _obtenerFraseEnProgreso(progreso);
              } else {
                iconoEstado = Icons.circle_outlined;
                colorEstado = Colors.red;
                textoPorcentaje = "0%";
                textoAnimado = _obtenerFrasePendiente();
              }
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(iconoEstado, color: colorEstado, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (esAdmin) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.star,
                                  color: Color(0xFFFFB800),
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            textoAnimado,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorEstado,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      textoPorcentaje,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: colorEstado,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FRASES ALEATORIAS PARA GAMIFICACIÓN
  // ─────────────────────────────────────────────────────────────

  /// Frase aleatoria para usuarios que completaron el libro.
  String _obtenerFraseFinalizada() {
    const List<String> frases = [
      "Libro devorado!",
      "Meta personal cumplida",
      "Lectura completada!",
      "Misión libro acabada!",
    ];
    return frases[DateTime.now().millisecond % frases.length];
  }

  /// Frase aleatoria según el progreso actual del usuario.
  String _obtenerFraseEnProgreso(double progreso) {
    if (progreso >= 75) {
      return "Ya casi lo tienes!";
    }
    if (progreso >= 50) {
      return "A mitad de camino!";
    }
    if (progreso >= 25) {
      return "Avanzando poco a poco";
    }
    return "Leyendo... ¡tú puedes!";
  }

  /// Frase aleatoria para usuarios que aún no han empezado.
  String _obtenerFrasePendiente() {
    const List<String> frases = [
      "Por empezar...",
      "Pendiente de lectura",
      "Sin empezar aún",
      "Esperando su turno",
    ];
    return frases[DateTime.now().millisecond % frases.length];
  }

  /// Versión archivada de la sección de comentarios (solo lectura).
  Widget _buildSeccionComentariosArchivado(
    String clubId,
    String currentGoalId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Comentarios y Debate",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(Icons.archive, size: 40, color: Colors.grey),
              const SizedBox(height: 12),
              Text(
                "Debate archivado",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Este club ya está cerrado pero puedes revivir los comentarios anteriores",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: () =>
                _mostrarHistorialMetas(context, clubId, currentGoalId),
            icon: const Icon(Icons.history, size: 18),
            label: const Text("Ver Historial de Comentarios"),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.morado,
              side: BorderSide(color: AppColors.morado.withValues(alpha: 0.3)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIÁLOGOS Y GESTIÓN DE MIEMBROS
  // ─────────────────────────────────────────────────────────────

  /// Diálogo para cambiar la imagen del club (solo admin).
  void _mostrarDialogoCambiarImagenClub(BuildContext context, String clubId) {
    final TextEditingController urlController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cambiar imagen del club"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Pega la nueva URL de la imagen personalizada:"),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: InputDecoration(
                hintText: "https://...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 10),
            const Text(
              "Nota: Esta imagen se verá en la lista de clubs, no aquí.",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () async {
              final String newUrl = urlController.text.trim();
              try {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .update({'clubImageUrl': newUrl});
                if (context.mounted) {
                  Navigator.pop(context);
                  mostrarSnackBar(
                    context,
                    "Imagen del club actualizada.",
                    AppColors.naranja,
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  mostrarSnackBar(context, "Error: $e", Colors.red);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.morado),
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Diálogo con lista completa de miembros del club.
  void _mostrarListaMiembros(
    BuildContext context,
    Map<String, dynamic> clubMembers,
    String currentUserId,
    bool esAdmin,
    String clubId,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 500),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Miembros del Club",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Cerrar",
                        style: TextStyle(
                          color: AppColors.morado,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: clubMembers.entries.map((entry) {
                      final String uid = entry.key;
                      final Map<String, dynamic> info =
                          entry.value as Map<String, dynamic>;
                      final String nombre = info['userName'] ?? "Usuario";
                      final String foto = info['userPhoto'] ?? "";
                      final String role = info['role'] ?? "miembro";
                      final Map<String, dynamic> stats =
                          info['statsSnapshot'] ?? {};
                      final bool soyYo = uid == currentUserId;
                      final bool esAdminMember = role == 'admin';
                      final String gossip = _generarFraseGossip(stats);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 15),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 25,
                              backgroundColor: Colors.grey[200],
                              backgroundImage:
                                  (foto.isNotEmpty && foto.startsWith('http'))
                                  ? NetworkImage(foto)
                                  : null,
                              child: (foto.isEmpty || !foto.startsWith('http'))
                                  ? Icon(Icons.person, color: Colors.grey[400])
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        nombre + (soyYo ? " (Tu)" : ""),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (esAdminMember) ...[
                                        const SizedBox(width: 5),
                                        const Icon(
                                          Icons.star,
                                          color: Color(0xFFFFB800),
                                          size: 14,
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    gossip,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF757575),
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (esAdmin && !soyYo)
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  _confirmarExpulsion(
                                    context,
                                    clubId,
                                    uid,
                                    nombre,
                                  );
                                },
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Diálogo de confirmación para expulsar a un miembro del club.
  void _confirmarExpulsion(
    BuildContext parentContext,
    String clubId,
    String uid,
    String nombre,
  ) {
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text("Expulsar miembro"),
          content: Text("Se eliminará a $nombre del club."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancelar"),
            ),
            TextButton(
              onPressed: () async {
                final safeDialogCtx = dialogContext;
                final safeParentCtx = parentContext;
                await DatabaseService.eliminarUsuarioDelClub(clubId, uid);
                if (!safeDialogCtx.mounted) {
                  return;
                }
                Navigator.pop(safeDialogCtx);
                if (!safeParentCtx.mounted) {
                  return;
                }
                mostrarSnackBar(
                  safeParentCtx,
                  "$nombre ha sido expulsado",
                  Colors.red,
                );
              },
              child: const Text(
                "Expulsar",
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Genera una frase basada en las estadísticas de lectura del miembro.
  String _generarFraseGossip(Map<String, dynamic> stats) {
    final int leidos = stats['booksRead'] ?? 0;
    final int leyendo = stats['currentlyReading'] ?? 0;
    final List<String> frases = [];
    if (leidos > 50) {
      frases.add("Es un devorador de libros!");
    } else if (leidos > 20) {
      frases.add(" Lector experimentado.");
    } else if (leidos > 5) {
      frases.add(" Le gustaba leer.");
    } else {
      frases.add("Nuevo en el mundo lector.");
    }
    if (leyendo > 3) {
      frases.add(" Lee varios a la vez!");
    } else if (leyendo > 1) {
      frases.add(" Tiene varios entre manos.");
    }
    return frases.join(" ");
  }

  /// Diálogo inicial obligatorio cuando el usuario no ha seleccionado formato.
  ///
  /// Se muestra una sola vez al entrar al detalle del club si `format` está vacío.
  void _mostrarDialogoSeleccionarFormato(String userBookId, int totalPaginas) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text("¿Cómo vas a leer este libro?"),
        content: const Text(
          "Selecciona el formato para personalizar tu seguimiento de progreso en el club:",
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('user_books')
                  .doc(userBookId)
                  .update({'format': 'Digital'});
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (mounted) {
                setState(() => _mostrandoDialogoFormato = false);
              }
            },
            child: const Text("Digital 📱"),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('user_books')
                  .doc(userBookId)
                  .update({
                    'format': 'Papel',
                    'totalPages': totalPaginas > 0 ? totalPaginas : 0,
                  });
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
              if (mounted) {
                setState(() => _mostrandoDialogoFormato = false);
              }
            },
            child: const Text("Papel 📖"),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS DE UTILIDAD
  // ─────────────────────────────────────────────────────────────

  /// Convierte `Timestamp` o `DateTime` a string formato corto: `dd/mm/aaaa`.
  String formatearFechaCorta(dynamic timestamp) {
    if (timestamp == null) {
      return '';
    }
    final DateTime date = (timestamp is Timestamp)
        ? timestamp.toDate()
        : timestamp;
    return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
  }
}
