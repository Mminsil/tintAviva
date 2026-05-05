import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/pages/login_page.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tintaviva/pages/home_page.dart';

/// Pantalla de bienvenida (Splash Screen).
///
/// Muestra el logo y slogan con una animación suave antes de navegar al Login.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    // Animación combinada de opacidad y escala.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();

    // Navegación automática tras 3 segundos.
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;

      // Verificamos si hay un usuario logueado actualmente
      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage())
        );
      }else{
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage())
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      body: Center(
        child: FadeTransition(
          opacity: _animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.8, end: 1.0).animate(_animation),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset('assets/portada.png', fit: BoxFit.contain),
                ),
                const SizedBox(height: 20),
                Text(
                  'Donde la tinta aviva tu mente.',
                  style: TextStyle(
                    fontSize: 20,
                    color: AppColors.textoNegroSuave,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
