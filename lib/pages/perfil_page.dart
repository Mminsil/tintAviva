import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Página de perfil del usuario.
///
/// Muestra:
/// 1. Datos personales y avatar.
/// 2. Estadísticas globales (desde el documento 'users').
/// 3. Estadísticas temporales (calculadas al vuelo desde 'user_books').
/// 4. Acciones de cuenta (Logout / Delete).
class PerfilPage extends StatelessWidget {
  const PerfilPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final stats =
              userData?['stats'] ?? {'read': 0, 'inProgress': 0, 'toRead': 0};
          final String? photoUrl = userData?['photoURL'];

          // Detectamos si la foto es un asset local o una URL remota.
          bool esAsset = photoUrl != null && photoUrl.contains('assets/');

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 60),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: AppColors.morado.withValues(
                          alpha: 0.1,
                        ),
                        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                            ? (esAsset
                                  ? AssetImage(photoUrl) as ImageProvider
                                  : NetworkImage(photoUrl))
                            : null,

                        // Icono por defecto si no hay foto
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? const Icon(
                                Icons.person,
                                size: 60,
                                color: AppColors.morado,
                              )
                            : null,
                      ),
                      // Botón decorativo de edición (funcionalidad pendiente).
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          backgroundColor: AppColors.naranja,
                          radius: 18,
                          child: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  userData?['name'] ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textoNegroSuave,
                  ),
                ),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),

                // --- ESTADÍSTICAS GLOBALES ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mi Actividad',
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                _buildContenedorActividad(stats),
                const SizedBox(height: 30),

                // --- ESTADÍSTICAS TEMPORALES (Calculadas en cliente) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Este periodo',
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 15),

                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('user_books')
                      .where('userId', isEqualTo: user?.uid)
                      .where('shelf', isEqualTo: 'Leído')
                      .snapshots(),
                  builder: (context, bookSnapshot) {
                    int leidosMes = 0;
                    int leidosAnio = 0;

                    if (bookSnapshot.hasData) {
                      final ahora = DateTime.now();
                      for (var doc in bookSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['dateFinished'] != null) {
                          DateTime fecha = (data['dateFinished'] as Timestamp)
                              .toDate();
                          if (fecha.year == ahora.year) {
                            leidosAnio++;
                            if (fecha.month == ahora.month) leidosMes++;
                          }
                        }
                      }
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _tarjetaEstadisticaDetalle(
                            "Este mes",
                            "$leidosMes",
                            Icons.calendar_month,
                            AppColors.naranja,
                          ),
                          const SizedBox(width: 15),
                          _tarjetaEstadisticaDetalle(
                            "Este año",
                            "$leidosAnio",
                            Icons.auto_awesome,
                            AppColors.morado,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 50),

                // --- ACCIONES DE CUENTA ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _confirmarCerrarSesion(context),
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text("Cerrar Sesión"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.naranja,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: TextButton(
                    onPressed: () => _confirmarEliminarCuenta(context),
                    child: const Text(
                      "Dar de baja mi cuenta",
                      style: TextStyle(
                        color: Colors.red,
                        decoration: TextDecoration.underline,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContenedorActividad(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _columnaStat("Leídos", "${stats['read']}"),
          _divider(),
          _columnaStat("Leyendo", "${stats['inProgress']}"),
          _divider(),
          _columnaStat("Por leer", "${stats['toRead']}"),
        ],
      ),
    );
  }

  Widget _columnaStat(String label, String valor) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.morado,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _divider() => Container(height: 30, width: 1, color: Colors.grey[200]);

  Widget _tarjetaEstadisticaDetalle(
    String titulo,
    String valor,
    IconData icono,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icono, color: color, size: 30),
            const SizedBox(height: 10),
            Text(
              valor,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              titulo,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarCerrarSesion(BuildContext context) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Cerrar sesión?",
      contenido: "¿Estás seguro de que deseas salir de TintAviva?",
      textoAccion: "Salir",
      colorAccion: AppColors.naranja,
    );
    if (confirmar == true) {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  /// Elimina todos los datos del usuario y su cuenta de Firebase.
  void _confirmarEliminarCuenta(BuildContext context) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Eliminar cuenta?",
      contenido:
          "Esta acción es irreversible. Se borrarán todos tus libros, estadísticas y datos personales permanentemente.",
      textoAccion: "Eliminar todo",
      colorAccion: Colors.red,
    );
    if (confirmar != true || !context.mounted) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // 1. Borrar libros personales.
      var books = await FirebaseFirestore.instance
          .collection('user_books')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (var doc in books.docs) {
        await doc.reference.delete();
      }
      // 2. Borrar documento de usuario.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      // 3. Borrar cuenta de Auth.
      await user.delete();

      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      // Error común: requiere re-autenticación reciente para borrar cuenta.
      if (e.code == 'requires-recent-login') {
        mostrarSnackBar(
          context,
          "Vuelve a iniciar sesión para borrar tu cuenta.",
          AppColors.naranja,
        );
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        mostrarSnackBar(context, "Error al eliminar: $e", Colors.red);
      }
    } catch (e) {
      if (!context.mounted) return;
      mostrarSnackBar(context, "Ocurrió un error inesperado: $e", Colors.red);
    }
  }
}
