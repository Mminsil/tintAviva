import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/dialogos_helpers.dart';

/// Diálogo modal para crear un nuevo club de lectura.
///
/// Flujo completo:
/// 1. Ingresar nombre, descripción, libro (por búsqueda o manual), autor, imagen del club (opcional)
/// 2. Seleccionar libro vía búsqueda en catálogo (Google Books) o escribir manualmente
/// 3. Si el libro ya fue leído por el usuario, muestra advertencia (al crearlo se reiniciará progreso)
/// 4. Al guardar, llama a `DatabaseService.crearClub` que crea el documento en Firestore
///
/// Características:
/// - Búsqueda híbrida: catálogo local + Google Books API vía `mostrarDialogoBusquedaLibros`
/// - Validación condicional: autor obligatorio solo para libros manuales
/// - Prevención de relectura no intencional: confirma si el usuario ya terminó el libro
/// - Generación de `bookId` único vía `DatabaseService.generarBookId`
///
/// Ejemplo de uso:
/// ```dart
/// // En ClubesPage, desde el SpeedDial:
/// showDialog(
///   context: context,
///   builder: (context) => const DialogoCrearClub(),
/// )
/// ```
class DialogoCrearClub extends StatefulWidget {
  const DialogoCrearClub({super.key});

  @override
  State<DialogoCrearClub> createState() => _DialogoCrearClubState();
}

class _DialogoCrearClubState extends State<DialogoCrearClub> {
  /// Clave para el `Form` que permite validar todos los campos del formulario.
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  /// Controladores para los campos de texto del formulario.
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _libroController = TextEditingController();
  final TextEditingController _autorController = TextEditingController();
  final TextEditingController _clubImageUrlController = TextEditingController();

  /// Portada del libro seleccionada desde el catálogo (URL de imagen).
  String? _portadaSeleccionado;

  /// ID del libro en la colección `'books'` si viene del catálogo.
  /// Si es `null`, el libro se considera "manual" (escrito por el usuario).
  String? _bookIdSeleccionado;

  /// URL de imagen personalizada para el club (opcional).
  String? _customClubImageUrl;

  /// Límite de miembros para el club (rango: 2-20, por defecto: 5).
  int _maxMiembros = 5;

  /// Datos adicionales del libro seleccionados desde el catálogo global.
  String? _isbnGlobal;
  String? _sinopsisGlobal;
  int? _pagesGlobal;

  @override
  void dispose() {
    // Liberar controladores para evitar fugas de memoria
    _nombreController.dispose();
    _descripcionController.dispose();
    _libroController.dispose();
    _autorController.dispose();
    _clubImageUrlController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD: UI DEL DIÁLOGO
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: AppColors.morado, width: 1),
      ),
      backgroundColor: const Color(0xFFF2F2F2),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Crea tu Club",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.morado,
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _nombreController,
                label: "Nombre del Club",
                hint: "Ej: Los devoradores de libros",
                validator: (value) => value?.trim().isEmpty ?? true
                    ? "El nombre es obligatorio"
                    : null,
              ),
              const SizedBox(height: 15),

              // Campo de libro con botón de búsqueda y botón de limpieza condicional
              TextFormField(
                controller: _libroController,
                decoration: InputDecoration(
                  labelText: "Libro a leer",
                  hintText: "Escribe o busca...",
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: _mostrarBusquedaLibrosParaClub,
                    tooltip: 'Buscar en catálogo',
                  ),
                  suffixIcon: _libroController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _libroController.clear();
                              _autorController.clear();
                              _bookIdSeleccionado = null;
                              _portadaSeleccionado = null;
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.naranja, width: 2),
                  ),
                ),
                validator: (value) => value?.trim().isEmpty ?? true
                    ? "El título es obligatorio"
                    : null,
                onChanged: (value) {
                  if (_bookIdSeleccionado != null) {
                    setState(() {
                      _bookIdSeleccionado = null;
                    });
                  }
                },
              ),

              // Mensaje condicional: si el libro viene del catálogo o es manual
              if (_bookIdSeleccionado == null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4),
                  child: Text(
                    "¿No encuentras tu libro? Escríbelo manualmente.",
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              if (_bookIdSeleccionado != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 4, bottom: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Libro y autor verificados en catálogo",
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 15),

              // Campo autor: readonly si viene del catálogo
              TextFormField(
                controller: _autorController,
                readOnly: _bookIdSeleccionado != null,
                decoration: InputDecoration(
                  labelText: "Autor",
                  hintText: _bookIdSeleccionado != null
                      ? "Del catálogo"
                      : "Obligatorio para libros manuales",
                  suffixIcon: _bookIdSeleccionado != null
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 18,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.naranja, width: 2),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                validator: (value) {
                  if (_bookIdSeleccionado == null &&
                      (value?.trim().isEmpty ?? true)) {
                    return "El autor es necesario";
                  }
                  return null;
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  _bookIdSeleccionado != null
                      ? ""
                      : "Escribe el autor del libro",
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
              const SizedBox(height: 15),

              // Imagen personalizada del club (opcional)
              _buildTextField(
                controller: _clubImageUrlController,
                label: "Imagen del Club",
                hint: "Pega una URL de imagen (opcional)",
                icon: Icons.image,
                keyboardType: TextInputType.url,
                onChanged: (value) {
                  final trimmed = value.trim();
                  setState(() {
                    _customClubImageUrl = trimmed.isEmpty ? null : trimmed;
                  });
                },
              ),
              if (_customClubImageUrl != null &&
                  _customClubImageUrl!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(_customClubImageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 15),

              _buildTextField(
                controller: _descripcionController,
                label: "Descripción",
                hint: "Cuéntales de qué va el club...",
                maxLines: 3,
              ),
              const SizedBox(height: 15),

              // Selector de límite de miembros (2 a 20)
              DropdownButtonFormField<int>(
                initialValue: _maxMiembros,
                decoration: _inputDecoration("Límite de miembros"),
                items: List.generate(19, (i) => i + 2)
                    .map(
                      (n) => DropdownMenuItem(
                        value: n,
                        child: Text("$n miembros"),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _maxMiembros = val!;
                  });
                },
              ),
              const SizedBox(height: 25),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      "Cancelar",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.morado,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: _validarYGuardar,
                    child: const Text(
                      "Crear Club",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
  // HELPERS DE UI
  // ─────────────────────────────────────────────────────────────

  /// Campo de texto reutilizable con configuración común.
  ///
  /// Parámetros:
  /// - [controller]: `TextEditingController` para el campo
  /// - [label]: Texto de la etiqueta (`InputDecoration.labelText`)
  /// - [hint]: Texto de ayuda opcional (`InputDecoration.hintText`)
  /// - [icon]: Icono opcional para el suffix (se muestra en color `AppColors.morado`)
  /// - [maxLines]: Número de líneas del campo (por defecto: 1)
  /// - [keyboardType]: Tipo de teclado (por defecto: `null` = texto)
  /// - [validator]: Función de validación para `TextFormField.validator`
  /// - [onTap]: Callback opcional para hacer el campo `readOnly` y abrir selector externo
  /// - [onChanged]: Callback opcional para reaccionar a cambios en el texto
  ///
  /// Retorna:
  /// - `TextFormField` configurado con estilos de `AppInputStyles` vía `_inputDecoration`
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    VoidCallback? onTap,
    Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: onTap != null,
      keyboardType: keyboardType,
      textCapitalization: TextCapitalization.sentences,
      enableInteractiveSelection: true,
      onChanged: onChanged,
      onTap: onTap,
      decoration: _inputDecoration(label).copyWith(
        hintText: hint,
        suffixIcon: icon != null ? Icon(icon, color: AppColors.morado) : null,
      ),
      validator: validator,
    );
  }

  /// Decoración base para inputs con estilos corporativos.
  ///
  /// Características:
  /// - Label en `AppColors.morado` con `FontWeight.w500`
  /// - Bordes redondeados (`borderRadius: 10`)
  /// - Borde enfocado: `AppColors.naranja` con `width: 2` para feedback visual
  /// - Borde por defecto: `Colors.grey.shade300`
  ///
  /// Parámetros:
  /// - [label]: Texto de la etiqueta
  ///
  /// Retorna:
  /// - `InputDecoration` listo para usar o personalizar con `.copyWith`
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppColors.morado,
        fontWeight: FontWeight.w500,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.naranja, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LÓGICA DE NEGOCIO: VALIDACIÓN Y GUARDADO
  // ─────────────────────────────────────────────────────────────

  /// Valida los campos y guarda el club en Firestore.
  ///
  /// Flujo detallado:
  /// 1. Valida el formulario con `_formKey.currentState!.validate()`
  /// 2. Validación adicional: autor requerido para libros manuales (`_bookIdSeleccionado == null`)
  /// 3. Genera `bookId` único vía `DatabaseService.generarBookId` (prioriza ISBN si existe)
  /// 4. Si el libro viene del catálogo (`_bookIdSeleccionado != null`):
  ///    - Consulta `user_books` para verificar si el usuario ya tiene este libro
  ///    - Si existe y `shelf == 'Leído'` → muestra diálogo de confirmación de relectura
  ///    - Si el usuario cancela → aborta el flujo
  /// 5. Llama a `DatabaseService.crearClub` con todos los parámetros
  /// 6. Muestra feedback con `SnackBar` y cierra el diálogo
  ///
  /// Manejo de errores:
  /// - Verifica `mounted` antes de navegar o mostrar `SnackBar` para evitar errores si el widget fue destruido
  /// - Propaga excepciones de Firestore con mensaje amigable
  ///
  /// Parámetros enviados a `DatabaseService.crearClub`:
  /// - `nombre`, `descripcion`, `libro`, `autorLibro`: datos del formulario
  /// - `portadaLibro`: URL de portada del catálogo o cadena vacía
  /// - `bookId`: generado o del catálogo
  /// - `maxMiembros`: valor del dropdown (2-20)
  /// - `status`: `'activo'` por defecto
  /// - `clubImageUrl`: URL personalizada o `null`
  /// - `isbn`, `sinopsis`, `pages`: datos adicionales del catálogo o valores por defecto
  void _validarYGuardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validación adicional: autor requerido para libros manuales
    if (_bookIdSeleccionado == null && _autorController.text.trim().isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "⚠️ Para libros manuales, por favor escribe también el autor",
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final String bookIdParaGuardar = DatabaseService.generarBookId(
      titulo: _libroController.text.trim(),
      autor: _autorController.text.trim(),
      isbn: _isbnGlobal ?? '',
    );

    // Verificar si el usuario ya leyó este libro
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _bookIdSeleccionado != null) {
      final userBookSnapshot = await FirebaseFirestore.instance
          .collection('user_books')
          .where('userId', isEqualTo: user.uid)
          .where('bookId', isEqualTo: _bookIdSeleccionado)
          .limit(1)
          .get();

      if (!mounted) {
        return;
      }

      if (userBookSnapshot.docs.isNotEmpty) {
        final bookData = userBookSnapshot.docs.first.data();
        final String shelf = bookData['shelf'] ?? '';
        final dateFinished = bookData['dateFinished'];

        // Si el libro está marcado como Leído, mostrar advertencia
        if (shelf == 'Leído' && dateFinished != null) {
          final DateTime fechaFin = (dateFinished as Timestamp).toDate();
          final String fechaFormateada = DateFormat(
            'dd/MM/yyyy',
          ).format(fechaFin);

          final bool? confirmar = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text("📚 Libro ya leído"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Ya terminaste este libro el $fechaFormateada.",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Al crear el club, el libro se moverá a 'Leyendo' y el progreso se reiniciará a 0%.",
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "¿Deseas continuar?",
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.naranja,
                  ),
                  child: const Text(
                    "Sí, continuar",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );

          if (!mounted) {
            return;
          }
          if (confirmar != true) {
            return;
          }
        }
      }
    }

    try {
      await DatabaseService.crearClub(
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        libro: _libroController.text.trim(),
        autorLibro: _autorController.text.trim(),
        portadaLibro: _portadaSeleccionado ?? '',
        bookId: bookIdParaGuardar,
        maxMiembros: _maxMiembros,
        status: 'activo',
        clubImageUrl: _customClubImageUrl,
        isbn: _isbnGlobal ?? '',
        sinopsis: _sinopsisGlobal ?? '',
        pages: _pagesGlobal,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
      mostrarSnackBar(context, "¡Club creado exitosamente!", AppColors.naranja);
    } catch (e) {
      if (!mounted) {
        return;
      }
      mostrarSnackBar(context, "Error al crear el club: $e", Colors.red);
    }
  }

  /// Abre el diálogo de búsqueda de libros (Google Books) y aplica el resultado al formulario.
  ///
  /// Flujo:
  /// 1. Llama a `mostrarDialogoBusquedaLibros(context)` que devuelve `Map<String, dynamic>?`
  /// 2. Si el usuario selecciona un libro y el widget sigue montado:
  ///    - Actualiza `_libroController` y `_autorController` con los datos seleccionados
  ///    - Guarda `_bookIdSeleccionado` para marcar el libro como "verificado"
  ///    - Guarda `_portadaSeleccionado`, `_isbnGlobal`, `_sinopsisGlobal`, `_pagesGlobal` para enviar a `DatabaseService.crearClub`
  /// 3. Si el usuario cancela o no hay resultado: no hace nada
  ///
  /// Nota: Los campos de libro y autor quedan en modo "readonly" visualmente cuando `_bookIdSeleccionado != null`,
  /// pero el usuario puede limpiarlos con el botón `Icons.clear` para escribir manualmente.
  void _mostrarBusquedaLibrosParaClub() async {
    final resultado = await mostrarDialogoBusquedaLibros(context);
    if (resultado != null && mounted) {
      setState(() {
        _libroController.text = resultado['titulo'] ?? '';
        _autorController.text = resultado['autor'] ?? '';
        _bookIdSeleccionado = resultado['bookId'];
        _portadaSeleccionado = resultado['cover'] ?? '';
        _isbnGlobal = resultado['isbn'] ?? '';
        _sinopsisGlobal = resultado['sinopsis'] ?? '';
        _pagesGlobal = resultado['pages'];
      });
    }
  }
}
