import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/services/database.dart';

// ------------------------------------------------------------------
// 1. DIALOGO PARA NUEVA ENTRADA DEL DIARIO
// ------------------------------------------------------------------

/// Dialogo para crear una nueva entrada en el diario de lectura.
///
/// Permite seleccionar un emoji de estado de animo (7 opciones predefinidas)
/// y escribir un texto de reflexion.
/// Retorna un Map con 'entry' (texto) y 'mood' (emoji seleccionado).
/// Si el texto esta vacio, retorna null.
class DialogoNuevaEntrada extends StatefulWidget {
  const DialogoNuevaEntrada({super.key});

  @override
  State<DialogoNuevaEntrada> createState() => DialogoNuevaEntradaState();
}

class DialogoNuevaEntradaState extends State<DialogoNuevaEntrada> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _moods = ['😍', '🤔', '😢', '😡', '😲', '😊', '😐'];
  String _selectedMood = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        "Nueva Entrada",
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.morado),
      ),
      content: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "¿Cómo te sientes con esta lectura?",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 15),

              // Selector de emojis (7 opciones)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _moods.map((mood) {
                  final isSelected = _selectedMood == mood;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMood = mood),
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

              const SizedBox(height: 20),

              // Campo de texto para la reflexion
              TextField(
                textCapitalization: TextCapitalization.sentences, 
                enableInteractiveSelection: true,                 
                controller: _controller,
                maxLines: 4,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: "Escribe tu reflexión aquí...",
                  hintStyle: TextStyle(color: Colors.grey[400]),
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
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () {
            final texto = _controller.text.trim();
            if (texto.isEmpty) {
              Navigator.pop(context, null);
              return;
            }
            Navigator.pop(context, {'entry': texto, 'mood': _selectedMood});
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.morado,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text("Guardar"),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------
// 2. WIDGET SECCION PERSONAJES
// ------------------------------------------------------------------

/// Widget que muestra la lista de personajes de un libro.
/// Permite agregar nuevos personajes y eliminar existentes.
/// Cada modificacion llama a onRefresh para reconstruir la UI.
///
/// Estructura de datos en Firestore:
/// user_books/{userBookId} -> campo 'characters' (List&lt;String&lg;)
Widget seccionPersonajes({
  required BuildContext context,
  required String userBookId,
  required List<String> personajes,
  required VoidCallback onRefresh,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 20),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Personajes", style: AppTextStyles.sectionTitle),
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: AppColors.naranja,
            ),
            onPressed: () async {
              final controller = TextEditingController();
              final bool? agregar = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Nuevo Personaje"),
                  content: TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: "Nombre del personaje",
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancelar"),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Añadir"),
                    ),
                  ],
                ),
              );

              if (agregar == true && controller.text.trim().isNotEmpty) {
                await DatabaseService.agregarPersonaje(
                  userBookId: userBookId,
                  nombrePersonaje: controller.text.trim(),
                );
                onRefresh();
              }
            },
          ),
        ],
      ),
      const SizedBox(height: 10),
      personajes.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(10),
              child: Text(
                "No hay personajes registrados.",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 8,
              children: personajes.map((nombre) {
                return Chip(
                  label: Text(nombre),
                  backgroundColor: AppColors.morado.withValues(alpha: 0.1),
                  side: BorderSide(
                    color: AppColors.morado.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  deleteIcon: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppColors.naranja,
                  ),
                  onDeleted: () async {
                    await DatabaseService.eliminarPersonaje(
                      userBookId: userBookId,
                      nombrePersonaje: nombre,
                    );
                    onRefresh();
                  },
                );
              }).toList(),
            ),
    ],
  );
}

// ------------------------------------------------------------------
// 3. WIDGET SECCION DIARIO
// ------------------------------------------------------------------

/// Widget que muestra las entradas del diario de lectura.
///
/// Caracteristicas:
/// - Muestra hasta 3 entradas inicialmente, con boton "Ver mas" si hay mas.
/// - Cada entrada muestra: emoji de animo, fecha/hora, texto, boton eliminar.
/// - Si no hay entradas, muestra mensaje de estado vacio.
/// - El diseno es consistente con la seccion de citas (mismo estilo de bordes y divisores).
Widget seccionDiario({
  required BuildContext context,
  required String userBookId,
  required List<Map<String, dynamic>> entradas,
  required VoidCallback onRefresh,
  required bool mostrarTodo,
  required VoidCallback onToggleVerMas,
}) {
  final entradasVisibles = mostrarTodo ? entradas : entradas.take(3).toList();

  void abrirDialogoEditarEntrada(Map<String, dynamic> entrada) {
    final TextEditingController controller = TextEditingController(
      text: entrada['entry'] ?? '', // 👈 CAMBIO: 'entry' en lugar de 'text'
    );

    final String moodActual = entrada['mood'] ?? '';
    String moodSeleccionado = moodActual;

    final List<String> moods = ['😍', '🤔', '😢', '😡', '😲', '😊', '😐'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Editar entrada",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector de emojis (igual que en DialogoNuevaEntrada)
                const Text(
                  "¿Cómo te sientes?",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: moods.map((mood) {
                    final isSelected = moodSeleccionado == mood;
                    return GestureDetector(
                      onTap: () =>
                          setDialogState(() => moodSeleccionado = mood),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.naranja.withValues(alpha: 0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.naranja
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(mood, style: TextStyle(fontSize: 20)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
                // Campo de texto
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: "Escribe tu reflexión...",
                  ),
                  textCapitalization:
                      TextCapitalization.sentences, // 👈 Mayúscula automática
                  autocorrect: true,
                  autofocus: false,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text(
                "Cancelar",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  try {
                    await DatabaseService.actualizarEntradaDiario(
                      userBookId: userBookId, // 👈 Ahora sí tiene acceso
                      entradaFecha: (entrada['date'] as Timestamp),
                      nuevoTexto: controller.text.trim(),
                      nuevoMood: moodSeleccionado,
                    );
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      onRefresh(); // 👈 Recarga la lista
                    }
                  } catch (e) {
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text("Error al actualizar: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.morado,
              ),
              child: const Text(
                "Guardar",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 30),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Mi Diario de Lectura", style: AppTextStyles.sectionTitle),
          ElevatedButton.icon(
            onPressed: () async {
              final resultado = await showDialog<Map<String, dynamic>>(
                context: context,
                builder: (context) => const DialogoNuevaEntrada(),
              );

              if (resultado == null) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.white),
                          SizedBox(width: 10),
                          Text(
                            "Escribe algo sobre tu lectura para guardar la entrada.",
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.naranja,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
                return;
              }

              if (resultado['entry'].toString().isNotEmpty) {
                await DatabaseService.agregarEntradaDiario(
                  userBookId: userBookId,
                  texto: resultado['entry'],
                  mood: resultado['mood'] ?? '',
                );
                onRefresh();
              }
            },
            icon: const Icon(Icons.edit_note, color: Colors.white),
            label: const Text(
              "Nueva Entrada",
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.naranja),
          ),
        ],
      ),
      const SizedBox(height: 10),
      entradas.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  "Aún no has escrito nada sobre este libro. ¡Empieza tu diario!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          : Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ...List.generate(entradasVisibles.length, (index) {
                    final entrada = entradasVisibles[index];
                    final Timestamp fechaTs = entrada['date'];
                    final DateTime fecha = fechaTs.toDate();
                    final String texto = entrada['entry'];
                    final String mood = entrada['mood'] ?? '';

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 10,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              //Emoji del mood
                              SizedBox(
                                width: 40,
                                child: Text(
                                  mood.isNotEmpty ? mood : '📖',
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                              const SizedBox(width: 10),

                              // Contenido
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'dd MMM yyyy, HH:mm',
                                          ).format(fecha),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Icono de editar
                                            IconButton(
                                              icon: const Icon(
                                                Icons.edit,
                                                size: 16,
                                                color: AppColors.morado,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () =>
                                                  abrirDialogoEditarEntrada(
                                                    entrada,
                                                  ),
                                            ),
                                            const SizedBox(
                                              width: 4,
                                            ), // Icono de eliminar
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                                size: 16,
                                                color: Colors.redAccent,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onPressed: () async {
                                                await DatabaseService.eliminarEntradaDiario(
                                                  userBookId: userBookId,
                                                  texto: texto,
                                                  fecha: fechaTs,
                                                );
                                                onRefresh();
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      texto,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (index < entradasVisibles.length - 1)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: Colors.grey.shade200,
                            indent: 15,
                            endIndent: 15,
                          ),
                      ],
                    );
                  }),
                  if (entradas.length > 3)
                    InkWell(
                      onTap: onToggleVerMas,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                mostrarTodo
                                    ? "Ocultar entradas antiguas"
                                    : "Ver todas las entradas (${entradas.length})",
                                style: TextStyle(
                                  color: AppColors.morado,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Icon(
                                mostrarTodo
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: AppColors.morado,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    ],
  );
}
