import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Diálogo modal para editar rápidamente el progreso de un libro.
///
/// Propósito:
/// - Permitir al usuario actualizar su progreso de lectura sin navegar a `DetalleLibroPage`
/// - Adaptar la UI según el formato: `'Papel'` (página actual) | `'Digital'` (porcentaje)
/// - Calcular automáticamente el porcentaje para libros en formato papel
/// - Mostrar confetti 🎉 al completar el libro (100% o última página)
///
/// Retorna al padre un `Map<String, int>` con:
/// ```dart
/// {
///   'pagina': int,      // Página actual (0 si es digital)
///   'progreso': int,    // Porcentaje calculado (0-100)
/// }
/// ```
///
/// Casos de retorno:
/// - Input vacío → `{'pagina': 0, 'progreso': 0}`
/// - Valor inválido (no numérico) → `null` + `SnackBar` de error
/// - Papel con página > total → `null` + `SnackBar` de error
/// - Digital con porcentaje fuera de 0-100 → `null` + `SnackBar` de error
/// - Éxito → `Map` con valores calculados
///
/// Características visuales:
/// - **TextField adaptativo**: `maxLength: 5` para papel, `3` para digital
/// - **Suffix dinámico**: `'/ {total}'` para papel, `'%'` para digital
/// - **Confetti overlay**: animación celebratoria al completar el libro
/// - **Validación en tiempo real**: solo dígitos con `FilteringTextInputFormatter.digitsOnly`
///
/// Ejemplo de uso:
/// ```dart
/// // En TarjetaLibroProgreso, desde el botón de edición rápida:
/// final resultado = await showDialog<Map<String, int>>(
///   context: context,
///   builder: (context) => DialogoEdicionRapida(
///     tituloLibro: libro['title'],
///     progresoActual: libro['progress'],
///     formato: libro['format'],
///     paginasTotales: libro['totalPages'],
///     paginaActual: libro['currentPage'],
///   ),
/// );
/// if (resultado != null) {
///   // Actualizar en Firestore vía DatabaseService.actualizarProgresoBiblioteca
///   await DatabaseService.actualizarProgresoBiblioteca(
///     userBookId: docId,
///     formato: formato,
///     porcentaje: formato == 'Digital' ? resultado['progreso'].toDouble() : null,
///     paginaActual: formato == 'Papel' ? resultado['pagina'] : null,
///     totalPaginas: totalPaginas,
///   );
/// }
/// ```
class DialogoEdicionRapida extends StatefulWidget {
  /// Título del libro para contexto en la pregunta del diálogo.
  ///
  /// Se muestra en: `'¿Por qué página vas de "${tituloLibro}"?'` o similar.
  final String tituloLibro;

  /// Progreso actual del libro (0-100) para prellenar el campo.
  final int progresoActual;

  /// Formato del libro: `'Papel'` | `'Digital'`.
  ///
  /// Determina:
  /// - Qué campo mostrar (página vs porcentaje)
  /// - Qué validación aplicar (vs `paginasTotales` vs 0-100)
  /// - Cómo calcular el resultado final
  final String formato;

  /// Total de páginas del libro (solo relevante para formato `'Papel'`).
  ///
  /// Usado para:
  /// - Validar que la página ingresada no supere el total
  /// - Calcular el porcentaje: `(paginaActual / paginasTotales) * 100`
  final int paginasTotales;

  /// Página actual del libro (solo relevante para formato `'Papel'`).
  ///
  /// Se usa como valor inicial del campo de texto.
  final int paginaActual;

  const DialogoEdicionRapida({
    super.key,
    required this.tituloLibro,
    required this.progresoActual,
    required this.formato,
    required this.paginasTotales,
    required this.paginaActual,
  });

  @override
  State<DialogoEdicionRapida> createState() => _DialogoEdicionState();
}

class _DialogoEdicionState extends State<DialogoEdicionRapida> {
  /// Controlador para el campo de texto de progreso/página.
  ///
  /// Se inicializa en `initState` con:
  /// - `paginaActual` si `widget.formato == 'Papel'`
  /// - `progresoActual` si `widget.formato == 'Digital'`
  late TextEditingController _controller;

  /// Controlador para la animación de confetti celebratorio.
  ///
  /// Se reproduce con `_confettiController.play()` al completar el libro.
  late ConfettiController _confettiController;

  /// Bandera para evitar mostrar confetti múltiples veces en una misma sesión.
  ///
  /// Se setea a `true` tras la primera reproducción y nunca se resetea.
  bool _yaMostroConfetti = false;

  @override
  void initState() {
    super.initState();
    // Valor inicial según formato: página actual (Papel) o porcentaje (Digital)
    final String valorInicial = (widget.formato == 'Papel')
        ? widget.paginaActual.toString()
        : widget.progresoActual.toString();
    _controller = TextEditingController(text: valorInicial);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    // Liberar controladores para evitar fugas de memoria
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD: UI DEL DIÁLOGO
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool esPapel = widget.formato == 'Papel';

    return Stack(
      clipBehavior:
          Clip.none, // Permite que el confetti sobresalga del diálogo
      children: [
        // Diálogo principal con formulario de edición
        AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Editar progreso',
            style: TextStyle(
              color: AppColors.morado,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pregunta contextual adaptada al formato
              Text(
                esPapel
                    ? '¿Por qué página vas de "${widget.tituloLibro}"?'
                    : '¿Qué porcentaje llevas de "${widget.tituloLibro}"?',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 15),
              // Campo de texto con validación y suffix dinámico
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                maxLength: esPapel ? 5 : 3,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    AppInputStyles.inputDecoration(
                      esPapel ? 'Página actual' : 'Porcentaje actual',
                    ).copyWith(
                      counterText: "", // Oculta el contador nativo de maxLength
                      suffixText: esPapel ? '/ ${widget.paginasTotales}' : '%',
                      suffixStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                    ),
              ),
            ],
          ),
          actions: [
            // Botón Cancelar: cierra sin acción
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
            // Botón Guardar: valida y devuelve resultado
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.naranja,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _guardar,
              child: const Text('Guardar'),
            ),
          ],
        ),
        // Overlay de confetti para celebración de completado
        ConfettiCelebration(controller: _confettiController),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE GUARDADO Y VALIDACIÓN
  // ─────────────────────────────────────────────────────────────

  /// Valida el input, calcula el progreso (si es papel) y retorna el resultado.
  ///
  /// Flujo detallado:
  /// 1. Obtiene y trimmea el texto del campo
  /// 2. Si está vacío → retorna `{'pagina': 0, 'progreso': 0}`
  /// 3. Parsea a `int`; si falla → muestra error y retorna `null`
  /// 4. Según el formato:
  ///    - **Papel**: valida que `0 <= valor <= paginasTotales`
  ///      - Calcula porcentaje: `(valor / paginasTotales) * 100`
  ///      - Si `paginasTotales == 0`, cualquier valor > 0 → 100%
  ///    - **Digital**: valida que `0 <= valor <= 100`
  /// 5. Si se completa el libro → reproduce confetti vía `_verificarYMostrarConfetti`
  /// 6. Espera 300ms para que se vea el confetti → retorna resultado con `Navigator.pop`
  ///
  /// Manejo de errores:
  /// - Muestra `SnackBar` con mensaje descriptivo para cada caso inválido
  /// - Cierra el diálogo tras mostrar el error para evitar estados inconsistentes
  ///
  /// Seguridad:
  /// - Verifica `mounted` antes de navegar tras el `Future.delayed`
  /// - Usa `.clamp(0, 100).toInt()` para asegurar que el progreso esté en rango válido
  void _guardar() {
    final String texto = _controller.text.trim();
    final bool esPapel = widget.formato == 'Papel';

    if (texto.isEmpty) {
      Navigator.pop(context, {'pagina': 0, 'progreso': 0});
      return;
    }

    final int? valorInput = int.tryParse(texto);

    if (valorInput == null) {
      Navigator.pop(context);
      mostrarSnackBar(context, "Valor inválido", Colors.red);
      return;
    }

    final navigator = Navigator.of(context);

    if (esPapel) {
      if (valorInput < 0 || valorInput > widget.paginasTotales) {
        navigator.pop(context);
        mostrarSnackBar(
          context,
          "La página ($valorInput) supera el total (${widget.paginasTotales})",
          Colors.red,
        );
        return;
      }

      int porcentajeCalculado = 0;
      if (widget.paginasTotales > 0) {
        final double resultado = (valorInput / widget.paginasTotales) * 100;
        porcentajeCalculado = resultado.round();
      } else {
        // Si no hay páginas definidas (paginasTotales = 0), cualquier página > 0 se considera 100%
        porcentajeCalculado = valorInput > 0 ? 100 : 0;
      }

      // Verificar si se completó para confetti
      _verificarYMostrarConfetti(porcentajeCalculado, valorInput);

      // DELAY PARA QUE SE VEA EL CONFETTI
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          navigator.pop({
            'pagina': valorInput,
            'progreso': porcentajeCalculado
                .clamp(0, 100)
                .toInt(), //  .toInt() CLAVE para tipo correcto
          });
        }
      });

      return;
    } else {
      if (valorInput < 0 || valorInput > 100) {
        navigator.pop();
        mostrarSnackBar(
          context,
          "El porcentaje debe estar entre 0 y 100",
          Colors.red,
        );
        return;
      }

      _verificarYMostrarConfetti(valorInput, null);

      // DELAY PARA QUE SE VEA EL CONFETTI
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          navigator.pop({'pagina': 0, 'progreso': valorInput});
        }
      });

      return;
    }
  }

  /// Verifica si el libro se completó y reproduce confetti si es la primera vez.
  ///
  /// Parámetros:
  /// - [nuevoProgreso]: Porcentaje calculado (0-100)
  /// - [paginaInput]: Página ingresada (solo para formato `'Papel'`, puede ser `null`)
  ///
  /// Lógica de completado:
  /// - **Papel**: `paginaInput >= widget.paginasTotales` (si `paginasTotales > 0`)
  /// - **Digital**: `nuevoProgreso >= 100`
  ///
  /// Prevención de repetición:
  /// - Usa `_yaMostroConfetti` para asegurar que el confetti solo se reproduzca una vez por sesión
  /// - Setea la bandera a `true` inmediatamente tras llamar a `play()`
  void _verificarYMostrarConfetti(int nuevoProgreso, int? paginaInput) {
    bool libroCompletado = false;

    if (widget.formato == 'Papel') {
      if (paginaInput != null && widget.paginasTotales > 0) {
        libroCompletado = paginaInput >= widget.paginasTotales;
      }
    } else {
      libroCompletado = nuevoProgreso >= 100;
    }

    if (libroCompletado && !_yaMostroConfetti) {
      _yaMostroConfetti = true;
      _confettiController.play(); // 🎉
    }
  }
}
