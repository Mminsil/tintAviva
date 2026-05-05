import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tintaviva/widgets/dialogo_registro.dart';
import 'package:tintaviva/pages/home_page.dart'; // Asegúrate de importar HomePage
import 'package:tintaviva/theme/app_styles.dart'; // Importa estilos

/// Pantalla de inicio de sesión y registro.
///
/// Permite acceso mediante:
/// 1. Email y contraseña (Firebase Auth).
/// 2. Google Sign-In.
/// 3. Registro de nuevo usuario (crea entrada en Firestore).
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
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
                    color: AppColors.morado, // Usa color global
                  ),
                ),
                const SizedBox(height: 50),

                // Los TextFields toman el estilo del tema global.
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email),
                  ),
                ),
                const SizedBox(height: 20),

                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: Icon(Icons.lock),
                  ),
                ),
                const SizedBox(height: 30),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _iniciarSesion,
                    child: const Text(
                      'Iniciar Sesión',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: _iniciarSesionConGoogle,
                  icon: const Icon(Icons.account_circle),
                  label: const Text('Entrar con Google', style: TextStyle(fontWeight: FontWeight.bold), ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: const BorderSide(color: AppColors.morado),
                    foregroundColor: AppColors.morado,
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _mostrarDialogoRegistro,
                  child: Text(
                    '¿No tienes cuenta? Regístrate aquí',
                    style: TextStyle(
                      color: AppColors.morado,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Inicia sesión con email y contraseña.
  Future<void> _iniciarSesion() async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      // Navegación segura: reemplaza la pila para evitar volver al login con "Back".
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      mostrarSnackBar(context, "Error: ${e.message}", Colors.red);
    }
  }

  /// Muestra el diálogo de registro y crea el usuario en Firebase y Firestore.
  void _mostrarDialogoRegistro() async {
    final Map<String, String>? datos = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => const DialogoRegistro(),
    );
    if (datos == null) return;
    if (!mounted) return;

    try {
      // 1. Crear usuario en Firebase Auth.
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: datos['email']!,
            password: datos['password']!,
          );
      final user = userCredential.user;

      // 2. Actualizar nombre visible en Auth.
      if (user != null) {
        await user.updateDisplayName(datos['name']);

        // 3. Crear documento de usuario en Firestore con estadísticas iniciales.
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': datos['name'],
          'email': datos['email'],
          'photoURL': datos['avatar'],
          'registrationDate': FieldValue.serverTimestamp(),
          'stats': {'inProgress': 0, 'read': 0, 'toRead': 0},
        });
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      mostrarSnackBar(context, "Error: ${e.message}", Colors.red);
    }
  }

  /// Lógica interna para el flujo de Google Sign-In.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId:
            '14443727035-sl8ccuo328v4o25qnpr80hmef75hu85f.apps.googleusercontent.com',
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null; // Usuario canceló el flujo.

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
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

  /// Inicia sesión con Google y sincroniza datos en Firestore.
  Future<void> _iniciarSesionConGoogle() async {
    final userCredential = await signInWithGoogle();
    if (!mounted) return;

    if (userCredential != null) {
      final user = userCredential.user;
      if (user != null) {
        // Usamos set con merge:true para crear el usuario si no existe o actualizar datos si ya existe.
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': user.displayName ?? "Usuario",
          'email': user.email ?? "",
          'photoURL': user.photoURL ?? "",
        }, SetOptions(merge: true));
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    } else {
      mostrarSnackBar(context, "Inicio de sesión cancelado", Colors.red);
    }
  }
}
