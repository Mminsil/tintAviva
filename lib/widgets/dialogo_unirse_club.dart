import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';
import '../../services/database.dart';

/// Diálogo modal que permite al usuario unirse a un club de lectura existente.
///
/// Solicita un código de invitación y valida la entrada antes de llamar al servicio.
/// Maneja estados de carga y muestra feedback visual en caso de éxito o error.
class DialogoUnirseClub extends StatefulWidget {
  const DialogoUnirseClub({super.key});

  @override
  State<DialogoUnirseClub> createState() => _DialogoUnirseClub();
}

class _DialogoUnirseClub extends State<DialogoUnirseClub> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codigoController = TextEditingController();

  // Flag para controlar el estado de carga y evitar múltiples clics.
  bool _cargando = false;

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  /// Intenta unir al usuario al club usando el código introducido.
  ///
  /// Lógica de flujo:
  /// 1. Valida el formulario.
  /// 2. Bloquea la UI mostrando un indicador de carga.
  /// 3. Llama a DatabaseService.unirseAClub.
  /// 4. Si hay éxito, cierra el diálogo y muestra SnackBar.
  /// 5. Si hay error, maneja casos específicos (ej: club lleno) o permite reintentar.
  void _intentarUnirse() async {
    if (_formKey.currentState!.validate()) {
      // Evitamos clics dobles bloqueando el estado inmediatamente.
      setState(() => _cargando = true);

      try {
        final codigo = _codigoController.text.trim().toUpperCase();

        // Llamada al servicio que gestiona la unión atómica en Firebase.
        await DatabaseService.unirseAClub(codigo);

        // ÉXITO: Cerrar diálogo y mostrar mensaje.
        if (!mounted) return;
        Navigator.pop(context);

        // Mostramos el éxito en la pantalla principal.
        mostrarSnackBar(
          context,
          "¡Te has unido al club con éxito!",
          AppColors.naranja,
        );
      } catch (e) {
        // ERROR: Procesamos el mensaje para hacerlo legible.
        if (!mounted) return;
        final errorMessage = e.toString().replaceAll("Exception: ", "");

        // Si el club está lleno, cerramos el diálogo automáticamente porque no hay nada que corregir.
        if (errorMessage.contains("completo")) {
          Navigator.pop(context);
        } else {
          // Si es otro error (código inválido, red, etc.), mantenemos abierto para reintentar.
          setState(() => _cargando = false);
        }

        mostrarSnackBar(context, errorMessage, Colors.red);
      }
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
              "Introduce el código de invitación para unirte a un club de lectura existente.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _codigoController,
              textAlign: TextAlign.center,
              enabled:
                  !_cargando, // Bloquea el campo mientras carga para evitar ediciones.
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing:
                    2, // Espaciado para facilitar lectura de códigos.
              ),
              decoration: InputDecoration(
                hintText: "CÓDIGO-123",
                hintStyle: TextStyle(color: Colors.grey[400], letterSpacing: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.naranja, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return "Por favor, ingresa un código válido.";
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.only(
        bottom: 20,
        top: 0,
        left: 20,
        right: 20,
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                // Deshabilita el botón si está cargando.
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
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            "Unirme",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.sentiment_satisfied_alt, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
