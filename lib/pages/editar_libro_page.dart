import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Pantalla de edición de un libro específico.
///
/// Permite al usuario modificar:
/// 1. Estado (Estantería) y Progreso (%).
/// 2. Puntuación (Estrellas).
/// 3. Datos técnicos (Páginas, Género, Sinopsis).
/// 4. Notas personales y Portada personalizada.
///
/// Lógica especial: Si el formato es 'Papel', el progreso se calcula automáticamente
/// basado en la página actual y el total de páginas.
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

class _EditarLibroPageState extends State<EditarLibroPage> {
  // Variables de estado local para los campos editables.
  late String _estanteria;
  late double _progreso;
  late double _puntuacion;

  // Controladores para los campos de texto.
  late TextEditingController _generoController;
  late TextEditingController _sinopsisController;
  late TextEditingController _notasController;
  late TextEditingController _paginaActualController;
  late TextEditingController _paginasTotalesController;
  late TextEditingController _bookCoverController;

  @override
  void initState() {
    super.initState();
    // Inicialización de variables con los datos recibidos o valores por defecto.
    _estanteria = widget.datosActuales['shelf'] ?? 'Leyendo';
    _progreso = (widget.datosActuales['progress'] ?? 0).toDouble();
    _puntuacion = (widget.datosActuales['rating'] ?? 0).toDouble();

    _generoController = TextEditingController(
      text: widget.datosActuales['genre'] ?? "",
    );
    _sinopsisController = TextEditingController(
      text: widget.datosActuales['synopsis'] ?? "",
    );
    _notasController = TextEditingController(
      text: widget.datosActuales['notes'] ?? "",
    );

    // Priorizamos totalPages (usuario) sobre pages (catálogo general).
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
  }

  @override
  void dispose() {
    // Liberamos memoria de los controladores.
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
    // Determinamos si el libro es físico para ajustar la UI (slider vs input numérico).
    final bool esPapel =
        (widget.datosActuales['format'] ?? 'Digital') == 'Papel';

    return Scaffold(
      backgroundColor: AppColors.fondoClaro,
      appBar: AppBar(
        title: const Text("Editar Libro", style: AppTextStyles.sectionTitle),
        backgroundColor: AppColors.blanco,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.morado),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECCIÓN 1: ESTADO Y PROGRESO ---
            const Text("Estado y Progreso", style: AppTextStyles.sectionTitle),
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
                    // Selector de estantería. Al cambiar a 'Leído', forzamos progreso al 100%.
                    DropdownButtonFormField<String>(
                      initialValue: _estanteria,
                      decoration: AppInputStyles.inputDecoration("Estantería"),
                      items: ['Leyendo', 'Leído', 'Por leer'].map((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _estanteria = newValue!;
                          if (_estanteria == 'Leído') _progreso = 100;
                          _actualizarEstanteriaSegunProgreso();
                        });
                      },
                    ),
                    const SizedBox(height: 20),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Progreso",
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (esPapel) ...[
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ],
                          ],
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

                    // UI Condicional: Slider para Digital, Barra estática + Inputs para Papel.
                    if (!esPapel)
                      Slider(
                        value: _progreso.clamp(0.0, 100.0),
                        max: 100,
                        divisions: 100,
                        activeColor: AppColors.naranja,
                        inactiveColor: AppColors.naranja.withValues(alpha: 0.3),
                        onChanged: (value) {
                          setState(() {
                            _progreso = value;
                            _actualizarEstanteriaSegunProgreso();
                          });
                        },
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progreso / 100,
                              backgroundColor: Colors.grey[200],
                              color: AppColors.naranja,
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Se calcula automáticamente al guardar las páginas.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),

                    const SizedBox(height: 20),

                    // Inputs de páginas solo visibles o funcionales según el formato.
                    if (esPapel)
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              "Pág. Actual",
                              _paginaActualController,
                              isNumber: true,
                              onChanged: (_) => _recalcularProgreso(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildTextField(
                              "Total Págs.",
                              _paginasTotalesController,
                              isNumber: true,
                              onChanged: (_) => _recalcularProgreso(),
                            ),
                          ),
                        ],
                      )
                    else
                      _buildTextField(
                        "Total Págs. (Referencia)",
                        _paginasTotalesController,
                        isNumber: true,
                      ),

                    const SizedBox(height: 20),

                    // Selector de puntuación con estrellas interactivas.
                    const Text(
                      "Puntuación",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 5),
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

            // --- SECCIÓN 2: DETALLES DEL LIBRO ---
            const Text("Detalles del Libro", style: AppTextStyles.sectionTitle),
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
                      controller: _bookCoverController,
                      decoration: AppInputStyles.inputDecoration(
                        "URL de la imagen",
                        prefixIcon: Icons.link,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    // Previsualización de la imagen si hay URL válida.
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

            // --- SECCIÓN 3: NOTAS Y SINOPSIS ---
            const Text("Notas y Sinopsis", style: AppTextStyles.sectionTitle),
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
                    _buildTextField("Sinopsis", _sinopsisController, lines: 3),
                    const SizedBox(height: 15),
                    _buildTextField("Mis Notas", _notasController, lines: 3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
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

  /// Widget auxiliar para crear TextFields consistentes.
  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int lines = 1,
    bool isNumber = false,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      maxLines: lines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      onChanged: onChanged,
      decoration: AppInputStyles.inputDecoration(label),
    );
  }

  /// Guarda los cambios en Firestore.
  ///
  /// Lógica clave:
  /// 1. Recalcula el progreso si es formato Papel.
  /// 2. Actualiza la estantería si el progreso llega al 100%.
  /// 3. Separa los datos en 'user_books' (personales) y 'books' (catálogo general).
  Future<void> _guardarCambios() async {
    try {
      final formato = widget.datosActuales['format'] ?? 'Digital';
      int totales = int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
      int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
      int progresoFinal = _progreso.toInt();

      // Si es papel, el progreso manda sobre la estantería.
      if (formato == 'Papel' && totales > 0) {
        progresoFinal = ((actual / totales) * 100).round().clamp(0, 100);
      }

      if (progresoFinal >= 100) _estanteria = 'Leído';

      // Datos específicos del usuario (no afectan a otros usuarios).
      Map<String, dynamic> datosUserBook = {
        'shelf': _estanteria,
        'progress': progresoFinal,
        'rating': _puntuacion,
        'notes': _notasController.text,
        'totalPages': totales,
        'currentPage': formato == 'Papel' ? actual : 0,
        'dateFinished': _estanteria == 'Leído'
            ? FieldValue.serverTimestamp()
            : null,
        'bookCover': _bookCoverController.text.trim(),
      };

      // Datos del catálogo (si el usuario cambia género/sinopsis, se actualiza para todos).
      Map<String, dynamic> datosCatalogo = {
        'pages': totales,
        'genre': _generoController.text,
        'synopsis': _sinopsisController.text,
        'bookCover': _bookCoverController.text.trim(),
      };

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
        Navigator.pop(context);
        mostrarSnackBar(context, "Libro actualizado.", AppColors.naranja);
      }
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(context, "Error: $e", Colors.red);
      }
    }
  }

  /// Recalcula el porcentaje de progreso basado en páginas (solo formato Papel).
  void _recalcularProgreso() {
    final int totales =
        int.tryParse(_paginasTotalesController.text.trim()) ?? 0;
    final int actual = int.tryParse(_paginaActualController.text.trim()) ?? 0;
    if (totales > 0) {
      setState(() => _progreso = ((actual / totales) * 100).clamp(0.0, 100.0));
      _actualizarEstanteriaSegunProgreso();
    }
  }

  /// Actualiza automáticamente la estantería basada en el % de progreso.
  void _actualizarEstanteriaSegunProgreso() {
    if (_progreso >= 100) {
      _estanteria = 'Leído';
    } else if (_progreso > 0) {
      _estanteria = 'Leyendo';
    } else {
      _estanteria = 'Por leer';
    }
  }
}
