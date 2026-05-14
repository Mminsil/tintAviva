import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';
import '../utils/input_validadores.dart';

/// Diálogo modal para agregar un nuevo libro a la biblioteca del usuario.
///
/// Características principales:
/// 1. Búsqueda integrada en catálogo global (Firestore + Google Books API) vía `mostrarDialogoBusquedaLibros`
/// 2. Validación de campos obligatorios y formatos numéricos con `GlobalKey<FormState>`
/// 3. Lógica condicional según estantería (`'Leído'`, `'Leyendo'`, `'Por leer'`) y formato (`'Papel'`, `'Digital'`)
/// 4. Cálculo automático de progreso para formato Papel: `(página actual / total) * 100`
/// 5. Selección de fechas de inicio/fin solo para libros en estado `'Leído'`
///
/// Retorna al padre un `Map<String, dynamic>` con todos los datos del libro para ser procesado por `DatabaseService`:
/// ```dart
/// {
///   'titulo': String,           // Título del libro (obligatorio)
///   'autor': String,            // Autor del libro (obligatorio)
///   'estanteria': String,       // 'Leído' | 'Leyendo' | 'Por leer'
///   'progreso': int,            // Porcentaje calculado (0-100)
///   'fechaInicio': DateTime?,   // Solo si estantería == 'Leído'
///   'fechaFin': DateTime?,      // Solo si estantería == 'Leído'
///   'formato': String,          // 'Papel' | 'Digital'
///   'paginasTotales': int,      // Total de páginas (0 si es Digital)
///   'paginaActual': int,        // Página actual (0 si es Digital o no 'Leyendo')
///   'cover': String,            // URL de portada (puede ser vacío)
///   'isbn': String,             // ISBN del catálogo global (puede ser vacío)
///   'sinopsis': String,         // Sinopsis del catálogo global (puede ser vacío)
///   'genero': String,           // Género normalizado ('Sin género' si vacío)
/// }
/// ```
///
/// Ejemplo de uso:
/// ```dart
/// // En MiBibliotecaPage, desde el botón "Agregar libro":
/// final resultado = await showDialog<Map<String, dynamic>>(
///   context: context,
///   builder: (context) => const DialogoAgregarLibro(),
/// );
/// if (resultado != null) {
///   // Procesar en DatabaseService.agregarLibroBiblioteca
///   await DatabaseService.agregarLibroBiblioteca(
///     userId: user.uid,
///     titulo: resultado['titulo'],
///     // ... resto de parámetros
///   );
/// }
/// ```
class DialogoAgregarLibro extends StatefulWidget {
  const DialogoAgregarLibro({super.key});

  @override
  State<DialogoAgregarLibro> createState() => _DialogoAgregarLibroState();
}

class _DialogoAgregarLibroState extends State<DialogoAgregarLibro> {
  /// Clave para validar el formulario completo.
  ///
  /// Se usa en `_enviarDatos()` con `_formKey.currentState!.validate()`
  /// para ejecutar todas las validaciones de `TextFormField.validator`.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controladores para los campos de texto del formulario.
  ///
  /// Se liberan en `dispose()` para evitar fugas de memoria.
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();
  final TextEditingController _progresoController = TextEditingController();
  final TextEditingController _paginasTotalesController =
      TextEditingController();
  final TextEditingController _paginaActualController = TextEditingController();
  final TextEditingController _coverUrlController = TextEditingController();

  /// Estado local del formulario: estantería seleccionada.
  ///
  /// Valores permitidos: `'Leído'`, `'Leyendo'`, `'Por leer'`
  /// Por defecto: `'Leyendo'`
  ///
  /// Efectos al cambiar:
  /// - `'Leído'`: progreso = 100, muestra selectores de fecha
  /// - `'Por leer'`: progreso = 0, oculta campos de progreso
  /// - `'Leyendo'`: muestra selector de formato (Papel/Digital)
  String _estanteriaSeleccionada = 'Leyendo';

  /// Estado local del formulario: formato del libro.
  ///
  /// Valores permitidos: `'Papel'`, `'Digital'`
  /// Por defecto: `'Papel'`
  ///
  /// Efectos al cambiar:
  /// - `'Papel'`: muestra campos "Pág. Actual" + "Total Págs."
  /// - `'Digital'`: muestra campo "Porcentaje" (0-100)
  String _formatoLibro = 'Papel';

  /// Fecha de inicio de lectura (solo relevante si `_estanteriaSeleccionada == 'Leído'`).
  ///
  /// Por defecto: 7 días antes de la fecha actual.
  DateTime _fechaInicio = DateTime.now().subtract(const Duration(days: 7));

  /// Fecha de finalización de lectura (solo relevante si `_estanteriaSeleccionada == 'Leído'`).
  ///
  /// Por defecto: fecha actual.
  /// Restricción: no puede ser anterior a `_fechaInicio`.
  DateTime _fechaFin = DateTime.now();

  /// Variables para almacenar datos adicionales obtenidos de la búsqueda global.

  /// ID del libro en el catálogo global (colección `'books'` de Firestore).
  /// Si es `null`, el libro se considera "manual" (escrito por el usuario).
  String? _bookIdGlobal;

  /// ISBN del libro (para identificación única y generación de `bookId`).
  String? _isbnGlobal;

  /// Sinopsis del libro (para enriquecer el detalle en `DetalleLibroPage`).
  String? _sinopsisGlobal;

  /// Género del libro (normalizado a `'Sin género'` si viene vacío).
  String? _generoGlobal;

  @override
  void initState() {
    super.initState();

    // Inicializar valores según estado y formato por defecto
    if (_estanteriaSeleccionada == 'Leyendo') {
      if (_formatoLibro == 'Digital') {
        _progresoController.text = "1";
      } else {
        _paginaActualController.text = "1";
      }
    }
  }

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

              // Campo Título con búsqueda integrada y botón de limpiar.
              TextFormField(
                controller: _tituloController,
                decoration:
                    AppInputStyles.inputDecoration(
                      "Título",
                      prefixIcon: Icons.search,
                    ).copyWith(
                      prefixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed:
                            _mostrarBusquedaLibros, // Abre diálogo de búsqueda híbrida.
                      ),
                      suffixIcon: _tituloController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed:
                                  _limpiarFormulario, // Limpia todo el formulario.
                            )
                          : null,
                    ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? "El título es obligatorio"
                    : null,
                onChanged: (val) {
                  // Si el usuario edita manualmente el título, invalidamos la selección de catálogo global.
                  if (_bookIdGlobal != null) {
                    setState(() {
                      _bookIdGlobal = null;
                    });
                  }
                },
              ),

              // Indicador visual si el libro fue verificado en catálogo global.
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
                decoration: AppInputStyles.inputDecoration(
                  "URL de imagen (opcional)",
                  prefixIcon: Icons.link,
                ),
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
                      _paginaActualController.text =
                          _paginasTotalesController.text;
                    }
                    if (_estanteriaSeleccionada == 'Por leer') {
                      _progresoController.text = "0";
                      _paginaActualController.text = "";
                    }
                    if (_estanteriaSeleccionada == 'Leyendo') {
                      // Ajustar según formato
                      if (_formatoLibro == 'Digital') {
                        _progresoController.text = "1";
                      } else {
                        _paginaActualController.text = "1";
                      }
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
                  selected: {_formatoLibro},
                  onSelectionChanged: (Set<String> newSelection) {
                    setState(() {
                      _formatoLibro = newSelection.first;
                      // Si está en 'Leyendo', ajustar campo según nuevo formato
                      if (_estanteriaSeleccionada == 'Leyendo') {
                        if (_formatoLibro == 'Digital') {
                          _progresoController.text = "1";
                          _paginaActualController.clear();
                        } else {
                          _paginaActualController.text = "1";
                          _progresoController.text = "0";
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

                // Inputs específicos según formato seleccionado.
                if (_formatoLibro == 'Papel') ...[
                  Row(
                    children: [
                      // Página actual: validada contra el total de páginas.
                      Expanded(
                        child: buildNumberField(
                          label: 'Pág. Actual',
                          controller: _paginaActualController,
                          maxPages: int.tryParse(
                            _paginasTotalesController.text,
                          ), // Validación dinámica.
                          onChanged: (_) {
                            setState(() {}); // Refresca UI si es necesario.
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Total de páginas: campo obligatorio para formato Papel.
                      Expanded(
                        child: buildNumberField(
                          label: 'Total Págs.',
                          controller: _paginasTotalesController,
                          isTotalField: true, // Valida que sea > 0.
                          onChanged: (_) {
                            setState(() {});
                          },
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // Para formato Digital: input directo de porcentaje (0-100).
                  TextFormField(
                    controller: _progresoController,
                    keyboardType: TextInputType.number,
                    decoration: AppInputStyles.inputDecoration(
                      'Porcentaje',
                    ).copyWith(suffixText: '%'),
                    validator: (v) {
                      final int? n = int.tryParse(v ?? '');
                      if (n == null || n < 0 || n > 100) {
                        return "0-100";
                      }
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
                          if (picked != null) {
                            setState(() {
                              _fechaInicio = picked;
                            });
                          }
                        },
                      ),
                    ),
                    // Fecha de finalización de lectura.
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
                            firstDate:
                                _fechaInicio, // No puede ser anterior al inicio.
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _fechaFin = picked;
                            });
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
                    onPressed:
                        _enviarDatos, // Valida y devuelve datos al padre.
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

  /// Limpia todos los campos del formulario y reinicia variables de estado.
  ///
  /// Acciones:
  /// - Limpia todos los `TextEditingController`
  /// - Reset `_progresoController` a "0"
  /// - Invalida datos de catálogo global (`_bookIdGlobal`, `_isbnGlobal`, etc.)
  /// - Llama a `setState` para reconstruir la UI con los valores por defecto
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
  /// Flujo:
  /// 1. Llama a `mostrarDialogoBusquedaLibros(context)` que devuelve `Map<String, dynamic>?`
  /// 2. Si el usuario selecciona un libro y el widget sigue montado:
  ///    - Actualiza `_tituloController`, `_autorController`, `_coverUrlController`
  ///    - Guarda `_bookIdGlobal` para marcar el libro como "verificado"
  ///    - Guarda `_isbnGlobal`, `_sinopsisGlobal`, `_generoGlobal` para enviar a `DatabaseService`
  ///    - Si hay `pages` en los datos, pre-llena `_paginasTotalesController`
  /// 3. Normaliza `_generoGlobal`: si viene vacío, usa `'Sin género'`
  ///
  /// Nota: Los campos de título y autor quedan editables; si el usuario los modifica,
  /// `_bookIdGlobal` se invalida automáticamente en el `onChanged` del campo título.
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
        final String generoRaw = resultado['genre'] ?? '';
        _generoGlobal = generoRaw.isEmpty ? 'Sin género' : generoRaw;

        // Si hay páginas en los datos, prellenar el campo total.
        if (resultado['pages'] != null && resultado['pages'] > 0) {
          _paginasTotalesController.text = resultado['pages'].toString();
        }
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO: VALIDACIÓN Y RETORNO DE DATOS
  // ─────────────────────────────────────────────────────────────

  /// Valida el formulario, calcula el progreso final y devuelve los datos al widget padre.
  ///
  /// Flujo detallado:
  /// 1. Valida el formulario con `_formKey.currentState!.validate()`
  /// 2. Parsea `paginasTotales` y `paginaActual` con fallback a 0 si falla el parseo
  /// 3. Calcula `progresoFinal` según estantería y formato:
  ///    - `'Leído'`: progreso = 100, `paginaActual` = `paginasTotales`
  ///    - `'Leyendo'` + `'Papel'`: progreso = `((paginaActual / paginasTotales) * 100).round()`
  ///    - `'Leyendo'` + `'Digital'`: progreso = valor ingresado directamente (0-100)
  ///    - `'Por leer'`: progreso = 0 (valor por defecto)
  /// 4. Devuelve `Map<String, dynamic>` con todos los datos vía `Navigator.pop`
  ///
  /// Estructura del mapa de retorno:
  /// ```dart
  /// {
  ///   'titulo': String,           // Título trimmeado
  ///   'autor': String,            // Autor trimmeado
  ///   'estanteria': String,       // Valor seleccionado
  ///   'progreso': int,            // Calculado según lógica anterior
  ///   'fechaInicio': DateTime?,   // Solo si estantería == 'Leído'
  ///   'fechaFin': DateTime?,      // Solo si estantería == 'Leído'
  ///   'formato': String,          // 'Papel' | 'Digital'
  ///   'paginasTotales': int,      // 0 si es Digital o no se ingresó
  ///   'paginaActual': int,        // 0 si es Digital o no 'Leyendo'
  ///   'cover': String,            // URL trimmeada (puede ser vacío)
  ///   'isbn': String,             // Del catálogo o vacío
  ///   'sinopsis': String,         // Del catálogo o vacío
  ///   'genero': String,           // Normalizado a 'Sin género' si vacío
  /// }
  /// ```
  ///
  /// Nota: Este método no muestra `SnackBar` de error; delega la validación visual
  /// a los `TextFormField.validator` que ya muestran mensajes en rojo automáticamente.
  void _enviarDatos() {
    // 1. Validación estándar del Form (campos vacíos, formatos, etc.).
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final int paginasTotales =
        int.tryParse(_paginasTotalesController.text) ?? 0;
    // Quitar 'final' porque se reasigna más abajo si estantería == 'Leído'
    int paginaActual = int.tryParse(_paginaActualController.text) ?? 0;
    int progresoFinal = 0;

    // Cálculo de progreso según estantería y formato.
    if (_estanteriaSeleccionada == 'Leído') {
      progresoFinal = 100;
      paginaActual = paginasTotales; // Ahora sí permite reasignación
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
      'genero': (_generoGlobal == null || _generoGlobal!.isEmpty)
          ? 'Sin género'
          : _generoGlobal!,
    });
  }
}
