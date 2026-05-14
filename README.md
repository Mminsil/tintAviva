# 📚 TintAviva v2.0
> Tu compañera perfecta de lectura  
> *Porque cada libro deja una huella.*

TintAviva es una aplicación móvil diseñada para lectores empedernidos que desean llevar un seguimiento detallado de sus lecturas, guardar reflexiones personales y conectar con sus amigos lectores a través de clubs privados. Nace de una necesidad real: centralizar en un espacio limpio y minimalista todas las herramientas que un lector necesita, sin sobrecargas ni distracciones.

---

## 🔄 Novedades en v2.0
✨ **Pestaña Diario**: Nueva sección para registrar reflexiones y citas favoritas con selector de estado de ánimo  
✨ **Validación robusta**: Contraseñas con mínimo 8 caracteres, 1 mayúscula y 1 número  
✨ **UX mejorada**: Auto-fill 1% al seleccionar "Leyendo" + ajuste dinámico por formato (Papel/Digital)  
✨ **Código profesional**: Refactorización de utils (`dialogos_helpers.dart`, `input_validadores.dart`) + documentación dartdoc completa  
✨ **Widgets reutilizables**: `AppBookCover`, `EntradaCard`, `WidgetCitaDelDia` para consistencia visual  
✨ **Calidad garantizada**: `flutter analyze: 0 issues`  

---

## ✨ Características Principales

### 📖 Biblioteca Personal
- Añade libros manualmente o búscalos en el catálogo integrado (Google Books API)
- Seguimiento de progreso en tiempo real (páginas o porcentaje)
- Organización por estanterías: Leyendo, Leído, Por leer, Clubes
- Valoración con estrellas y notas personales por obra

### 📒 Diario de Lectura *(NUEVO en v2)*
- Registra reflexiones después de cada sesión de lectura
- Guarda citas favoritas vinculadas automáticamente al libro
- Selector de estado de ánimo con 7 emojis predefinidos
- Edición y eliminación completa de entradas
- Vista cronológica con tarjetas expansibles

### 💬 Clubs de Lectura Privados
- Crea o únete a clubs mediante código de invitación
- Establece metas colectivas con fechas límite
- Comentarios y progreso compartido en tiempo real
- Espacios cerrados por diseño para mantener la intimidad del grupo

### ❞ Citas Favoritas
- Guarda frases destacadas vinculadas automáticamente al libro
- Visualización de cita aleatoria diaria en pantalla de inicio

### 👥 Personajes
- Registro de personajes principales por obra

### 🏆 Racha
- Contador visual de días consecutivos de actividad

### 📉 Estadísticas
- Estadísticas simples que motivan sin gamificación invasiva

### 🎯 Guía Interactiva (Onboarding)
- Tutorial paso a paso que aparece solo en el primer arranque
- Explica biblioteca, diario, clubs y citas de forma visual

---

## 🛠️ Tecnologías Utilizadas

| Capa | Tecnología |
|------|-----------|
| **Frontend** | Flutter 3.x (Dart) |
| **Backend** | Firebase (Authentication, Cloud Firestore) |
| **Estado** | Provider + StreamBuilder |
| **APIs externas** | Google Books API |
| **Utilidades** | `intl`, `confetti`, `flutter_dotenv`, `shared_preferences` |
| **Testing** | flutter_test (unitarias + integración) |
| **Control de versiones** | Git & GitHub |
| **IDE** | Visual Studio Code |

---

## 📱 Requisitos
- Android 5.0 (Lollipop) o superior
- Conexión a Internet activa (Firebase)
- Espacio disponible: ~50 MB
- Cuenta de Google o correo válido para registro

---

## 🚀 Instalación

### Opción 1: Descargar APK (Recomendado)
1. Ve a la sección **Releases** de este repositorio.
2. Descarga `app-arm64-v8a-release.apk` de la última versión (**v2.0.0**).
3. En tu dispositivo Android:
   - Ajustes → Seguridad → Instalar aplicaciones desconocidas (activar para tu navegador/gestor)
   - O Ajustes → Aplicaciones → Acceso especial → Instalar apps desconocidas (Android 8+)
4. Abre el `.apk` y pulsa **Instalar**.
5. ¡Listo! Abre la app y comienza tu experiencia de lectura.

### Opción 2: Compilar desde código fuente
```bash
# 1. Clona el repositorio
git clone https://github.com/Mminsil/tintAviva.git
cd tintaviva

# 2. Instala dependencias
flutter pub get

# 3. Configura Firebase
# - Crea un proyecto en https://console.firebase.google.com
# - Añade una app Android con el package name del proyecto
# - Descarga google-services.json y colócalo en android/app/
# - Habilita Authentication (Email/Google) y Firestore

# 4. Configura variables de entorno
# - Crea un archivo .env en la raíz del proyecto
# - Añade: GOOGLE_BOOKS_API_KEY=tu_api_key_aqui

# 5. Ejecuta en modo debug (emulador o dispositivo)
flutter run

# 6. O genera APK de producción
flutter build apk --release --split-per-abi
# Los APKs estarán en: build/app/outputs/flutter-apk/
