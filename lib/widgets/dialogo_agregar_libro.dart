import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';
import 'package:tintaviva/utils/ui_helpers.dart';
import '../utils/input_validadores.dart';

// ============================================================================
// DIÁLOGO DE AGREGAR LIBRO
// ============================================================================

/// Diálogo modal para agregar un nuevo libro a la biblioteca del usuario.
///
/// Soporta tres formatos:
/// - `'Papel'`: ingreso de páginas (actual/total)
/// - `'Digital'`: ingreso directo de porcentaje (0-100)
/// - `'Audio'`: ingreso de tiempos en formato MM:SS o HH:MM:SS (SIN campo de porcentaje)
///
/// Retorna al padre un `Map<String, dynamic>` con todos los datos del libro.
class DialogoAgregarLibro extends StatefulWidget {
  const DialogoAgregarLibro({super.key});

  @override
  State<DialogoAgregarLibro> createState() => _DialogoAgregarLibroState();
}

class _DialogoAgregarLibroState extends State<DialogoAgregarLibro> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers para campos de texto
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();
  final TextEditingController _progresoController = TextEditingController();
  final TextEditingController _paginasTotalesController =
      TextEditingController();
  final TextEditingController _paginaActualController = TextEditingController();
  final TextEditingController _coverUrlController = TextEditingController();

  // Controllers para formato Audio (se inicializan bajo demanda)
  TextEditingController? _tiempoTotalController;
  TextEditingController? _tiempoActualController;

  // Estado del formulario
  String _estanteriaSeleccionada = 'Leyendo';
  String _formatoLibro = 'Papel'; // Por defecto Papel para mayor compatibilidad
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaFin = DateTime.now();

  // Campos opcionales desde búsqueda en catálogo global
  String? _bookIdGlobal;
  String? _isbnGlobal;
  String? _sinopsisGlobal;
  String? _generoGlobal;

  @override
  void initState() {
    super.initState();
    // Inicializar valores según estado y formato por defecto
    _inicializarValoresPorDefecto();
  }

  /// Inicializa los valores del formulario según el estado y formato actuales.
  void _inicializarValoresPorDefecto() {
    if (_estanteriaSeleccionada == 'Leyendo') {
      if (_formatoLibro == 'Digital') {
        _progresoController.text = "1";
      } else if (_formatoLibro == 'Papel') {
        _paginaActualController.text = "1";
      } else if (_formatoLibro == 'Audio') {
        _tiempoTotalController ??= TextEditingController(text: "00:00:00");
        _tiempoActualController ??= TextEditingController(text: "00:00");
      }
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _progresoController.dispose();
    _paginasTotalesController.dispose();
    _paginaActualController.dispose();
    _coverUrlController.dispose();
    _tiempoTotalController?.dispose();
    _tiempoActualController?.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD: UI DEL DIÁLOGO
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      backgroundColor: AppColors.fondoClaro,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Agregar nuevo libro', style: AppTextStyles.dialogTitle),
              const SizedBox(height: 20),

              // Campo Título con búsqueda integrada
              TextFormField(
                controller: _tituloController,
                decoration:
                    AppInputStyles.inputDecoration(
                      "Título",
                      prefixIcon: Icons.search,
                    ).copyWith(
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _mostrarBusquedaLibros,
                      ),
                      suffixIcon: _tituloController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: _limpiarFormulario,
                            )
                          : null,
                    ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? "El título es obligatorio"
                    : null,
                onChanged: (val) {
                  if (_bookIdGlobal != null) {
                    setState(() => _bookIdGlobal = null);
                  }
                },
              ),

              // Indicador de datos verificados
              if (_bookIdGlobal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, bottom: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Datos verificados",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 15),

              // Autor
              TextFormField(
                controller: _autorController,
                decoration: AppInputStyles.inputDecoration("Autor"),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? "El autor es necesario"
                    : null,
              ),
              const SizedBox(height: 15),

              // URL de portada (opcional)
              TextField(
                controller: _coverUrlController,
                decoration: AppInputStyles.inputDecoration(
                  "URL de imagen (opcional)",
                  prefixIcon: Icons.link,
                ),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),

              // Selector de estantería
              DropdownButtonFormField<String>(
                initialValue: _estanteriaSeleccionada,
                decoration: AppInputStyles.inputDecoration('Estantería'),
                items: ['Leído', 'Leyendo', 'Por leer']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _estanteriaSeleccionada = val!;
                    if (_estanteriaSeleccionada == 'Leído') {
                      _progresoController.text = "100";
                      _paginaActualController.text =
                          _paginasTotalesController.text;
                    }
                    if (_estanteriaSeleccionada == 'Por leer') {
                      _progresoController.text = "0";
                      _paginaActualController.text = "";
                      _tiempoActualController?.clear();
                      _tiempoTotalController?.clear();
                      _formKey.currentState?.reset();
                    }
                    if (_estanteriaSeleccionada == 'Leyendo') {
                      _inicializarValoresPorDefecto();
                    }
                  });
                },
              ),
              const SizedBox(height: 20),

              // Campos condicionales si está en 'Leyendo'
              if (_estanteriaSeleccionada == 'Leyendo') ...[
                // Selector de formato: Papel, Digital o Audio
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
                  selected: {_formatoLibro},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _formatoLibro = newSelection.first;
                      if (_estanteriaSeleccionada == 'Leyendo') {
                        if (_formatoLibro == 'Digital') {
                          _progresoController.text = "1";
                          _paginaActualController.clear();
                          _tiempoTotalController?.clear();
                          _tiempoActualController?.clear();
                        } else if (_formatoLibro == 'Papel') {
                          _paginaActualController.text = "1";
                          _progresoController.text = "0";
                          _tiempoTotalController?.clear();
                          _tiempoActualController?.clear();
                        } else if (_formatoLibro == 'Audio') {
                          _paginaActualController.clear();
                          _progresoController.clear();
                          _tiempoTotalController ??= TextEditingController(
                            text: "00:00:00",
                          );
                          _tiempoActualController ??= TextEditingController(
                            text: "00:00",
                          );
                        }
                      }
                    });
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.morado,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),

                // ─────────────────────────────────────────────────
                // INPUTS SEGÚN FORMATO SELECCIONADO
                // ─────────────────────────────────────────────────

                // CASO 1: Formato Papel → campos de páginas
                if (_formatoLibro == 'Papel') ...[
                  Row(
                    children: [
                      Expanded(
                        child: buildNumberField(
                          label: 'Pág. Actual',
                          controller: _paginaActualController,
                          maxPages: int.tryParse(
                            _paginasTotalesController.text,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: buildNumberField(
                          label: 'Total Págs.',
                          controller: _paginasTotalesController,
                          isTotalField: true,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ]
                // CASO 2: Formato Digital → SOLO campo de porcentaje (0-100)
                else if (_formatoLibro == 'Digital') ...[
                  TextFormField(
                    controller: _progresoController,
                    keyboardType: TextInputType.number,
                    decoration: AppInputStyles.inputDecoration(
                      'Porcentaje',
                    ).copyWith(suffixText: '%'),
                    validator: (v) {
                      final int? n = int.tryParse(v ?? '');
                      if (n == null || n < 0 || n > 100) return "0-100";
                      return null;
                    },
                  ),
                ]
                // CASO 3: Formato Audio → SOLO campos de tiempo (SIN porcentaje)
                else if (_formatoLibro == 'Audio') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _tiempoActualController,
                          keyboardType: TextInputType.datetime,
                          decoration:
                              AppInputStyles.inputDecoration(
                                'Tiempo actual',
                              ).copyWith(
                                helperText: 'Ej: 30:45 o 1:20:15',
                                helperStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                suffixText: '⏱️',
                              ),
                          validator: (v) {
                            if (_estanteriaSeleccionada != 'Leyendo') return null;
                            if (v == null || v.trim().isEmpty){
                              return 'Requerido';
                            }
                            if (tiempoASegundos(v) == null){
                              return 'Formato inválido (MM:SS)';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _tiempoTotalController,
                          keyboardType: TextInputType.datetime,
                          decoration:
                              AppInputStyles.inputDecoration(
                                'Tiempo total',
                              ).copyWith(
                                helperText: 'Duración completa',
                                helperStyle: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                suffixText: '⏱️',
                              ),
                          validator: (v) {
                            if (_estanteriaSeleccionada != 'Leyendo') return null;
                            if (v == null || v.trim().isEmpty){
                              return 'Requerido';
                            }
                            final total = tiempoASegundos(v);
                            if (total == null || total <= 0){
                              return 'Debe ser > 0';
                            }
                            return null;
                          },
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  // Validación cruzada: tiempo actual <= tiempo total
                  if (_tiempoActualController?.text.isNotEmpty == true &&
                      _tiempoTotalController?.text.isNotEmpty == true)
                    Builder(
                      builder: (context) {
                        final actual = tiempoASegundos(
                          _tiempoActualController!.text,
                        );
                        final total = tiempoASegundos(
                          _tiempoTotalController!.text,
                        );
                        if (actual != null && total != null && actual > total) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '⚠️ El tiempo actual no puede superar el total',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                ],
              ],

              // Selectores de fecha solo para 'Leído'
              if (_estanteriaSeleccionada == 'Leído') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text(
                          "Inicio",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(_fechaInicio),
                        ),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _fechaInicio,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null){
                            setState(() => _fechaInicio = picked);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text(
                          "Fin",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          DateFormat('dd/MM/yyyy').format(_fechaFin),
                        ),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _fechaFin,
                            firstDate: _fechaInicio,
                            lastDate: DateTime.now(),
                          );
                          if (picked != null){
                            setState(() => _fechaFin = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 30),

              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: AppButtonStyles.primaryElevatedButton,
                    onPressed: _enviarDatos,
                    child: const Text('Agregar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS DE UI Y BÚSQUEDA
  // ─────────────────────────────────────────────────────────────

  void _limpiarFormulario() {
    setState(() {
      _tituloController.clear();
      _autorController.clear();
      _paginasTotalesController.clear();
      _paginaActualController.clear();
      _coverUrlController.clear();
      _progresoController.text = "0";
      _tiempoActualController?.clear();
      _tiempoTotalController?.clear();
      _bookIdGlobal = null;
      _isbnGlobal = null;
      _sinopsisGlobal = null;
      _generoGlobal = null;
      _estanteriaSeleccionada = 'Leyendo';
      _formatoLibro = 'Papel';
      _inicializarValoresPorDefecto();
    });
  }

  void _mostrarBusquedaLibros() async {
    final resultado = await mostrarDialogoBusquedaLibros(context);
    if (resultado != null && mounted) {
      setState(() {
        _tituloController.text = resultado['titulo'] ?? '';
        _autorController.text = resultado['autor'] ?? '';
        _coverUrlController.text = resultado['cover'] ?? '';
        _bookIdGlobal = resultado['bookId'];
        _isbnGlobal = resultado['isbn'] ?? '';
        _sinopsisGlobal = resultado['sinopsis'] ?? '';
        final String generoRaw = resultado['genre'] ?? '';
        _generoGlobal = generoRaw.isEmpty ? 'Sin género' : generoRaw;
        if (resultado['pages'] != null && resultado['pages'] > 0) {
          _paginasTotalesController.text = resultado['pages'].toString();
        }
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO: VALIDACIÓN Y RETORNO DE DATOS
  // ─────────────────────────────────────────────────────────────

  void _enviarDatos() {
    if (!_formKey.currentState!.validate()) return;

    final int paginasTotales =
        int.tryParse(_paginasTotalesController.text) ?? 0;
    int paginaActual = int.tryParse(_paginaActualController.text) ?? 0;
    int progresoFinal = 0;

    // Variables para Audio
    int? totalSeconds, currentSeconds;
    if (_formatoLibro == 'Audio' && _estanteriaSeleccionada == 'Leyendo') {
      totalSeconds = tiempoASegundos(_tiempoTotalController?.text ?? '');
      currentSeconds = tiempoASegundos(_tiempoActualController?.text ?? '');

      if (totalSeconds == null ||
          currentSeconds == null ||
          currentSeconds > totalSeconds ||
          totalSeconds <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verifica los tiempos del audiolibro')),
        );
        return;
      }
    }

    // Cálculo de progreso según formato
    if (_estanteriaSeleccionada == 'Leído') {
      progresoFinal = 100;
      paginaActual = paginasTotales;
    } else if (_estanteriaSeleccionada == 'Leyendo') {
      if (_formatoLibro == 'Papel' && paginasTotales > 0) {
        progresoFinal = ((paginaActual / paginasTotales) * 100).round();
      } else if (_formatoLibro == 'Digital') {
        progresoFinal = int.tryParse(_progresoController.text) ?? 0;
      } else if (_formatoLibro == 'Audio' &&
          totalSeconds != null &&
          currentSeconds != null) {
        progresoFinal = ((currentSeconds / totalSeconds) * 100).round().clamp(
          0,
          100,
        );
      }
    }
    // 'Por leer' → progresoFinal = 0 (por defecto)

    Navigator.pop(context, {
      'titulo': _tituloController.text.trim(),
      'autor': _autorController.text.trim(),
      'estanteria': _estanteriaSeleccionada,
      'progreso': progresoFinal,
      'fechaInicio': _estanteriaSeleccionada == 'Leído' ? _fechaInicio : null,
      'fechaFin': _estanteriaSeleccionada == 'Leído' ? _fechaFin : null,
      'formato': _formatoLibro,
      'paginasTotales': paginasTotales,
      'paginaActual': paginaActual,
      'totalSeconds': totalSeconds, // ← NUEVO: para Audio
      'currentSeconds': currentSeconds, // ← NUEVO: para Audio
      'cover': _coverUrlController.text.trim(),
      'isbn': _isbnGlobal ?? '',
      'sinopsis': _sinopsisGlobal ?? '',
      'genero': (_generoGlobal == null || _generoGlobal!.isEmpty)
          ? 'Sin género'
          : _generoGlobal!,
    });
  }
}
