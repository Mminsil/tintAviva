# 📚 TintAviva
**Tu compañera perfecta de lectura**  
*Porque cada libro deja una huella.*

TintAviva es una aplicación móvil diseñada para lectores empedernidos que desean llevar un seguimiento detallado de sus lecturas, guardar reflexiones personales y conectar con sus amigos lectores a través de clubs privados. Nace de una necesidad real: centralizar en un espacio limpio y minimalista todas las herramientas que un lector necesita, sin sobrecargas ni distracciones.

---

## ✨ Características Principales

### 📖 Biblioteca Personal
- Añade libros manualmente o búscalos en el catálogo integrado
- Seguimiento de progreso en tiempo real (páginas o porcentaje)
- Organización por estanterías: `Leyendo`, `Leído`, `Por leer`, `Clubes`
- Valoración con estrellas y notas personales por obra

### 📒 Diario de Lectura
- Registra reflexiones después de cada sesión de lectura
- Selector de estado de ánimo con 7 emojis predefinidos
- Edición y eliminación completa de entradas

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
|------|------------|
| **Frontend** | Flutter 3.x (Dart) |
| **Backend** | Firebase (Authentication, Cloud Firestore, Cloud Storage) |
| **Estado** | Provider + StreamBuilder |
| **Testing** | `flutter_test` (unitarias + integración) |
| **Control de versiones** | Git & GitHub |
| **IDE** | Visual Studio Code / Android Studio |

---

## 📱 Requisitos

- Android 5.0 (Lollipop) o superior
- Conexión a Internet activa (Firebase)
- Espacio disponible: ~50 MB
- Cuenta de Google o correo válido para registro

---

## 🚀 Instalación

### Opción 1: Descargar APK (Recomendado)
1. Ve a la sección **[Releases](https://github.com/Mminsil/tintAviva/releases)** de este repositorio.
2. Descarga `app-release.apk` de la última versión (`v1.0.0`).
3. En tu dispositivo Android:
   - `Ajustes → Seguridad → Instalar aplicaciones desconocidas` (activar para tu navegador/gestor)
   - O `Ajustes → Aplicaciones → Acceso especial → Instalar apps desconocidas` (Android 8+)
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

# 4. Ejecuta en modo debug
-d chrome --web-port 8080

# 5. O genera APK de producción
flutter build apk --release
