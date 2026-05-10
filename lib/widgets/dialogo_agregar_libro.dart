import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Diálogo modal para agregar un nuevo libro a la biblioteca del usuario.
///
/// Características principales:
/// 1. Búsqueda integrada en catálogo global (Firestore + Google Books API).
/// 2. Validación de campos obligatorios y formatos numéricos.
/// 3. Lógica condicional según estantería ('Leído', 'Leyendo', 'Por leer') y formato ('Papel', 'Digital').
/// 4. Cálculo automático de progreso para formato Papel (página actual / total * 100).
/// 5. Selección de fechas de inicio/fin solo para libros 'Leído'.
///
/// Retorna al padre un mapa con todos los datos del libro para ser procesado por DatabaseService.
class DialogoAgregarLibro extends StatefulWidget {
  const DialogoAgregarLibro({super.key});

  @override
  State<DialogoAgregarLibro> createState() => _DialogoAgregarLibroState();
}

class _DialogoAgregarLibroState extends State<DialogoAgregarLibro> {
  // Clave para validar el formulario completo.
  final _formKey = GlobalKey<FormState>();
  
  // Controladores para los campos de texto del formulario.
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();
  final TextEditingController _progresoController = TextEditingController(text: "0");
  final TextEditingController _paginasTotalesController = TextEditingController();
  final TextEditingController _paginaActualController = TextEditingController();
  final TextEditingController _coverUrlController = TextEditingController();

  // Estado local del formulario.
  String _estanteriaSeleccionada = 'Leyendo';
  String _formatoLibro = 'Papel';
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 7));
  DateTime _fechaFin = DateTime.now();

  // Variables para almacenar datos adicionales obtenidos de la búsqueda global.
  String? _bookIdGlobal;    // ID del libro en catálogo global (Firestore).
  String? _isbnGlobal;      // ISBN del libro (para identificación única).
  String? _sinopsisGlobal;  // Sinopsis del libro.
  String? _generoGlobal;    // Género del libro.

  @override
  void dispose() {
    // Liberar recursos de los controladores para evitar fugas de memoria.
    _tituloController.dispose();
    _autorController.dispose();
    _progresoController.dispose();
    _paginasTotalesController.dispose();
    _paginaActualController.dispose();
    _coverUrlController.dispose();
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

              // Campo Título con búsqueda integrada y botón de limpiar.
              TextFormField(
                controller: _tituloController,
                decoration: AppInputStyles.inputDecoration("Título", prefixIcon: Icons.search).copyWith(
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _mostrarBusquedaLibros, // Abre diálogo de búsqueda híbrida.
                  ),
                  suffixIcon: _tituloController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _limpiarFormulario, // Limpia todo el formulario.
                        )
                      : null,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? "El título es obligatorio"
                    : null,
                onChanged: (val) {
                  // Si el usuario edita manualmente el título, invalidamos la selección de catálogo global.
                  if (_bookIdGlobal != null) {
                    setState(() => _bookIdGlobal = null);
                  }
                },
              ),

              // Indicador visual si el libro fue verificado en catálogo global.
              if (_bookIdGlobal != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, bottom: 8),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "Datos verificados",
                        style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _autorController,
                decoration: AppInputStyles.inputDecoration("Autor"),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? "El autor es necesario"
                    : null,
              ),
              const SizedBox(height: 15),

              // Campo opcional para URL de portada personalizada.
              TextField(
                controller: _coverUrlController,
                decoration: AppInputStyles.inputDecoration("URL de imagen (opcional)", prefixIcon: Icons.link),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 20),

              // Selector de estantería con lógica automática de progreso.
              DropdownButtonFormField<String>(
                initialValue: _estanteriaSeleccionada,
                decoration: AppInputStyles.inputDecoration('Estantería'),
                items: ['Leído', 'Leyendo', 'Por leer']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _estanteriaSeleccionada = val!;
                    // Auto-ajuste de progreso según estantería seleccionada.
                    if (_estanteriaSeleccionada == 'Leído') {
                      _progresoController.text = "100";
                    }
                    if (_estanteriaSeleccionada == 'Por leer') {
                      _progresoController.text = "0";
                    }
                  });
                },
              ),
              const SizedBox(height: 20),

              // Campos condicionales si el libro está en estado 'Leyendo'.
              if (_estanteriaSeleccionada == 'Leyendo') ...[
                // Selector de formato: Papel o Digital.
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'Papel', label: Text('Papel'), icon: Icon(Icons.menu_book)),
                    ButtonSegment(value: 'Digital', label: Text('Digital'), icon: Icon(Icons.tablet_android)),
                  ],
                  selected: {_formatoLibro},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() => _formatoLibro = newSelection.first);
                  },
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: AppColors.morado,
                    selectedForegroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 15),

                // Inputs específicos según formato seleccionado.
                if (_formatoLibro == 'Papel') ...[
                  Row(
                    children: [
                      // Página actual: validada contra el total de páginas.
                      Expanded(
                        child: buildNumberField(
                          label: 'Pág. Actual',
                          controller: _paginaActualController,
                          maxPages: int.tryParse(_paginasTotalesController.text), // Validación dinámica.
                          onChanged: (_) => setState(() {}), // Refresca UI si es necesario.
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Total de páginas: campo obligatorio para formato Papel.
                      Expanded(
                        child: buildNumberField(
                          label: 'Total Págs.',
                          controller: _paginasTotalesController,
                          isTotalField: true, // Valida que sea > 0.
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Para formato Digital: input directo de porcentaje (0-100).
                  TextFormField(
                    controller: _progresoController,
                    keyboardType: TextInputType.number,
                    decoration: AppInputStyles.inputDecoration('Porcentaje').copyWith(suffixText: '%'),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 0 || n > 100) return "0-100";
                      return null;
                    },
                  ),
                ],
              ],

              // Selectores de fecha solo para libros en estado 'Leído'.
              if (_estanteriaSeleccionada == 'Leído') ...[
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Fecha de inicio de lectura.
                    Expanded(
                      child: ListTile(
                        title: const Text("Inicio", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaInicio)),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _fechaInicio,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _fechaInicio = picked);
                          }
                        },
                      ),
                    ),
                    // Fecha de finalización de lectura.
                    Expanded(
                      child: ListTile(
                        title: const Text("Fin", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        subtitle: Text(DateFormat('dd/MM/yyyy').format(_fechaFin)),
                        contentPadding: EdgeInsets.zero,
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _fechaFin,
                            firstDate: _fechaInicio, // No puede ser anterior al inicio.
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _fechaFin = picked);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 30),

              // Botones de acción: Cancelar o Agregar.
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
                    onPressed: _enviarDatos, // Valida y devuelve datos al padre.
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

  /// Limpia todos los campos del formulario y reinicia variables de estado.
  void _limpiarFormulario() {
    setState(() {
      _tituloController.clear();
      _autorController.clear();
      _paginasTotalesController.clear();
      _paginaActualController.clear();
      _coverUrlController.clear();
      _progresoController.text = "0";
      // Reiniciar datos de catálogo global.
      _bookIdGlobal = null;
      _isbnGlobal = null;
      _sinopsisGlobal = null;
      _generoGlobal = null;
    });
  }

  /// Abre el diálogo de búsqueda híbrida y rellena el formulario con los resultados.
  ///
  /// Si el libro viene de la API de Google Books, los campos adicionales (ISBN, sinopsis, género)
  /// se almacenan en variables globales para ser enviados al servicio de base de datos.
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
        
        // Normalización de género: si viene vacío, usar valor por defecto.
        String generoRaw = resultado['genre'] ?? '';
        _generoGlobal = generoRaw.isEmpty ? 'Sin género' : generoRaw;
        
        // Si hay páginas en los datos, prellenar el campo total.
        if (resultado['pages'] != null && resultado['pages'] > 0) {
          _paginasTotalesController.text = resultado['pages'].toString();
        }
      });
    }
  }

  /// Valida el formulario, calcula el progreso final y devuelve los datos al widget padre.
  ///
  /// Lógica de cálculo de progreso:
  /// - 'Leído': progreso = 100%, página actual = total de páginas.
  /// - 'Leyendo' + Papel: progreso = (página actual / total) * 100, redondeado.
  /// - 'Leyendo' + Digital: progreso = valor ingresado directamente (0-100).
  /// - 'Por leer': progreso = 0%.
  void _enviarDatos() {
    // 1. Validación estándar del Form (campos vacíos, formatos, etc.).
    if (!_formKey.currentState!.validate()) return;

    int paginasTotales = int.tryParse(_paginasTotalesController.text) ?? 0;
    int paginaActual = int.tryParse(_paginaActualController.text) ?? 0;
    int progresoFinal = 0;

    // Cálculo de progreso según estantería y formato.
    if (_estanteriaSeleccionada == 'Leído') {
      progresoFinal = 100;
      paginaActual = paginasTotales; // Si está leído, la página actual es el total.
    } else if (_estanteriaSeleccionada == 'Leyendo') {
      if (_formatoLibro == 'Papel' && paginasTotales > 0) {
        // Para Papel: calcular porcentaje basado en páginas.
        progresoFinal = ((paginaActual / paginasTotales) * 100).round();
      } else {
        // Para Digital: usar el porcentaje ingresado directamente.
        progresoFinal = int.tryParse(_progresoController.text) ?? 0;
      }
    }
    // Para 'Por leer', progresoFinal permanece en 0 (valor por defecto).

    // Devolver mapa completo con todos los datos necesarios para DatabaseService.
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
      'cover': _coverUrlController.text.trim(),
      'isbn': _isbnGlobal ?? '',
      'sinopsis': _sinopsisGlobal ?? '',
      'genero': (_generoGlobal == null || _generoGlobal!.isEmpty) ? 'Sin género' : _generoGlobal!,
    });
  }
}