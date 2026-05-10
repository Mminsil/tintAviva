import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:tintaviva/utils/streak_helper.dart';

/// Página de perfil del usuario.
///
/// Muestra:
/// 1. Datos personales y avatar del usuario.
/// 2. Racha de lectura actual (gamificación).
/// 3. Estadísticas globales de estanterías (Leídos, Leyendo, Por leer).
/// 4. Estadísticas temporales (libros leídos este mes/año).
/// 5. Acciones de cuenta (Cerrar sesión / Eliminar cuenta).
///
/// Característica técnica: Usa AutomaticKeepAliveClientMixin para preservar
/// el estado de esta página cuando el usuario navega entre pestañas en HomePage.
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage>
    with AutomaticKeepAliveClientMixin {
  /// Indica a Flutter que debe preservar el estado de este widget cuando se oculta.
  /// Esto evita que la página se reconstruya cada vez que el usuario cambia de pestaña,
  /// manteniendo así la racha de lectura y los datos cargados en memoria.
  @override
  bool get wantKeepAlive => true;

  // Variables de estado para la racha de lectura.
  int _streak = 0;
  bool _isLoadingStreak = true;

  @override
  void initState() {
    super.initState();
    // Cargamos la racha de lectura al iniciar la página.
    _loadStreak();
  }

  /// Carga la racha de lectura actual desde StreakHelper y actualiza la UI.
  Future<void> _loadStreak() async {
    final streak = await StreakHelper.getCurrentStreak();
    // Verificamos que el widget siga montado antes de actualizar el estado.
    if (mounted) {
      setState(() {
        _streak = streak;
        _isLoadingStreak = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Llamada obligatoria cuando se usa AutomaticKeepAliveClientMixin.
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      // Stream principal: Escucha cambios en los datos del usuario en Firestore.
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

                // --- AVATAR DEL USUARIO ---
                Center(
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.morado.withValues(alpha: 0.1),
                    // Lógica condicional para cargar imagen local o de red.
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? (esAsset
                              ? AssetImage(photoUrl) as ImageProvider
                              : NetworkImage(photoUrl))
                        : null,
                    // Icono por defecto si no hay foto.
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: AppColors.morado,
                          )
                        : null,
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

                // --- RACHA DE LECTURA (Gamificación) ---
                Card(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    child: _isLoadingStreak
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              // Icono dinámico: naranja si hay racha, gris si no.
                              Icon(
                                Icons.emoji_events,
                                color: _streak > 0
                                    ? Colors.orange
                                    : Colors.grey[400],
                                size: 60,
                              ),
                              const SizedBox(height: 10),
                              // Número de días consecutivos leído.
                              Text(
                                _streak.toString(),
                                style: TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.morado,
                                ),
                              ),
                              const SizedBox(height: 5),
                              // Mensaje motivacional dinámico según la longitud de la racha.
                              Text(
                                StreakHelper.getStreakMessage(_streak),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 30),

                // --- MIS ESTANTERÍAS (Estadísticas globales) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Mis Estanterías',
                      style: AppTextStyles.sectionTitle,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                _buildContenedorActividad(stats),
                const SizedBox(height: 30),

                // --- ESTADÍSTICAS TEMPORALES (Cálculo en cliente) ---
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

                // Stream secundario: Calcula libros leídos por mes/año filtrando por fecha.
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
                      // Iteramos sobre los documentos para filtrar por fecha manualmente.
                      // Nota: Para grandes volúmenes de datos, esto podría optimizarse con consultas compuestas.
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

  // --- WIDGETS AUXILIARES DE UI ---

  /// Construye la tarjeta de estadísticas globales con borde naranja.
  Widget _buildContenedorActividad(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // Borde decorativo naranja para diferenciar visualmente esta sección.
        border: Border.all(
          color: AppColors.naranja.withValues(alpha: 0.3),
          width: 1.5,
        ),
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
          _columnaStat(
            "Leídos",
            "${stats['read']}",
            Icons.check_circle,
            Colors.green.shade700,
          ),
          _divider(),
          _columnaStat(
            "Leyendo",
            "${stats['inProgress']}",
            Icons.menu_book,
            AppColors.naranja,
          ),
          _divider(),
          _columnaStat(
            "Por leer",
            "${stats['toRead']}",
            Icons.bookmark_border,
            AppColors.morado,
          ),
        ],
      ),
    );
  }

  /// Widget auxiliar para cada columna de estadística (icono + valor + etiqueta).
  Widget _columnaStat(String label, String valor, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
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

  /// Construye una tarjeta de estadística temporal con borde morado.
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
          // Borde decorativo morado para diferenciar visualmente esta sección.
          border: Border.all(
            color: AppColors.morado.withValues(alpha: 0.3),
            width: 1.5,
          ),
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

  // --- LÓGICA DE GESTIÓN DE CUENTA ---

  /// Muestra diálogo de confirmación y cierra la sesión del usuario.
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
      // pushNamedAndRemoveUntil elimina todas las pantallas anteriores para evitar volver al perfil tras logout.
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  /// Elimina permanentemente la cuenta del usuario y todos sus datos asociados.
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
      // 1. Eliminar todos los libros personales del usuario.
      var books = await FirebaseFirestore.instance
          .collection('user_books')
          .where('userId', isEqualTo: user.uid)
          .get();
      for (var doc in books.docs) {
        await doc.reference.delete();
      }
      // 2. Eliminar el documento de usuario.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .delete();
      // 3. Eliminar la cuenta de Firebase Auth.
      await user.delete();

      if (!context.mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) return;
      // Manejo del error común: requiere re-autenticación reciente para borrar cuenta.
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
