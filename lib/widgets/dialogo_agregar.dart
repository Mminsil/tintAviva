import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Diálogo modal para agregar un nuevo libro a la biblioteca del usuario.
/// 
/// Permite:
/// 1. Buscar en el catálogo global (autocompletado de datos).
/// 2. Entrada manual de datos.
/// 3. Selección de formato (Papel/Digital) que cambia los inputs de progreso.
/// 4. Selección de fechas para libros finalizados.
class DialogoAgregar extends StatefulWidget {
  const DialogoAgregar({super.key});

  @override
  State<DialogoAgregar> createState() => _DialogoAgregarState();
}

class _DialogoAgregarState extends State<DialogoAgregar> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para los campos de texto.
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();
  final TextEditingController _progresoController = TextEditingController(text: "1");
  final TextEditingController _paginasTotalesController = TextEditingController();
  final TextEditingController _paginaActualController = TextEditingController();
  final TextEditingController _coverUrlController = TextEditingController();

  // Estado local del formulario.
  String _estanteriaSeleccionada = 'Leyendo';
  String _formatoLibro = 'Papel';
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaFin = DateTime.now();

  // Variables para gestión de catálogo global.
  String? _bookIdSeleccionado; // ID del libro si viene del catálogo.
  String? _coverSeleccionado;  // Portada del catálogo.
  bool _buscandoEnCatalogo = false;
  String? _customCoverUrl;     // URL manual introducida por el usuario.

  @override
  void dispose() {
    _tituloController.dispose();
    _autorController.dispose();
    _progresoController.dispose();
    _coverUrlController.dispose();
    _paginasTotalesController.dispose();
    _paginaActualController.dispose();
    super.dispose();
  }

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

              // Campo Título con búsqueda integrada.
              TextFormField(
                controller: _tituloController,
                readOnly: _buscandoEnCatalogo, // Bloquea edición manual si se busca.
                decoration: AppInputStyles.inputDecoration("Título", prefixIcon: Icons.search).copyWith(
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _mostrarBusquedaLibros, // Abre el diálogo de búsqueda.
                    tooltip: 'Buscar en catálogo',
                  ),
                  suffixIcon: _tituloController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() {
                            // Limpia todo el formulario al borrar título.
                            _tituloController.clear();
                            _bookIdSeleccionado = null;
                            _coverSeleccionado = null;
                            _autorController.clear();
                            _paginasTotalesController.clear();
                            _paginaActualController.clear();
                            _coverUrlController.clear();
                          }),
                        )
                      : null,
                ),
                validator: (value) => (value == null || value.trim().isEmpty) ? "Debes escribir un título" : null,
                onChanged: (value) {
                  // Si el usuario escribe manualmente, invalidamos la selección de catálogo.
                  if (_bookIdSeleccionado != null) {
                    setState(() => _bookIdSeleccionado = null);
                  }
                },
              ),

              // Feedback visual si el libro fue seleccionado del catálogo.
              if (_bookIdSeleccionado != null) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
                      const SizedBox(width: 4),
                      Text("Libro verificado en catálogo", style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                    ],
                  ),
                ),
              ],

              if (_bookIdSeleccionado == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text("¿No encuentras tu libro? Escríbelo manualmente.", style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _autorController,
                decoration: AppInputStyles.inputDecoration("Autor"),
                validator: (value) => (value == null || value.trim().isEmpty) ? "El autor es necesario" : null,
              ),
              const SizedBox(height: 15),

              TextField(
                controller: _coverUrlController,
                decoration: AppInputStyles.inputDecoration("URL de imagen (opcional)", prefixIcon: Icons.link),
                keyboardType: TextInputType.url,
                onChanged: (value) => _customCoverUrl = value.trim(),
              ),
              const SizedBox(height: 20),

              // Selector de Estantería.
              DropdownButtonFormField<String>(
                initialValue: _estanteriaSeleccionada,
                decoration: AppInputStyles.inputDecoration('Estantería'),
                items: ['Leído', 'Leyendo', 'Por leer'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (nuevoValor) {
                  setState(() {
                    _estanteriaSeleccionada = nuevoValor!;
                    // Auto-ajuste de progreso según estantería.
                    if (_estanteriaSeleccionada == 'Leído') _progresoController.text = "100";
                    if (_estanteriaSeleccionada == 'Por leer') _progresoController.text = "0";
                  });
                },
              ),

              // Campos condicionales si está "Leyendo".
              if (_estanteriaSeleccionada == 'Leyendo') ...[
                const SizedBox(height: 15),
                // Selector de Formato (Papel vs Digital).
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Papel', label: Text('Papel'), icon: Icon(Icons.menu_book)),
                    ButtonSegment(value: 'Digital', label: Text('Digital'), icon: Icon(Icons.tablet_android)),
                  ],
                  selected: {_formatoLibro},
                  onSelectionChanged: (Set<String> nuevaSeleccion) {
                    setState(() { _formatoLibro = nuevaSeleccion.first; });
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.morado,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),

                // Inputs específicos según formato.
                if (_formatoLibro == 'Papel') ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _paginaActualController,
                          keyboardType: TextInputType.number,
                          decoration: AppInputStyles.inputDecoration('Pág. Actual'),
                          validator: (value) => (value == null || value.isEmpty) ? "Obligatorio" : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _paginasTotalesController,
                          keyboardType: TextInputType.number,
                          decoration: AppInputStyles.inputDecoration('Total Págs.'),
                          validator: (value) => (value == null || value.isEmpty) ? "Obligatorio" : null,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Para digital, usamos porcentaje directo.
                  TextFormField(
                    controller: _progresoController,
                    keyboardType: TextInputType.number,
                    decoration: AppInputStyles.inputDecoration('Porcentaje actual').copyWith(suffixText: '%'),
                    validator: (value) {
                      final n = int.tryParse(value ?? '');
                      if (n == null || n < 0 || n > 100) return "Entre 0 y 100";
                      return null;
                    },
                  ),
                ],
              ],

              // Selectores de Fecha si está "Leído".
              if (_estanteriaSeleccionada == 'Leído') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text("Inicio", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaInicio)),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(context: context, initialDate: _fechaInicio, firstDate: DateTime(2000), lastDate: DateTime.now());
                          if (picked != null) setState(() => _fechaInicio = picked);
                        },
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text("Fin", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaFin)),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(context: context, initialDate: _fechaFin, firstDate: _fechaInicio, lastDate: DateTime.now());
                          if (picked != null) setState(() => _fechaFin = picked);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 30),

              // Botones de Acción.
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: AppButtonStyles.primaryElevatedButton,
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        // Cálculo final de datos antes de cerrar.
                        int? paginasTotales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
                        int? paginaActual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
                        int progresoFinal = 0;
                        int paginaGuardada = 0;

                        if (_estanteriaSeleccionada == 'Leído') {
                          progresoFinal = 100;
                          paginaGuardada = paginasTotales;
                        } else if (_estanteriaSeleccionada == 'Leyendo') {
                          if (_formatoLibro == 'Papel' && paginasTotales > 0) {
                            progresoFinal = ((paginaActual / paginasTotales) * 100).round();
                            paginaGuardada = paginaActual;
                          } else {
                            progresoFinal = int.tryParse(_progresoController.text.trim()) ?? 0;
                            paginaGuardada = 0;
                          }
                        }

                        // Prioridad de portada: URL manual > URL del catálogo.
                        String coverFinal = '';
                        if (_customCoverUrl != null && _customCoverUrl!.isNotEmpty) {
                          coverFinal = _customCoverUrl!;
                        } else if (_coverSeleccionado != null && _coverSeleccionado!.isNotEmpty) {
                          coverFinal = _coverSeleccionado!;
                        }

                        // Devolvemos el mapa de datos al padre.
                        Navigator.pop(context, {
                          'titulo': _tituloController.text.trim(),
                          'autor': _autorController.text.trim(),
                          'progreso': progresoFinal,
                          'paginaActual': paginaGuardada,
                          'estanteria': _estanteriaSeleccionada,
                          'fechaInicio': _estanteriaSeleccionada == 'Leído' ? _fechaInicio : null,
                          'fechaFin': _estanteriaSeleccionada == 'Leído' ? _fechaFin : null,
                          'cover': coverFinal,
                          'formato': _estanteriaSeleccionada == 'Leyendo' ? _formatoLibro : 'Digital',
                          'paginasTotales': paginasTotales,
                          'bookId': _bookIdSeleccionado,
                        });
                      }
                    },
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

  /// Abre el diálogo de búsqueda global y rellena el formulario con los resultados.
  void _mostrarBusquedaLibros() async {
    final resultado = await mostrarDialogoBusquedaLibros(context);

    if (resultado != null && mounted) {
      setState(() {
        _tituloController.text = resultado['titulo'] ?? '';
        _autorController.text = resultado['autor'] ?? '';
        _bookIdSeleccionado = resultado['bookId'];
        _coverUrlController.text = resultado['cover'] ?? '';
        
        final int? pagesFromDb = resultado['pages'];
        if (pagesFromDb != null && pagesFromDb > 0) {
          _paginasTotalesController.text = pagesFromDb.toString();
        } else {
          _paginasTotalesController.clear();
        }
        _buscandoEnCatalogo = false;
      });
    }
  }
}