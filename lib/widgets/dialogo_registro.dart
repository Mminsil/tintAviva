import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Diálogo modal para el registro de nuevos usuarios.
///
/// Permite:
/// 1. Seleccionar un avatar predeterminado de una lista horizontal.
/// 2. Introducir nombre, email y contraseña.
/// 3. Validar los datos localmente antes de devolverlos al LoginPage.
class DialogoRegistro extends StatefulWidget {
  const DialogoRegistro({super.key});

  @override
  State<DialogoRegistro> createState() => _DialogoRegistroState();
}

class _DialogoRegistroState extends State<DialogoRegistro> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Lista de rutas a las imágenes de avatar disponibles en assets.
  final List<String> _avatares = [
    'assets/avatares/ava1.png',
    'assets/avatares/ava2.png',
    'assets/avatares/ava3.png',
    'assets/avatares/ava4.png',
    'assets/avatares/ava5.png',
    'assets/avatares/ava6.png',
  ];

  // Avatar seleccionado por defecto.
  String _avatarSeleccionado = 'assets/avatares/ava1.png';

  /// Valida el formato del email usando una expresión regular estándar.
  bool _esCorreoValido(String email) {
    final RegExp regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      backgroundColor: AppColors.fondoClaro,
      title: Text('Crear cuenta', style: AppTextStyles.dialogTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Elige tu avatar:",
              style: TextStyle(fontSize: 14, color: AppColors.textoNegroSuave),
            ),
            const SizedBox(height: 10),

            // Lista horizontal de avatares seleccionables.
            SizedBox(
              height: 70,
              width: double.maxFinite,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _avatares.length,
                itemBuilder: (context, index) {
                  bool esSeleccionado = _avatarSeleccionado == _avatares[index];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _avatarSeleccionado = _avatares[index]),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Borde naranja para indicar selección.
                        border: Border.all(
                          color: esSeleccionado
                              ? AppColors.naranja
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 25,
                        backgroundImage: AssetImage(_avatares[index]),
                        backgroundColor: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              decoration: AppInputStyles.inputDecoration('Nombre completo'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: AppInputStyles.inputDecoration('Correo electrónico'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true, // Oculta la contraseña.
              decoration: AppInputStyles.inputDecoration('Contraseña'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: AppButtonStyles.primaryElevatedButton,
          onPressed: () {
            final String nombre = _nameController.text.trim();
            final String email = _emailController.text.trim();
            final String password = _passwordController.text.trim();

            // 1. Validación de campos vacíos.
            if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Por favor, completa todos los campos"),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // 2. Validación de formato de correo.
            if (!_esCorreoValido(email)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Introduce un correo electrónico válido"),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // 3. Si todo es correcto, devolvemos el mapa de datos al LoginPage.
            Navigator.pop(context, {
              'name': nombre,
              'email': email,
              'password': password,
              'avatar': _avatarSeleccionado,
            });
          },
          child: const Text('Registrarme'),
        ),
      ],
    );
  }
}
