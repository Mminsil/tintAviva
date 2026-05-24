import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';

// ------------------------------------------------------------------
// 1. DIÁLOGO PARA NUEVA ENTRADA DEL DIARIO
// ------------------------------------------------------------------

/// Diálogo unificado para guardar una Reflexión o una Cita en el diario de lectura.
///
/// Propósito:
/// - Permitir al usuario guardar una reflexión personal o una cita textual de un libro
/// - Adaptar la UI dinámicamente según el tipo seleccionado (`'diary'` | `'quote'`)
/// - Validar que el texto no esté vacío antes de devolver los datos al padre
///
/// Parámetros:
/// - [tituloLibro]: `String` → Título del libro (obligatorio, para contexto en el título del diálogo)
/// - [autorLibro]: `String?` → Autor del libro (opcional, para prellenar el campo de autor en citas)
/// - [tipoInicial]: `String` → Tipo por defecto: `'diary'` | `'quote'` (por defecto: `'diary'`)
///
/// Retorna al padre un `Map<String, dynamic>` con la estructura según el tipo:
/// ```dart
/// Si es 'diary' (reflexión):
/// {
///   'type': 'diary',
///   'text': String,      // Texto de la reflexión
///   'mood': String,      // Emoji de estado de ánimo (puede ser vacío)
/// }
///
///  Si es 'quote' (cita):
/// {
///   'type': 'quote',
///   'text': String,      // Texto de la cita
///   'author': String,    // Autor de la cita (prefiere input del usuario, fallback a autorLibro)
/// }
///
/// Si el usuario cancela:
/// null
/// ```
///
/// Características visuales:
/// - **ToggleButtons** para cambiar entre "Reflexión" y "Cita" con colores corporativos
/// - **TextField adaptable**: 3 líneas para citas, 4 para reflexiones
/// - **Selector de emojis** (solo para reflexiones): 7 opciones con feedback visual de selección
/// - **Campo de autor** (solo para citas): prellenado con `autorLibro` si está disponible
/// - **Validación**: bloquea guardar si el texto está vacío
///
/// Ejemplo de uso:
/// ```dart
/// En DetalleLibroPage, desde el botón "Guardar entrada":
/// final resultado = await showDialog<Map<String, dynamic>>(
///   context: context,
///   builder: (context) => DialogoGuardarEntrada(
///     tituloLibro: libro['title'],
///     autorLibro: libro['author'],
///     tipoInicial: 'quote', // ← Opcional: abrir directamente en modo cita
///   ),
/// );
/// if (resultado != null) {
/// Guardar en Firestore vía DatabaseService.agregarEntradaGlobal
///   await DatabaseService.agregarEntradaGlobal(
///     userId: user.uid,
///     userBookId: docId,
///     bookId: libro['bookId'],
///     bookTitle: libro['title'],
///     text: resultado['text'],
///     type: resultado['type'],
///     mood: resultado['mood'],      // Solo para 'diary'
///     author: resultado['author'],  // Solo para 'quote'
///   );
/// }
/// ```
class DialogoGuardarEntrada extends StatefulWidget {
  /// Título del libro para contexto en el título del diálogo.
  ///
  /// Se muestra en: `'Guardar en el diario de "${tituloLibro}"'`
  final String tituloLibro;

  /// Autor del libro para prellenar el campo de autor cuando se guarda una cita.
  ///
  /// Si es `null` o vacío, el campo de autor queda vacío para que el usuario lo complete.
  final String? autorLibro;

  /// Tipo de entrada por defecto al abrir el diálogo.
  ///
  /// Valores permitidos:
  /// - `'diary'` → Muestra selector de emojis + campo de texto de 4 líneas
  /// - `'quote'` → Muestra campo de autor + campo de texto de 3 líneas
  ///
  /// Por defecto: `'diary'`
  final String tipoInicial;

  const DialogoGuardarEntrada({
    super.key,
    required this.tituloLibro,
    this.autorLibro,
    this.tipoInicial = 'diary',
  });

  @override
  State<DialogoGuardarEntrada> createState() => _DialogoGuardarEntradaState();
}

class _DialogoGuardarEntradaState extends State<DialogoGuardarEntrada> {
  /// Controlador para el campo de texto principal (común para reflexiones y citas).
  final TextEditingController _textController = TextEditingController();

  /// Controlador para el campo de autor (solo usado cuando `_tipoSeleccionado == 'quote'`).
  ///
  /// Se pre-llena con `widget.autorLibro` en `initState` si está disponible.
  final TextEditingController _authorController = TextEditingController();

  /// Tipo de entrada seleccionado actualmente: `'diary'` | `'quote'`.
  ///
  /// Se inicializa con `widget.tipoInicial` y se actualiza con `setState` al tocar los ToggleButtons.
  late String _tipoSeleccionado;

  /// Emoji de estado de ánimo seleccionado para reflexiones.
  ///
  /// Valores posibles: elementos de `_moods` (`'😍'`, `'🤔'`, `'😢'`, etc.) o cadena vacía `''` si no se seleccionó.
  String _moodSeleccionado = '';

  /// Lista de emojis disponibles para seleccionar como estado de ánimo en reflexiones.
  final List<String> _moods = ['😍', '🤔', '😢', '😡', '😲', '😊', '😐'];

  @override
  void initState() {
    super.initState();
    // Si el autor está disponible, prellenar para citas (mejora UX al guardar citas)
    if (widget.autorLibro != null && widget.autorLibro!.isNotEmpty) {
      _authorController.text = widget.autorLibro!;
    }

    _tipoSeleccionado = widget.tipoInicial;
  }

  @override
  void dispose() {
    // Liberar controladores para evitar fugas de memoria
    _textController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD: UI DEL DIÁLOGO
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool esCita = _tipoSeleccionado == 'quote';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        widget.tituloLibro,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.morado,
          fontSize: 16,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle: Reflexión / Cita
              // Toggle personalizado responsive (evita overflow en diálogos)
              Row(
                children: [
                  Expanded(child: _buildToggleOption('Reflexión', 'diary')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildToggleOption('Cita', 'quote')),
                ],
              ),
              const SizedBox(height: 20),

              //  Campo de texto (común para ambos tipos)
              TextField(
                controller: _textController,
                minLines: esCita ? 4 : 6,
                maxLines: esCita ? 8 : 12,
                expands: false,
                autofocus: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                textCapitalization: TextCapitalization.sentences,
                enableInteractiveSelection: true,
                decoration: InputDecoration(
                  hintText: esCita
                      ? 'Pega o escribe la frase...'
                      : '¿Qué te hizo sentir esta lectura?',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  isDense: false,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.morado,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),

              //  Campos condicionales según tipo seleccionado
              if (!esCita) ...[
                // Selector de emojis (solo para Reflexión)
                const SizedBox(height: 20),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '¿Cómo te sientes?',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(width: 4),
                    Tooltip(
                      message:
                          'Selecciona tu emoción para recordar cómo te hizo sentir este libro.',
                      waitDuration: const Duration(milliseconds: 200),
                      triggerMode: TooltipTriggerMode.tap,
                      child: Icon(
                        Icons.help_outline,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _moods.map((mood) {
                    final bool isSelected = _moodSeleccionado == mood;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _moodSeleccionado = mood);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.naranja.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.naranja
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          mood,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                // Campo de autor (solo para Cita)
                const SizedBox(height: 20),
                const Text(
                  'Autor (opcional)',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _authorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Nombre del autor',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.morado,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        // Botón Cancelar: cierra el diálogo sin acción
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
        ),
        // Botón Guardar: valida y devuelve datos al padre
        ElevatedButton(
          onPressed: _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.morado,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  /// Widget auxiliar para las opciones de tipo (Reflexión/Cita).
  /// Reemplaza ToggleButtons para evitar overflow en diálogos estrechos.
  Widget _buildToggleOption(String label, String value) {
    final bool isSelected = _tipoSeleccionado == value;
    return GestureDetector(
      onTap: () => setState(() => _tipoSeleccionado = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.naranja : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.naranja : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.morado,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE GUARDADO
  // ─────────────────────────────────────────────────────────────

  /// Valida y devuelve los datos al padre vía `Navigator.pop`.
  ///
  /// Flujo:
  /// 1. Obtiene el texto del campo principal y lo trimmea
  /// 2. Si está vacío → cierra el diálogo con `null` (sin acción)
  /// 3. Si es `'diary'` → devuelve mapa con `'type'`, `'text'`, `'mood'`
  /// 4. Si es `'quote'` → devuelve mapa con `'type'`, `'text'`, `'author'`
  ///    - Prioriza el input del usuario (`_authorController.text`)
  ///    - Fallback a `widget.autorLibro` si el input está vacío
  ///
  /// Nota: No muestra `SnackBar` de error si el texto está vacío;
  /// simplemente cierra el diálogo silenciosamente. El padre puede
  /// manejar este caso si necesita feedback visual.
  void _guardar() {
    final String texto = _textController.text.trim();

    if (texto.isEmpty) {
      Navigator.pop(context, null);
      return;
    }

    if (_tipoSeleccionado == 'diary') {
      // Retorno para reflexión
      Navigator.pop(context, {
        'type': 'diary',
        'text': texto,
        'mood': _moodSeleccionado,
      });
    } else {
      // Retorno para cita
      final String autor = _authorController.text.trim();
      Navigator.pop(context, {
        'type': 'quote',
        'text': texto,
        'author': autor.isNotEmpty ? autor : widget.autorLibro ?? '',
      });
    }
  }
}
