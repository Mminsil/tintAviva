import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:tintaviva/utils/streak_helper.dart';

/// Servicio centralizado para todas las operaciones de lectura y escritura en Firebase.
///
/// Propósito:
/// 1. Centralizar la lógica de negocio relacionada con Firestore para evitar duplicación.
/// 2. Garantizar consistencia de datos mediante operaciones atómicas (WriteBatch).
/// 3. Manejar sincronización entre colecciones relacionadas (users, user_books, books, clubs).
///
/// Características clave:
/// - Usa batches para asegurar que múltiples cambios ocurran juntos o fallen juntos.
/// - Normaliza títulos y autores para generar IDs únicos y consistentes.
/// - Integra con StreakHelper para actualizar la racha de lectura tras acciones relevantes.
class DatabaseService {
  // Instancia singleton de Firestore para toda la aplicación.
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ------------------------------------------------------------------
  // GESTIÓN DE LIBROS
  // ------------------------------------------------------------------

  /// Guarda un nuevo libro en la biblioteca del usuario y, si es necesario, en el catálogo global.
  ///
  /// Parámetros:
  /// - [titulo], [autor], [isbn]: Datos de identificación del libro.
  /// - [estanteria]: Estado inicial ('Leído', 'Leyendo', 'Por leer').
  /// - [progreso]: Porcentaje de lectura (0-100).
  /// - [fechaInicio], [fechaFin]: Fechas de lectura (opcionales).
  /// - [formato]: 'Papel' o 'Digital' (afecta cómo se calcula el progreso).
  /// - [paginasTotalesFormulario], [paginaActual]: Datos específicos de formato papel.
  /// - [coverUrlFormulario], [sinopsis], [genero]: Metadatos adicionales.
  ///
  /// Lógica de unicidad:
  /// 1. Genera un ID único basado en título+autor normalizados (ignora ISBN para evitar duplicados por ediciones).
  /// 2. Verifica si el usuario ya tiene el libro en su biblioteca personal.
  /// 3. Si el libro no existe en el catálogo global ('books'), lo crea con los datos proporcionados.
  /// 4. Crea la entrada personal en 'user_books' vinculando al usuario y al libro global.
  /// 5. Actualiza las estadísticas del usuario (incremento atómico de contadores).
  static Future<void> guardarLibroFirestore(
    String titulo,
    String autor,
    String estanteria,
    int progreso,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String formato,
    int paginasTotalesFormulario,
    int paginaActual,
    String coverUrlFormulario,
    String isbn,
    String sinopsis,
    String genero,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Normalización de estado: si el progreso es 100%, forzar estantería a 'Leído'.
    String estanteriaFinal = (progreso >= 100) ? 'Leído' : estanteria;
    int progresoFinal = progreso > 100 ? 100 : progreso;

    // Generar ID único e inmutable para el libro (usando normalización para consistencia).
    String bookId = DatabaseService.generarBookId(
      titulo: titulo,
      autor: autor,
      isbn: isbn,
    );
    String userBookDocId = "${user.uid}_$bookId";

    final docRef = _db.collection('user_books').doc(userBookDocId);
    final bookRef = _db.collection('books').doc(bookId);
    final userRef = _db.collection('users').doc(user.uid);

    // 1. VERIFICAR DUPLICADO: El usuario no puede tener el mismo libro dos veces.
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      throw Exception(
        "El libro '${docSnapshot.data()?['title']}' ya está en tu biblioteca. ",
      );
    }

    // 2. VERIFICAR CATÁLOGO GLOBAL: ¿Existe ya este libro en la base de datos compartida?
    final bookSnapshot = await bookRef.get();
    String globalCover = bookSnapshot.exists
        ? (bookSnapshot.data()?['bookCover'] ?? '')
        : '';
    int globalPages = bookSnapshot.exists
        ? ((bookSnapshot.data()?['pages'] ?? 0) as int)
        : 0;

    String globalGenero = bookSnapshot.exists
        ? (bookSnapshot.data()?['genre'] ?? 'Sin género')
        : genero;

    // Iniciar batch atómico: todos los cambios siguientes se ejecutarán juntos o ninguno.
    final batch = _db.batch();

    // Crear entrada en catálogo global SOLO si es un libro nuevo para toda la plataforma.
    if (!bookSnapshot.exists) {
      Map<String, dynamic> nuevosDatosCatalogo = {
        'title': capitalizarTitulo(titulo.trim()),
        'author': capitalizarAutor(autor.trim()),
        'isbn': isbn,
        'synopsis': sinopsis,
        'pages': paginasTotalesFormulario > 0 ? paginasTotalesFormulario : 0,
        'bookCover': coverUrlFormulario.isNotEmpty ? coverUrlFormulario : '',
        'genre': genero,
      };
      batch.set(bookRef, nuevosDatosCatalogo);
    }

    // Crear entrada personal del usuario en 'user_books'.
    // Prioridad de datos: si el usuario proporcionó portada, usar esa; sino, la del catálogo global.
    String userCover = coverUrlFormulario.isNotEmpty
        ? coverUrlFormulario
        : globalCover;
    int userTotalPages = paginasTotalesFormulario > 0
        ? paginasTotalesFormulario
        : globalPages;

    batch.set(docRef, {
      'userId': user.uid,
      'bookId': bookId,
      'title': capitalizarTitulo(titulo.trim()),
      'author': capitalizarAutor(autor.trim()),
      'bookCover': userCover,
      'shelf': estanteriaFinal,
      'progress': progresoFinal.toInt(),
      'format': formato,
      'totalPages': userTotalPages,
      'currentPage': paginaActual,
      'rating': 0.0,
      'notes': '',
      'dateStarted': fechaInicio ?? FieldValue.serverTimestamp(),
      'dateFinished': estanteriaFinal == 'Leído'
          ? (fechaFin ?? FieldValue.serverTimestamp())
          : null,
      'genre': globalGenero,
    });

    // Actualizar estadísticas del usuario: incrementar el contador de la estantería correspondiente.
    String campoStats = "";
    if (estanteriaFinal == 'Leído') {
      campoStats = "stats.read";
    } else if (estanteriaFinal == 'Leyendo') {
      campoStats = "stats.inProgress";
    } else if (estanteriaFinal == 'Por leer') {
      campoStats = "stats.toRead";
    }

    if (campoStats.isNotEmpty) {
      batch.update(userRef, {
        campoStats: FieldValue.increment(
          1,
        ), // Incremento atómico seguro para concurrencia.
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }

    // Ejecutar todas las operaciones del batch de forma atómica.
    await batch.commit();
  }

  /// Elimina un libro de la biblioteca del usuario y decrementa sus estadísticas.
  ///
  /// Usa batch para asegurar que la eliminación del libro y la actualización de stats
  /// ocurran juntas, evitando inconsistencias si una falla.
  static Future<void> eliminarLibro(String docId, String estanteria) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = _db.batch();
      final libroRef = _db.collection('user_books').doc(docId);
      final userRef = _db.collection('users').doc(user.uid);

      batch.delete(libroRef);

      // Decremento atómico del contador correspondiente a la estantería actual.
      String campoStats = "";
      if (estanteria == 'Leído') campoStats = "stats.read";
      if (estanteria == 'Leyendo') campoStats = "stats.inProgress";
      if (estanteria == 'Por leer') campoStats = "stats.toRead";

      if (campoStats.isNotEmpty) {
        batch.update(userRef, {campoStats: FieldValue.increment(-1)});
      }

      await batch.commit();
    } catch (e) {
      throw Exception("Error al borrar el libro y actualizar estadísticas: $e");
    }
  }

  /// Edita datos de un libro personal y del catálogo global, ajustando estadísticas si cambia de estantería.
  ///
  /// Parámetros:
  /// - [oldShelf], [newShelf]: Para calcular el delta neto en estadísticas (evita race conditions).
  /// - [datosUserBook], [datosCatalogo]: Mapas con los campos a actualizar en cada colección.
  ///
  /// Lógica de stats: Solo se ajustan contadores si la estantería cambió (ej: de 'Leyendo' a 'Leído').
  static Future<void> editarLibroYStats({
    required String userBookId,
    required String bookId,
    required String userId,
    required String oldShelf,
    required String newShelf,
    required Map<String, dynamic> datosUserBook,
    required Map<String, dynamic> datosCatalogo,
  }) async {
    final batch = _db.batch();
    final userBookRef = _db.collection('user_books').doc(userBookId);
    final bookRef = _db.collection('books').doc(bookId);
    final userRef = _db.collection('users').doc(userId);

    // Asegurar que progress sea int inclusivo si viene como double de UI
    if (datosUserBook.containsKey('progress')) {
      final progressValue = datosUserBook['progress'];
      datosUserBook['progress'] = progressValue is int
          ? progressValue
          : (progressValue is double ? progressValue.round() : 0);
    }

    batch.update(userBookRef, datosUserBook);
    batch.update(bookRef, datosCatalogo);

    // Ajuste de estadísticas solo si hubo cambio de estantería (Delta neto).
    if (oldShelf != newShelf) {
      String campoQuitar = _obtenerCampoStats(oldShelf);
      String campoSumar = _obtenerCampoStats(newShelf);

      if (campoQuitar.isNotEmpty) {
        batch.update(userRef, {campoQuitar: FieldValue.increment(-1)});
      }
      if (campoSumar.isNotEmpty) {
        batch.update(userRef, {campoSumar: FieldValue.increment(1)});
      }
    }

    await batch.commit();
    // Actualizar racha de lectura tras editar un libro (acción relevante para el hábito).
    await StreakHelper.updateStreak();
  }

  /// Actualiza el progreso de lectura y sincroniza automáticamente la estantería y estadísticas.
  /// También sincroniza el progreso con el club si el libro está vinculado a uno.
  ///
  /// Lógica de progreso:
  /// - Digital: usa el porcentaje directamente.
  /// - Papel: calcula porcentaje como (páginaActual / totalPages) * 100.
  ///
  /// Sincronización con clubes: Si el libro tiene 'id_club', actualiza el progreso del miembro en ese club.
  static Future<void> actualizarProgresoBiblioteca({
    required String userBookId,
    required String formato,
    double? porcentaje,
    int? paginaActual,
    int? totalPaginas,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final bookRef = FirebaseFirestore.instance
        .collection('user_books')
        .doc(userBookId);
    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);

    try {
      // Leemos estado actual para calcular deltas correctos y evitar sobrescrituras.
      final bookDoc = await bookRef.get();
      if (!bookDoc.exists) return;

      final currentData = bookDoc.data() as Map<String, dynamic>;
      final String currentShelf = currentData['shelf'] ?? 'Por leer';

      // Cálculo de progreso según formato.
      double progresoFinal = 0;
      if (formato == 'Digital') {
        progresoFinal = porcentaje ?? 0;
      } else {
        final pActual = paginaActual ?? 0;
        final pTotal = totalPaginas ?? 1;
        progresoFinal = pTotal > 0 ? (pActual / pTotal) * 100 : 0.0;
      }

      progresoFinal = progresoFinal.clamp(0.0, 100.0);
      final int progresoInt = progresoFinal.round().toInt();

      // Determinación automática de estantería basada en progreso.
      String newShelf = currentShelf;
      if (progresoInt >= 100) {
        newShelf = 'Leído';
      } else if (progresoInt > 0) {
        newShelf = 'Leyendo';
      } else {
        newShelf = 'Por leer';
      }

      // Preparación de datos para user_books.
      Map<String, dynamic> bookUpdates = {
        'progress': progresoInt,
        'shelf': newShelf,
        'lastUpdate': FieldValue.serverTimestamp(),
      };

      if (formato == 'Digital') {
        bookUpdates['format'] = 'Digital';
      } else {
        bookUpdates['format'] = 'Papel';
        bookUpdates['currentPage'] = paginaActual ?? 0;
        bookUpdates['totalPages'] = totalPaginas ?? 0;
      }

      // Gestión de fecha de finalización: solo establecer si se completa por primera vez.
      if (newShelf == 'Leído' && currentData['dateFinished'] == null) {
        bookUpdates['dateFinished'] = FieldValue.serverTimestamp();
      } else if (newShelf != 'Leído') {
        bookUpdates['dateFinished'] = null;
      }

      batch.update(bookRef, bookUpdates);

      // Actualización de estadísticas si cambió la estantería (delta neto).
      if (currentShelf != newShelf) {
        Map<String, dynamic> statsUpdates = {};

        // Restar de la antigua estantería.
        if (currentShelf == 'Leído') {
          statsUpdates['stats.read'] = FieldValue.increment(-1);
        } else if (currentShelf == 'Leyendo') {
          statsUpdates['stats.inProgress'] = FieldValue.increment(-1);
        } else if (currentShelf == 'Por leer') {
          statsUpdates['stats.toRead'] = FieldValue.increment(-1);
        }

        // Sumar a la nueva estantería.
        if (newShelf == 'Leído') {
          statsUpdates['stats.read'] = FieldValue.increment(1);
        } else if (newShelf == 'Leyendo') {
          statsUpdates['stats.inProgress'] = FieldValue.increment(1);
        } else if (newShelf == 'Por leer') {
          statsUpdates['stats.toRead'] = FieldValue.increment(1);
        }

        if (statsUpdates.isNotEmpty) batch.update(userRef, statsUpdates);
      }

      // Sincronización con Club: Si el libro pertenece a un club, actualizamos el progreso del miembro.
      final String? clubId = currentData['id_club'];
      if (clubId != null && clubId.isNotEmpty) {
        batch.update(
          FirebaseFirestore.instance.collection('clubs').doc(clubId),
          {
            'club_members.${user.uid}.progress': progresoInt,
            'club_members.${user.uid}.goalReached': progresoInt >= 100,
          },
        );
      }

      await batch.commit();
      // Actualizar racha de lectura tras actualizar progreso (acción relevante para el hábito).
      await StreakHelper.updateStreak();
    } catch (e) {
      debugPrint("Error actualizando progreso: $e");
    }
  }

  // ------------------------------------------------------------------
  // GESTIÓN DE CLUBES
  // ------------------------------------------------------------------

  /// Crea un club completo: Documento principal, meta inicial, comentario de bienvenida y vincula al creador.
  ///
  /// Estructura creada:
  /// 1. Documento 'clubs' con datos del club, miembros y estado.
  /// 2. Subcolección 'club_goals' con la meta inicial.
  /// 3. Sub-subcolección 'comments' con un mensaje de bienvenida.
  /// 4. Vinculación del club al usuario creador ('my_clubs').
  /// 5. Gestión del libro del club en la biblioteca personal del admin.
  static Future<void> crearClub({
    required String nombre,
    String descripcion = "",
    required String libro,
    required String autorLibro,
    String? bookId,
    String? portadaLibro,
    required int maxMiembros,
    String status = 'activo',
    String? clubImageUrl,
    String? isbn,
    String? sinopsis,
    int? pages,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Generar código de invitación único: primer nombre del club + timestamp corto.
    String codigoCorto = DateTime.now().millisecondsSinceEpoch
        .toString()
        .substring(9);
    String codigoInvitacion =
        "${nombre.trim().toUpperCase().split(' ').first}-$codigoCorto";

    try {
      final batch = _db.batch();
      final DocumentReference clubRef = _db.collection('clubs').doc();
      final DocumentReference initialGoalRef = clubRef
          .collection('club_goals')
          .doc();
      final DocumentReference commentRef = initialGoalRef
          .collection('comments')
          .doc();

      // Obtener stats del admin para el snapshot inicial del miembro.
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userStats = userDoc.data()?['stats'] ?? {};
      final statsSnapshot = {
        'booksRead': userStats['read'] ?? 0,
        'currentlyReading': userStats['inProgress'] ?? 0,
      };

      // 1. Crear documento principal del club.
      batch.set(clubRef, {
        'name': nombre,
        'description': descripcion,
        'clubImageUrl': clubImageUrl ?? "",
        'book': libro,
        'bookAuthor': autorLibro,
        'bookCover': portadaLibro,
        'bookId': bookId,
        'maxMembers': maxMiembros,
        'membersCount': 1,
        'isPublic': false,
        'code': codigoInvitacion,
        'ownerId': user.uid,
        'members': [user.uid],
        'club_members': {
          user.uid: {
            'role': 'admin',
            'goalReached': false,
            'joinedAt': FieldValue.serverTimestamp(),
            'userName': userDoc.data()?['name'] ?? "Anfitrión",
            'userPhoto': userDoc.data()?['photoURL'] ?? "",
            'progress': 0,
            'format': null,
            'statsSnapshot': statsSnapshot,
          },
        },
        'status': 'activo',
        'createdAt': FieldValue.serverTimestamp(),
        'currentGoalId': initialGoalRef.id,
        'currentGoalName': "¡Bienvenidos al club!",
        'limitDate': null,
      });

      // 2. Crear meta inicial y comentario de bienvenida.
      batch.set(initialGoalRef, {
        'goalName': "¡Bienvenidos al club!",
        'endDate': null,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'activa',
      });
      batch.set(commentRef, {
        'text': "¡Hola! Bienvenidos al club.",
        'userName': userDoc.data()?['name'] ?? "Anfitrión",
        'userId': user.uid,
        'userPhoto': userDoc.data()?['photoURL'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 3. Vincular club al usuario creador.
      batch.set(_db.collection('users').doc(user.uid), {
        'my_clubs': FieldValue.arrayUnion([clubRef.id]),
      }, SetOptions(merge: true));

      // 4. Gestionar libro del admin en su biblioteca personal (usando función auxiliar robusta).
      await _gestionarLibroAlUnirse(
        batch,
        user.uid,
        libro,
        autorLibro,
        clubRef.id,
        isbn ?? '',
        sinopsis ?? '',
        pages ?? 0,
        portadaLibro ?? '',
      );

      await batch.commit();

      // Actualizar racha de lectura tras crear un club (acción relevante para el hábito).
      await StreakHelper.updateStreak();
    } catch (e) {
      throw Exception("Error al crear el club: $e");
    }
  }

  /// Permite a un usuario unirse a un club mediante código.
  /// Gestiona automáticamente la adición del libro a su biblioteca si no lo tenía.
  static Future<void> unirseAClub(String codigo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "Debes iniciar sesión.";

    // Buscar club por código de invitación.
    final snapshot = await _db
        .collection('clubs')
        .where('code', isEqualTo: codigo.trim())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) throw "Club no encontrado.";

    final clubDoc = snapshot.docs.first;
    final clubData = clubDoc.data();

    // Validar capacidad del club.
    final int maxMembers = clubData['maxMembers'] ?? 999;
    final int currentMembers = (clubData['membersCount'] ?? 0) as int;
    if (currentMembers >= maxMembers) throw "El club está completo.";

    final batch = _db.batch();
    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    // Extraer datos del libro del club para pasarlos a la gestión de biblioteca.
    String isbnClub = clubData['isbn'] ?? '';
    String sinopsisClub = clubData['sinopsis'] ?? '';
    int pagesClub = clubData['pages'] ?? 0;
    String coverClub = clubData['bookCover'] ?? '';

    // Asegurar que el usuario tenga el libro del club en su biblioteca personal.
    await _gestionarLibroAlUnirse(
      batch,
      user.uid,
      clubData['book'] ?? "Sin título",
      clubData['bookAuthor'] ?? '',
      clubDoc.id,
      isbnClub,
      sinopsisClub,
      pagesClub,
      coverClub,
    );

    // Capturar stats actuales del usuario para el snapshot del nuevo miembro.
    final statsActuales = userData['stats'] ?? {};
    final statsSnapshot = {
      'booksRead': statsActuales['read'] ?? 0,
      'currentlyReading': statsActuales['inProgress'] ?? 0,
    };

    // Actualizar documento del club: añadir miembro y incrementar contador.
    batch.update(clubDoc.reference, {
      'members': FieldValue.arrayUnion([user.uid]),
      'membersCount': FieldValue.increment(1),
      'club_members.${user.uid}': {
        'userName': userData['name'] ?? 'Usuario',
        'userPhoto': userData['photoURL'] ?? "",
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'miembro',
        'progress': 0,
        'format': null,
        'goalReached': false,
        'statsSnapshot': statsSnapshot,
      },
    });

    // Vincular club al usuario en su documento personal.
    batch.set(userDoc.reference, {
      'my_clubs': FieldValue.arrayUnion([clubDoc.id]),
    }, SetOptions(merge: true));

    await batch.commit();
    // Actualizar racha de lectura tras unirse a un club.
    await StreakHelper.updateStreak();
  }

  /// Finaliza un club: Cierra metas, libera libros a bibliotecas personales y marca fecha de fin.
  ///
  /// Lógica de liberación:
  /// - Si el usuario terminó el libro (progress >= 100), pasa a 'Leído' con fecha de finalización.
  /// - Si no, se queda en 'Leyendo' como libro personal independiente.
  static Future<void> finalizarClub(String clubId) async {
    final batch = _db.batch();
    final clubRef = _db.collection('clubs').doc(clubId);

    try {
      batch.update(clubRef, {
        'status': 'finalizado',
        'endDate': FieldValue.serverTimestamp(),
        'currentGoalId': null,
        'currentGoalName': null,
      });

      // Liberar todos los libros vinculados a este club.
      final booksSnapshot = await _db
          .collection('user_books')
          .where('id_club', isEqualTo: clubId)
          .get();
      for (var doc in booksSnapshot.docs) {
        final data = doc.data();
        final progress = (data['progress'] ?? 0).toDouble();
        final shelfActual = data['shelf'] as String?;

        Map<String, dynamic> updates = {
          'id_club': FieldValue.delete(), // Romper vínculo con el club.
          'lastUpdated': FieldValue.delete(),
        };

        // Si terminó el libro, pasa a 'Leído'. Si no, se queda 'Leyendo' como personal.
        if (progress >= 100) {
          updates['shelf'] = 'Leído';
          updates['dateFinished'] = FieldValue.serverTimestamp();
        } else if (shelfActual == 'Leyendo') {
          updates['shelf'] = 'Leyendo';
        }

        batch.update(doc.reference, updates);
      }

      await batch.commit();
    } catch (e) {
      throw Exception("No se pudo finalizar el club: $e");
    }
  }

  /// Elimina un club permanentemente: Borra subcolecciones, ajusta stats de usuarios y elimina documentos.
  ///
  /// Proceso atómico:
  /// 1. Para cada miembro: calcular delta neto de stats y actualizar su libro personal.
  /// 2. Borrar recursivamente metas y comentarios (subcolecciones anidadas).
  /// 3. Eliminar documento del club y limpiar referencias en usuarios ('my_clubs').
  static Future<void> eliminarClub(String clubId) async {
    final batch = _db.batch();
    final clubRef = _db.collection('clubs').doc(clubId);
    final clubDoc = await clubRef.get();

    if (!clubDoc.exists) throw Exception("Club no encontrado");
    final clubData = clubDoc.data() as Map<String, dynamic>;
    final List<String> members = List<String>.from(clubData['members'] ?? []);
    final String? bookIdFromClub = clubData['bookId'];
    final String libroTitulo = clubData['book'] ?? "";

    // 1. Procesar libros y estadísticas de cada miembro.
    for (String uid in members) {
      QuerySnapshot booksSnapshot;
      if (bookIdFromClub != null && bookIdFromClub.isNotEmpty) {
        // Búsqueda precisa por bookId (más eficiente y segura).
        booksSnapshot = await _db
            .collection('user_books')
            .where('userId', isEqualTo: uid)
            .where('bookId', isEqualTo: bookIdFromClub)
            .limit(1)
            .get();
      } else {
        // Fallback por título (menos preciso pero funcional).
        booksSnapshot = await _db
            .collection('user_books')
            .where('userId', isEqualTo: uid)
            .where('title', isEqualTo: libroTitulo)
            .limit(1)
            .get();
      }

      if (booksSnapshot.docs.isEmpty) continue;

      final docRef = booksSnapshot.docs.first.reference;
      final bookData = booksSnapshot.docs.first.data() as Map<String, dynamic>;
      final double progress = (bookData['progress'] ?? 0).toDouble();
      final String currentShelf = bookData['shelf'] ?? 'Leyendo';
      final String newShelf = progress >= 100 ? 'Leído' : 'Leyendo';

      // Cálculo de Delta Neto para estadísticas (evita race conditions en contadores).
      int inProgressDelta = 0, readDelta = 0, toReadDelta = 0;

      if (currentShelf == 'Leyendo') {
        inProgressDelta--;
      } else if (currentShelf == 'Leído') {
        readDelta--;
      } else if (currentShelf == 'Por leer') {
        toReadDelta--;
      }

      if (newShelf == 'Leyendo') {
        inProgressDelta++;
      } else if (newShelf == 'Leído') {
        readDelta++;
      } else if (newShelf == 'Por leer') {
        toReadDelta++;
      }

      batch.update(docRef, {'id_club': FieldValue.delete(), 'shelf': newShelf});

      if (inProgressDelta != 0 || readDelta != 0 || toReadDelta != 0) {
        Map<String, dynamic> statsUpdate = {};
        if (inProgressDelta != 0) {
          statsUpdate['stats.inProgress'] = FieldValue.increment(
            inProgressDelta,
          );
        }
        if (readDelta != 0) {
          statsUpdate['stats.read'] = FieldValue.increment(readDelta);
        }
        if (toReadDelta != 0) {
          statsUpdate['stats.toRead'] = FieldValue.increment(toReadDelta);
        }
        batch.update(_db.collection('users').doc(uid), statsUpdate);
      }
    }

    // 2. Borrar subcolecciones (Metas y Comentarios) de forma recursiva.
    final goalsSnapshot = await clubRef.collection('club_goals').get();
    for (var goal in goalsSnapshot.docs) {
      final commentsSnapshot = await goal.reference
          .collection('comments')
          .get();
      for (var comment in commentsSnapshot.docs) {
        batch.delete(comment.reference);
      }
      batch.delete(goal.reference);
    }

    // 3. Borrar club y limpiar referencias en usuarios.
    batch.delete(clubRef);
    for (String uid in members) {
      batch.update(_db.collection('users').doc(uid), {
        'my_clubs': FieldValue.arrayRemove([clubId]),
      });
    }

    await batch.commit();
  }

  /// Expulsa o permite salir a un usuario de un club.
  ///
  /// Proceso:
  /// 1. Quitar usuario del club (miembros, contador, club_members).
  /// 2. Quitar club de la lista personal del usuario ('my_clubs').
  /// 3. Desvincular el libro del club (quitar 'id_club') pero mantenerlo en biblioteca personal.
  static Future<void> eliminarUsuarioDelClub(
    String clubId,
    String userId,
  ) async {
    try {
      final batch = _db.batch();
      final clubRef = _db.collection('clubs').doc(clubId);
      final userRef = _db.collection('users').doc(userId);

      batch.update(clubRef, {
        'members': FieldValue.arrayRemove([userId]),
        'membersCount': FieldValue.increment(-1),
        'club_members.$userId': FieldValue.delete(),
      });

      batch.update(userRef, {
        'my_clubs': FieldValue.arrayRemove([clubId]),
      });

      // Desvincular libro del club: quitar campo 'id_club' pero mantener el libro.
      final userBooksSnapshot = await _db
          .collection('user_books')
          .where('userId', isEqualTo: userId)
          .where('id_club', isEqualTo: clubId)
          .limit(1)
          .get();
      if (userBooksSnapshot.docs.isNotEmpty) {
        batch.update(userBooksSnapshot.docs.first.reference, {
          'id_club': FieldValue.delete(),
        });
      }

      await batch.commit();
    } catch (e) {
      throw Exception("Error al eliminar usuario del club: $e");
    }
  }

  /// Crea una nueva meta en el club, reseteando el estado de lectura de los miembros.
  ///
  /// Proceso:
  /// 1. Crear nuevo documento en subcolección 'club_goals'.
  /// 2. Actualizar club con referencia a la nueva meta.
  /// 3. Resetear 'goalReached' e 'isReading' para todos los miembros.
  static Future<void> actualizarMetaClub({
    required String clubId,
    required String nombreMeta,
    required DateTime fecha,
    required List<String> todosLosUids,
  }) async {
    try {
      final batch = _db.batch();
      final clubRef = _db.collection('clubs').doc(clubId);
      final newGoalRef = clubRef.collection('club_goals').doc();

      batch.set(newGoalRef, {
        'goalName': nombreMeta,
        'endDate': Timestamp.fromDate(fecha),
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'activa',
      });

      Map<String, dynamic> clubUpdates = {
        'currentGoalId': newGoalRef.id,
        'currentGoalName': nombreMeta,
        'limitDate': Timestamp.fromDate(fecha),
        'currentGoalCreatedAt': FieldValue.serverTimestamp(),
      };

      // Resetear estado de todos los miembros para la nueva meta.
      for (String uid in todosLosUids) {
        clubUpdates['club_members.$uid.goalReached'] = false;
        clubUpdates['club_members.$uid.isReading'] = false;
      }

      batch.update(clubRef, clubUpdates);
      await batch.commit();
    } catch (e) {
      throw "No se pudo actualizar la meta: $e";
    }
  }

  static Future<void> confirmarLlegadaMeta(String clubId, String userId) async {
    try {
      await _db.collection('clubs').doc(clubId).update({
        'club_members.$userId.goalReached': true,
      });
    } catch (e) {
      throw "No se pudo confirmar tu progreso.";
    }
  }

  static Future<void> marcarMetaComoEmpezada(
    String clubId,
    String userId,
  ) async {
    try {
      await _db.collection('clubs').doc(clubId).update({
        'club_members.$userId.goalReached': false,
        'club_members.$userId.isReading': true,
      });
    } catch (e) {
      throw "Error al actualizar estado de lectura.";
    }
  }

  static Future<void> enviarComentario({
    required String clubId,
    required String goalId,
    required String texto,
    required String userId,
    required String userName,
    required String userPhoto,
  }) async {
    if (texto.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('clubs')
        .doc(clubId)
        .collection('club_goals')
        .doc(goalId)
        .collection('comments')
        .add({
          'text': texto.trim(),
          'userId': userId,
          'userName': userName,
          'userPhoto': userPhoto,
          'createdAt': FieldValue.serverTimestamp(),
        });
  }

  /// Reactiva un club finalizado: Restaura estado activo y re-vincula libros de los miembros.
  ///
  /// Lógica de re-vinculación:
  /// - Si el usuario no terminó el libro (progress < 100), lo devuelve a 'Leyendo' para que aparezca en vistas activas.
  /// - Si ya lo terminó, lo mantiene en 'Leído' pero restaura el vínculo con el club.
  static Future<void> reactivarClub(String clubId) async {
    final batch = _db.batch();
    final clubRef = _db.collection('clubs').doc(clubId);

    try {
      final clubDoc = await clubRef.get();
      if (!clubDoc.exists) throw Exception("Club no encontrado");
      final clubData = clubDoc.data() as Map<String, dynamic>;
      final List<String> members = List<String>.from(clubData['members'] ?? []);
      final String bookTitle = clubData['book'] ?? "";
      final String? bookIdFromClub = clubData['bookId'];

      batch.update(clubRef, {'status': 'activo', 'endDate': null});

      // Restaurar vínculo id_club en los libros de los miembros.
      for (String uid in members) {
        QuerySnapshot booksSnapshot;
        if (bookIdFromClub != null && bookIdFromClub.isNotEmpty) {
          booksSnapshot = await _db
              .collection('user_books')
              .where('userId', isEqualTo: uid)
              .where('bookId', isEqualTo: bookIdFromClub)
              .limit(1)
              .get();
        } else {
          booksSnapshot = await _db
              .collection('user_books')
              .where('userId', isEqualTo: uid)
              .where('title', isEqualTo: bookTitle)
              .limit(1)
              .get();
        }

        if (booksSnapshot.docs.isNotEmpty) {
          final docRef = booksSnapshot.docs.first.reference;
          final bookData =
              booksSnapshot.docs.first.data() as Map<String, dynamic>;
          double progress = (bookData['progress'] ?? 0).toDouble();

          Map<String, dynamic> updates = {'id_club': clubId};

          // Si no estaba terminado, lo devolvemos a 'Leyendo' para que aparezca en la vista activa.
          if (progress < 100) {
            updates['shelf'] = 'Leyendo';
            updates['dateFinished'] = null;
          }

          batch.update(docRef, updates);
        }
      }

      await batch.commit();
    } catch (e) {
      throw Exception("No se pudo reactivar el club: $e");
    }
  }

  // ------------------------------------------------------------------
  // GESTIÓN DE CITAS FAVORITAS
  // ------------------------------------------------------------------

  /// Añade una cita favorita al perfil del usuario.
  ///
  /// Almacena la cita en un array 'favoriteQuotes' dentro del documento del usuario.
  static Future<void> agregarCitaFavorita({
    required String texto,
    required String libroTitulo,
    required String autor,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = _db.collection('users').doc(user.uid);

    // Creamos el mapa de la cita con metadatos.
    final nuevaCita = {
      'text': texto,
      'author': autor,
      'bookTitle': libroTitulo,
      'createdAt': FieldValue.serverTimestamp(),
    };

    try {
      await userRef.collection('quotes').add(nuevaCita);
    } catch (e) {
      throw Exception("Error al guardar cita: $e");
    }
  }

  /// Obtiene una cita aleatoria de la lista del usuario.
  /// Devuelve null si no tiene citas.
  // TODO(escalado): Si quotes > ~1000 por usuario, cambiar a:
  // 1. Añadir campo 'randomSeed' (double 0.0-1.0) al guardar cada cita
  // 2. Query: orderBy('randomSeed').limit(1)
  // Motivo: evitar descargar todas las citas para elegir una al azar.
  // Fecha: Mayo 2026 - Escala actual: <500 citas/usuario.
  static Future<Map<String, dynamic>?> obtenerCitaAleatoria(
    String userId,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    try {
      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('quotes')
          .get();

      if (snapshot.docs.isEmpty) return null;

      // Elegimos una al azar
      final random = Random();
      final randomDoc = snapshot.docs[random.nextInt(snapshot.docs.length)];
      final data = randomDoc.data();

      return {
        'text': data['text'] ?? '',
        'author': data['author'] ?? '',
        'bookTitle': data['bookTitle'] ?? '',
      };
    } catch (e) {
      throw Exception("Error obteniendo cita aleatoria: $e");
    }
  }

  /// Elimina una cita específica de la lista de favoritos del usuario.
  ///
  /// Nota: Como usamos arrays sin IDs únicos, buscamos por coincidencia exacta de texto, título y autor.
  static Future<void> eliminarCitaFavorita({
    required String texto,
    required String libroTitulo,
    required String autor,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("Usuario no autenticado");

    try {
      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('quotes')
          .where('text', isEqualTo: texto)
          .where('bookTitle', isEqualTo: libroTitulo)
          .where('author', isEqualTo: autor)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        await snapshot.docs.first.reference.delete();
      }
    } catch (e) {
      throw Exception("Error al eliminar cita: $e");
    }
  }

  /// Obtiene todas las citas favoritas de un libro específico.
  static Future<List<Map<String, dynamic>>> obtenerCitasDeLibro(
    String tituloLibro,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];
    final snapshot = await _db
        .collection('users')
        .doc(user.uid)
        .collection('quotes')
        .where('bookTitle', isEqualTo: tituloLibro)
        .get();
    //Convertir los documentos a una lista de Map
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  static Future<void> actualizarCitaFavorita({
    required String textoAntiguo,
    required String textoNuevo,
    required String libroTitulo,
    required String autor,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Buscar la cita por texto antiguo + metadata
      final snapshot = await _db
          .collection('users')
          .doc(user.uid)
          .collection('quotes')
          .where('text', isEqualTo: textoAntiguo)
          .where('bookTitle', isEqualTo: libroTitulo)
          .where('author', isEqualTo: autor)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        // Actualizar solo el campo 'text'
        await snapshot.docs.first.reference.update({'text': textoNuevo});
      }
    } catch (e) {
      throw Exception("Error al actualizar cita: $e");
    }
  }

  // ------------------------------------------------------------------
  // GESTIÓN DE DIARIO DE LECTURA Y PERSONAJES
  // ------------------------------------------------------------------

  /// Añade una nueva entrada al diario de lectura de un libro específico.
  ///
  /// Parámetros:
  /// - [userBookId]: El ID del documento en 'user_books'.
  /// - [texto]: La reflexión del usuario.
  /// - [mood]: El emoji seleccionado (ej: '😍', '🤔').
  ///
  /// Almacena la entrada en un array 'readingJournal' dentro del documento del libro personal.
  static Future<void> agregarEntradaDiario({
    required String userBookId,
    required String texto,
    required String mood,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = _db.collection('user_books').doc(userBookId);

    await docRef.update({
      'readingJournal': FieldValue.arrayUnion([
        {'date': DateTime.now(), 'entry': texto, 'mood': mood},
      ]),
    });
  }

  static Future<void> actualizarEntradaDiario({
    required String userBookId,
    required Timestamp entradaFecha,
    required String nuevoTexto,
    String? nuevoMood,
  }) async {
    final docRef = _db.collection('user_books').doc(userBookId);
    final doc = await docRef.get();
    if (!doc.exists) return;

    final data = doc.data()!;
    List<dynamic> journal = data['readingJournal'] ?? [];

    // Buscar el índice de la entrada por fecha/timestamp
    int index = journal.indexWhere(
      (entry) => entry['date']?.toDate() == entradaFecha.toDate(),
    );

    if (index != -1) {
      journal[index]['entry'] = nuevoTexto;
      if (nuevoMood != null && nuevoMood.isNotEmpty) {
        journal[index]['mood'] = nuevoMood;
      }

      await docRef.update({'readingJournal': journal});
    }
  }

  /// Elimina una entrada específica del diario.
  ///
  /// Nota: Como usamos arrays sin IDs únicos, buscamos por coincidencia exacta de fecha y texto.
  /// Esto puede ser frágil si hay entradas idénticas en el mismo milisegundo.
  static Future<void> eliminarEntradaDiario({
    required String userBookId,
    required String texto,
    required Timestamp fecha,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = _db.collection('user_books').doc(userBookId);

    try {
      // Leemos el documento actual para obtener el array completo.
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) return;

      final data = docSnapshot.data();
      if (data == null || !data.containsKey('readingJournal')) return;

      List<dynamic> journal = data['readingJournal'];

      // Filtramos para quitar la entrada que coincide con fecha y texto.
      final nuevaLista = journal.where((item) {
        // Comparamos timestamp y texto.
        // Nota: Los timestamps de Firestore pueden tener microsegundos de diferencia,
        // pero al venir del mismo objeto 'fecha' pasado como argumento, debería coincidir.
        return !(item['entry'] == texto && item['date'] == fecha);
      }).toList();

      // Actualizamos el array en Firestore (reemplazo completo).
      await docRef.update({'readingJournal': nuevaLista});
    } catch (e) {
      throw Exception("Error al eliminar entrada del diario: $e");
    }
  }

  /// Añade un personaje a la lista de personajes principales del libro.
  static Future<void> agregarPersonaje({
    required String userBookId,
    required String nombrePersonaje,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = _db.collection('user_books').doc(userBookId);

    await docRef.update({
      'characters': FieldValue.arrayUnion([nombrePersonaje.trim()]),
    });
  }

  /// Elimina un personaje de la lista.
  static Future<void> eliminarPersonaje({
    required String userBookId,
    required String nombrePersonaje,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final docRef = _db.collection('user_books').doc(userBookId);

    await docRef.update({
      'characters': FieldValue.arrayRemove([nombrePersonaje.trim()]),
    });
  }

  // ------------------------------------------------------------------
  // MÉTODOS AUXILIARES PRIVADOS
  // ------------------------------------------------------------------

  /// Mapea el nombre de una estantería al campo de estadísticas correspondiente.
  static String _obtenerCampoStats(String estanteria) {
    if (estanteria == 'Leído') return "stats.read";
    if (estanteria == 'Leyendo') return "stats.inProgress";
    if (estanteria == 'Por leer') return "stats.toRead";
    return "";
  }

  /// Lógica interna compartida: Asegura que el usuario tenga el libro del club en su biblioteca.
  /// Si ya lo tiene, lo vincula. Si no, lo crea en estado 'Leyendo'.
  ///
  /// Parámetros adicionales para enriquecer el catálogo global si es un libro nuevo.
  static Future<void> _gestionarLibroAlUnirse(
    WriteBatch batch,
    String uid,
    String tituloLibro,
    String autorLibro,
    String clubId,
    String? isbn,
    String? sinopsis,
    int? pages,
    String? coverUrl,
  ) async {
    final userBooksRef = _db.collection('user_books');
    final userRef = _db.collection('users').doc(uid);

    String bookId = DatabaseService.generarBookId(
      titulo: tituloLibro,
      autor: autorLibro,
      isbn: isbn,
    );
    final bookRef = _db.collection('books').doc(bookId);
    final userBookDocId = "${uid}_$bookId";
    final docRef = userBooksRef.doc(userBookDocId);

    final docSnapshot = await docRef.get();

    if (docSnapshot.exists) {
      // CASO A: El usuario ya tiene este libro en su biblioteca.
      final data = docSnapshot.data() as Map<String, dynamic>;
      final estanteriaActual = data['shelf'];

      if (estanteriaActual == 'Leyendo') {
        // Ya está leyendo, solo vinculamos al club si no lo estaba.
        if (data['id_club'] != clubId) {
          batch.update(docRef, {'id_club': clubId});
        }
      } else {
        // Si estaba en 'Por leer' o 'Leído', lo movemos a 'Leyendo' y ajustamos stats.
        Map<String, dynamic> statsUpdate = {
          'stats.inProgress': FieldValue.increment(1),
        };

        if (estanteriaActual == 'Por leer') {
          statsUpdate['stats.toRead'] = FieldValue.increment(-1);
        }
        if (estanteriaActual == 'Leído') {
          statsUpdate['stats.read'] = FieldValue.increment(-1);
          // Si estaba leído, reiniciamos progreso a 0 al pasar a Leyendo.
          batch.update(docRef, {
            'shelf': 'Leyendo',
            'id_club': clubId,
            'progress': 0,
            'currentPage': 0,
            'dateFinished': null,
          });
        } else {
          batch.update(docRef, {
            'shelf': 'Leyendo',
            'id_club': clubId,
            'progress': 0,
          });
        }
        batch.update(userRef, statsUpdate);
      }
    } else {
      // CASO B: Libro nuevo para el usuario. Buscar o crear en catálogo global.
      final bookSnapshot = await bookRef.get();

      String finalAuthor = autorLibro;
      int finalPages = pages ?? 0;
      String finalCover = coverUrl ?? '';
      String finalSynopsis = sinopsis ?? '';
      String finalIsbn = isbn ?? '';

      if (bookSnapshot.exists) {
        // El libro ya existe en el catálogo global: usar sus datos (más completos).
        final existingData = bookSnapshot.data() as Map<String, dynamic>;
        finalAuthor = existingData['author'] ?? autorLibro;
        finalPages = (existingData['pages'] ?? 0) as int;
        finalCover = existingData['bookCover'] ?? '';
        finalSynopsis = existingData['synopsis'] ?? '';
        finalIsbn = existingData['isbn'] ?? '';
      } else {
        // El libro NO existe en el catálogo global: crearlo con los datos proporcionados.
        finalAuthor = autorLibro;
        finalPages = pages ?? 0;
        finalCover = coverUrl ?? '';
        finalSynopsis = sinopsis ?? '';
        finalIsbn = isbn ?? '';

        batch.set(bookRef, {
          'title': capitalizarTitulo(tituloLibro),
          'author': capitalizarAutor(autorLibro),
          'isbn': finalIsbn,
          'synopsis': finalSynopsis,
          'pages': finalPages > 0 ? finalPages : 0,
          'bookCover': finalCover.isNotEmpty ? finalCover : '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Crear entrada en user_books para el usuario.
      batch.set(docRef, {
        'userId': uid,
        'bookId': bookId,
        'title': capitalizarTitulo(tituloLibro),
        'author': capitalizarAutor(finalAuthor),
        'shelf': 'Leyendo',
        'progress': 0,
        'id_club': clubId,
        'format': null,
        'dateStarted': FieldValue.serverTimestamp(),
        'bookCover': finalCover,
        'currentPage': 0,
        'totalPages': finalPages,
        'rating': 0,
        'notes': '',
        'dateFinished': null,
      });

      batch.update(userRef, {'stats.inProgress': FieldValue.increment(1)});
    }
  }

  /// Normaliza texto para IDs y búsquedas consistentes.
  /// Convierte a minúsculas, quita tildes y reemplaza espacios/caracteres raros por guiones bajos.
  ///
  /// Propósito: Garantizar que "El Señor de los Anillos" y "el señor de los anillos" generen el mismo ID.
  static String _normalizarTexto(String texto) {
    if (texto.isEmpty) return '';

    String limpio = texto.toLowerCase().trim();

    // Quitar tildes y diéresis para normalización internacional.
    limpio = limpio
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll('ñ', 'n');

    // Reemplazar cualquier cosa que no sea letra o número por guion bajo.
    limpio = limpio.replaceAll(RegExp(r'[^a-z0-9]'), '_');

    // Evitar múltiples guiones bajos seguidos (limpieza final).
    limpio = limpio.replaceAll(RegExp(r'_+'), '_');

    return limpio;
  }

  /// Genera un ID único para un libro basado en Título y Autor normalizados.
  /// IGNORA el ISBN para el ID para evitar duplicados por distintas ediciones del mismo libro.
  ///
  /// Ejemplo: "El Hobbit" + "J.R.R. Tolkien" -> "el_hobbit_j_r_r_tolkien"
  static String generarBookId({
    required String titulo,
    String? autor,
    String? isbn, // Lo recibimos pero no lo usamos para el ID
  }) {
    // Normalizamos título y autor para crear una clave única y limpia.
    final tNorm = _normalizarTexto(titulo);
    final aNorm = autor != null && autor.isNotEmpty
        ? _normalizarTexto(autor)
        : 'desconocido';

    return "${tNorm}_$aNorm";
  }

  /// Capitaliza solo la primera letra del título.
  /// Ejemplo: "el señor de los anillos" -> "El señor de los anillos"
  static String capitalizarTitulo(String texto) {
    if (texto.isEmpty) return '';
    String limpio = texto.trim();
    return limpio[0].toUpperCase() + limpio.substring(1);
  }

  /// Capitaliza la primera letra de cada palabra del autor.
  /// Ejemplo: "j.r.r. tolkien" -> "J.R.R. Tolkien"
  static String capitalizarAutor(String texto) {
    if (texto.isEmpty) return '';
    return texto
        .split(' ')
        .map((palabra) {
          if (palabra.isEmpty) return palabra;
          return palabra[0].toUpperCase() + palabra.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
