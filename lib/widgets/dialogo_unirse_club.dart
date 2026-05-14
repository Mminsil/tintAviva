import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
/// Diálogo para unirse a un club existente mediante código de invitación.
///
/// Flujo completo:
/// 1. Validar que el código existe en Firestore (`clubs.where('code', isEqualTo: ...)`)
/// 2. Obtener el `bookId` del club para verificar historial de lectura
/// 3. Verificar si el usuario ya leyó ese libro (`shelf == 'Leído'`)
/// 4. Si es relectura → mostrar confirmación (el progreso se reiniciará a 0%)
/// 5. Llamar a `DatabaseService.unirseAClub` para agregar al usuario
///
/// Formato del código:
/// - Alfanumérico, típicamente `"CLUB-123"` (se normaliza a mayúsculas con `.toUpperCase()`)
///
/// Casos de error manejados:
/// - Código inválido → mensaje de error, permanece en el diálogo
/// - Club lleno (`maxMembers`) → excepción de `DatabaseService`, se cierra el diálogo
/// - Usuario ya es miembro → excepción de `DatabaseService`, se cierra el diálogo
/// - Relectura cancelada → no procede con la unión
///
/// Ejemplo de uso:
/// ```dart
/// // En ClubesPage, desde el SpeedDial:
/// showDialog(
///   context: context,
///   builder: (context) => const DialogoUnirseClub(),
/// )
/// ```
class DialogoUnirseClub extends StatefulWidget {
  const DialogoUnirseClub({super.key});

  @override
  State<DialogoUnirseClub> createState() => _DialogoUnirseClubState();
}

class _DialogoUnirseClubState extends State<DialogoUnirseClub> {
  /// Clave para el `Form` que permite validar el campo de código.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controlador para el campo de texto del código de invitación.
  ///
  /// Se normaliza a mayúsculas con `.toUpperCase()` antes de consultar Firestore.
  final TextEditingController _codigoController = TextEditingController();

  /// Controla el estado de carga para deshabilitar inputs y mostrar `CircularProgressIndicator`.
  bool _cargando = false;

  @override
  void dispose() {
    // Liberar el controlador para evitar fugas de memoria.
    _codigoController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO: UNIÓN AL CLUB
  // ─────────────────────────────────────────────────────────────

  /// Procesa la solicitud de unión al club.
  ///
  /// Flujo detallado:
  /// 1. Valida el formulario con `_formKey.currentState!.validate()`
  /// 2. Activa estado de carga (`_cargando = true`)
  /// 3. Verifica que haya usuario autenticado (`FirebaseAuth.instance.currentUser`)
  /// 4. Busca el club por código en Firestore (`clubs.where('code', isEqualTo: ...)`)
  /// 5. Si no existe → lanza excepción con mensaje amigable
  /// 6. Si existe → obtiene `bookId` para verificar historial de lectura
  /// 7. Si el usuario ya tiene el libro con `shelf == 'Leído'` → muestra confirmación de relectura
  /// 8. Si confirma (o no es relectura) → llama a `DatabaseService.unirseAClub(codigo)`
  /// 9. Muestra feedback con `SnackBar` y cierra el diálogo
  ///
  /// Manejo de errores:
  /// - Limpia el mensaje: `e.toString().replaceAll("Exception: ", "")`
  /// - Si el error es "completo" o "no válido" → cierra el diálogo automáticamente
  /// - Otros errores → mantiene el diálogo abierto para reintentar
  ///
  /// Seguridad:
  /// - Verifica `mounted` antes de llamar a `setState`, `Navigator.pop` o `mostrarSnackBar`
  void _intentarUnirse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _cargando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Debes iniciar sesión.");
      }

      final String codigo = _codigoController.text.trim().toUpperCase();

      // Buscar el club por su código de invitación
      final clubsSnapshot = await FirebaseFirestore.instance
          .collection('clubs')
          .where('code', isEqualTo: codigo)
          .limit(1)
          .get();

      if (clubsSnapshot.docs.isEmpty) {
        throw Exception("Código de club no válido.");
      }

      final clubDoc = clubsSnapshot.docs.first;
      final Map<String, dynamic> clubData = clubDoc.data();
      final String bookId = clubData['bookId'] ?? clubData['isbn'] ?? '';

      if (bookId.isEmpty) {
        // Caso: club sin libro asociado (no debería ocurrir normalmente)
        await DatabaseService.unirseAClub(codigo);
        if (mounted) {
          Navigator.pop(context);
          mostrarSnackBar(context, "¡Te has unido al club!", AppColors.naranja);
        }
        return;
      }

      // Verificar si el usuario ya tiene este libro en su biblioteca y está marcado como Leído
      final userBookRef = FirebaseFirestore.instance
          .collection('user_books')
          .doc('${user.uid}_$bookId');

      final userBookSnap = await userBookRef.get();
      bool esRelectura = false;

      if (userBookSnap.exists) {
        final userData = userBookSnap.data() as Map<String, dynamic>;
        if (userData['shelf'] == 'Leído') {
          esRelectura = true;
        }
      }

      // Si es relectura, mostrar diálogo de confirmación
      if (esRelectura && mounted) {
        setState(() => _cargando = false);

        final bool? confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("🔄 ¿Volver a leer?"),
            content: const Text(
              "Ya has terminado este libro. Al unirte al club, tu progreso se reiniciará al 0% y pasarás a 'Leyendo'. ¿Continuar?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.naranja,
                ),
                child: const Text(
                  "Sí, unirme",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );

        if (confirmar != true) {
          return;
        }
        if (mounted) {
          setState(() => _cargando = true);
        }
      }

      // Proceder con la unión
      await DatabaseService.unirseAClub(codigo);

      if (mounted) {
        Navigator.pop(context);
        mostrarSnackBar(
          context,
          "¡Te has unido al club con éxito!",
          AppColors.naranja,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      final String errorMessage = e.toString().replaceAll("Exception: ", "");

      // Si el error indica que el club está completo o código inválido, cerramos el diálogo
      if (errorMessage.contains("completo") || errorMessage.contains("no válido")) {
        Navigator.pop(context);
      } else {
        setState(() => _cargando = false);
      }
      mostrarSnackBar(context, errorMessage, AppColors.naranja);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD: UI DEL DIÁLOGO
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        "Unirse a un club",
        style: TextStyle(
          color: AppColors.morado,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Introduce el código de invitación.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            // Campo de código con validación y estilo destacado
            TextFormField(
              controller: _codigoController,
              textAlign: TextAlign.center,
              enabled: !_cargando,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              decoration: InputDecoration(
                hintText: "CÓDIGO-123",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.naranja, width: 2),
                ),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? "Ingresa un código."
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        // Botones en fila: Cancelar + Unirme (con loading)
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: _cargando ? null : () => Navigator.pop(context),
                child: Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.naranja,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _cargando ? null : _intentarUnirse,
                child: _cargando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Unirme",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}