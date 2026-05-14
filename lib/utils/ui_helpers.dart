import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/theme/app_styles.dart';

// ─────────────────────────────────────────────────────────────
// WIDGETS VISUALES REUTILIZABLES
// ─────────────────────────────────────────────────────────────

/// Widget visual reutilizable para mostrar barras de progreso de lectura.
///
/// Propósito:
/// - Mostrar visualmente el avance de un libro en biblioteca o clubes
/// - Adaptar el texto descriptivo según el formato del libro (`'Papel'` | `'Digital'`)
/// - Mantener consistencia visual en toda la aplicación con colores corporativos
///
/// Comportamiento por formato:
/// - `'Digital'`: Muestra `"{progress}% leído"`
/// - `'Papel'`: Muestra `"Pág. X de Y (progress%)"`, calculando la página si no se proporciona
///
/// Parámetros:
/// - [progress]: Porcentaje de progreso (0-100), usado para el valor de `LinearProgressIndicator`
/// - [currentPage]: Página actual (solo relevante para formato `'Papel'`)
/// - [totalPages]: Total de páginas del libro (requerido para formato `'Papel'`)
/// - [format]: `'Digital'` | `'Papel'` → determina el texto descriptivo mostrado
/// - [height]: Altura de la barra en píxeles (por defecto: `8`)
///
/// Características visuales:
/// - Barra con `borderRadius` circular calculado como `height / 2`
/// - Color de progreso: `AppColors.naranja` (definido en `app_styles.dart`)
/// - Fondo de barra: `Colors.grey[200]` para contraste suave
/// - Texto descriptivo: `fontSize: 12`, `color: Colors.grey[700]`, `fontWeight: w500`
///
/// Ejemplo de uso:
/// ```dart
/// // En TarjetaLibroProgreso:
/// WidgetBarraProgreso(
///   progress: 75,
///   currentPage: 150,
///   totalPages: 200,
///   format: 'Papel',
///   height: 6,
/// )
/// // Resultado visual: "Pág. 150 de 200 (75%)" + barra al 75%
/// ```
class WidgetBarraProgreso extends StatelessWidget {
  /// Porcentaje de progreso completado (0-100).
  ///
  /// Controla el valor de `LinearProgressIndicator.value` (se normaliza a 0.0-1.0 internamente).
  final int progress;

  /// Página actual de lectura (solo relevante para formato `'Papel'`).
  ///
  /// Si es `0` y el formato es `'Papel'`, se calcula automáticamente como:
  /// `(progress * totalPages / 100).round()`
  final int currentPage;

  /// Total de páginas del libro (requerido para formato `'Papel'`).
  ///
  /// Usado para:
  /// - Calcular la página actual si `currentPage == 0`
  /// - Mostrar el texto descriptivo `"Pág. X de Y"`
  final int totalPages;

  /// Formato del libro que determina el texto descriptivo.
  ///
  /// Valores permitidos:
  /// - `'Digital'` → Muestra `"{progress}% leído"`
  /// - `'Papel'` → Muestra `"Pág. X de Y (progress%)"`
  final String format;

  /// Altura de la barra de progreso en píxeles.
  ///
  /// Por defecto: `8`. El `borderRadius` se calcula automáticamente como `height / 2`
  /// para mantener bordes perfectamente circulares.
  final double height;

  const WidgetBarraProgreso({
    super.key,
    required this.progress,
    required this.currentPage,
    required this.totalPages,
    required this.format,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final Color colorNaranja = const Color(0xFFFF6B35);
    String textoDescriptivo = "$progress% leído";

    // Lógica condicional para formato Papel: calcula página y ajusta texto
    if (format == 'Papel' && totalPages > 0) {
      final int paginaMostrar = currentPage > 0
          ? currentPage
          : (progress * totalPages / 100).round();
      textoDescriptivo = "Pág. $paginaMostrar de $totalPages ($progress%)";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: progress / 100,
            backgroundColor: Colors.grey[200],
            color: colorNaranja,
            minHeight: height,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          textoDescriptivo,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Widget de confetti celebratorio reutilizable para logros de lectura.
///
/// Propósito:
/// - Mostrar una animación festiva al completar un libro, alcanzar una racha, etc.
/// - Ser fácilmente integrable en cualquier contexto mediante `Stack` + `Positioned.fill`
/// - Ofrecer configuración completa de la física de partículas para personalización
///
/// Uso típico:
/// ```dart
/// Stack(
///   clipBehavior: Clip.none, // Permite que el confetti sobresalga
///   children: [
///     // Widget principal (diálogo, pantalla, etc.)
///     MiDialogo(),
///     // Overlay de confetti
///     ConfettiCelebration(controller: _confettiController),
///   ],
/// )
/// ```
///
/// Parámetros de configuración:
/// - [controller]: `ConfettiController` para gestionar `play()`, `pause()`, `dispose()`
/// - [colors]: Lista de colores de partículas (por defecto: festivos variados)
/// - [numberOfParticles]: Cantidad de partículas a emitir (por defecto: `50`)
/// - [gravity]: Fuerza de gravedad (`0.0` = flotan, `1.0` = caen rápido, por defecto: `0.1`)
/// - [maxBlastForce] / [minBlastForce]: Rango de fuerza de explosión (por defecto: `100`/`20`)
/// - [emissionFrequency]: Frecuencia de emisión de partículas (por defecto: `0.05`)
/// - [blastDirectionality]: Dirección de explosión (`explosive` = radial, por defecto)
/// - [shouldLoop]: Si la animación debe repetirse en bucle (por defecto: `false`)
///
/// Nota sobre rendimiento:
/// - Usar `clipBehavior: Clip.none` en el `Stack` padre es esencial para que las partículas
///   no se recorten en los bordes del contenedor.
/// - Llamar a `controller.dispose()` en el `dispose()` del widget padre para evitar fugas.
class ConfettiCelebration extends StatelessWidget {
  /// Controlador que gestiona el ciclo de vida de la animación.
  ///
  /// Debe ser creado en el widget padre y pasado como parámetro.
  /// Ejemplo: `ConfettiController(duration: Duration(seconds: 3))`
  final ConfettiController controller;

  /// Lista de colores para las partículas de confetti.
  ///
  /// Por defecto: `[Colors.green, Colors.blue, Colors.pink, Colors.orange, Colors.purple]`
  final List<Color> colors;

  /// Número total de partículas a emitir en la explosión.
  ///
  /// Por defecto: `50`. Valores más altos pueden afectar el rendimiento en dispositivos antiguos.
  final int numberOfParticles;

  /// Fuerza de gravedad aplicada a las partículas.
  ///
  /// Valores:
  /// - `0.0`: Las partículas flotan sin caer
  /// - `0.1` (por defecto): Caída suave y natural
  /// - `1.0`: Caída rápida y directa
  final double gravity;

  /// Fuerza máxima de la explosión inicial.
  ///
  /// Por defecto: `100`. Controla qué tan lejos pueden llegar las partículas en su impulso inicial.
  final double maxBlastForce;

  /// Fuerza mínima de la explosión inicial.
  ///
  /// Por defecto: `20`. Junto con `maxBlastForce`, define el rango de variación del impulso.
  final double minBlastForce;

  /// Frecuencia de emisión de nuevas partículas durante la animación.
  ///
  /// Por defecto: `0.05`. Valores más altos emiten partículas más seguido.
  final double emissionFrequency;

  /// Dirección de la explosión de partículas.
  ///
  /// Valores de `BlastDirectionality`:
  /// - `explosive` (por defecto): Partículas en todas direcciones (radial)
  /// - `directional`: Partículas en una dirección específica (requiere `blastDirection` adicional)
  final BlastDirectionality blastDirectionality;

  /// Indica si la animación debe repetirse en bucle automáticamente.
  ///
  /// Por defecto: `false`. Para celebraciones únicas, mantener en `false`.
  final bool shouldLoop;

  const ConfettiCelebration({
    super.key,
    required this.controller,
    this.colors = const [
      Colors.green,
      Colors.blue,
      Colors.pink,
      Colors.orange,
      Colors.purple,
    ],
    this.numberOfParticles = 50,
    this.gravity = 0.1,
    this.maxBlastForce = 100,
    this.minBlastForce = 20,
    this.emissionFrequency = 0.05,
    this.blastDirectionality = BlastDirectionality.explosive,
    this.shouldLoop = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Align(
        alignment: Alignment.center,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: blastDirectionality,
          shouldLoop: shouldLoop,
          colors: colors,
          numberOfParticles: numberOfParticles,
          gravity: gravity,
          emissionFrequency: emissionFrequency,
          maxBlastForce: maxBlastForce,
          minBlastForce: minBlastForce,
          particleDrag: 0.05, // Resistencia al aire para movimiento más natural
        ),
      ),
    );
  }
}

/// Widget para texto largo con opción de expandir/contraer mediante interacción.
///
/// Propósito:
/// - Mostrar sinopsis o descripciones largas sin ocupar espacio excesivo en la UI
/// - Permitir al usuario expandir solo el contenido que le interesa leer completo
/// - Mantener consistencia visual con botones "Leer más/menos" estilizados
///
/// Comportamiento:
/// - Si `texto.length <= maxLength` o `_expanded == true`: muestra todo el texto sin botón
/// - Si `texto.length > maxLength` y `_expanded == false`: muestra texto recortado + "Leer más"
/// - Al tocar "Leer más": expande a texto completo + cambia botón a "Leer menos"
/// - Al tocar "Leer menos": contrae a texto recortado + cambia botón a "Leer más"
///
/// Parámetros:
/// - [texto]: Contenido completo a mostrar (String)
/// - [maxLength]: Número máximo de caracteres antes de recortar (por defecto: `250`)
/// - [style]: `TextStyle` opcional para personalizar la apariencia del texto
///
/// Características visuales del botón de toggle:
/// - `padding: EdgeInsets.zero` + `minimumSize: Size.zero` para botón compacto
/// - `tapTargetSize: MaterialTapTargetSize.shrinkWrap` para área de toque precisa
/// - Color: `AppColors.morado`, `fontWeight: bold`, `fontSize: 13`
///
/// Ejemplo de uso:
/// ```dart
/// // En DetalleLibroPage, para la sinopsis:
/// TextoExpandible(
///   texto: libro['synopsis'] ?? '',
///   maxLength: 250,
///   style: TextStyle(color: Colors.grey[700], height: 1.5),
/// )
/// ```
class TextoExpandible extends StatefulWidget {
  /// Contenido completo de texto a mostrar.
  ///
  /// Si es más largo que `maxLength`, se mostrará recortado inicialmente.
  final String texto;

  /// Número máximo de caracteres a mostrar antes de recortar y añadir botón "Leer más".
  ///
  /// Por defecto: `250`. Ajustar según el diseño de la pantalla donde se usa.
  final int maxLength;

  /// Estilo de texto opcional para personalizar la apariencia.
  ///
  /// Si es `null`, se usa el estilo por defecto:
  /// `TextStyle(color: Colors.grey, height: 1.5)`
  final TextStyle? style;

  const TextoExpandible({
    super.key,
    required this.texto,
    this.maxLength = 150,
    this.style,
  });

  @override
  State<TextoExpandible> createState() => _TextoExpandibleState();
}

class _TextoExpandibleState extends State<TextoExpandible> {
  /// Estado interno que controla si el texto está expandido o contraído.
  ///
  /// Inicializado en `false` (contraído). Se actualiza con `setState` al tocar los botones.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Caso 1: Texto corto o ya expandido → mostrar completo sin botón de toggle
    if (widget.texto.length <= widget.maxLength || _expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.texto,
            style: widget.style ?? const TextStyle(color: Colors.grey, height: 1.5),
          ),
          // Mostrar botón "Leer menos" solo si el texto original era largo
          if (widget.texto.length > widget.maxLength)
            TextButton(
              onPressed: () {
                setState(() {
                  _expanded = false;
                });
              },
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Leer menos',
                style: TextStyle(
                  color: AppColors.morado,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      );
    }

    // Caso 2: Texto largo y contraído → mostrar recortado + botón "Leer más"
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${widget.texto.substring(0, widget.maxLength)}...',
          style: widget.style ?? const TextStyle(color: Colors.grey, height: 1.5),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _expanded = true;
            });
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Leer más',
            style: TextStyle(
              color: AppColors.morado,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}