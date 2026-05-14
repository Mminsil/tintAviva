import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Widget que muestra una cita aleatoria de la base de datos.
///
/// Se carga una vez al iniciar y permanece fija hasta que el widget se reconstruye.
/// Si no hay citas disponibles, no muestra nada (`SizedBox.shrink`).
///
/// Características:
/// - Carga asíncrona en `initState()` vía `DatabaseService.obtenerCitaAleatoria`
/// - Verifica `mounted` antes de `setState` para evitar errores si el widget se destruye
/// - Muestra cita con formato: `"texto" — libro, autor` + icono decorativo
/// - Silencioso: si no hay usuario o no hay citas, no muestra nada ni errores
///
/// Uso típico:
/// - En `MiBibliotecaPage` como inspiración diaria
/// - En `PerfilPage` como elemento motivacional
/// - En cualquier pantalla donde quieras mostrar contenido literario aleatorio
///
/// Ejemplo:
/// ```dart
/// Column(
///   children: [
///     _buildHeader(),
///     const WidgetCitaDelDia(), // 👈 Cita aleatoria
///     _buildSearchBar(),
///     // ...
///   ],
/// )
/// ```
class WidgetCitaDelDia extends StatefulWidget {
  const WidgetCitaDelDia({super.key});

  @override
  State<WidgetCitaDelDia> createState() => _WidgetCitaDelDiaState();
}

class _WidgetCitaDelDiaState extends State<WidgetCitaDelDia> {
  /// Cita cargada desde Firestore.
  ///
  /// Estructura esperada del `Map<String, dynamic>`:
  /// - `'text'`: `String` → texto de la cita
  /// - `'bookTitle'`: `String` → título del libro de origen
  /// - `'author'`: `String` → autor del libro
  ///
  /// Es `null` mientras se carga o si no hay citas disponibles.
  Map<String, dynamic>? _cita;

  /// Controla si la cita está cargándose para evitar mostrar UI incompleta.
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarCita();
  }

  /// Obtiene una cita aleatoria desde Firestore vía `DatabaseService`.
  ///
  /// Flujo:
  /// 1. Verifica que haya un usuario autenticado (`FirebaseAuth.instance.currentUser`)
  /// 2. Si no hay usuario → log de advertencia y marca como cargado (sin error visible)
  /// 3. Llama a `DatabaseService.obtenerCitaAleatoria(user.uid)`
  /// 4. Si el widget sigue montado → actualiza `_cita` y `_cargando` con `setState`
  ///
  /// Manejo de seguridad:
  /// - Verifica `mounted` antes de llamar a `setState` para evitar errores si el widget
  ///   fue destruido durante la operación asíncrona
  /// - Si `DatabaseService.obtenerCitaAleatoria` devuelve `null`, `_cita` queda `null`
  ///   y el widget no muestra nada (comportamiento silencioso)
  Future<void> _cargarCita() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      debugPrint('⚠️ No hay usuario logueado');
      if (mounted) {
        setState(() => _cargando = false);
      }
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
    if (_cita == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => refresh(), // 👈 Recarga al tocar
      child: Tooltip(
        message: 'Toca para otra cita ✨', // 👈 Feedback sutil
        waitDuration: const Duration(milliseconds: 800),
        child: AnimatedOpacity(
          opacity: _cargando ? 0.5 : 1.0, // 👈 Feedback visual durante carga
          duration: const Duration(milliseconds: 200),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            padding: const EdgeInsets.all(16),
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
                        "\"${_cita?['text'] ?? ''}\"",
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "— ${_cita?['bookTitle'] ?? ''}, ${_cita?['author'] ?? ''}",
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.morado,
                        ),
                      ),
                    ],
                  ),
                ),
                // Icono de refresh sutil (opcional, para dar pista visual)
                if (!_cargando)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.refresh,
                      size: 14,
                      color: Colors.grey[400],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Recarga la cita aleatoria desde Firestore.
  ///
  /// Útil para permitir al usuario obtener una nueva cita sin reconstruir el widget.
  /// Verifica `mounted` antes de actualizar el estado para seguridad.
  Future<void> refresh() async {
    if (_cargando) return; // Evita llamadas duplicadas

    setState(() => _cargando = true);
    await _cargarCita();
  }
}
