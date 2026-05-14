import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/input_validadores.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Pantalla de edición de un libro en la biblioteca personal.
///
/// Permite modificar: estantería, formato (Papel/Digital), progreso, puntuación,
/// género, sinopsis, notas, portada y páginas.
///
/// Incluye lógica de conversión entre formato papel (páginas) y digital (porcentaje).
/// Al completar un libro (estantería cambia a `'Leído'`) muestra confetti.
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

  // Controlador para la animación de confeti
  late ConfettiController _confettiController;
  int? _paginaActualGuardada;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _initializeFormState();
  }

  /// Inicializa el estado del formulario con los datos actuales del libro.
  void _initializeFormState() {
    _estanteria = widget.datosActuales['shelf'] ?? 'Leyendo';
    _progreso = (widget.datosActuales['progress'] ?? 0).toDouble();
    _puntuacion = (widget.datosActuales['rating'] ?? 0).toDouble();
    _formatoSeleccionado = widget.datosActuales['format'] ?? 'Digital';

    _generoController = TextEditingController(text: widget.datosActuales['genre'] ?? "");
    _sinopsisController = TextEditingController(text: widget.datosActuales['synopsis'] ?? "");
    _notasController = TextEditingController(text: widget.datosActuales['notes'] ?? "");

    _paginasTotalesController = TextEditingController(
      text: (widget.datosActuales['totalPages'] ?? widget.datosActuales['pages'] ?? "0").toString(),
    );
    _paginaActualController = TextEditingController(
      text: (widget.datosActuales['currentPage'] ?? "0").toString(),
    );
    _bookCoverController = TextEditingController(text: widget.datosActuales['bookCover'] ?? "");

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

  // ─────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL (ÍNDICE LEGIBLE)
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: _buildAppBar(),
      body: _buildBody(),
      floatingActionButton: _buildFAB(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WIDGETS AUXILIARES DE UI (EXTRAÍDOS DEL BUILD)
  // ─────────────────────────────────────────────────────────────

  /// Construye la AppBar con título y estilos personalizados.
  AppBar _buildAppBar() {
    return AppBar(
      title: const Text("Editar Libro", style: AppTextStyles.sectionTitle),
      backgroundColor: AppColors.blanco,
      elevation: 0,
      iconTheme: const IconThemeData(color: AppColors.morado),
    );
  }

  /// Construye el cuerpo principal con Stack para confetti + contenido scrollable.
  Widget _buildBody() {
    return Stack(
      children: [
        _buildScrollableContent(),
        ConfettiCelebration(controller: _confettiController),
      ],
    );
  }

  /// Construye el contenido scrollable con todas las secciones del formulario.
  Widget _buildScrollableContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

  /// Construye el título de sección con estilo consistente.
  Widget _buildSectionTitle(String title) {
    return Text(title, style: AppTextStyles.sectionTitle);
  }

  /// Construye la tarjeta de Estado y Progreso con todos sus controles.
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

  /// Dropdown para seleccionar la estantería del libro.
  Widget _buildEstanteriaDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _estanteria,
      decoration: AppInputStyles.inputDecoration("Estantería"),
      items: ['Leyendo', 'Leído', 'Por leer'].map((String value) {
        return DropdownMenuItem<String>(value: value, child: Text(value));
      }).toList(),
      onChanged: _onEstanteriaChanged,
    );
  }

  /// SegmentedButton para alternar entre formato Papel y Digital.
  Widget _buildFormatoSelector() {
    return Column(
      children: [
        const Text("Formato del Libro", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'Papel', label: Text('Papel'), icon: Icon(Icons.menu_book)),
            ButtonSegment(value: 'Digital', label: Text('Digital'), icon: Icon(Icons.tablet_android)),
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

  /// Control de progreso: slider para Digital, barra visual para Papel.
  Widget _buildProgresoControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Progreso", style: TextStyle(fontWeight: FontWeight.w500)),
            Text("${_progreso.toInt()}%", style: const TextStyle(color: AppColors.naranja, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        if (_formatoSeleccionado == 'Digital') 
          _buildDigitalProgressSlider()
         else 
          _buildPaperProgressIndicator(),
        
      ],
    );
  }

  /// Slider editable para progreso en formato Digital.
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

  /// Barra de progreso visual (no editable) para formato Papel.
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

  /// Controles de páginas: editables en Papel, solo lectura en Digital.
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
    } else {
      return buildNumberField(
        label: 'Total Págs. (Referencia)',
        controller: _paginasTotalesController,
        isTotalField: true,
      );
    }
  }

  /// Selector de estrellas para puntuación (1 a 5).
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
              onTap: () {
                setState(() => _puntuacion = index + 1.0);
              },
              child: Icon(
                index < _puntuacion ? Icons.star_rounded : Icons.star_outline_rounded,
                color: index < _puntuacion ? Colors.amber : Colors.grey[400],
                size: 35,
              ),
            );
          }),
        ),
      ],
    );
  }

  /// Construye la tarjeta de Detalles del Libro (portada + género).
  Widget _buildDetallesCard() {
    return Card(
      color: AppColors.blanco,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Align(alignment: Alignment.centerLeft, child: Text("Portada Personalizada", style: TextStyle(fontWeight: FontWeight.w500, color: AppColors.morado))),
            const SizedBox(height: 8),
            _buildBookCoverInput(),
            if (_bookCoverController.text.isNotEmpty) 
              _buildBookCoverPreview(),
            
            const SizedBox(height: 15),
            _buildTextField("Género", _generoController),
          ],
        ),
      ),
    );
  }

  /// Campo de texto para URL de portada personalizada.
  Widget _buildBookCoverInput() {
    return TextField(
      textCapitalization: TextCapitalization.sentences,
      enableInteractiveSelection: true,
      autocorrect: true,
      controller: _bookCoverController,
      decoration: AppInputStyles.inputDecoration("URL de la imagen", prefixIcon: Icons.link),
      keyboardType: TextInputType.url,
    );
  }

  /// Vista previa de la portada si hay URL válida.
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
              errorBuilder: (_, __, ___) {
                return Container(
                  height: 120,
                  width: 80,
                  color: Colors.grey[200],
                  child: const Icon(Icons.broken_image),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Construye la tarjeta de Notas personales.
  Widget _buildNotasCard() {
    return Card(
      color: AppColors.blanco,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildTextField("Escribe tus apuntes personales sobre este libro...", _notasController, lines: 5),
          ],
        ),
      ),
    );
  }

  /// Campo de texto reutilizable con configuración común.
  ///
  /// [lines] define el número de líneas visibles.
  /// [isNumber] habilita teclado numérico.
  /// [isReadOnly] deshabilita edición con estilo visual.
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

  /// Construye el FAB para guardar cambios.
  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _guardarCambios,
      backgroundColor: AppColors.naranja,
      label: const Text("Guardar cambios", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO Y HANDLERS
  // ─────────────────────────────────────────────────────────────

  /// Maneja cambios en el dropdown de estantería.
  ///
  /// Muestra diálogo de confirmación si cambiar implica perder progreso.
  /// Al confirmar, actualiza `_progreso` y `_paginaActualController` según la nueva estantería.
  void _onEstanteriaChanged(String? newValue) async {
    if (newValue == null || newValue == _estanteria) {
      return;
    }

    final String oldShelf = _estanteria;
    final int currentProgress = _progreso.toInt();
    final int totalPages = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    final int currentPage = int.tryParse(_paginaActualController.text.trim()) ?? 0;

    bool confirmar = true;
    String mensaje = "";
    String titulo = "";

    if (oldShelf == 'Leyendo' && (newValue == 'Leído' || newValue == 'Por leer')) {
      titulo = "¿Perder progreso?";
      mensaje = "El libro está al $currentProgress%. Si cambias a '$newValue', el progreso se actualizará (${newValue == 'Leído' ? '100%' : '0%'}). ¿Continuar?";
    } else if (oldShelf == 'Leído' && (newValue == 'Leyendo' || newValue == 'Por leer')) {
      titulo = "¿Volver a leer?";
      mensaje = "Ya marcaste este libro como 'Leído'. Al cambiar a '$newValue', reiniciaremos el progreso a 0%. ¿Seguro?";
    }

    if ((oldShelf == 'Leyendo' || oldShelf == 'Leído') && newValue != oldShelf) {
      confirmar = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
                content: Text(mensaje),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar")),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranja),
                    child: const Text("Sí, cambiar", style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          ) ??
          false;
    }

    if (!confirmar) {
      return;
    }

    setState(() {
      _estanteria = newValue;
      if (newValue == 'Leído') {
        _progreso = 100.0;
        _paginaActualController.text = totalPages > 0 ? totalPages.toString() : "0";
        _paginaActualGuardada = currentPage;
      } else if (newValue == 'Por leer') {
        _progreso = 0.0;
        _paginaActualController.text = "1";
        _paginaActualGuardada = currentPage;
      } else if (newValue == 'Leyendo') {
        if (_paginaActualGuardada != null && _paginaActualGuardada! > 0) {
          if (_paginaActualGuardada == totalPages) {
            _paginaActualController.text = "0";
          } else {
            _paginaActualController.text = _paginaActualGuardada.toString();
          }
          final int paginaParaCalculo = int.tryParse(_paginaActualController.text.trim()) ?? 0;
          if (totalPages > 0) {
            _progreso = ((paginaParaCalculo / totalPages) * 100).clamp(0.0, 100.0);
          }
        } else {
          final int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
          if (totalPages > 0) {
            _progreso = ((actual / totalPages) * 100).clamp(0.0, 100.0);
          }
        }
      }
    });

    if (oldShelf == 'Por leer' && newValue == 'Leyendo') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mostrarSnackBar(context, "📖 ¡Qué ilusión! Has empezado a leer '${widget.datosActuales['title']}'.", AppColors.naranja);
      });
    }

    if (oldShelf == 'Leído' && newValue == 'Leyendo') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        mostrarSnackBar(context, "📖 ¿Te gustó '${widget.datosActuales['title']}'? Crea un club y comparte con tus amigos.", AppColors.naranja);
      });
    }
  }

  /// Convierte el progreso entre formato Papel y Digital.
  ///
  /// - Papel → Digital: `páginas actual / totales = porcentaje`
  /// - Digital → Papel: `porcentaje * totales = páginas calculadas`
  void _onFormatoChanged(Set<String> newSelection) {
    final nuevoFormato = newSelection.first;
    if (nuevoFormato == _formatoSeleccionado) {
      return;
    }

    setState(() {
      final int totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
      final int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;

      if (nuevoFormato == 'Papel') {
        if (totales > 0) {
          int paginasCalculadas = ((_progreso / 100) * totales).round();
          _paginaActualController.text = paginasCalculadas.toString();
        } else {
          _paginaActualController.text = "0";
        }
      } else {
        if (totales > 0) {
          _progreso = ((actual / totales) * 100).clamp(0.0, 100.0);
        } else {
          _progreso = 0.0;
        }
      }
      _formatoSeleccionado = nuevoFormato;
    });
  }

  /// Recalcula el porcentaje de progreso basado en página actual y totales.
  ///
  /// Solo se ejecuta en formato Papel. Además actualiza la estantería según el nuevo progreso.
  void _recalcularProgreso() {
    final bool esPapel = _formatoSeleccionado == 'Papel';
    if (!esPapel) {
      return;
    }

    final int totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    final int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;

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

  /// Guarda todos los cambios en Firestore.
  ///
  /// Si el libro pasa a estado `'Leído'` por primera vez, activa confetti.
  /// Usa `DatabaseService.editarLibroYStats` que además actualiza las estadísticas del usuario.
  Future<void> _guardarCambios() async {
    try {
      final formato = _formatoSeleccionado;
      int totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
      int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
      int progresoFinal = _progreso.toInt();

      if (formato == 'Papel' && totales > 0 && actual > totales) {
        mostrarSnackBar(context, "La página actual ($actual) no puede superar al total ($totales)", Colors.red);
        return;
      }

      final progresoRaw = widget.datosActuales['progress'];
      final paginaRaw = widget.datosActuales['currentPage'];
      final int progresoOriginal = progresoRaw is int ? progresoRaw : (progresoRaw is double ? progresoRaw.toInt() : 0);
      final int paginaOriginal = paginaRaw is int ? paginaRaw : (paginaRaw is double ? paginaRaw.toInt() : 0);

      bool haDisminuido = false;
      String mensajeConfirmacion = "";

      if (formato == 'Papel') {
        if (actual < paginaOriginal && paginaOriginal > 0) {
          haDisminuido = true;
          mensajeConfirmacion = "Has indicado la página $actual, menor a la anterior ($paginaOriginal). ¿Seguro que quieres retroceder?";
        }
      } else {
        if (progresoFinal < progresoOriginal && progresoOriginal > 0) {
          haDisminuido = true;
          mensajeConfirmacion = "Has indicado $progresoFinal%, menor al anterior ($progresoOriginal%). ¿Seguro que quieres retroceder?";
        }
      }

      if (haDisminuido) {
        final bool? confirmar = await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text("¿Disminuir progreso?", style: TextStyle(fontWeight: FontWeight.bold)),
              content: Text(mensajeConfirmacion),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancelar", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Sí, disminuir", style: TextStyle(color: AppColors.naranja, fontWeight: FontWeight.bold))),
              ],
            );
          },
        );
        if (confirmar != true || !mounted) {
          return;
        }
      }

      if (formato == 'Papel' && totales > 0) {
        progresoFinal = ((actual / totales) * 100).round().clamp(0, 100);
      }
      if (progresoFinal >= 100) {
        _estanteria = 'Leído';
      }

      final bool esNuevoLeido = (_estanteria == 'Leído' && widget.datosActuales['shelf'] != 'Leído');

      Map<String, dynamic> datosUserBook = {
        'shelf': _estanteria,
        'progress': progresoFinal,
        'rating': _puntuacion,
        'notes': _notasController.text,
        'totalPages': totales,
        'currentPage': formato == 'Papel' ? actual : 0,
        'format': formato,
        'dateFinished': _estanteria == 'Leído' ? FieldValue.serverTimestamp() : null,
        'bookCover': _bookCoverController.text.trim(),
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
        if (esNuevoLeido) {
          _confettiController.play();
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        if (mounted) {
          Navigator.pop(context);
          mostrarSnackBar(context, esNuevoLeido ? "🎉 ¡Felicidades! Libro completado." : "Libro actualizado.", AppColors.naranja);
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