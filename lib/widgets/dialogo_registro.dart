import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Diálogo modal para el registro de nuevos usuarios.
///
/// Propósito:
/// 1. Permitir al usuario seleccionar un avatar predeterminado de una lista horizontal
/// 2. Recopilar datos básicos: nombre, email y contraseña
/// 3. Validar los datos localmente antes de devolverlos al `LoginPage` para su procesamiento en Firebase
///
/// Retorna al padre un `Map<String, String>` con los datos del nuevo usuario:
/// ```dart
/// {
///   'name': String,      // Nombre completo del usuario
///   'email': String,     // Correo electrónico validado con regex
///   'password': String,  // Contraseña validada (mínimo 8 chars, 1 mayúscula, 1 número)
///   'avatar': String,    // Ruta del asset de avatar seleccionado
/// }
/// ```
///
/// Validaciones locales:
/// - Campos vacíos → `SnackBar` de error
/// - Email inválido (regex RFC 5322 simplificado) → `SnackBar` de error
/// - Contraseña inválida (<8 chars, sin mayúscula, sin número) → mensaje en rojo bajo el campo
/// - Solo si todo es válido → `Navigator.pop(context, datos)`
///
/// Ejemplo de uso:
/// ```dart
/// // En LoginPage:
/// final Map<String, String>? datos = await showDialog<Map<String, String>>(
///   context: context,
///   builder: (context) => const DialogoRegistro(),
/// );
/// if (datos != null) {
///   // Crear cuenta en Firebase Auth y Firestore con los datos
///   await FirebaseAuth.instance.createUserWithEmailAndPassword(...);
/// }
/// ```
class DialogoRegistro extends StatefulWidget {
  const DialogoRegistro({super.key});

  @override
  State<DialogoRegistro> createState() => _DialogoRegistroState();
}

class _DialogoRegistroState extends State<DialogoRegistro> {
  /// Controladores para capturar los datos de los campos de texto.
  ///
  /// Se liberan en `dispose()` para evitar fugas de memoria.
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  /// Lista de rutas a las imágenes de avatar disponibles en `assets/`.
  ///
  /// Estos archivos deben estar declarados en `pubspec.yaml` bajo `flutter.assets`
  /// para ser accesibles en tiempo de ejecución.
  ///
  /// Ejemplo en `pubspec.yaml`:
  /// ```yaml
  /// flutter:
  ///   assets:
  ///     - assets/avatares/ava1.png
  ///     - assets/avatares/ava2.png
  ///     # ... etc
  /// ```
  final List<String> _avatares = [
    'assets/avatares/ava1.png',
    'assets/avatares/ava2.png',
    'assets/avatares/ava3.png',
    'assets/avatares/ava4.png',
    'assets/avatares/ava5.png',
    'assets/avatares/ava6.png',
  ];

  /// Avatar seleccionado por defecto (primero de la lista).
  ///
  /// Se actualiza con `setState` al tocar un avatar en la lista horizontal.
  String _avatarSeleccionado = 'assets/avatares/ava1.png';

  /// Valida el formato del email usando una expresión regular estándar.
  ///
  /// Patrón RFC 5322 simplificado:
  /// - Permite caracteres alfanuméricos, puntos, guiones, guiones bajos y signos `+` en la parte local
  /// - Requiere un `@` y un dominio con al menos un punto y TLD de 2+ letras
  ///
  /// Ejemplos válidos:
  /// - `usuario@example.com`
  /// - `nombre.apellido+tag@sub.dominio.co.uk`
  ///
  /// Ejemplos inválidos:
  /// - `sin-arroba.com`
  /// - `@nodominio.com`
  /// - `usuario@.com`
  ///
  /// Parámetros:
  /// - [email]: `String` a validar
  ///
  /// Retorna:
  /// - `true` si el email coincide con el patrón, `false` en caso contrario
  bool _esCorreoValido(String email) {
    final RegExp regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email);
  }

  /// Valida que la contraseña cumpla con los requisitos de seguridad.
  ///
  /// Requisitos:
  /// 1. Mínimo 8 caracteres
  /// 2. Al menos una letra mayúscula (`A-Z`)
  /// 3. Al menos un número (`0-9`)
  ///
  /// Parámetros:
  /// - [value]: `String?` con la contraseña a validar
  ///
  /// Retorna:
  /// - `String` con mensaje de error descriptivo si es inválida
  /// - `null` si cumple todos los requisitos (para que `TextFormField` no muestre error)
  ///
  /// Ejemplos:
  /// ```dart
  /// _validarContrasena('abc')        // → 'Mínimo 8 caracteres'
  /// _validarContrasena('abcdefgh')   // → 'Debe incluir una mayúscula'
  /// _validarContrasena('Abcdefgh')   // → 'Debe incluir un número'
  /// _validarContrasena('Abcdefg1')   // → null (válida ✅)
  /// ```
  String? _validarContrasena(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 8) {
      return 'Mínimo 8 caracteres';
    }
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Debe incluir una mayúscula';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Debe incluir un número';
    }
    return null; // ✅ Válida
  }

  @override
  void dispose() {
    // Liberar recursos de los controladores para evitar fugas de memoria.
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD: UI DEL DIÁLOGO
  // ─────────────────────────────────────────────────────────────

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
            // Selector de avatar con lista horizontal
            const Text(
              "Elige tu avatar:",
              style: TextStyle(fontSize: 14, color: AppColors.textoNegroSuave),
            ),
            const SizedBox(height: 10),

            // Lista horizontal de avatares seleccionables con scroll.
            SizedBox(
              height: 70,
              width: double.maxFinite,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _avatares.length,
                itemBuilder: (context, index) {
                  final bool esSeleccionado = _avatarSeleccionado == _avatares[index];
                  return GestureDetector(
                    onTap: () {
                      setState(() => _avatarSeleccionado = _avatares[index]);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Borde naranja para indicar selección visualmente.
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

            // Campos de formulario con estilos reutilizables
            TextFormField(
              controller: _nameController,
              decoration: AppInputStyles.inputDecoration('Nombre completo'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 10),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: AppInputStyles.inputDecoration('Correo electrónico'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El correo es requerido';
                }
                if (!_esCorreoValido(value.trim())) {
                  return 'Introduce un correo válido';
                }
                return null;
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 10),

            // Campo de contraseña con validación robusta
            TextFormField(
              controller: _passwordController,
              obscureText: true, // Oculta la contraseña para privacidad.
              decoration: AppInputStyles.inputDecoration('Contraseña').copyWith(
                helperText: 'Mín. 8 caracteres, 1 mayúscula, 1 número',
                helperStyle: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
              validator: _validarContrasena,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
          ],
        ),
      ),
      actions: [
        // Botón Cancelar: cierra el diálogo sin acción.
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        // Botón Registrarme: valida y devuelve datos al padre.
        ElevatedButton(
          style: AppButtonStyles.primaryElevatedButton,
          onPressed: () {
            final String nombre = _nameController.text.trim();
            final String email = _emailController.text.trim();
            final String password = _passwordController.text.trim();

            // Validación de contraseña (se ejecuta primero para feedback inmediato)
            final String? passwordError = _validarContrasena(password);
            if (passwordError != null) {
              // Forzar validación visual si el usuario no ha interactuado aún
              setState(() {}); // Dispara la validación visual de TextFormField
              return; // Detiene el flujo
            }

            // 1. Validación de campos vacíos (prevención de errores básicos)
            if (nombre.isEmpty || email.isEmpty || password.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Por favor, completa todos los campos"),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // 2. Validación de formato de correo (prevención de errores de Firebase Auth)
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
            // El LoginPage se encargará de crear la cuenta en Firebase Auth y Firestore.
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