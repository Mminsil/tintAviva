import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/input_validadores.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

// ============================================================================
// CLASE PRINCIPAL
// ============================================================================

/// Pantalla de edición de un libro en la biblioteca personal.
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
  late String _estanteria;
  late double _progreso;
  late double _puntuacion;
  late String _formatoSeleccionado;

  late TextEditingController _generoController;
  late TextEditingController _sinopsisController;
  late TextEditingController _notasController;
  late TextEditingController _paginaActualController;
  late TextEditingController _paginasTotalesController;
  late TextEditingController _bookCoverController;
  late TextEditingController _tiempoActualController;
  late TextEditingController _tiempoTotalController;
  late TextEditingController _tituloController;

  late ConfettiController _confettiController;
  int? _paginaActualGuardada;
  int? _currentSecondsGuardado;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _initializeFormState();
  }

  void _initializeFormState() {
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
                  0)
              .toString(),
    );
    _paginaActualController = TextEditingController(
      text: (widget.datosActuales['currentPage'] ?? 0).toString(),
    );
    _bookCoverController = TextEditingController(
      text: widget.datosActuales['bookCover'] ?? "",
    );

    final totalSec = widget.datosActuales['totalSeconds'] as int?;
    final currentSec = widget.datosActuales['currentSeconds'] as int?;

    _tiempoTotalController = TextEditingController(
      text: totalSec != null ? segundosATiempo(totalSec) : "00:00:00",
    );
    _tiempoActualController = TextEditingController(
      text: currentSec != null ? segundosATiempo(currentSec) : "00:00",
    );
    _currentSecondsGuardado = currentSec;
    _paginaActualGuardada = widget.datosActuales['currentPage'] ?? 0;

    _tituloController = TextEditingController(
      text: widget.datosActuales['title'] ?? "",
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _generoController.dispose();
    _sinopsisController.dispose();
    _notasController.dispose();
    _paginaActualController.dispose();
    _tituloController.dispose();
    _paginasTotalesController.dispose();
    _bookCoverController.dispose();
    _tiempoActualController.dispose();
    _tiempoTotalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text("Editar Libro", style: AppTextStyles.sectionTitle),
      backgroundColor: AppColors.blanco,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.morado),
    );
  }

  Widget _buildBody() {
    return Stack(
      children: [
        _buildScrollableContent(),
        ConfettiCelebration(controller: _confettiController),
      ],
    );
  }

  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle("Título"),
          const SizedBox(height: 10),
          _buildTituloInput(),
          const SizedBox(height: 20),
          _buildSectionTitle("Detalles del Libro"),
          _buildSectionTitle("Estado y Progreso"),
          const SizedBox(height: 10),
          _buildEstadoYProgresoCard(),
          const SizedBox(height: 20),
          _buildSectionTitle("Detalles del Libro"),
          const SizedBox(height: 10),
          _buildDetallesCard(),
          const SizedBox(height: 20),
          _buildSectionTitle("Notas"),
          const SizedBox(height: 10),
          _buildNotasCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTituloInput() {
    return Card(
      color: AppColors.blanco,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _tituloController,
          textCapitalization: TextCapitalization.sentences,
          decoration: AppInputStyles.inputDecoration(
            "Título del libro",
          ).copyWith(prefixIcon: const Icon(Icons.title)),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) =>
      Text(title, style: AppTextStyles.sectionTitle);

  Widget _buildEstadoYProgresoCard() {
    return Card(
      color: AppColors.blanco,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildEstanteriaDropdown(),
            const SizedBox(height: 20),
            _buildFormatoSelector(),
            const SizedBox(height: 20),
            _buildProgresoControl(),
            const SizedBox(height: 20),
            _buildPaginasControls(), // ← Aquí estaba el problema
            const SizedBox(height: 20),
            _buildPuntuacionSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildEstanteriaDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _estanteria,
      decoration: AppInputStyles.inputDecoration("Estantería"),
      items: [
        'Leyendo',
        'Leído',
        'Por leer',
      ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: _onEstanteriaChanged,
    );
  }

  Widget _buildFormatoSelector() {
    return Column(
      children: [
        const Text(
          "Formato del Libro",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 10),
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
            ButtonSegment(
              value: 'Audio',
              label: Text('Audio'),
              icon: Icon(Icons.headphones),
            ),
          ],
          selected: {_formatoSeleccionado},
          onSelectionChanged: _onFormatoChanged,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.morado,
            selectedForegroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProgresoControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          _buildDigitalProgressSlider()
        else if (_formatoSeleccionado == 'Papel')
          _buildPaperProgressIndicator()
        else
          _buildAudioProgressControls(),
      ],
    );
  }

  Widget _buildDigitalProgressSlider() {
    return Slider(
      value: _progreso.clamp(0.0, 100.0),
      max: 100,
      divisions: 100,
      activeColor: AppColors.naranja,
      inactiveColor: AppColors.naranja.withValues(alpha: 0.3),
      onChanged: (value) {
        setState(() {
          _progreso = value;
          if (_progreso >= 100) {
            _estanteria = 'Leído';
          } else if (_progreso > 0) {
            _estanteria = 'Leyendo';
          } else {
            _estanteria = 'Por leer';
          }
        });
      },
    );
  }

  Widget _buildPaperProgressIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: _progreso / 100,
        backgroundColor: Colors.grey[200],
        color: AppColors.naranja,
        minHeight: 8,
      ),
    );
  }

  Widget _buildAudioProgressControls() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tiempoActualController,
                keyboardType: TextInputType.datetime,
                decoration: AppInputStyles.inputDecoration('Tiempo actual')
                    .copyWith(
                      suffixText: '⏱️',
                      helperText: 'Ej: 30:45 o 1:20:15',
                      helperStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  if (tiempoASegundos(v) == null) return 'Formato inválido';
                  return null;
                },
                onChanged: (_) => _recalcularProgresoAudio(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _tiempoTotalController,
                keyboardType: TextInputType.datetime,
                decoration: AppInputStyles.inputDecoration('Tiempo total')
                    .copyWith(
                      suffixText: '⏱️',
                      helperText: 'Duración completa',
                      helperStyle: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Requerido';
                  final total = tiempoASegundos(v);
                  if (total == null || total <= 0) return 'Debe ser > 0';
                  return null;
                },
                onChanged: (_) => _recalcularProgresoAudio(),
              ),
            ),
          ],
        ),
        if (_tiempoActualController.text.isNotEmpty &&
            _tiempoTotalController.text.isNotEmpty)
          Builder(
            builder: (context) {
              final actual = tiempoASegundos(_tiempoActualController.text);
              final total = tiempoASegundos(_tiempoTotalController.text);
              if (actual != null && total != null && actual > total) {
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '⚠️ El tiempo actual no puede superar el total',
                    style: TextStyle(color: Colors.red.shade700, fontSize: 11),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  /// ✅ CORREGIDO: Ahora maneja los 3 formatos correctamente
  Widget _buildPaginasControls() {
    if (_formatoSeleccionado == 'Papel') {
      return Row(
        children: [
          Expanded(
            child: buildNumberField(
              label: 'Pág. Actual',
              controller: _paginaActualController,
              maxPages: int.tryParse(_paginasTotalesController.text),
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
      );
    }
    // ✅ Para Digital: muestra total de páginas como texto (no editable)
    else if (_formatoSeleccionado == 'Digital') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'Total páginas: ${_paginasTotalesController.text.isNotEmpty ? _paginasTotalesController.text : "0"}',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      );
    }
    // ✅ Para Audio: NO muestra nada de páginas
    else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildPuntuacionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Puntuación", style: TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            return GestureDetector(
              onTap: () => setState(() => _puntuacion = index + 1.0),
              child: Icon(
                index < _puntuacion
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: index < _puntuacion ? Colors.amber : Colors.grey[400],
                size: 35,
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildDetallesCard() {
    return Card(
      color: AppColors.blanco,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
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
            _buildBookCoverInput(),
            if (_bookCoverController.text.isNotEmpty) _buildBookCoverPreview(),
            const SizedBox(height: 15),
            _buildTextField("Género", _generoController),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCoverInput() {
    return TextField(
      controller: _bookCoverController,
      decoration: AppInputStyles.inputDecoration(
        "URL de la imagen",
        prefixIcon: Icons.link,
      ),
      keyboardType: TextInputType.url,
      textCapitalization: TextCapitalization.sentences,
      enableInteractiveSelection: true,
      autocorrect: true,
    );
  }

  Widget _buildBookCoverPreview() {
    return Column(
      children: [
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
    );
  }

  Widget _buildNotasCard() {
    return Card(
      color: AppColors.blanco,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField(
              "Escribe tus apuntes personales sobre este libro...",
              _notasController,
              lines: 5,
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _guardarCambios,
      backgroundColor: AppColors.naranja,
      label: const Text(
        "Guardar cambios",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _onEstanteriaChanged(String? newValue) async {
    if (newValue == null || newValue == _estanteria) return;
    final String oldShelf = _estanteria;
    final int currentProgress = _progreso.toInt();
    final int totalPages =
        int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    final int currentPage =
        int.tryParse(_paginaActualController.text.trim()) ?? 0;

    bool confirmar = true;
    String mensaje = "", titulo = "";

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
        if (_paginaActualGuardada != null && _paginaActualGuardada! > 0) {
          _paginaActualController.text = (_paginaActualGuardada == totalPages)
              ? "0"
              : _paginaActualGuardada.toString();
          final paginaParaCalculo =
              int.tryParse(_paginaActualController.text.trim()) ?? 0;
          if (totalPages > 0) {
            _progreso = ((paginaParaCalculo / totalPages) * 100).clamp(
              0.0,
              100.0,
            );
          }
        } else {
          final actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
          if (totalPages > 0) {
            _progreso = ((actual / totalPages) * 100).clamp(0.0, 100.0);
          }
        }
      }
    });

    if (mounted) {
      if (oldShelf == 'Por leer' && newValue == 'Leyendo') {
        mostrarSnackBar(
          context,
          "📖 ¡Qué ilusión! Has empezado a leer '${widget.datosActuales['title']}'.",
          AppColors.naranja,
        );
      } else if (oldShelf == 'Leído' && newValue == 'Leyendo') {
        mostrarSnackBar(
          context,
          "📖 ¿Te gustó '${widget.datosActuales['title']}'? Crea un club y comparte con tus amigos.",
          AppColors.naranja,
        );
      }
    }
  }

  void _onFormatoChanged(Set<String> newSelection) {
    final nuevoFormato = newSelection.first;
    if (nuevoFormato == _formatoSeleccionado) return;

    setState(() {
      final totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
      final actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
      final totalSec = tiempoASegundos(_tiempoTotalController.text) ?? 0;
      final currentSec = tiempoASegundos(_tiempoActualController.text) ?? 0;

      if (nuevoFormato == 'Papel') {
        if (totales > 0) {
          _paginaActualController.text = ((_progreso / 100) * totales)
              .round()
              .toString();
        }
      } else if (nuevoFormato == 'Digital') {
        if (_formatoSeleccionado == 'Papel' && totales > 0) {
          _progreso = ((actual / totales) * 100).clamp(0.0, 100.0);
        } else if (_formatoSeleccionado == 'Audio' && totalSec > 0) {
          _progreso = ((currentSec / totalSec) * 100).clamp(0.0, 100.0);
        }
      } else if (nuevoFormato == 'Audio') {
        if (totalSec > 0) {
          _tiempoActualController.text = segundosATiempo(
            ((_progreso / 100) * totalSec).round(),
          );
        }
      }
      _formatoSeleccionado = nuevoFormato;
    });
  }

  void _recalcularProgreso() {
    if (_formatoSeleccionado != 'Papel') return;
    final totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    final actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
    if (totales > 0) {
      setState(() {
        _progreso = ((actual / totales) * 100).clamp(0.0, 100.0);
        if (actual > totales) {
          _paginaActualController.text = totales.toString();
          _progreso = 100.0;
        }
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

  void _recalcularProgresoAudio() {
    if (_formatoSeleccionado != 'Audio') return;
    final actual = tiempoASegundos(_tiempoActualController.text);
    final total = tiempoASegundos(_tiempoTotalController.text);
    if (actual != null && total != null && total > 0) {
      setState(() {
        _progreso = ((actual / total) * 100).clamp(0.0, 100.0);
        if (_progreso >= 100 && _estanteria != 'Leído') {
          _estanteria = 'Leído';
        } else if (_progreso == 0 && _estanteria != 'Por leer') {
          _estanteria = 'Por leer';
        } else if (_progreso > 0 &&
            _progreso < 100 &&
            _estanteria != 'Leyendo') {
          _estanteria = 'Leyendo';
        }
      });
    }
  }

  Future<void> _guardarCambios() async {
    try {
      final formato = _formatoSeleccionado;
      int totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
      int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
      int progresoFinal = _progreso.toInt();
      int? totalSeconds, currentSeconds;

      if (formato == 'Audio') {
        totalSeconds = tiempoASegundos(_tiempoTotalController.text);
        currentSeconds = tiempoASegundos(_tiempoActualController.text);
        if (totalSeconds == null || totalSeconds <= 0) {
          mostrarSnackBar(context, "Duración total inválida", Colors.red);
          return;
        }
        if (currentSeconds == null ||
            currentSeconds < 0 ||
            currentSeconds > totalSeconds) {
          mostrarSnackBar(context, "Tiempo actual inválido", Colors.red);
          return;
        }
        progresoFinal = ((currentSeconds / totalSeconds) * 100).round().clamp(
          0,
          100,
        );
      }

      final progresoRaw = widget.datosActuales['progress'];
      final progresoOriginal = progresoRaw is num ? progresoRaw.toInt() : 0;
      final valorOriginal = formato == 'Papel'
          ? (widget.datosActuales['currentPage'] as int? ?? 0)
          : (formato == 'Audio'
                ? (widget.datosActuales['currentSeconds'] as int? ?? 0)
                : progresoOriginal);

      bool haDisminuido = false;
      String mensajeConfirmacion = "";
      if (formato == 'Papel' && actual < valorOriginal && valorOriginal > 0) {
        haDisminuido = true;
        mensajeConfirmacion =
            "Has indicado la página $actual, menor a la anterior ($valorOriginal). ¿Seguro?";
      } else if (formato == 'Audio' &&
          currentSeconds != null &&
          _currentSecondsGuardado != null &&
          currentSeconds < _currentSecondsGuardado! &&
          _currentSecondsGuardado! > 0) {
        haDisminuido = true;
        mensajeConfirmacion =
            "Has retrocedido en el audio (${segundosATiempo(currentSeconds)} < ${segundosATiempo(_currentSecondsGuardado!)}). ¿Seguro?";
      } else if (formato == 'Digital' &&
          progresoFinal < progresoOriginal &&
          progresoOriginal > 0) {
        haDisminuido = true;
        mensajeConfirmacion =
            "Has indicado $progresoFinal%, menor al anterior ($progresoOriginal%). ¿Seguro?";
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
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancelar"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Sí, continuar",
                  style: TextStyle(color: AppColors.naranja),
                ),
              ),
            ],
          ),
        );
        if (confirmar != true || !mounted) return;
      }

      if (progresoFinal >= 100) _estanteria = 'Leído';

      Map<String, dynamic> datosUserBook = {
        'title': _tituloController.text.trim(),
        'shelf': _estanteria,
        'progress': progresoFinal,
        'rating': _puntuacion,
        'notes': _notasController.text,
        'totalPages': formato == 'Papel' ? totales : 0,
        'currentPage': formato == 'Papel' ? actual : 0,
        'format': formato,
        'dateFinished': _estanteria == 'Leído'
            ? FieldValue.serverTimestamp()
            : null,
        'bookCover': _bookCoverController.text.trim(),
        'totalSeconds': formato == 'Audio' ? totalSeconds : null,
        'currentSeconds': formato == 'Audio' ? currentSeconds : null,
      };
      Map<String, dynamic> datosCatalogo = {'genre': _generoController.text};

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
        final esNuevoLeido =
            (_estanteria == 'Leído' &&
            widget.datosActuales['shelf'] != 'Leído');
        if (esNuevoLeido) {
          _confettiController.play();
          await Future.delayed(const Duration(milliseconds: 1500));
        }
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
