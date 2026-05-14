# 📚 TintAviva v2.0
> Tu compañera perfecta de lectura  
> *Porque cada libro deja una huella.*

TintAviva es una aplicación móvil para lectores que quieren gestionar sus libros, guardar reflexiones y conectar con amigos mediante clubs privados. Todo en un espacio limpio y minimalista.

---

## 🔄 Novedades en v2.0
- ✨ **Pestaña Diario**: Nueva sección para registrar reflexiones y citas con selector de estado de ánimo.
- ✨ **Validación robusta**: Contraseñas con mínimo 8 caracteres, 1 mayúscula y 1 número.
- ✨ **UX mejorada**: Auto-fill 1% al seleccionar "Leyendo" + ajuste dinámico por formato.
- ✨ **Código profesional**: Refactorización de utils + documentación dartdoc completa.
- ✨ **Calidad garantizada**: `flutter analyze: 0 issues`.

---

## ✨ Características Principales

### 📖 Biblioteca Personal
- Añade libros manualmente o búscalos en el catálogo integrado (Google Books API).
- Seguimiento de progreso en tiempo real (páginas o porcentaje).
- Organización por estanterías: Leyendo, Leído, Por leer, Clubes.

### 📒 Diario de Lectura *(NUEVO)*
- Registra reflexiones y guarda citas favoritas vinculadas al libro.
- Selector de estado de ánimo con 7 emojis predefinidos.
- Edición y eliminación completa de entradas.

### 💬 Clubs de Lectura Privados
- Crea o únete a clubs mediante código de invitación.
- Establece metas colectivas con fechas límite.
- Comentarios y progreso compartido en tiempo real.

### 🏆 Otras Funcionalidades
- **Citas Favoritas**: Frases destacadas y cita aleatoria diaria.
- **Personajes**: Registro de personajes principales por obra.
- **Racha**: Contador visual de días consecutivos de actividad.
- **Estadísticas**: Datos simples que motivan sin gamificación invasiva.

---

## 🛠️ Tecnologías

- **Frontend**: Flutter 3.x (Dart)
- **Backend**: Firebase (Auth, Firestore)
- **APIs**: Google Books API
- **Utilidades**: `intl`, `confetti`, `flutter_dotenv`, `shared_preferences`
- **Testing**: flutter_test
- **Control de versiones**: Git & GitHub

---

## 📱 Requisitos
- Android 5.0 (Lollipop) o superior
- Conexión a Internet activa
- Espacio disponible: ~50 MB

---

## 🚀 Instalación

### Opción 1: Descargar APK (Recomendado)
1. Ve a la sección **Releases** de este repositorio.
2. Descarga `app-arm64-v8a-release.apk` (versión **v2.0.0**).
3. En tu móvil Android:
   - Ajustes → Seguridad → Activar "Instalar aplicaciones desconocidas".
4. Abre el archivo descargado y pulsa **Instalar**.

### Opción 2: Compilar desde código
```bash
# 1. Clonar repositorio
git clone https://github.com/Mminsil/tintAviva.git
cd tintaviva

# 2. Instalar dependencias
flutter pub get

# 3. Configurar Firebase
# - Crear proyecto en Firebase Console
# - Añadir app Android con tu package name
# - Descargar google-services.json en android/app/
# - Habilitar Auth y Firestore

# 4. Configurar variables de entorno
# Crear archivo .env en la raíz con:
# GOOGLE_BOOKS_API_KEY=tu_api_key_aqui

# 5. Ejecutar en debug
flutter run

# 6. Generar APK de producción
flutter build apk --release --split-per-abi
# Los APKs estarán en: build/app/outputs/flutter-apk/
---

## 👩‍💻 Autora

**Mariana Mincarelli Silvero**  
📧 Contacto: [maryminca@gmail.com](mailto:maryminca@gmail.com)  
🔗 GitHub: [@Mminsil](https://github.com/Mminsil)  

> Proyecto Final DAM | Curso 2025-2026  
> *Código documentado, validado y listo para producción.*