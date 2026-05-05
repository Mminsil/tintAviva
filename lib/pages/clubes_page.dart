import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:tintaviva/pages/detalle_club_page.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/utils/ui_helpers.dart'; // Para mostrarDialogoConfirmacion
import 'package:tintaviva/widgets/dialogo_unirse_club.dart';
import 'package:tintaviva/widgets/dialogo_crear_club.dart';
import 'package:tintaviva/theme/app_styles.dart'; // Importamos los estilos globales

/// Pantalla principal que muestra los clubes de lectura a los que pertenece el usuario.
///
/// Esta página gestiona:
/// 1. La visualización de clubes activos (en formato grid).
/// 2. La visualización de clubes finalizados (en lista horizontal).
/// 3. Las acciones de administración (crear, unirse, editar, finalizar, reactivar, eliminar) según el rol del usuario.
class ClubesPage extends StatefulWidget {
  const ClubesPage({super.key});

  @override
  State<ClubesPage> createState() => _ClubesPageState();
}

class _ClubesPageState extends State<ClubesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro, // Fondo consistente con el tema
      body: SafeArea(child: _buildBody()),
      floatingActionButton: _buildSpeedDial(),
    );
  }

  /// Construye el cuerpo principal de la pantalla.
  ///
  /// Lógica de flujo:
  /// 1. Verifica si hay un usuario autenticado.
  /// 2. Si no hay usuario, muestra mensaje de error.
  /// 3. Si hay usuario, escucha en tiempo real los cambios en la colección 'clubs' de Firestore.
  Widget _buildBody() {
    final user = FirebaseAuth.instance.currentUser;

    // Protección básica: si no hay sesión iniciada, no intentamos cargar datos.
    if (user == null) {
      return const Center(
        child: Text("Por favor, inicia sesión para ver los clubes."),
      );
    }

    // StreamBuilder: Se reconstruye automáticamente cuando cambian los datos en Firebase.
    // Filtramos directamente en la consulta para traer solo los clubes donde el usuario es miembro.
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs')
          .where('members', arrayContains: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        // 1. Manejo de errores de conexión o permisos.
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

        // 2. Estado de carga mientras Firebase recupera los datos.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 3. Estado vacío: El usuario está logueado pero no pertenece a ningún club.
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

        // Procesamiento de datos: Separamos los clubes en 'activos' y 'finalizados'.
        // Esto nos permite mostrarlos en secciones diferentes de la UI.
        final allDocs = snapshot.data!.docs;

        // Filtramos clubes cuyo estado NO sea 'finalizado'.
        final activos = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] != 'finalizado';
        }).toList();

        // Filtramos clubes cuyo estado SÍ sea 'finalizado'.
        final finalizados = allDocs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'finalizado';
        }).toList();

        // CustomScrollView permite combinar diferentes tipos de listas (Grid y List) en un solo scroll.
        return CustomScrollView(
          physics:
              const BouncingScrollPhysics(), // Efecto de rebote iOS/Android moderno
          slivers: [
            // Título principal de la sección
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  "Mis Clubes de Lectura",
                  style: AppTextStyles.sectionTitle, // Usamos estilo global
                ),
              ),
            ),

            // SECCIÓN 1: GRID DE CLUBES ACTIVOS
            // Usamos SliverGrid para mostrar las tarjetas en 2 columnas.
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // 2 tarjetas por fila
                  crossAxisSpacing: 15, // Espacio horizontal entre tarjetas
                  mainAxisSpacing: 20, // Espacio vertical entre tarjetas
                  childAspectRatio:
                      0.65, // Relación ancho/alto para que las tarjetas sean altas
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final clubData =
                      activos[index].data() as Map<String, dynamic>;
                  final String idDoc = activos[index].id;
                  // Determinamos si el usuario actual es el administrador (owner) para mostrar opciones extra.
                  final bool esAdmin = clubData['ownerId'] == user.uid;
                  return _tarjetaClub(context, clubData, idDoc, esAdmin);
                }, childCount: activos.length),
              ),
            ),

            // SECCIÓN 2: CLUBES FINALIZADOS (Solo si existen)
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
              // Lista horizontal para los clubes antiguos.
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 240, // Altura fija para la lista horizontal
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

            // Espacio extra al final para que el FAB no tape el último elemento.
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        );
      },
    );
  }

  /// Construye el botón de acción flotante doble (SpeedDial).
  ///
  /// Permite dos acciones rápidas:
  /// 1. Unirse a un club existente.
  /// 2. Crear un nuevo club.
  Widget? _buildSpeedDial() {
    return SpeedDial(
      icon: Icons.add,
      activeIcon: Icons.close,
      backgroundColor: AppColors.morado, // Color global
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
            // Abre el diálogo modal para introducir código de invitación.
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
            // Abre el diálogo modal para configurar un nuevo club.
            showDialog(
              context: context,
              builder: (context) => const DialogoCrearClub(),
            );
          },
        ),
      ],
    );
  }

  /// Widget que representa una tarjeta de club activo.
  ///
  /// Muestra imagen, nombre, contador de miembros y menú de administración si el usuario es owner.
  Widget _tarjetaClub(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
    bool esAdmin,
  ) {
    // Prioridad de imagen: primero la específica del club, si no, la portada del libro actual.
    final String imageUrl = data['clubImageUrl'] ?? data['bookCover'] ?? '';

    return GestureDetector(
      // Al tocar la tarjeta, navegamos a la página de detalles del club.
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
                // Contenedor de la imagen con bordes redondeados y sombra.
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
                            // Si la imagen falla al cargar, mostramos un placeholder.
                            errorBuilder: (context, error, stackTrace) =>
                                _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                ),

                // Menú de administración (solo visible para el creador del club).
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
                          // Routing interno del menú: decide qué función llamar según la opción elegida.
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
                          // La opción de finalizar solo aparece si el club aún no está finalizado.
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
          // Nombre del club (truncateado si es muy largo).
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
          // Contador de miembros (ej: 3/7 miembros).
          Text(
            "${(data['members'] as List? ?? []).length}/${data['maxMembers'] ?? 7} miembros",
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Widget que representa una tarjeta de club finalizado (más pequeña, lista horizontal).
  Widget _tarjetaClubFinalizado(
    BuildContext context,
    Map<String, dynamic> data,
    String id,
  ) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool esAdmin = data['ownerId'] == currentUserId;
    // En clubes finalizados, priorizamos la portada del libro sobre la imagen del club.
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
                  // Menú de admin también disponible en clubes finalizados.
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
                            // Routing interno para clubes finalizados.
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
                            // La opción de reactivar solo aparece si el club está finalizado.
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
            // Descripción breve solo en clubes finalizados para dar contexto histórico.
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

  /// Muestra un diálogo de confirmación antes de eliminar un club.
  ///
  /// Si el usuario confirma, llama al servicio de base de datos y muestra feedback.
  void _confirmarEliminarClub(BuildContext context, String clubId) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Eliminar club permanentemente?",
      contenido:
          "Esta acción NO se puede deshacer. Se eliminará el club, metas, comentarios e historial.",
      textoAccion: "Sí, eliminar todo",
      colorAccion: Colors.red,
    );

    // Solo procedemos si el usuario pulsó "Sí".
    if (confirmar == true) {
      try {
        // 1. Eliminamos el club en Firebase (esto debería cascada borrar subcolecciones si está configurado así en Backend).
        await DatabaseService.eliminarClub(clubId);

        // 2. Verificamos que el widget siga montado en el árbol antes de actualizar la UI.
        // Esto evita errores si el usuario salió de la pantalla mientras se eliminaba.
        if (!context.mounted) return;

        // 3. Mostramos feedback visual de éxito.
        mostrarSnackBar(
          context,
          "Club se eliminó permanentemente.",
          Colors.red,
        );
      } catch (e) {
        // Manejo de errores si la eliminación falla (ej: problemas de red).
        if (!context.mounted) return;

        mostrarSnackBar(context, "Error al eliminar club: $e", Colors.red);
      }
    }
  }

  /// Confirma y finaliza un club activo.
  ///
  /// Cambia el estado del club a 'finalizado' y procesa los libros en las bibliotecas personales.
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
        // Llamada al servicio que gestiona la lógica de finalización en Firebase.
        await DatabaseService.finalizarClub(clubId);
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

  /// Confirma y reactiva un club finalizado.
  ///
  /// Vuelve a poner el club en estado activo y restablece la meta actual.
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
        // Llamada al servicio que cambia el estado a 'activo' en Firebase.
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

  /// Widget placeholder que se muestra cuando no hay imagen de club o libro.
  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: AppColors.morado.withValues(alpha: 0.1), // Usamos color global
      child: Image.asset(
        'assets/imagen_app.jpg', // Imagen por defecto
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }

  /// Muestra un diálogo modal para editar el nombre y descripción del club.
  void _mostrarDialogoEditarClub(
    BuildContext context,
    String clubId,
    Map<String, dynamic> currentData,
  ) {
    // Inicializamos los controladores con los valores actuales del club.
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
          mainAxisSize: MainAxisSize.min, // Ajusta el alto al contenido
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
              // Validación básica: no permitir nombres vacíos.
              if (nameController.text.trim().isEmpty) return;
              try {
                // Actualizamos solo los campos modificados en Firestore.
                await FirebaseFirestore.instance
                    .collection('clubs')
                    .doc(clubId)
                    .update({
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                    });

                // Cerramos el diálogo y mostramos confirmación.
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (context.mounted) {
                  mostrarSnackBar(
                    context,
                    "Club actualizado",
                    AppColors.naranja,
                  );
                }
              } catch (e) {
                // En caso de error, cerramos diálogo y mostramos error.
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
