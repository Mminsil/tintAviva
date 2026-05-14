import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tintaviva/theme/app_styles.dart';

/// Crea un campo de texto numérico estricto con validación automática.
///
/// Características:
/// - Solo acepta dígitos (`FilteringTextInputFormatter.digitsOnly`)
/// - Valida que no sea negativo
/// - Si [isTotalField] es `true`, valida que sea `> 0`
/// - Si [maxPages] está definido, valida que no lo supere
///
/// Parámetros:
/// - [label]: Texto de la etiqueta del campo
/// - [controller]: `TextEditingController` para controlar el valor
/// - [maxPages]: Valor máximo permitido (opcional)
/// - [isTotalField]: Si es `true`, aplica validación de "mayor a 0"
/// - [onChanged]: Callback opcional cuando cambia el valor
///
/// Retorna:
/// - `TextFormField` configurado con validaciones y estilo de `AppInputStyles`
///
/// Ejemplo:
/// ```dart
/// buildNumberField(
///   label: 'Pág. Actual',
///   controller: _paginaActualController,
///   maxPages: int.tryParse(_paginasTotalesController.text),
/// )
/// ```
Widget buildNumberField({
  required String label,
  required TextEditingController controller,
  int? maxPages,
  bool isTotalField = false,
  void Function(String)? onChanged,
}) {
  return TextFormField(
    controller: controller,
    keyboardType: TextInputType.number,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: AppInputStyles.inputDecoration(label),
    onChanged: onChanged,
    validator: (value) {
      if (value == null || value.isEmpty) {
        return "Requerido";
      }

      final int? n = int.tryParse(value);
      if (n == null) {
        return "Solo números";
      }
      if (n < 0) {
        return "No negativo";
      }

      if (isTotalField && n <= 0) {
        return "Debe ser mayor a 0";
      }
      if (!isTotalField && maxPages != null && maxPages > 0 && n > maxPages) {
        return "Mayor que el total ($maxPages)";
      }

      return null;
    },
  );
}

/// Formateador que bloquea la entrada si el número supera un máximo definido.
///
/// Útil para campos como "página actual" que no deben exceder "total de páginas".
///
/// Parámetros:
/// - [max]: Valor máximo permitido (`null` = sin límite)
///
/// Comportamiento:
/// - Si el nuevo valor `<= max` → permite el cambio
/// - Si el nuevo valor `> max` → bloquea la tecla (mantiene el valor anterior)
/// - Si el campo está vacío o no es parseable → permite el cambio (para borrar)
///
/// Ejemplo:
/// ```dart
/// TextFormField(
///   inputFormatters: [
///     FilteringTextInputFormatter.digitsOnly,
///     MaxNumberInputFormatter(totalPaginas),
///   ],
/// )
/// ```
class MaxNumberInputFormatter extends TextInputFormatter {
  final int? max;

  MaxNumberInputFormatter(this.max);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (max == null || newValue.text.isEmpty) {
      return newValue;
    }

    final int? newInt = int.tryParse(newValue.text);

    if (newInt == null) {
      return newValue;
    }

    if (newInt <= max!) {
      return newValue;
    }

    return oldValue;
  }
}