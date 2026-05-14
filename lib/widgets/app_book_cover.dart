import 'package:flutter/material.dart';

/// Widget universal para mostrar portadas de libros o imágenes con fallback.
///
/// Características:
/// - Si la URL es válida (`https`), intenta cargar la imagen de red
/// - Si falla la carga o la URL es `null`/inválida, muestra `'assets/sin_portada.png'`
/// - Procesa URLs de Google Books para mejorar calidad (`&zoom=5`) y forzar `HTTPS`
/// - Permite personalizar tamaño, bordes y modo de ajuste (`fit`)
///
/// Parámetros:
/// - [imageUrl]: URL de la imagen o `null` para usar fallback
/// - [width]: Ancho del widget (por defecto: `70`)
/// - [height]: Alto del widget (por defecto: `105`)
/// - [borderRadius]: Radio de los bordes (por defecto: `8.0`)
/// - [fit]: `BoxFit` para ajustar la imagen (por defecto: `BoxFit.cover`)
///
/// Ejemplo de uso:
/// ```dart
/// En una tarjeta de libro:
/// AppBookCover(
///   imageUrl: libro['bookCover'],
///   width: 70,
///   height: 105,
/// )
/// ```
class AppBookCover extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final double borderRadius;
  final BoxFit fit;

  const AppBookCover({
    super.key,
    this.imageUrl,
    this.width = 70,
    this.height = 105,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Procesar la URL para asegurar HTTPS y mejor calidad.
    String? processedUrl = imageUrl;

    if (processedUrl != null && processedUrl.isNotEmpty) {
      // Forzar HTTPS si es HTTP (evita errores de mixed content).
      if (processedUrl.startsWith('http://')) {
        processedUrl = processedUrl.replaceFirst('http://', 'https://');
      }

      // Si es de Google Books, intentar mejorar el zoom para mejor resolución.
      if (processedUrl.contains('google.com/books')) {
        processedUrl = processedUrl.replaceFirst('&zoom=1', '&zoom=5');
      }
    }

    // Validación básica de URL: debe ser https y no vacía.
    final bool isValidUrl =
        processedUrl != null &&
        processedUrl.isNotEmpty &&
        processedUrl.startsWith('https');

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: isValidUrl
          ? Image.network(
              processedUrl,
              width: width,
              height: height,
              fit: fit,
              // Mostrar indicador de carga mientras se descarga la imagen.
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) {
                  return child;
                }
                return Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              // Si hay error de red o imagen corrupta, mostrar fallback.
              errorBuilder: (context, error, stackTrace) => _buildFallback(),
            )
          : _buildFallback(), // URL inválida -> mostrar fallback inmediato.
    );
  }

  /// Widget de fallback: muestra imagen de asset cuando no hay portada válida.
  Widget _buildFallback() {
    return Image.asset(
      'assets/sin_portada.png',
      width: width,
      height: height,
      fit: fit,
    );
  }
}
