import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tintaviva/theme/app_styles.dart';
import 'package:tintaviva/utils/ui_helpers.dart';

/// Tarjeta reutilizable para mostrar una entrada del diario de lectura.
///
/// Propósito:
/// - Mostrar una entrada (cita o reflexión) con contexto del libro y fecha
/// - Permitir acciones rápidas: editar, eliminar, navegar al libro
/// - Adaptar visualmente según el tipo: `'quote'` (cita) o `'diary'` (reflexión)
///
/// Características visuales:
/// - **Header**: fecha formateada (`'dd MMM, HH:mm'`) + título del libro + botones de acción
/// - **Contenido**:
///   - Citas: icono `❝` + texto en itálica
///   - Reflexiones: emoji de estado de ánimo (`mood`) o `📖` + texto normal
/// - Texto truncado a 250 caracteres con `TextoExpandible` para "Leer más/menos"
/// - Borde redondeado (`borderRadius: 12`) y sombra sutil (`elevation: 2`)
///
/// Estructura esperada de `entrada`:
/// ```dart
/// {
///   'type': String,           // 'quote' | 'diary'
///   'text': String,           // Contenido de la entrada
///   'mood': String?,          // Emoji de estado de ánimo (solo para 'diary')
///   'bookTitle': String,      // Título del libro asociado
///   'userBookId': String?,    // ID en 'user_books' para navegación (opcional)
///   'timestamp': Timestamp,   // Fecha de creación en Firestore
/// }
/// ```
///
/// Parámetros:
/// - [entrada]: `Map<String, dynamic>` con los datos de la entrada a mostrar
/// - [docId]: ID del documento en `'entries'` (para contexto, no usado directamente aquí)
/// - [onEdit]: `VoidCallback?` opcional para editar la entrada (muestra botón ✏️)
/// - [onDelete]: `VoidCallback?` opcional para eliminar la entrada (muestra botón 🗑️)
/// - [onBookTap]: `Function(String userBookId)?` opcional para navegar al libro al tocar la tarjeta
///
/// Ejemplo de uso:
/// ```dart
/// // En DiarioPage, dentro de ListView.builder:
/// EntradaCard(
///   entrada: entradaData,
///   docId: doc.id,
///   onEdit: () => _abrirDialogoEditar(entrada, doc.id),
///   onDelete: () => _confirmarEliminar(doc.id),
///   onBookTap: (userBookId) => _navegarADetalleLibro(userBookId),
/// )
/// ```
class EntradaCard extends StatelessWidget {
  /// Mapa con los datos de la entrada a mostrar.
  ///
  /// Debe contener las claves documentadas en la descripción de la clase.
  /// Valores `null` se manejan con fallbacks visuales (`'Libro desconocido'`, `DateTime.now()`, etc.)
  final Map<String, dynamic> entrada;

  /// ID del documento en la colección `'entries'`.
  ///
  /// Proporcionado para contexto, aunque no se usa directamente en este widget.
  /// Útil si el padre necesita pasar el ID a callbacks externos.
  final String docId;

  /// Callback opcional para editar la entrada.
  ///
  /// Si se proporciona, muestra un botón `Icons.edit` en el header.
  /// Típicamente abre un diálogo de edición pre-cargado con los datos de `entrada`.
  final VoidCallback? onEdit;

  /// Callback opcional para eliminar la entrada.
  ///
  /// Si se proporciona, muestra un botón `Icons.delete_outline` en el header.
  /// Típicamente muestra un diálogo de confirmación antes de llamar a `DatabaseService.eliminarEntradaGlobal`.
  final VoidCallback? onDelete;

  /// Callback opcional para navegar al detalle del libro al tocar la tarjeta.
  ///
  /// Parámetro: `userBookId` (ID del documento en `'user_books'`)
  ///
  /// Comportamiento:
  /// - Si `entrada['userBookId']` es `null` o vacío → no hace nada al tocar
  /// - Si tiene valor → ejecuta `onBookTap(userBookId)`
  final Function(String userBookId)? onBookTap;

  const EntradaCard({
    super.key,
    required this.entrada,
    required this.docId,
    this.onEdit,
    this.onDelete,
    this.onBookTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool esCita = entrada['type'] == 'quote';
    final String texto = entrada['text'] ?? '';
    final String mood = entrada['mood'] ?? '';
    final String bookTitle = entrada['bookTitle'] ?? 'Libro desconocido';
    final Timestamp? timestamp = entrada['timestamp'] as Timestamp?;
    final DateTime fecha = timestamp?.toDate() ?? DateTime.now();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        // Navegación al libro: solo si hay userBookId válido
        onTap: () async {
          final String? userBookId = entrada['userBookId'];
          if (userBookId != null && userBookId.isNotEmpty) {
            onBookTap?.call(userBookId);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: fecha + título del libro + botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('dd MMM, HH:mm').format(fecha),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      bookTitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.morado,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Botón editar (solo si onEdit está definido)
                      if (onEdit != null)
                        IconButton(
                          icon: const Icon(
                            Icons.edit,
                            size: 16,
                            color: AppColors.morado,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onEdit,
                        ),
                      // Botón eliminar (solo si onDelete está definido)
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Colors.redAccent,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: onDelete,
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Contenido: icono según tipo + texto con TextoExpandible
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono según tipo de entrada
                  SizedBox(
                    width: 32,
                    child: Center(
                      child: Text(
                        esCita ? '❝' : (mood.isNotEmpty ? mood : '📖'),
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Texto truncado con opción de expandir
                  Flexible(
                    child: TextoExpandible(
                      texto: texto,
                      maxLength: 250,
                      style: const TextStyle(fontSize: 14, height: 1.3),
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
}
