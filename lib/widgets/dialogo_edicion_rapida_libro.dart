import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart'; // ← Aquí están tus funciones de tiempo

/// Diálogo modal para editar rápidamente el progreso de un libro.
///
/// Soporta tres formatos:
/// - `'Papel'`: edita página actual, calcula porcentaje automáticamente
/// - `'Digital'`: edita porcentaje directamente (0-100)
/// - `'Audio'`: edita tiempo actual (MM:SS o HH:MM:SS), calcula porcentaje desde segundos
///
/// Retorna al padre un `Map<String, dynamic>` con:
/// ```dart
/// {
///   'pagina': int?,           // Página actual (solo Papel, null si no aplica)
///   'progreso': int,          // Porcentaje calculado (0-100)
///   'currentSeconds': int?,   // Segundos reproducidos (solo Audio, null si no aplica)
/// }
/// ```
class DialogoEdicionRapida extends StatefulWidget {
  final String tituloLibro;
  final int progresoActual;
  final String formato;
  final int paginasTotales;
  final int paginaActual;
  final int? totalSeconds; // ← NUEVO: para Audio
  final int? currentSeconds; // ← NUEVO: para Audio

  const DialogoEdicionRapida({
    super.key,
    required this.tituloLibro,
    required this.progresoActual,
    required this.formato,
    required this.paginasTotales,
    required this.paginaActual,
    this.totalSeconds,
    this.currentSeconds,
  });

  @override
  State<DialogoEdicionRapida> createState() => _DialogoEdicionState();
}

class _DialogoEdicionState extends State<DialogoEdicionRapida> {
  late TextEditingController _controller;
  late ConfettiController _confettiController;
  bool _yaMostroConfetti = false;

  @override
  void initState() {
    super.initState();

    // ✅ CORREGIDO: Inicializar el valor según el formato
    String valorInicial;

    if (widget.formato == 'Papel') {
      // Para Papel: mostrar página actual
      valorInicial = widget.paginaActual.toString();
    } else if (widget.formato == 'Audio' && widget.currentSeconds != null) {
      // ✅ Para Audio: convertir segundos a tiempo legible (MM:SS o HH:MM:SS)
      valorInicial = segundosATiempo(widget.currentSeconds!);
    } else {
      // Para Digital: mostrar porcentaje
      valorInicial = widget.progresoActual.toString();
    }

    _controller = TextEditingController(text: valorInicial);
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final esPapel = widget.formato == 'Papel';
    final esAudio = widget.formato == 'Audio';

    return Stack(
      clipBehavior: Clip.none,
      children: [
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
                    : esAudio
                    ? '¿En qué minuto vas de "${widget.tituloLibro}"?'
                    : '¿Qué porcentaje llevas de "${widget.tituloLibro}"?',
                style: TextStyle(color: Colors.grey[700], fontSize: 14),
              ),
              const SizedBox(height: 15),

              // Campo de texto adaptativo
              TextField(
                controller: _controller,
                keyboardType: esAudio
                    ? TextInputType.datetime
                    : TextInputType.number,
                maxLength: esAudio ? 8 : (esPapel ? 5 : 3),
                inputFormatters: esAudio
                    ? [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
                      ] // Permitir ":" para tiempo
                    : [FilteringTextInputFormatter.digitsOnly],
                decoration:
                    AppInputStyles.inputDecoration(
                      esPapel
                          ? 'Página actual'
                          : (esAudio ? 'Tiempo actual' : 'Porcentaje actual'),
                    ).copyWith(
                      counterText: "",
                      suffixText: esPapel
                          ? '/ ${widget.paginasTotales}'
                          : (esAudio ? '⏱️' : '%'),
                      suffixStyle: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                      ),
                      helperText: esAudio ? 'Formato: MM:SS o HH:MM:SS' : null,
                      helperStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancelar',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
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
        ConfettiCelebration(controller: _confettiController),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE GUARDADO Y VALIDACIÓN
  // ─────────────────────────────────────────────────────────────

  void _guardar() {
    final String texto = _controller.text.trim();
    final bool esPapel = widget.formato == 'Papel';
    final bool esAudio = widget.formato == 'Audio';

    // Caso vacío: retornar ceros
    if (texto.isEmpty) {
      if (mounted) {
        Navigator.pop(context, {
          'pagina': null,
          'progreso': 0,
          'currentSeconds': null,
        });
      }
      return;
    }

    if (!mounted) return;

    final navigator = Navigator.of(context);

    if (esPapel) {
      _guardarPapel(navigator, texto);
    } else if (esAudio) {
      _guardarAudio(navigator, texto);
    } else {
      _guardarDigital(navigator, texto);
    }
  }

  /// Lógica específica para formato Papel.
  void _guardarPapel(NavigatorState navigator, String texto) {
    final int? valorInput = int.tryParse(texto);
    if (valorInput == null) {
      if (mounted) {
        navigator.pop(context);
        mostrarSnackBar(context, "Valor inválido", Colors.red);
      }
      return;
    }
    if (valorInput < 0 || valorInput > widget.paginasTotales) {
      if (mounted) {
        navigator.pop(context);
        mostrarSnackBar(
          context,
          "La página ($valorInput) supera el total (${widget.paginasTotales})",
          Colors.red,
        );
      }
      return;
    }

    // Calcular porcentaje
    int porcentajeCalculado = widget.paginasTotales > 0
        ? ((valorInput / widget.paginasTotales) * 100).round()
        : (valorInput > 0 ? 100 : 0);

    _verificarYMostrarConfetti(porcentajeCalculado, paginaInput: valorInput);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && context.mounted) {
        navigator.pop({
          'pagina': valorInput,
          'progreso': porcentajeCalculado.clamp(0, 100),
          'currentSeconds': null,
        });
      }
    });
  }

  /// Lógica específica para formato Digital.
  void _guardarDigital(NavigatorState navigator, String texto) {
    final int? valorInput = int.tryParse(texto);
    if (valorInput == null || valorInput < 0 || valorInput > 100) {
      if (mounted) {
        navigator.pop(context);
        mostrarSnackBar(
          context,
          "El porcentaje debe estar entre 0 y 100",
          Colors.red,
        );
      }
      return;
    }

    _verificarYMostrarConfetti(valorInput);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && context.mounted) {
        navigator.pop({
          'pagina': null,
          'progreso': valorInput,
          'currentSeconds': null,
        });
      }
    });
  }

  /// Lógica específica para formato Audio.
  void _guardarAudio(NavigatorState navigator, String texto) {
    // ✅ Usar las funciones de ui_helpers.dart
    final int? segundosActuales = tiempoASegundos(texto);
    final int? totalSeg = widget.totalSeconds;

    if (segundosActuales == null) {
      if (mounted) {
        navigator.pop(context);
        mostrarSnackBar(
          context,
          "Formato de tiempo inválido (usa MM:SS o HH:MM:SS)",
          Colors.red,
        );
      }
      return;
    }
    if (totalSeg == null || totalSeg <= 0) {
      if (mounted) {
        navigator.pop(context);
        mostrarSnackBar(
          context,
          "Error: duración total no definida",
          Colors.red,
        );
        return;
      }
    }
    if (segundosActuales < 0 || segundosActuales > totalSeg!) {
      if (mounted) {
        navigator.pop(context);
        mostrarSnackBar(
          context,
          "El tiempo actual no puede superar la duración total (${segundosATiempo(totalSeg!)})",
          Colors.red,
        );
      }
      return;
    }

    // Calcular porcentaje: (actual / total) * 100
    final porcentajeCalculado = ((segundosActuales / totalSeg) * 100)
        .round()
        .clamp(0, 100);

    _verificarYMostrarConfetti(
      porcentajeCalculado,
      currentSeconds: segundosActuales,
      totalSeconds: totalSeg,
    );

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted && context.mounted) {
        navigator.pop({
          'pagina': null,
          'progreso': porcentajeCalculado,
          'currentSeconds':
              segundosActuales, // ← RETORNAR SEGUNDOS PARA ACTUALIZAR
        });
      }
    });
  }

  /// Verifica si el libro/audio se completó y reproduce confetti si es la primera vez.
  void _verificarYMostrarConfetti(
    int nuevoProgreso, {
    int? paginaInput,
    int? currentSeconds,
    int? totalSeconds,
  }) {
    bool libroCompletado = false;

    if (widget.formato == 'Papel') {
      if (paginaInput != null && widget.paginasTotales > 0) {
        libroCompletado = paginaInput >= widget.paginasTotales;
      }
    } else if (widget.formato == 'Audio') {
      if (currentSeconds != null && totalSeconds != null && totalSeconds > 0) {
        libroCompletado = currentSeconds >= totalSeconds;
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
