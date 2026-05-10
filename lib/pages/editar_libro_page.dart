import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:confetti/confetti.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Pantalla de edicion de un libro en la biblioteca personal.
/// Permite modificar: estanteria, formato (Papel/Digital), progreso, puntuacion,
/// genero, sinopsis, notas, portada y paginas.
/// Incluye logica de conversion entre formato papel (paginas) y digital (porcentaje).
/// Al completar un libro (estanteria cambia a 'Leido') muestra confetti.
class EditarLibroPage extends StatefulWidget {
  final String userBookId;
  final String bookId;
  final Map<String, dynamic> datosActuales;

  const EditarLibroPage({
    super.key,
    required this.userBookId,
    required this.bookId,
    required this.datosActuales,
  });

  @override
  State<EditarLibroPage> createState() => _EditarLibroPageState();
}

class _EditarLibroPageState extends State<EditarLibroPage>
    with TickerProviderStateMixin {
  // Estado local del formulario
  late String _estanteria;
  late double _progreso;
  late double _puntuacion;
  late String _formatoSeleccionado;

  // Controladores de campos de texto
  late TextEditingController _generoController;
  late TextEditingController _sinopsisController;
  late TextEditingController _notasController;
  late TextEditingController _paginaActualController;
  late TextEditingController _paginasTotalesController;
  late TextEditingController _bookCoverController;

  // Controlador para la animacion de confeti
  late ConfettiController _confettiController;
  int? _paginaActualGuardada;

  @override
  void initState() {
    super.initState();

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    // Inicializar estado desde datosActuales
    _estanteria = widget.datosActuales['shelf'] ?? 'Leyendo';
    _progreso = (widget.datosActuales['progress'] ?? 0).toDouble();
    _puntuacion = (widget.datosActuales['rating'] ?? 0).toDouble();
    _formatoSeleccionado = widget.datosActuales['format'] ?? 'Digital';

    _generoController = TextEditingController(
      text: widget.datosActuales['genre'] ?? "",
    );
    _sinopsisController = TextEditingController(
      text: widget.datosActuales['synopsis'] ?? "",
    );
    _notasController = TextEditingController(
      text: widget.datosActuales['notes'] ?? "",
    );

    _paginasTotalesController = TextEditingController(
      text:
          (widget.datosActuales['totalPages'] ??
                  widget.datosActuales['pages'] ??
                  "0")
              .toString(),
    );

    _paginaActualController = TextEditingController(
      text: (widget.datosActuales['currentPage'] ?? "0").toString(),
    );

    _bookCoverController = TextEditingController(
      text: widget.datosActuales['bookCover'] ?? "",
    );

    _paginaActualGuardada = widget.datosActuales['currentPage'] ?? 0;
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _generoController.dispose();
    _sinopsisController.dispose();
    _notasController.dispose();
    _paginaActualController.dispose();
    _paginasTotalesController.dispose();
    _bookCoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        title: const Text("Editar Libro", style: AppTextStyles.sectionTitle),
        backgroundColor: AppColors.blanco,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.morado),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Estado y Progreso",
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 10),

                Card(
                  color: AppColors.blanco,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Selector de estanteria: Leyendo, Leido, Por leer
                        DropdownButtonFormField<String>(
                          initialValue: _estanteria,
                          decoration: AppInputStyles.inputDecoration(
                            "Estantería",
                          ),
                          items: ['Leyendo', 'Leído', 'Por leer'].map((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: _onEstanteriaChanged,
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          "Formato del Libro",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        // SegmentedButton para alternar entre Papel y Digital
                        // Cambiar formato dispara conversion de progreso
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(
                              value: 'Papel',
                              label: Text('Papel'),
                              icon: Icon(Icons.menu_book),
                            ),
                            ButtonSegment(
                              value: 'Digital',
                              label: Text('Digital'),
                              icon: Icon(Icons.tablet_android),
                            ),
                          ],
                          selected: {_formatoSeleccionado},
                          onSelectionChanged: _onFormatoChanged,
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: AppColors.morado,
                            selectedForegroundColor: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Control de progreso: slider para Digital, solo informativo para Papel
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Progreso",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "${_progreso.toInt()}%",
                              style: const TextStyle(
                                color: AppColors.naranja,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (_formatoSeleccionado == 'Digital')
                          Slider(
                            value: _progreso.clamp(0.0, 100.0),
                            max: 100,
                            divisions: 100,
                            activeColor: AppColors.naranja,
                            inactiveColor: AppColors.naranja.withValues(
                              alpha: 0.3,
                            ),
                            onChanged: (value) {
                              setState(() {
                                _progreso = value;
                                // Al mover slider Digital, actualizar estanteria automaticamente
                                if (_progreso >= 100) {
                                  _estanteria = 'Leído';
                                } else if (_progreso > 0) {
                                  _estanteria = 'Leyendo';
                                } else {
                                  _estanteria = 'Por leer';
                                }
                              });
                            },
                          )
                        else
                          // En modo Papel, la barra es solo visual (no editable directamente)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progreso / 100,
                              backgroundColor: Colors.grey[200],
                              color: AppColors.naranja,
                              minHeight: 8,
                            ),
                          ),

                        const SizedBox(height: 20),

                        // Campos de paginas: solo visibles/editables cuando formato es Papel
                        if (_formatoSeleccionado == 'Papel')
                          Row(
                            children: [
                              Expanded(
                                child: buildNumberField(
                                  label: 'Pág. Actual',
                                  controller: _paginaActualController,
                                  maxPages: int.tryParse(
                                    _paginasTotalesController.text,
                                  ),
                                  onChanged: (_) => _recalcularProgreso(),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: buildNumberField(
                                  label: 'Total Págs.',
                                  controller: _paginasTotalesController,
                                  isTotalField: true,
                                  onChanged: (_) => _recalcularProgreso(),
                                ),
                              ),
                            ],
                          )
                        else
                          buildNumberField(
                            label: 'Total Págs. (Referencia)',
                            controller: _paginasTotalesController,
                            isTotalField: true,
                          ),

                        const SizedBox(height: 20),
                        const Text(
                          "Puntuación",
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 5),
                        // Selector de estrellas (1 a 5)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            return GestureDetector(
                              onTap: () =>
                                  setState(() => _puntuacion = index + 1.0),
                              child: Icon(
                                index < _puntuacion
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                color: index < _puntuacion
                                    ? Colors.amber
                                    : Colors.grey[400],
                                size: 35,
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                const Text(
                  "Detalles del Libro",
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 10),
                Card(
                  color: AppColors.blanco,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Portada Personalizada",
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppColors.morado,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          textCapitalization: TextCapitalization.sentences,
                          enableInteractiveSelection: true,
                          autocorrect: true,

                          controller: _bookCoverController,
                          decoration: AppInputStyles.inputDecoration(
                            "URL de la imagen",
                            prefixIcon: Icons.link,
                          ),
                          keyboardType: TextInputType.url,
                        ),
                        // Preview de la portada si hay URL
                        if (_bookCoverController.text.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _bookCoverController.text,
                                height: 120,
                                width: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 120,
                                  width: 80,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.broken_image),
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 15),
                        _buildTextField("Género", _generoController),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                const Text("Notas", style: AppTextStyles.sectionTitle),
                const SizedBox(height: 10),
                Card(
                  color: AppColors.blanco,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildTextField(
                          "Escribe tus apuntes personales sobre este libro...",
                          _notasController,
                          lines:
                              5, // 👈 Más líneas para que sea más cómodo escribir
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),

          // Widget de confeti que se activa al completar un libro
          ConfettiCelebration(controller: _confettiController),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _guardarCambios,
        backgroundColor: AppColors.naranja,
        label: const Text(
          "Guardar cambios",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  /// Campo de texto reutilizable con configuracion comun.
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int lines = 1,
    bool isNumber = false,
    bool isReadOnly = false,
    Function(String)? onChanged,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      readOnly: isReadOnly,
      enabled: !isReadOnly,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      textCapitalization: TextCapitalization.sentences,
      enableInteractiveSelection: true,
      autocorrect: true,
      decoration: AppInputStyles.inputDecoration(label).copyWith(
        filled: isReadOnly,
        fillColor: isReadOnly ? Colors.grey[100] : null,
      ),
    );
  }

  /// Maneja cambios manuales en el dropdown de estanteria.
  /// Muestra dialogo de confirmacion si cambiar implica perder progreso.
  /// Al confirmar, actualiza _progreso y _paginaActualController segun la nueva estanteria.
  void _onEstanteriaChanged(String? newValue) async {
    if (newValue == null || newValue == _estanteria) return;

    final String oldShelf = _estanteria;
    final int currentProgress = _progreso.toInt();
    final int totalPages =
        int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    final int currentPage =
        int.tryParse(_paginaActualController.text.trim()) ?? 0;

    bool confirmar = true;
    String mensaje = "";
    String titulo = "";

    // Logica de confirmacion para transiciones criticas
    if (oldShelf == 'Leyendo' &&
        (newValue == 'Leído' || newValue == 'Por leer')) {
      titulo = "¿Perder progreso?";
      mensaje =
          "El libro está al $currentProgress%. Si cambias a '$newValue', el progreso se actualizará (${newValue == 'Leído' ? '100%' : '0%'}). ¿Continuar?";
    } else if (oldShelf == 'Leído' &&
        (newValue == 'Leyendo' || newValue == 'Por leer')) {
      titulo = "¿Volver a leer?";
      mensaje =
          "Ya marcaste este libro como 'Leído'. Al cambiar a '$newValue', reiniciaremos el progreso a 0%. ¿Seguro?";
    }

    if ((oldShelf == 'Leyendo' || oldShelf == 'Leído') &&
        newValue != oldShelf) {
      confirmar =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Text(mensaje),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.naranja,
                  ),
                  child: const Text(
                    "Sí, cambiar",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ) ??
          false;
    }

    if (!confirmar) return;

    // Aplicar cambios locales segun la nueva estanteria
    setState(() {
      _estanteria = newValue;

      if (newValue == 'Leído') {
        _progreso = 100.0;
        _paginaActualController.text = totalPages > 0
            ? totalPages.toString()
            : "0";
        _paginaActualGuardada = currentPage;
      } else if (newValue == 'Por leer') {
        _progreso = 0.0;
        _paginaActualController.text = "1";
        _paginaActualGuardada = currentPage;
      } else if (newValue == 'Leyendo') {
        // Restaurar progreso guardado o calcular desde pagina actual
        if (_paginaActualGuardada != null && _paginaActualGuardada! > 0) {
          // Si la página guardada era el TOTAL, reiniciamos a 0 (para relectura)
          // Si no, restauramos la página guardada tal cual
          if (_paginaActualGuardada == totalPages) {
            _paginaActualController.text = "0";
          } else {
            _paginaActualController.text = _paginaActualGuardada.toString();
          }

          // Recalcular progreso basado en el nuevo valor del input
          final int paginaParaCalculo =
              int.tryParse(_paginaActualController.text.trim()) ?? 0;
          if (totalPages > 0) {
            _progreso = ((paginaParaCalculo / totalPages) * 100).clamp(
              0.0,
              100.0,
            );
          }
        } else {
          final int actual =
              int.tryParse(_paginaActualController.text.trim()) ?? 0;
          if (totalPages > 0) {
            _progreso = ((actual / totalPages) * 100).clamp(0.0, 100.0);
          }
        }
      }
    });

    // Mensaje motivacional al empezar a leer un libro
    if (oldShelf == 'Por leer' && newValue == 'Leyendo') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mostrarSnackBar(
          context,
          "📖 ¡Qué ilusión! Has empezado a leer '${widget.datosActuales['title']}'.",
          AppColors.naranja,
        );
      });
    }

    // Mensaje motivacional al empezar a leer un libro
    if (oldShelf == 'Leído' && newValue == 'Leyendo') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mostrarSnackBar(
          context,
          "📖 ¿Te gustó '${widget.datosActuales['title']}'? Crea un club y comparte con tus amigos.",
          AppColors.naranja,
        );
      });
    }
  }

  /// Convierte el progreso entre formato Papel y Digital.
  /// Papel -> Digital: paginas actual / totales = porcentaje
  /// Digital -> Papel: porcentaje * totales = paginas calculadas
  void _onFormatoChanged(Set<String> newSelection) {
    final nuevoFormato = newSelection.first;
    if (nuevoFormato == _formatoSeleccionado) return;

    setState(() {
      final int totales =
          int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
      final int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;

      if (nuevoFormato == 'Papel') {
        // Digital a Papel
        if (totales > 0) {
          int paginasCalculadas = ((_progreso / 100) * totales).round();
          _paginaActualController.text = paginasCalculadas.toString();
        } else {
          _paginaActualController.text = "0";
        }
      } else {
        // Papel a Digital
        if (totales > 0) {
          _progreso = ((actual / totales) * 100).clamp(0.0, 100.0);
        } else {
          _progreso = 0.0;
        }
      }

      _formatoSeleccionado = nuevoFormato;
    });
  }

  /// Recalcula el porcentaje de progreso basado en pagina actual y totales.
  /// Solo se ejecuta en formato Papel. Ademas actualiza la estanteria segun el nuevo progreso.
  void _recalcularProgreso() {
    final bool esPapel = _formatoSeleccionado == 'Papel';
    if (!esPapel) return;

    final int totales =
        int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    final int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;

    if (totales > 0) {
      setState(() {
        _progreso = ((actual / totales) * 100).clamp(0.0, 100.0);

        if (actual > totales) {
          _paginaActualController.text = totales.toString();
          _progreso = 100.0;
        }

        // Sincronizar estanteria con el progreso calculado
        if (_progreso < 100 && _estanteria == 'Leído') {
          _estanteria = 'Leyendo';
        } else if (_progreso >= 100 && _estanteria != 'Leído') {
          _estanteria = 'Leído';
        } else if (_progreso == 0 && _estanteria != 'Por leer') {
          _estanteria = 'Por leer';
        }
      });
    } else {
      setState(() => _progreso = 0.0);
    }
  }

  /// Guarda todos los cambios en Firestore.
  /// Si el libro pasa a estado 'Leido' por primera vez, activa confeti.
  /// Usa DatabaseService.editarLibroYStats que ademas actualiza las estadisticas del usuario.
  Future<void> _guardarCambios() async {
    try {
      final formato = _formatoSeleccionado;
      int totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
      int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
      int progresoFinal = _progreso.toInt();

      // Validacion: pagina actual no puede superar al total (Solo Papel)
      if (formato == 'Papel' && totales > 0 && actual > totales) {
        mostrarSnackBar(
          context,
          "La página actual ($actual) no puede superar al total ($totales)",
          Colors.red,
        );
        return;
      }

      //Detectar si el progreso o página ha disminuido
      final progresoRaw = widget.datosActuales['progress'];
      final paginaRaw = widget.datosActuales['currentPage'];

      final int progresoOriginal = progresoRaw is int
          ? progresoRaw
          : (progresoRaw is double ? progresoRaw.toInt() : 0);

      final int paginaOriginal = paginaRaw is int
          ? paginaRaw
          : (paginaRaw is double ? paginaRaw.toInt() : 0);

      bool haDisminuido = false;
      String mensajeConfirmacion = "";

      if (formato == 'Papel') {
        // En formato Papel, comparamos páginas
        if (actual < paginaOriginal && paginaOriginal > 0) {
          haDisminuido = true;
          mensajeConfirmacion =
              "Has indicado la página $actual, menor a la anterior ($paginaOriginal). ¿Seguro que quieres retroceder?";
        }
      } else {
        // En formato Digital, comparamos porcentaje
        if (progresoFinal < progresoOriginal && progresoOriginal > 0) {
          haDisminuido = true;
          mensajeConfirmacion =
              "Has indicado $progresoFinal%, menor al anterior ($progresoOriginal%). ¿Seguro que quieres retroceder?";
        }
      }

      if (haDisminuido) {
        final bool? confirmar = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              "¿Disminuir progreso?",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(mensajeConfirmacion),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Sí, disminuir",
                  style: TextStyle(
                    color: AppColors.naranja,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );

        // Si el usuario cancela o el contexto no está montado, salir sin guardar
        if (confirmar != true || !mounted) return;
      }

      // Recalcular progreso si es formato Papel
      if (formato == 'Papel' && totales > 0) {
        progresoFinal = ((actual / totales) * 100).round().clamp(0, 100);
      }

      // Auto-actualizar estantería si se completó el libro
      if (progresoFinal >= 100) _estanteria = 'Leído';

      final bool esNuevoLeido =
          (_estanteria == 'Leído' && widget.datosActuales['shelf'] != 'Leído');

      Map<String, dynamic> datosUserBook = {
        'shelf': _estanteria,
        'progress': progresoFinal,
        'rating': _puntuacion,
        'notes': _notasController.text,
        'totalPages': totales,
        'currentPage': formato == 'Papel' ? actual : 0,
        'format': formato,
        'dateFinished': _estanteria == 'Leído'
            ? FieldValue.serverTimestamp()
            : null,
        'bookCover': _bookCoverController.text.trim(),
      };

      Map<String, dynamic> datosCatalogo = {'genre': _generoController.text};

      // Llamada al servicio que actualiza user_books, books y estadisticas del usuario
      await DatabaseService.editarLibroYStats(
        userBookId: widget.userBookId,
        bookId: widget.bookId,
        userId: widget.datosActuales['userId'],
        oldShelf: widget.datosActuales['shelf'],
        newShelf: _estanteria,
        datosUserBook: datosUserBook,
        datosCatalogo: datosCatalogo,
      );

      if (mounted) {
        FocusScope.of(context).unfocus();

        // Mostrar confetti si es un nuevo libro completado
        if (esNuevoLeido) {
          _confettiController.play();
          await Future.delayed(const Duration(milliseconds: 1500));
        }

        // Cerrar pantalla y mostrar mensaje de confirmación
        if (mounted) {
          Navigator.pop(context);
          mostrarSnackBar(
            context,
            esNuevoLeido
                ? "🎉 ¡Felicidades! Libro completado."
                : "Libro actualizado.",
            AppColors.naranja,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        FocusScope.of(context).unfocus();
        mostrarSnackBar(context, "Error: $e", Colors.red);
      }
    }
  }
}
