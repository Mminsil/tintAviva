import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:flutter/services.dart';
import 'package:confetti/confetti.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Dialogo modal para editar rapidamente el progreso de un libro.
///
/// Se adapta al formato del libro:
/// - Papel: Muestra campo para ingresar pagina actual. Calcula porcentaje automaticamente.
/// - Digital: Muestra campo para ingresar porcentaje directamente (0 a 100).
///
/// Retorna un Map&lt;String, int&gt; con las claves 'pagina' y 'progreso'.
/// Si el usuario cancela o ingresa valor invalido, retorna null.
/// Muestra confetti 🎉 cuando el usuario marca el libro como completado (100% o última página).
class DialogoEdicionRapida extends StatefulWidget {
  final String tituloLibro;
  final int progresoActual;
  final String formato;
  final int paginasTotales;
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
  late TextEditingController _controller;
  late ConfettiController _confettiController;
   bool _yaMostroConfetti = false;

  @override
  void initState() {
    super.initState();
    // Valor inicial segun formato: pagina actual (Papel) o porcentaje (Digital)
    String valorInicial = (widget.formato == 'Papel')
        ? widget.paginaActual.toString()
        : widget.progresoActual.toString();
    _controller = TextEditingController(text: valorInicial);
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool esPapel = widget.formato == 'Papel';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(
            'Editar progreso',
            style: TextStyle(color: AppColors.morado, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                esPapel
                    ? '¿Por qué página vas de "${widget.tituloLibro}"?'
                    : '¿Qué porcentaje llevas de "${widget.tituloLibro}"?',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                maxLength: esPapel ? 5 : 3,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: "",
                  labelText: esPapel ? 'Página actual' : 'Porcentaje actual',
                  suffixText: esPapel ? '/ ${widget.paginasTotales}' : '%',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranja),
              onPressed: _guardar,
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        ConfettiCelebration(controller: _confettiController),
      ],
    );
  }


  /// Valida el input, calcula el progreso (si es papel) y retorna el resultado.
  ///
  /// Casos de retorno:
  /// - Input vacio: retorna {'pagina': 0, 'progreso': 0}
  /// - Valor invalido (no numerico): muestra error y retorna null
  /// - Papel con pagina > totalPaginas: muestra error y retorna null
  /// - Digital con porcentaje fuera de 0-100: muestra error y retorna null
  /// - Exito: retorna Map con los valores calculados
  void _guardar() {
    final texto = _controller.text.trim();
    bool esPapel = widget.formato == 'Papel';

    if (texto.isEmpty) {
      Navigator.pop(context, {'pagina': 0, 'progreso': 0});
      return;
    }

    int? valorInput = int.tryParse(texto);

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
        double resultado = (valorInput / widget.paginasTotales) * 100;
        porcentajeCalculado = resultado.round();
      } else {
        // Si no hay paginas definidas (paginasTotales = 0), cualquier pagina > 0 se considera 100%
        porcentajeCalculado = valorInput > 0 ? 100 : 0;
      }

      // Verificar si se completó para confetti
      _verificarYMostrarConfetti(porcentajeCalculado, valorInput);

      // 👇 DELAY PARA QUE SE VEA EL CONFETTI
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          navigator.pop({
            'pagina': valorInput,
            'progreso': porcentajeCalculado.clamp(0, 100).toInt(), // 👇 .toInt() CLAVE
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

      // 👇 DELAY PARA QUE SE VEA EL CONFETTI
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          navigator.pop({
            'pagina': 0,
            'progreso': valorInput,
          });
        }
      });
      
      return;
    }
  }

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

