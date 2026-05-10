import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:tintaviva/pages/detalle_club_page.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/widgets/dialogo_unirse_club.dart';
import 'package:tintaviva/widgets/dialogo_crear_club.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Pantalla principal que muestra los clubes de lectura del usuario autenticado.
/// Diferencia entre clubes activos (grid) y finalizados (lista horizontal).
/// Las acciones de administracion (editar, finalizar, reactivar, eliminar) solo
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: SafeArea(child: _buildBody()),
      floatingActionButton: _buildSpeedDial(),
    );
  }

  /// Construye el cuerpo principal.
  /// Verifica autenticacion primero. Si hay usuario, hace stream de Firestore
  /// filtrando clubs donde 'members' contiene su uid. Separa los documentos en
  /// dos listas: activos (status != 'finalizado') y finalizados (status == 'finalizado').
  /// Usa CustomScrollView para combinar SliverGrid (activos) y SliverList (finalizados).
  Widget _buildBody() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
        child: Text("Por favor, inicia sesión para ver los clubes."),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .where('members', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                "Error de conexión: ${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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

        final allDocs = snapshot.data!.docs;
        final activos = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'finalizado';
        }).toList();
        final finalizados = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'finalizado';
        }).toList();

        return CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Center(
                  child: Text(
                    "Mis Clubes de Lectura",
                    style: AppTextStyles.sectionTitle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.65,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final clubData =
                      activos[index].data() as Map<String, dynamic>;
                  final String idDoc = activos[index].id;
                  final bool esAdmin = clubData['ownerId'] == user.uid;
                  return _tarjetaClub(context, clubData, idDoc, esAdmin);
                }, childCount: activos.length),
              ),
            ),
            if (finalizados.isNotEmpty) ...[
              const SliverToBoxAdapter(
                child: Divider(height: 40, indent: 20, endIndent: 20),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 15),
                  child: Text(
                    "Clubes Finalizados",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 240,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    itemCount: finalizados.length,
                    itemBuilder: (context, index) {
                      final clubDoc = finalizados[index];
                      final clubData = clubDoc.data() as Map<String, dynamic>;
                      return _tarjetaClubFinalizado(
                        context,
                        clubData,
                        clubDoc.id,
                      );
                    },
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  /// Boton flotante con dos acciones: 'Unirse' (abre DialogoUnirseClub) y
  /// 'Crear club' (abre DialogoCrearClub). Usa flutter_speed_dial.
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
            await showDialog(
              context: context,
              builder: (context) => const DialogoUnirseClub(),
            );
          },
        ),
        SpeedDialChild(
          child: const Icon(Icons.edit),
          label: 'Crear club',
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => const DialogoCrearClub(),
            );
          },
        ),
      ],
    );
  }

  /// Tarjeta para club activo.
  /// Muestra imagen (clubImageUrl o bookCover como fallback), nombre, contador de miembros.
  /// Si esAdmin es true, muestra PopupMenuButton con opciones: editar, finalizar, eliminar.
  /// Al tocar la tarjeta navega a DetalleClubPage con el clubId.
  Widget _tarjetaClub(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
    bool esAdmin,
  ) {
    final String imageUrl = data['clubImageUrl'] ?? data['bookCover'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetalleClubPage(clubId: id)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),
                if (esAdmin)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.transparent,
                      child: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_vert,
                          color: Colors.white,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 4),
                          ],
                        ),
                        tooltip: 'Opciones de admin',
                        onSelected: (value) {
                          if (value == 'edit_club') {
                            _mostrarDialogoEditarClub(context, id, data);
                          } else if (value == 'finish_club') {
                            _confirmarFinalizarClub(context, id);
                          } else if (value == 'delete_club') {
                            _confirmarEliminarClub(context, id);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit_club',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Editar club'),
                              ],
                            ),
                          ),
                          if (data['status'] != 'finalizado')
                            const PopupMenuItem(
                              value: 'finish_club',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    size: 20,
                                    color: AppColors.naranja,
                                  ),
                                  SizedBox(width: 8),
                                  Text('Finalizar club'),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'delete_club',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Eliminar club',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data['name'] ?? 'Sin nombre',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          Text(
            "${(data['members'] as List? ?? []).length}/${data['maxMembers'] ?? 7} miembros",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Tarjeta para club finalizado. Similar a la activa pero formato mas pequeno
  /// para lista horizontal. Prioriza bookCover sobre clubImageUrl.
  /// Si es admin, las opciones del menu son: editar, reactivar, eliminar.
  Widget _tarjetaClubFinalizado(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool esAdmin = data['ownerId'] == currentUserId;
    final String imageUrl = data['bookCover'] ?? data['clubImageUrl'] ?? '';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DetalleClubPage(clubId: id)),
      ),
      child: Container(
        width: 130,
        height: 180,
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  AppBookCover(
                    imageUrl: imageUrl,
                    width: 130,
                    height: 180,
                    borderRadius: 12.0,
                  ),
                  if (esAdmin)
                    Positioned(
                      top: 5,
                      right: 5,
                      child: Material(
                        color: Colors.transparent,
                        child: PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.white,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                          onSelected: (value) {
                            if (value == 'edit_club') {
                              _mostrarDialogoEditarClub(context, id, data);
                            } else if (value == 'reactivate_club') {
                              _confirmarReactivarClub(context, id);
                            } else if (value == 'delete_club') {
                              _confirmarEliminarClub(context, id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit_club',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20),
                                  SizedBox(width: 8),
                                  Text('Editar'),
                                ],
                              ),
                            ), 
                            
                            // Solo muestra "Reactivar" si el club SÍ está finalizado
                            if (data['status'] == 'finalizado')
                              const PopupMenuItem(
                                value: 'reactivate_club',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.refresh,
                                      size: 20,
                                      color: AppColors.morado,
                                    ),
                                    SizedBox(width: 8),
                                    Text('Reactivar club'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete_club',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Eliminar',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              data['name'] ?? 'Sin nombre',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            if (data['description'] != null &&
                data['description'].toString().isNotEmpty)
              Text(
                data['description'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
          ],
        ),
      ),
    );
  }

  /// Muestra dialogo de confirmacion y llama a DatabaseService.eliminarClub.
  /// La eliminacion es permanente. Verifica context.mounted antes de mostrar
  /// feedback para evitar errores si el widget se desmonta.
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
        if (!context.mounted) return;
        mostrarSnackBar(
          context,
          "Club se eliminó permanentemente.",
          Colors.red,
        );
      } catch (e) {
        if (!context.mounted) return;
        mostrarSnackBar(context, "Error al eliminar club: $e", Colors.red);
      }
    }
  }

  /// Cambia el status del club a 'finalizado'.
  /// Además procesa los libros de la meta actual y los asigna a la biblioteca
  /// personal de cada miembro segun su progreso.
  void _confirmarFinalizarClub(BuildContext context, String clubId) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Finalizar club?",
      contenido:
          "Al finalizar el club, se cerrará la meta actual y los libros pasarán a la biblioteca personal de los miembros según su progreso.",
      textoAccion: "Sí, finalizar",
      colorAccion: AppColors.naranja,
    );

    if (confirmar == true) {
      try {
        await DatabaseService.finalizarClub(clubId);
        // La lógica de pasar libros a biblioteca personal está en DatabaseService
        if (!context.mounted) return;
        mostrarSnackBar(
          context,
          "Club finalizado correctamente",
          AppColors.naranja,
        );
      } catch (e) {
        if (!context.mounted) return;
        mostrarSnackBar(context, "Error al finalizar club: $e", Colors.red);
      }
    }
  }

  /// Cambia el status del club de 'finalizado' a 'activo'.
  /// Restablece la meta actual para que los miembros puedan seguir leyendo.
  void _confirmarReactivarClub(BuildContext context, String clubId) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Reactivar club?",
      contenido:
          "Esto volverá a abrir el club para todos los miembros. La meta actual se restablecerá.",
      textoAccion: "Sí, reactivar",
      colorAccion: AppColors.morado,
    );

    if (confirmar == true) {
      try {
        await DatabaseService.reactivarClub(clubId);
        if (!context.mounted) return;
        mostrarSnackBar(
          context,
          "Club reactivado correctamente",
          AppColors.morado,
        );
      } catch (e) {
        if (!context.mounted) return;
        mostrarSnackBar(context, "Error al reactivar club: $e", Colors.red);
      }
    }
  }

  /// Placeholder visual cuando falla la carga de una imagen.
  /// Muestra assets/imagen_app.jpg sobre fondo morado con opacidad 0.1.
  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.morado.withValues(alpha: 0.1),
      child: Image.asset(
        'assets/imagen_app.jpg',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  /// Dialogo para editar nombre y descripcion de un club.
  /// Pre-carga los valores actuales en los TextEditingController.
  /// Al guardar, actualiza directamente en Firestore los campos 'name' y 'description'.
  void _mostrarDialogoEditarClub(
    BuildContext context,
    String clubId,
    Map<String, dynamic> currentData,
  ) {
    final TextEditingController nameController = TextEditingController(
      text: currentData['name'] ?? '',
    );
    final TextEditingController descController = TextEditingController(
      text: currentData['description'] ?? '',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Editar Club", style: AppTextStyles.dialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: AppInputStyles.inputDecoration(""),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descController,
              decoration: AppInputStyles.inputDecoration("Descripción"),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: AppButtonStyles.primaryElevatedButton,
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              try {
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .update({
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                    });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  mostrarSnackBar(
                    context,
                    "Club actualizado",
                    AppColors.naranja,
                  );
                }
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  mostrarSnackBar(
                    context,
                    "Error al actualizar club: $e",
                    Colors.red,
                  );
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
