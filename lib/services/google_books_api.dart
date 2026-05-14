import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Servicio para consultar la API de Google Books.
///
/// Propósito:
/// 1. Buscar libros por título o autor en el catálogo global de Google Books
/// 2. Devolver datos estructurados para enriquecer el catálogo local de Tintaviva
///
/// Seguridad:
/// - La API Key se carga desde variables de entorno (`.env`) para no exponerla en Git
/// - Se usa un getter estático para acceder a la clave en tiempo de ejecución
///
/// Endpoint usado:
/// - `https://www.googleapis.com/books/v1/volumes`
/// - Parámetros: `q` (query), `key` (API key), `maxResults` (límite de resultados)
class GoogleBooksApi {
  /// Getter para acceder a la API Key de forma segura.
  ///
  /// Se evalúa en tiempo de ejecución (no compilación), permitiendo cargar
  /// el valor desde `dotenv.env` después de inicializar la app en `main()`.
  ///
  /// Retorna:
  /// - `String` con la API Key, o cadena vacía si no está configurada
  static String get apiKey => dotenv.env['GOOGLE_BOOKS_API_KEY'] ?? '';

  /// Busca libros en la API de Google Books por título o autor.
  ///
  /// Parámetros:
  /// - [query]: Término de búsqueda (título, autor o ambos)
  ///
  /// Retorna:
  /// - `Future<List<Map<String, dynamic>>>` con datos normalizados de cada libro encontrado
  ///   - `'title'`: `String` → título del libro
  ///   - `'authors'`: `String` → autores separados por coma
  ///   - `'thumbnail'`: `String` → URL de portada (forzada a HTTPS)
  ///   - `'pageCount'`: `int` → número total de páginas
  ///   - `'isbn'`: `String` → ISBN-13 preferido, sino ISBN-10, sino vacío
  ///   - `'description'`: `String` → sinopsis del libro
  ///   - `'genre'`: `String` → primera categoría disponible o `'Sin género'`
  ///
  /// Excepciones:
  /// - Lanza `Exception` si la API Key no está configurada
  /// - Lanza `Exception` si hay error de red o respuesta HTTP no exitosa
  ///
  /// Ejemplo de uso:
  /// ```dart
  /// try {
  ///   final libros = await GoogleBooksApi.searchBooks('El señor de los anillos');
  ///   for (var libro in libros) {
  ///     print('${libro['title']} - ${libro['authors']}');
  ///   }
  /// } catch (e) {
  ///   print('Error: $e');
  /// }
  /// ```
  static Future<List<Map<String, dynamic>>> searchBooks(String query) async {
    // Validación de seguridad: verificar que la API Key está configurada.
    if (apiKey.isEmpty) {
      throw Exception('GOOGLE_BOOKS_API_KEY no configurada en .env');
    }

    // Construir URL con parámetros de búsqueda y API Key.
    final url = Uri.parse(
      'https://www.googleapis.com/books/v1/volumes?q=$query&key=$apiKey&maxResults=20',
    );

    try {
      // Realizar petición HTTP GET.
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items = data['items'] as List<dynamic>?;

        if (items == null || items.isEmpty) {
          return [];
        }

        // Normalizar y extraer solo los campos que necesitamos.
        return items.map((item) {
          final volumeInfo = item['volumeInfo'] ?? {};
          final industryIdentifiers =
              (volumeInfo['industryIdentifiers'] as List<dynamic>?) ?? [];

          // Extraer ISBN-13 si está disponible, sino ISBN-10, sino vacío.
          String isbn = '';
          for (var id in industryIdentifiers) {
            if (id['type'] == 'ISBN_13') {
              isbn = id['identifier'] ?? '';
              break;
            }
            if (id['type'] == 'ISBN_10' && isbn.isEmpty) {
              isbn = id['identifier'] ?? '';
            }
          }

          // Extraer género/categoría (primera categoría disponible).
          final categories = (volumeInfo['categories'] as List<dynamic>?) ?? [];
          final genre = categories.isNotEmpty
              ? categories.first.toString()
              : 'Sin género';

          return {
            'title': volumeInfo['title'] ?? 'Sin título',
            'authors':
                (volumeInfo['authors'] as List<dynamic>?)?.join(', ') ??
                'Autor desconocido',
            'thumbnail': (volumeInfo['imageLinks']?['thumbnail'] ?? '')
                .toString()
                .replaceFirst('http://', 'https://'), // Forzar HTTPS
            'pageCount': volumeInfo['pageCount'] ?? 0,
            'isbn': isbn,
            'description': volumeInfo['description'] ?? '',
            'genre': genre,
          };
        }).toList();
      } else {
        // Manejo de errores HTTP (401, 403, 500, etc.)
        throw Exception('Error API Google Books: ${response.statusCode}');
      }
    } catch (e) {
      // Propagar errores de red o parsing para que la UI los maneje.
      throw Exception('Error de conexión o respuesta: $e');
    }
  }
}
