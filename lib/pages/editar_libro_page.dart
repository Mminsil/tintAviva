import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/input_validadores.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import 'package:intl/intl.dart';

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
  DateTime? _fechaInicio;
  DateTime? _fechaFin;
  bool _sinopsisEraVacia = false;

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

    _fechaInicio = (widget.datosActuales['dateStarted'] as Timestamp?)
        ?.toDate();
    _fechaFin =
        (widget.datosActuales['dateFinished'] as Timestamp?)?.toDate() ??
        DateTime.now();

    _sinopsisEraVacia =
        widget.datosActuales['synopsis'] == null ||
        widget.datosActuales['synopsis'].toString().trim().isEmpty;
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
          const SizedBox(height: 20),
          _buildFechasCard(),
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
            _buildPaginasControls(),
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

  /// Ahora maneja los 3 formatos correctamente
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
    // Para Digital: muestra total de páginas como texto (no editable)
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
            if (_sinopsisEraVacia) ...[
              const SizedBox(height: 15),
              _buildTextField(
                "Sinopsis (será visible para todas las usuarias) ⚠️",
                _sinopsisController,
                lines: 4,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "Esta sinopsis se guardará en el catálogo global.",
                  style: TextStyle(fontSize: 11, color: Colors.orange[700]),
                ),
              ),
            ],
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

  Widget _buildFechasCard() {
    if (_estanteria != 'Leído') return const SizedBox.shrink();

    return Card(
      color: AppColors.blanco,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildDateTile(
              'Fecha de inicio',
              _fechaInicio,
              (val) => setState(() => _fechaInicio = val),
            ),
            const Divider(height: 20),
            _buildDateTile(
              'Fecha de finalización',
              _fechaFin,
              (val) => setState(() => _fechaFin = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile(
    String label,
    DateTime? date,
    ValueChanged<DateTime> onPick,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        date != null
            ? DateFormat('dd/MM/yyyy').format(date)
            : 'No seleccionada',
      ),
      trailing: const Icon(Icons.calendar_today, color: AppColors.morado),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) onPick(picked);
      },
    );
  }

  void _onEstanteriaChanged(String? newValue) async {
    if (newValue == null || newValue == _estanteria) return;

    final String oldShelf = _estanteria;
    final int currentProgress = _progreso.toInt();
    final int totalPages =
        int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    final int? totalSec = tiempoASegundos(_tiempoTotalController.text);

    bool confirmar = true;
    String mensaje = "", titulo = "";

    // ─────────────────────────────────────────────────────────────
    // VALIDACIÓN ESPECIAL: Cambiar a Audio sin tiempo total definido
    // ─────────────────────────────────────────────────────────────
    if (newValue == 'Leyendo' && _formatoSeleccionado == 'Audio') {
      if (totalSec == null || totalSec <= 0) {
        confirmar = await _mostrarDialogoIngresarTiempoTotal();
        if (!confirmar || !mounted) {
          return; // Usuario canceló → no cambiar estantería
        }
      }
    }

    // ─────────────────────────────────────────────────────────────
    // Mensajes de confirmación según el cambio de estantería
    // ─────────────────────────────────────────────────────────────
    if (oldShelf == 'Leyendo' &&
        (newValue == 'Leído' || newValue == 'Por leer')) {
      titulo = "¿Actualizar progreso?";
      if (newValue == 'Leído') {
        mensaje =
            "El libro está al $currentProgress%. Al marcar como 'Leído', el progreso se actualizará al 100%. ¿Continuar?";
      } else {
        mensaje =
            "El libro está al $currentProgress%. Si cambias a 'Por leer', el progreso se reiniciará a 0%. ¿Continuar?";
      }
    } else if (oldShelf == 'Leído' &&
        (newValue == 'Leyendo' || newValue == 'Por leer')) {
      titulo = "¿Volver a leer?";
      if (newValue == 'Leyendo') {
        mensaje =
            "Ya marcaste este libro como 'Leído'. Al cambiar a 'Leyendo', recuperaremos tu progreso anterior. ¿Seguro?";
      } else {
        mensaje =
            "Ya marcaste este libro como 'Leído'. Al cambiar a 'Por leer', reiniciaremos el progreso a 0%. ¿Seguro?";
      }
    } else if (oldShelf == 'Por leer' && newValue == 'Leído') {
      titulo = "¿Marcar como leído?";
      mensaje =
          "El libro está en 'Por leer'. Al marcar como 'Leído', el progreso se actualizará al 100%. ¿Continuar?";
    }

    // Mostrar diálogo de confirmación si es necesario
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

    if (!confirmar || !mounted) return;

    // ─────────────────────────────────────────────────────────────
    // ACTUALIZAR ESTADO Y CONTROLLERS SEGÚN NUEVA ESTANTERÍA
    // ─────────────────────────────────────────────────────────────
    setState(() {
      _estanteria = newValue;

      if (newValue == 'Leído') {
        // PROGRESO 100% + ACTUALIZAR CAMPOS SEGÚN FORMATO
        _progreso = 100.0;

        if (_formatoSeleccionado == 'Papel' && totalPages > 0) {
          _paginaActualController.text = totalPages.toString();
        } else if (_formatoSeleccionado == 'Audio' && totalSec != null) {
          // 🎧 AUDIO: tiempo actual = tiempo total + ACTUALIZAR INPUT
          _tiempoActualController.text = segundosATiempo(totalSec);
        }
        // Digital: no hace falta cambiar nada, el progreso 100% ya lo dice todo
      } else if (newValue == 'Por leer') {
        _progreso = 0.0;
        _paginaActualController.text = "0";
        _tiempoActualController.text = "00:00";
        _paginaActualGuardada = 0;
        _currentSecondsGuardado = 0;

        if (_formatoSeleccionado == 'Papel') {
          _paginaActualController.text = "1";
        } else if (_formatoSeleccionado == 'Audio') {
          _tiempoActualController.text = "00:00";
        }
        // Digital: no hace falta cambiar nada, el progreso 0% ya lo dice todo
      } else if (newValue == 'Leyendo') {
        // RESTAURAR PROGRESO ANTERIOR CUANDO SE VUELVE A "LEYENDO"
        if (oldShelf == 'Leído') {
          // Restaurar valores guardados al editar
          if (_formatoSeleccionado == 'Papel' &&
              _paginaActualGuardada != null) {
            _paginaActualController.text = _paginaActualGuardada.toString();
            if (totalPages > 0) {
              _progreso = ((_paginaActualGuardada! / totalPages) * 100).clamp(
                0.0,
                100.0,
              );
            }
          } else if (_formatoSeleccionado == 'Audio' &&
              _currentSecondsGuardado != null) {
            _tiempoActualController.text = segundosATiempo(
              _currentSecondsGuardado!,
            );
            if (totalSec != null && totalSec > 0) {
              _progreso = ((_currentSecondsGuardado! / totalSec) * 100).clamp(
                0.0,
                100.0,
              );
            }
          } else if (_formatoSeleccionado == 'Digital') {
            // Restaurar progreso digital desde los datos originales
            _progreso = (widget.datosActuales['progress'] ?? 0).toDouble();
          }
        } else {
          // Cálculo normal cuando viene de "Por leer"
          if (_formatoSeleccionado == 'Papel' && totalPages > 0) {
            final actual =
                int.tryParse(_paginaActualController.text.trim()) ?? 0;
            _progreso = ((actual / totalPages) * 100).clamp(0.0, 100.0);
          } else if (_formatoSeleccionado == 'Audio') {
            final actual = tiempoASegundos(_tiempoActualController.text);
            if (totalSec != null && totalSec > 0 && actual != null) {
              _progreso = ((actual / totalSec) * 100).clamp(0.0, 100.0);
            }
          }
        }
      }
    });

    // ─────────────────────────────────────────────────────────────
    // FEEDBACK VISUAL AL USUARIO
    // ─────────────────────────────────────────────────────────────
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
      } else if (newValue == 'Por leer') {
        mostrarSnackBar(
          context,
          "📚 Libro movido a 'Por leer'. El progreso se ha reiniciado.",
          AppColors.naranja,
        );
      }
    }
  }

  /// Muestra un diálogo para ingresar la duración total del audiolibro.
  Future<bool> _mostrarDialogoIngresarTiempoTotal() async {
    final TextEditingController tiempoController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Ingrese duración total"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Para cambiar a formato Audio, necesitas indicar la duración total del libro.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tiempoController,
              decoration: AppInputStyles.inputDecoration("Duración total")
                  .copyWith(
                    helperText: "Ej: 10:30:00 o 2:15:30",
                    suffixText: "⏱️",
                  ),
              keyboardType: TextInputType.datetime,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              final tiempo = tiempoASegundos(tiempoController.text);
              if (tiempo != null && tiempo > 0) {
                setState(() {
                  _tiempoTotalController.text = segundosATiempo(tiempo);
                });
                Navigator.pop(context, true);
              } else {
                mostrarSnackBar(
                  context,
                  "Formato inválido. Usa MM:SS o HH:MM:SS",
                  Colors.red,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranja),
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    tiempoController.dispose();
    return result ?? false;
  }

  /// Muestra un diálogo para ingresar el total de páginas al cambiar a formato Papel.
Future<bool> _mostrarDialogoIngresarTotalPaginas() async {
  final TextEditingController paginasController = TextEditingController();

  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Ingrese total de páginas"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Para cambiar a formato Papel, necesitas indicar el total de páginas."),
          const SizedBox(height: 16),
          TextField(
            controller: paginasController,
            decoration: AppInputStyles.inputDecoration("Total de páginas")
                .copyWith(helperText: "Ej: 350", suffixText: "📖"),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: () {
            final paginas = int.tryParse(paginasController.text);
            if (paginas != null && paginas > 0) {
              setState(() => _paginasTotalesController.text = paginas.toString());
              Navigator.pop(context, true);
            } else {
              mostrarSnackBar(context, "Ingresa un número válido mayor a 0", Colors.red);
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranja),
          child: const Text("Guardar", style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );

  paginasController.dispose();
  return result ?? false;
}

  Future<void> _onFormatoChanged(Set<String> newSelection) async {
    final nuevoFormato = newSelection.first;

    if (nuevoFormato == _formatoSeleccionado) return;

    // Validaciín: Si cambia a Audio sin duración total, pedirla antes de cambiar el formato
    if (nuevoFormato == 'Audio') {
      final totalSec = tiempoASegundos(_tiempoTotalController.text);

      // Si no hay tiempo total válido, pedirlo al usuario
      if (totalSec == null || totalSec <= 0) {
        // ignore: unnecessary_nullable_for_final_variable_declarations
        final bool? confirmado = await _mostrarDialogoIngresarTiempoTotal();

        // Si canceló o no está montado, NO cambiar de formato
        if (confirmado != true || !mounted) return;

        // Si confirmó, recalcular totalSec con el nuevo valor
        if (totalSec == null || totalSec <= 0) {
          // Releer el valor actualizado después del diálogo
          final nuevoTotal = tiempoASegundos(_tiempoTotalController.text);
          if (nuevoTotal == null || nuevoTotal <= 0) return;
        }
      }
    }

     if (nuevoFormato == 'Papel') {
    final totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    if (totales <= 0) {
      // ignore: unnecessary_nullable_for_final_variable_declarations
      final bool? confirmado = await _mostrarDialogoIngresarTotalPaginas();
      if (confirmado != true || !mounted) return;
    }
  }

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
        } else {
          // Si por algún motivo no hay total, poner 00:00
          _tiempoActualController.text = "00:00";
          _tiempoTotalController.text = "00:00:00";
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
        'genre': _generoController.text.trim(),
        'totalPages': formato == 'Papel' ? totales : 0,
        'currentPage': formato == 'Papel' ? actual : 0,
        'format': formato,
        'dateStarted': _fechaInicio != null
            ? Timestamp.fromDate(_fechaInicio!)
            : null,
        'dateFinished': _fechaFin != null
            ? Timestamp.fromDate(_fechaFin!)
            : null,
        'bookCover': _bookCoverController.text.trim(),
        'totalSeconds': formato == 'Audio' ? totalSeconds : null,
        'currentSeconds': formato == 'Audio' ? currentSeconds : null,
      };

      Map<String, dynamic> datosCatalogo = {};
      if (_sinopsisEraVacia && _sinopsisController.text.trim().isNotEmpty) {
        datosCatalogo['synopsis'] = _sinopsisController.text.trim();
      }

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
