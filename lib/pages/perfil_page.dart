import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/pages/onboarding_page.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';
import 'package:tintaviva/utils/streak_helper.dart';

/// Página de perfil del usuario.
///
/// Muestra:
/// 1. Datos personales y avatar del usuario (foto, nombre, email)
/// 2. Racha de lectura actual (gamificación con `StreakHelper`)
/// 3. Estadísticas globales de estanterías: `'Leídos'`, `'Leyendo'`, `'Por leer'`
/// 4. Estadísticas temporales: libros leídos este mes/año (cálculo en cliente)
/// 5. Acciones de cuenta: cerrar sesión / eliminar cuenta permanentemente
///
/// Característica técnica:
/// - Usa `AutomaticKeepAliveClientMixin` para preservar el estado al cambiar de pestaña en `HomePage`
/// - Escucha cambios en tiempo real en `users/{uid}` con `StreamBuilder`
class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key});

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage>
    with AutomaticKeepAliveClientMixin {
  /// Indica a Flutter que debe preservar el estado de este widget cuando se oculta.
  ///
  /// Esto evita que la página se reconstruya cada vez que el usuario cambia de pestaña,
  /// manteniendo en memoria: la racha de lectura, los datos cargados y el scroll.
  @override
  bool get wantKeepAlive => true;

  /// Días consecutivos de lectura actuales del usuario.
  int _streak = 0;

  /// Controla si la racha está cargándose para mostrar loading.
  bool _isLoadingStreak = true;

  @override
  void initState() {
    super.initState();
    // Cargamos la racha de lectura al iniciar la página.
    _loadStreak();
  }

  /// Carga la racha de lectura actual desde `StreakHelper` y actualiza la UI.
  ///
  /// Verifica `mounted` antes de llamar a `setState` para evitar errores si el widget
  /// fue destruido durante la operación asíncrona.
  Future<void> _loadStreak() async {
    final streak = await StreakHelper.getCurrentStreak();
    if (mounted) {
      setState(() {
        _streak = streak;
        _isLoadingStreak = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (ÍNDICE LEGIBLE)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Llamada obligatoria cuando se usa `AutomaticKeepAliveClientMixin`.
    super.build(context);

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: _buildBody(user),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye el cuerpo principal con `StreamBuilder` para datos del usuario.
  ///
  /// Escucha cambios en tiempo real en `users/{uid}` y renderiza:
  /// - Estado de carga
  /// - Perfil completo: avatar, nombre, email, racha, estadísticas y acciones
  Widget _buildBody(User? user) {
    return StreamBuilder<DocumentSnapshot>(
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
        final bool esAsset = photoUrl != null && photoUrl.contains('assets/');

        return SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildUserAvatar(photoUrl, esAsset),
              const SizedBox(height: 15),
              _buildUserName(userData),
              _buildUserEmail(user),
              const SizedBox(height: 30),
              _buildStreakCard(),
              const SizedBox(height: 30),
              _buildSectionHeader('Mis Estanterías'),
              const SizedBox(height: 15),
              _buildContenedorActividad(stats),
              const SizedBox(height: 30),
              _buildSectionHeader('Este periodo'),
              const SizedBox(height: 15),
              _buildTemporalStatsStream(user),
              const SizedBox(height: 50),
              _buildAccountActions(),
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  /// Construye el avatar circular del usuario con lógica para imagen local o remota.
  ///
  /// - Si `photoUrl` contiene `'assets/'`: usa `AssetImage`
  /// - Si es URL http/https: usa `NetworkImage`
  /// - Si es null/vacío: muestra icono por defecto `Icons.person`
  Widget _buildUserAvatar(String? photoUrl, bool esAsset) {
    return Center(
      child: CircleAvatar(
        radius: 60,
        backgroundColor: AppColors.morado.withValues(alpha: 0.1),
        backgroundImage: photoUrl != null && photoUrl.isNotEmpty
            ? (esAsset
                  ? AssetImage(photoUrl) as ImageProvider
                  : NetworkImage(photoUrl))
            : null,
        child: (photoUrl == null || photoUrl.isEmpty)
            ? const Icon(Icons.person, size: 60, color: AppColors.morado)
            : null,
      ),
    );
  }

  /// Construye el nombre del usuario con estilo de título.
  Widget _buildUserName(Map<String, dynamic>? userData) {
    return Text(
      userData?['name'] ?? 'Usuario',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: AppColors.textoNegroSuave,
      ),
    );
  }

  /// Construye el email del usuario con estilo secundario.
  Widget _buildUserEmail(User? user) {
    return Text(user?.email ?? '', style: TextStyle(color: Colors.grey[600]));
  }

  /// Construye la tarjeta de racha de lectura con animación de carga.
  Widget _buildStreakCard() {
    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: _isLoadingStreak
            ? const Center(child: CircularProgressIndicator())
            : _buildStreakContent(),
      ),
    );
  }

  /// Construye el contenido de la racha cuando ya está cargada.
  Widget _buildStreakContent() {
    return Column(
      children: [
        Icon(
          Icons.emoji_events,
          color: _streak > 0 ? Colors.orange : Colors.grey[400],
          size: 60,
        ),
        const SizedBox(height: 10),
        Text(
          _streak.toString(),
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: AppColors.morado,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          StreakHelper.getStreakMessage(_streak),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    );
  }

  /// Construye el título de sección con estilo consistente.
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: AppTextStyles.sectionTitle),
      ),
    );
  }

  /// Construye la tarjeta de estadísticas globales con borde naranja.
  Widget _buildContenedorActividad(Map<String, dynamic> stats) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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

  /// Divider vertical para separar columnas de estadísticas.
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

  /// Construye el stream para estadísticas temporales (libros leídos este mes/año).
  ///
  /// Nota: El filtrado por fecha se hace en cliente iterando sobre los documentos.
  /// Para grandes volúmenes de datos, esto podría optimizarse con consultas compuestas en Firestore.
  Widget _buildTemporalStatsStream(User? user) {
    return StreamBuilder<QuerySnapshot>(
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
              final DateTime fecha = (data['dateFinished'] as Timestamp)
                  .toDate();
              if (fecha.year == ahora.year) {
                leidosAnio++;
                if (fecha.month == ahora.month) {
                  leidosMes++;
                }
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
    );
  }

  /// Construye las acciones de cuenta: cerrar sesión y eliminar cuenta.
  /// Construye las acciones de cuenta: ver guía, cerrar sesión y eliminar cuenta.
  Widget _buildAccountActions() {
    return Column(
      children: [
        //  Ver guía de nuevo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _volverAVerGuia(),
              icon: const Icon(Icons.school, color: AppColors.morado),
              label: const Text(
                "Volver a ver la guía",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.morado,
                side: BorderSide(color: AppColors.morado, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 15),

        // Botón cerrar sesión (ya existente)
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

        // Botón eliminar cuenta (ya existente)
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
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE GESTIÓN DE CUENTA
  // ─────────────────────────────────────────────────────────────

  /// Muestra diálogo de confirmación y cierra la sesión del usuario.
  ///
  /// Usa `pushNamedAndRemoveUntil` para eliminar todas las pantallas anteriores
  /// y evitar que el usuario pueda volver al perfil tras el logout.
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
      if (!context.mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  /// Elimina permanentemente la cuenta del usuario y todos sus datos asociados.
  ///
  /// Proceso atómico:
  /// 1. Elimina todos los documentos en `user_books` del usuario
  /// 2. Elimina el documento en `users/{uid}`
  /// 3. Elimina la cuenta en `FirebaseAuth`
  ///
  /// Manejo de errores:
  /// - `requires-recent-login`: fuerza al usuario a re-autenticarse antes de borrar
  /// - Otros errores: muestra mensaje genérico
  void _confirmarEliminarCuenta(BuildContext context) async {
    final bool? confirmar = await mostrarDialogoConfirmacion(
      context: context,
      titulo: "¿Eliminar cuenta?",
      contenido:
          "Esta acción es irreversible. Se borrarán todos tus libros, estadísticas y datos personales permanentemente.",
      textoAccion: "Eliminar todo",
      colorAccion: Colors.red,
    );
    if (confirmar != true || !context.mounted) {
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }

    try {
      // 1. Eliminar todos los libros personales del usuario.
      final books = await FirebaseFirestore.instance
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

      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } on FirebaseAuthException catch (e) {
      if (!context.mounted) {
        return;
      }
      if (e.code == 'requires-recent-login') {
        mostrarSnackBar(
          context,
          "Vuelve a iniciar sesión para borrar tu cuenta.",
          AppColors.naranja,
        );
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) {
          return;
        }
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/login', (route) => false);
      } else {
        mostrarSnackBar(context, "Error al eliminar: $e", Colors.red);
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      mostrarSnackBar(context, "Ocurrió un error inesperado: $e", Colors.red);
    }
  }

  /// Navega a OnboardingPage para que el usuario vuelva a ver la guía.
  void _volverAVerGuia() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnboardingPage(
          // Callback que hace pop() para volver al perfil sin perder sesión
          onComplete: () => Navigator.pop(context),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
