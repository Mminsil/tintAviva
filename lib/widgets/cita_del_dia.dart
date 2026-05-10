import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/services/database.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Widget que muestra una cita aleatoria de la base de datos.
/// 
/// Se carga una vez al iniciar y permanece fija hasta que el widget se reconstruye.
/// Si no hay citas disponibles, no muestra nada (SizedBox.shrink).
/// 
/// Uso tipico: en la pantalla de inicio (HomePage) o en el perfil del usuario.
class WidgetCitaDelDia extends StatefulWidget {
  const WidgetCitaDelDia({super.key});

  @override
  State<WidgetCitaDelDia> createState() => _WidgetCitaDelDiaState();
}

class _WidgetCitaDelDiaState extends State<WidgetCitaDelDia> {
  Map<String, dynamic>? _cita;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCita();
  }

  /// Obtiene una cita aleatoria desde Firestore.
  /// La cita se selecciona del lado del servidor mediante `orderBy` + `limit`.
  /// DatabaseService.obtenerCitaAleatoria debe devolver null si no hay citas.
  Future<void> _cargarCita() async {
    final user = FirebaseAuth.instance.currentUser;
    
    if (user == null) {
      if (mounted) setState(() => _cargando = false);
      return;
    }

    final cita = await DatabaseService.obtenerCitaAleatoria(user.uid);
    if (mounted) {
      setState(() {
        _cita = cita;
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const SizedBox.shrink();
    if (_cita == null){
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(16),
      // Nota: Este container no tiene decoracion (borde, fondo, etc).
      // En la implementacion original se omitio BoxDecoration.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, color: AppColors.naranja, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "\"${_cita!['text']}\"",
                  style: TextStyle(
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "— ${_cita!['bookTitle']}, ${_cita!['author']}",
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.morado,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}