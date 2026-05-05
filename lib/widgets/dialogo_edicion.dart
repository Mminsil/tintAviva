import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Diálogo reutilizable para editar el progreso de un libro de forma rápida.
///
/// Se adapta al formato del libro:
/// - **Papel:** Pide la página actual y calcula el porcentaje automáticamente.
/// - **Digital:** Pide directamente el porcentaje leído.
class DialogoEdicion extends StatefulWidget {
  final String tituloLibro;
  final int progresoActual;
  final String formato;
  final int paginasTotales;
  final int paginaActual;

  const DialogoEdicion({
    super.key,
    required this.tituloLibro,
    required this.progresoActual,
    required this.formato,
    required this.paginasTotales,
    required this.paginaActual,
  });

  @override
  State<DialogoEdicion> createState() => _DialogoEdicionState();
}

class _DialogoEdicionState extends State<DialogoEdicion> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    // Inicializamos el controlador con el valor relevante según el formato.
    // Si es Papel, mostramos la página; si es Digital, el porcentaje.
    String valorInicial = (widget.formato == 'Papel')
        ? widget.paginaActual.toString()
        : widget.progresoActual.toString();

    _controller = TextEditingController(text: valorInicial);
  }

  @override
  Widget build(BuildContext context) {
    bool esPapel = widget.formato == 'Papel';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(
        'Editar progreso',
        style: TextStyle(color: AppColors.morado, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Texto dinámico según el tipo de libro.
          Text(
            esPapel
                ? '¿Por qué página vas de "${widget.tituloLibro}"?'
                : '¿Qué porcentaje llevas de "${widget.tituloLibro}"?',
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            maxLength: esPapel ? 5 : 3, // Límite de caracteres según formato.
            decoration: InputDecoration(
              counterText: "", // Ocultamos el contador nativo de Flutter.
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
          onPressed: () {
            final texto = _controller.text.trim();
            int? valorInput = int.tryParse(texto);

            if (esPapel) {
              // Validación para formato Papel: debe estar entre 0 y total de páginas.
              if (valorInput == null ||
                  valorInput < 0 ||
                  valorInput > widget.paginasTotales) {
                mostrarSnackBar(
                  context,
                  "Introduce una página válida (0-${widget.paginasTotales})",
                  Colors.red,
                );
                return;
              }

              // Cálculo del porcentaje basado en la página ingresada.
              int porcentajeCalculado =
                  ((valorInput / widget.paginasTotales) * 100).round();

              // Devolvemos tanto la página como el porcentaje calculado.
              Navigator.pop(context, {
                'pagina': valorInput,
                'progreso': porcentajeCalculado,
              });
            } else {
              // Validación para formato Digital: debe estar entre 0 y 100.
              if (valorInput == null || valorInput < 0 || valorInput > 100) {
                mostrarSnackBar(
                  context,
                  "Introduce un porcentaje válido (0-100)",
                  Colors.red,
                );
                return;
              }

              // En digital, el input es directamente el progreso.
              Navigator.pop(context, {'pagina': 0, 'progreso': valorInput});
            }
          },
          child: const Text('Guardar', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
