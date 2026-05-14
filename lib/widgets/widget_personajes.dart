import 'package:flutter/material.dart';
import 'package:tintaviva/services/database.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Widget que muestra la lista de personajes de un libro.
///
/// Propósito:
/// - Permitir al usuario gestionar personajes clave de un libro (agregar/eliminar)
/// - Reflejar cambios inmediatamente en la UI mediante `onRefresh`
/// - Integrarse en pantallas como `DetalleLibroPage` para enriquecer la experiencia literaria
///
/// Estructura de datos en Firestore:
/// ```
/// user_books/{userBookId}
///   └─ 'characters': List<String>  // Ej: ['Harry Potter', 'Hermione Granger']
/// ```
///
/// Características visuales:
/// - Título de sección con estilo `AppTextStyles.sectionTitle`
/// - Botón "+" naranja para agregar personajes
/// - Lista de `Chip` con estilo morado (`AppColors.morado`) y borde sutil
/// - Mensaje "No hay personajes registrados" cuando la lista está vacía
/// - Icono de eliminar naranja en cada chip para acción rápida
///
/// Interacciones:
/// - **Tap en "+"** → Abre `AlertDialog` para ingresar nombre → guarda en Firestore → refresca UI
/// - **Tap en ✕ de un chip** → Elimina personaje de Firestore → refresca UI
///
/// Parámetros:
/// - [context]: `BuildContext` para mostrar diálogos y snackbars
/// - [userBookId]: ID del documento en `'user_books'` para vincular los personajes
/// - [personajes]: `List<String>` con los nombres actuales a mostrar
/// - [onRefresh]: `VoidCallback` para reconstruir la UI tras cambios en Firestore
///
/// Ejemplo de uso:
/// ```dart
/// // En DetalleLibroPage:
/// seccionPersonajes(
///   context: context,
///   userBookId: docId,
///   personajes: personajesList, // Extraído de userBookData['characters']
///   onRefresh: () => setState(() {}), // Reconstruye para reflejar cambios
/// )
/// ```
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
              size: 28,
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
