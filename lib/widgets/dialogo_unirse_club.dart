import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tintaviva/theme/app_styles.dart';
import '../../services/database.dart';

/// Dialogo para unirse a un club existente mediante codigo de invitacion.
///
/// Flujo completo:
/// 1. Validar que el codigo existe en Firestore
/// 2. Obtener el bookId del club
/// 3. Verificar si el usuario ya leyo ese libro (shelf == 'Leido')
/// 4. Si es relectura, mostrar confirmacion (el progreso se reiniciara a 0%)
/// 5. Llamar a DatabaseService.unirseAClub para agregar al usuario
///
/// El codigo de invitacion suele tener formato como "CLUB-123" (alfanumerico).
class DialogoUnirseClub extends StatefulWidget {
  const DialogoUnirseClub({super.key});

  @override
  State<DialogoUnirseClub> createState() => _DialogoUnirseClubState();
}

class _DialogoUnirseClubState extends State<DialogoUnirseClub> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codigoController = TextEditingController();
  bool _cargando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  /// Procesa la solicitud de union al club.
  ///
  /// Casos especiales:
  /// - Codigo invalido: muestra error y permanece en el dialogo
  /// - Club lleno (maxMembers): DatabaseService lanza excepcion
  /// - Usuario ya es miembro: DatabaseService lanza excepcion
  /// - Relectura: muestra confirmacion antes de proceder
  void _intentarUnirse() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Debes iniciar sesión.");

      final codigo = _codigoController.text.trim().toUpperCase();

      // Buscar el club por su codigo de invitacion
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
        // Caso: club sin libro asociado (no deberia ocurrir normalmente)
        await DatabaseService.unirseAClub(codigo);
        if (mounted) {
          Navigator.pop(context);
          mostrarSnackBar(context, "¡Te has unido al club!", AppColors.naranja);
        }
        return;
      }

      // Verificar si el usuario ya tiene este libro en su biblioteca y esta marcado como Leido
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

      // Si es relectura, mostrar dialogo de confirmacion
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

        if (confirmar != true) return;
        if (mounted) setState(() => _cargando = true);
      }

      // Proceder con la union
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
      if (!mounted) return;
      final errorMessage = e.toString().replaceAll("Exception: ", "");

      // Si el error indica que el club esta completo o codigo invalido, cerramos el dialogo
      if (errorMessage.contains("completo") ||
          errorMessage.contains("no válido")) {
        Navigator.pop(context);
      } else {
        setState(() => _cargando = false);
      }
      mostrarSnackBar(context, errorMessage, Colors.red);
    }
  }

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
