import 'package:shared_preferences/shared_preferences.dart';

/// Gestión de rachas de lectura consecutivas.
///
/// La lógica se basa en fechas (sin hora) almacenadas en `SharedPreferences`.
/// Una racha se incrementa solo si el usuario actualiza su progreso en días consecutivos.
/// Si pasa un día sin actualizar, la racha se reinicia a 1.
///
/// Reglas de negocio:
/// - **Primera vez**: racha = 1
/// - **Misma fecha**: no hacer nada (evita duplicados en el mismo día)
/// - **Diferencia de 1 día**: incrementa racha en 1
/// - **Diferencia > 1 día**: reinicia racha a 1
///
/// Uso recomendado:
/// - Llamar a `updateStreak()` cada vez que el usuario registre progreso:
///   - Al modificar progreso en `EditarLibroPage`
///   - Al marcar una meta en un club
///   - Al completar un libro
class StreakHelper {
  /// Clave para almacenar la última fecha de lectura en `SharedPreferences`.
  ///
  /// Formato: `YYYY-MM-DD` (ISO 8601 sin componente horaria)
  static const String _keyLastDate = 'lastReadDate';

  /// Clave para almacenar el contador de racha actual en `SharedPreferences`.
  ///
  /// Valor: `int` ≥ 0
  static const String _keyCurrentStreak = 'currentStreak';

  /// Actualiza la racha de lectura.
  ///
  /// Debe llamarse **CADA VEZ** que el usuario registre progreso de lectura
  /// (ej: al modificar progreso en `EditarLibroPage`, al marcar una meta en club, etc).
  ///
  /// Reglas de negocio:
  /// 1. **Primera vez**: racha = 1
  /// 2. **Fecha igual a la última registrada**: no hacer nada (evita duplicados en el mismo día)
  /// 3. **Diferencia de 1 día**: incrementa racha en 1
  /// 4. **Diferencia mayor a 1 día**: reinicia racha a 1
  ///
  /// Persistencia:
  /// - Usa `SharedPreferences` para guardar `_keyLastDate` y `_keyCurrentStreak`
  /// - Las fechas se almacenan como `String` en formato ISO 8601 (`YYYY-MM-DD`)
  ///
  /// Ejemplo de uso:
  /// ```dart
  /// // En EditarLibroPage, tras guardar cambios:
  /// await DatabaseService.editarLibroYStats(...);
  /// await StreakHelper.updateStreak(); // 👈 Actualiza la racha
  /// ```
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
        // Ya actualizó hoy: no modificar racha
        return;
      } 
      
      final difference = today.difference(lastDate).inDays;

      if (difference == 1) {
        // Día consecutivo: incrementar racha
        await prefs.setString(_keyLastDate, todayString);
        await prefs.setInt(_keyCurrentStreak, currentStreak + 1);
      } else if (difference > 1) {
        // Se saltó al menos un día: reiniciar racha
        await prefs.setString(_keyLastDate, todayString);
        await prefs.setInt(_keyCurrentStreak, 1);
      }
    }
  }

  /// Obtiene la racha actual almacenada en `SharedPreferences`.
  ///
  /// Retorna:
  /// - `Future<int>` con el valor de la racha, o `0` si no está configurada
  ///
  /// Uso típico:
  /// ```dart
  /// // En PerfilPage, para mostrar la racha:
  /// final streak = await StreakHelper.getCurrentStreak();
  /// setState(() => _streak = streak);
  /// ```
  static Future<int> getCurrentStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyCurrentStreak) ?? 0;
  }

  /// Genera un mensaje motivacional según el valor de la racha.
  ///
  /// Utilizado para mostrar en el perfil del usuario como feedback gamificado.
  ///
  /// Parámetros:
  /// - [streak]: Número de días consecutivos de lectura (≥ 0)
  ///
  /// Retorna:
  /// - `String` con mensaje + emoji según el rango de la racha:
  ///   - `0`: "💤 Tu racha está dormida..."
  ///   - `1`: "🌱 ¡Día 1!..."
  ///   - `2-6`: "🔥 ¡X días seguidos..."
  ///   - `7-29`: "🔥 ¡X días! ¡Eres imparable!"
  ///   - `≥30`: "👑 ¡X días! Eres una leyenda..."
  ///
  /// Ejemplo:
  /// ```dart
  /// Text(StreakHelper.getStreakMessage(_streak))
  /// // Si _streak = 15 → "🔥 ¡15 días! ¡Eres imparable!"
  /// ```
  static String getStreakMessage(int streak) {
    if (streak == 0) return "💤 Tu racha está dormida. ¡Lee hoy para activarla!";
    if (streak == 1) return "🌱 ¡Día 1! Empieza tu hábito lector.";
    if (streak < 7) return "🔥 ¡$streak días seguidos leyendo!";
    if (streak < 30) return "🔥 ¡$streak días! ¡Eres imparable!";
    return "👑 ¡$streak días! Eres una leyenda lectora.";
  }
}