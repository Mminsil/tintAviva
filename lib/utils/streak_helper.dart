import 'package:shared_preferences/shared_preferences.dart';

/// Gestion de rachas de lectura consecutivas.
/// 
/// La logica se basa en fechas (sin hora) almacenadas en SharedPreferences.
/// Una racha se incrementa solo si el usuario actualiza su progreso en dias consecutivos.
/// Si pasa un dia sin actualizar, la racha se reinicia a 1.
class StreakHelper {
  static const String _keyLastDate = 'lastReadDate';
  static const String _keyCurrentStreak = 'currentStreak';

  /// Actualiza la racha de lectura.
  /// 
  /// Debe llamarse CADA VEZ que el usuario registre progreso de lectura
  /// (ej: al modificar progreso en EditarLibroPage, al marcar una meta en club, etc).
  /// 
  /// Reglas de negocio:
  /// - Primera vez: racha = 1
  /// - Fecha igual a la ultima registrada: no hacer nada (evita duplicados en el mismo dia)
  /// - Diferencia de 1 dia: incrementa racha en 1
  /// - Diferencia mayor a 1 dia: reinicia racha a 1
  static Future<void> updateStreak() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Obtener fecha actual sin componente horaria
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayString = today.toIso8601String().split('T')[0];

    final lastDateStr = prefs.getString(_keyLastDate);
    int currentStreak = prefs.getInt(_keyCurrentStreak) ?? 0;

    if (lastDateStr == null) {
      // Primer uso: racha inicial
      await prefs.setString(_keyLastDate, todayString);
      await prefs.setInt(_keyCurrentStreak, 1);
    } else {
      final lastDate = DateTime.parse(lastDateStr);
      
      if (today.isAtSameMomentAs(lastDate)) {
        // Ya actualizo hoy: no modificar racha
        return;
      } 
      
      final difference = today.difference(lastDate).inDays;

      if (difference == 1) {
        // Dia consecutivo: incrementar racha
        await prefs.setString(_keyLastDate, todayString);
        await prefs.setInt(_keyCurrentStreak, currentStreak + 1);
      } else if (difference > 1) {
        // Se salto al menos un dia: reiniciar racha
        await prefs.setString(_keyLastDate, todayString);
        await prefs.setInt(_keyCurrentStreak, 1);
      }
    }
  }

  /// Obtiene la racha actual almacenada.
  static Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCurrentStreak) ?? 0;
  }

  /// Genera un mensaje motivacional segun el valor de la racha.
  /// Utilizado para mostrar en el perfil del usuario.
  static String getStreakMessage(int streak) {
    if (streak == 0) return "💤 Tu racha está dormida. ¡Lee hoy para activarla!";
    if (streak == 1) return "🌱 ¡Día 1! Empieza tu hábito lector.";
    if (streak < 7) return "🔥 ¡$streak días seguidos leyendo!";
    if (streak < 30) return "🔥 ¡$streak días! ¡Eres imparable!";
    return "👑 ¡$streak días! Eres una leyenda lectora.";
  }
}