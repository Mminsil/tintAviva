import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tintaviva/pages/home_page.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/widgets/dialogo_registro.dart';

/// Pantalla de autenticación que maneja tres flujos:
/// 1. Login con email/contraseña (`signInWithEmailAndPassword`)
/// 2. Registro de nueva cuenta (`DialogoRegistro` + `createUserWithEmailAndPassword`)
/// 3. Login con Google (`GoogleSignIn` + `FirebaseAuth.credential`)
///
/// Tras autenticación exitosa, navega a `HomePage` y reemplaza la pila de navegación.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (ÍNDICE LEGIBLE)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye el cuerpo principal con logo, formulario y botones de autenticación.
  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(25.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(),
              const SizedBox(height: 50),
              _buildEmailField(),
              const SizedBox(height: 20),
              _buildPasswordField(),
              const SizedBox(height: 30),
              _buildLoginButton(),
              _buildForgotPasswordButton(),
              _buildGoogleSignInButton(),
              const SizedBox(height: 10),
              _buildRegisterButton(),
            ],
          ),
        ),
      ),
    );
  }

  /// Construye el logo de la app con bordes redondeados.
  Widget _buildLogo() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/portada.png',
            height: 120,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'TintAviva',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.bold,
            color: AppColors.morado,
          ),
        ),
      ],
    );
  }

  /// Construye el campo de texto para correo electrónico.
  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: const InputDecoration(
        labelText: 'Correo electrónico',
        prefixIcon: Icon(Icons.email),
      ),
    );
  }

  /// Construye el campo de texto para contraseña (oculto).
  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: true,
      decoration: const InputDecoration(
        labelText: 'Contraseña',
        prefixIcon: Icon(Icons.lock),
      ),
    );
  }

  /// Construye el botón principal de inicio de sesión.
  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _iniciarSesion,
        child: const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  /// Construye el botón para recuperar contraseña.
  Widget _buildForgotPasswordButton() {
    return TextButton(
      onPressed: _abrirRecuperarContrasena,
      child: const Text(
        '¿Olvidaste tu contraseña?',
        style: TextStyle(color: AppColors.morado, fontSize: 13),
      ),
    );
  }

  /// Construye el botón de inicio de sesión con Google.
  Widget _buildGoogleSignInButton() {
    return OutlinedButton.icon(
      onPressed: _iniciarSesionConGoogle,
      icon: const Icon(Icons.account_circle),
      label: const Text('Entrar con Google', style: TextStyle(fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 50),
        side: const BorderSide(color: AppColors.morado),
        foregroundColor: AppColors.morado,
      ),
    );
  }

  /// Construye el botón para navegar al diálogo de registro.
  Widget _buildRegisterButton() {
    return TextButton(
      onPressed: _mostrarDialogoRegistro,
      child: Text(
        '¿No tienes cuenta? Regístrate aquí',
        style: TextStyle(color: AppColors.morado, fontWeight: FontWeight.bold),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO: AUTENTICACIÓN
  // ─────────────────────────────────────────────────────────────

  /// Autentica con email y contraseña.
  ///
  /// Si falla, captura `FirebaseAuthException` y muestra el mensaje de error.
  /// Usa `pushReplacement` para que el usuario no pueda volver a login con el botón de retroceso.
  Future<void> _iniciarSesion() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      mostrarSnackBar(context, "Error: ${e.message}", Colors.red);
    }
  }

  /// Abre `DialogoRegistro` y procesa la creación de cuenta.
  ///
  /// Flujo completo:
  /// 1. Recoge nombre, email, password y avatar del diálogo
  /// 2. `createUserWithEmailAndPassword` en Firebase Auth
  /// 3. `updateDisplayName` para establecer el nombre visible
  /// 4. Crea documento en colección `'users'` con estadísticas iniciales
  /// 5. Navega a `HomePage`
  void _mostrarDialogoRegistro() async {
    final Map<String, String>? datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const DialogoRegistro(),
    );
    if (datos == null) {
      return;
    }
    if (!mounted) {
      return;
    }

    try {
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: datos['email']!,
            password: datos['password']!,
          );
      final User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(datos['name']);
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': datos['name'],
          'email': datos['email'],
          'photoURL': datos['avatar'],
          'registrationDate': FieldValue.serverTimestamp(),
          'stats': {'inProgress': 0, 'read': 0, 'toRead': 0},
        });
      }
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      mostrarSnackBar(context, "Error: ${e.message}", Colors.red);
    }
  }

  /// Lógica interna de Google Sign-In.
  ///
  /// Devuelve `UserCredential?` o `null` si el usuario cancela el flujo.
  /// El `clientId` es el de la aplicación de Google Cloud Console.
  Future<UserCredential?> _signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: '14443727035-sl8ccuo328v4o25qnpr80hmef75hu85f.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Error en Google Sign-In: $e");
      return null;
    }
  }

  /// Inicia sesión con Google y sincroniza con Firestore.
  ///
  /// Diferencia clave con registro por email: usa `set` con `merge: true`.
  /// Esto permite que si el usuario ya existe, solo se actualicen campos como `photoURL`
  /// sin sobrescribir `stats` ni `registrationDate`.
  Future<void> _iniciarSesionConGoogle() async {
    final UserCredential? userCredential = await _signInWithGoogle();
    if (!mounted) {
      return;
    }

    if (userCredential != null) {
      final User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? "Usuario",
          'email': user.email ?? "",
          'photoURL': user.photoURL ?? "",
        }, SetOptions(merge: true));
      }
      if (!mounted) {
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      mostrarSnackBar(context, "Inicio de sesión cancelado", Colors.red);
    }
  }

  /// Abre diálogo para recuperar contraseña vía email.
  ///
  /// Envía enlace de restablecimiento con `sendPasswordResetEmail`.
  /// Muestra feedback según resultado y gestiona `mounted` tras `await`.
  Future<void> _abrirRecuperarContrasena() async {
    final emailController = TextEditingController();
    bool exito = false;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Olvidaste tu contraseña?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Te enviaremos un enlace para restablecerla.'),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Tu correo electrónico',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty || !email.contains('@')) {
                mostrarSnackBar(dialogContext, 'Ingresa un correo válido', Colors.orange);
                return;
              }
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                exito = true;
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                final msg = (e is FirebaseAuthException && e.code == 'user-not-found')
                    ? 'No hay cuenta con ese correo'
                    : 'Error al enviar';
                if (dialogContext.mounted) {
                  mostrarSnackBar(dialogContext, msg, Colors.red);
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.morado),
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (!mounted) {
      return;
    }
    emailController.dispose();

    if (exito) {
      mostrarSnackBar(context, 'Enlace enviado ✓ Revisa tu bandeja', Colors.green);
    }
  }
}