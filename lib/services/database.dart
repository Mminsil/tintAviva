import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Servicio centralizado para todas las operaciones de lectura y escritura en Firebase.
///
/// Utiliza WriteBatch para operaciones atómicas: asegura que múltiples cambios
/// (ej: borrar libro + actualizar stats) ocurran juntos o fallen juntos.
class DatabaseService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- SECCIÓN DE LIBROS ---

  /// Guarda un nuevo libro en la biblioteca del usuario y, si es necesario, en el catálogo global.
  ///
  /// Lógica de unicidad:
  /// 1. Genera un ID único basado en ISBN o Título+Autor.
  /// 2. Verifica si el usuario ya lo tiene.
  /// 3. Si el libro no existe en el catálogo global ('books'), lo crea con los datos del formulario.
  /// 4. Crea el documento personal en 'user_books' vinculando al usuario.
  /// 5. Actualiza las estadísticas del usuario (incremento atómico).
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
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Normalización de estado inicial.
    String estanteriaFinal = (progreso >= 100) ? 'Leído' : estanteria;
    int progresoFinal = progreso > 100 ? 100 : progreso;

    // Normalización de texto para consistencia en búsquedas.
    String tituloNormalizado = capitalizarTitulo(titulo.trim());
    String autorNormalizado = capitalizarAutor(autor.trim());

    // Generación de ID único e inmutable para el libro.
    String bookId = DatabaseService.generarBookId(
      titulo: tituloNormalizado,
      autor: autorNormalizado,
      isbn: isbn,
    );

    String userBookDocId = "${user.uid}_$bookId";
    final docRef = _db.collection('user_books').doc(userBookDocId);
    final bookRef = _db.collection('books').doc(bookId);
    final userRef = _db.collection('users').doc(user.uid);

    // 1. VERIFICACIÓN: El usuario no puede tener el mismo libro dos veces.
    final docSnapshot = await docRef.get();
    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>;
      final estanteriaActual = data['shelf'] ?? 'Por leer';
      throw Exception(
        "El libro '${data['title']}' ya está en tu biblioteca en la estantería '$estanteriaActual'.",
      );
    }

    // 2. VERIFICACIÓN: ¿Existe el libro en el catálogo global?
    final bookSnapshot = await bookRef.get();
    String globalCover = '';
    int globalPages = 0;

    if (bookSnapshot.exists) {
      // CASO A: Libro existente. Usamos sus datos como referencia, pero NO los sobrescribimos.
      final existingData = bookSnapshot.data() as Map<String, dynamic>;
      globalCover = existingData['bookCover'] ?? '';
      globalPages = (existingData['pages'] ?? 0).toInt();
    } else {
      // CASO B: Libro nuevo en la plataforma. Los datos del usuario definen el catálogo.
      globalCover = coverUrlFormulario.isNotEmpty ? coverUrlFormulario : '';
      globalPages = paginasTotalesFormulario > 0 ? paginasTotalesFormulario : 0;
    }

    // 3. EJECUCIÓN ATÓMICA (BATCH)
    final batch = _db.batch();

    // A. Crear entrada en catálogo global SOLO si es nuevo.
    if (!bookSnapshot.exists) {
      Map<String, dynamic> nuevosDatosCatalogo = {
        'title': tituloNormalizado,
        'author': autorNormalizado,
        'isbn': isbn,
      };
      if (globalCover.isNotEmpty) {
        nuevosDatosCatalogo['bookCover'] = globalCover;
      }
      if (globalPages > 0) nuevosDatosCatalogo['pages'] = globalPages;
      batch.set(bookRef, nuevosDatosCatalogo);
    }

    // B. Crear entrada personal del usuario.
    // Priorizamos los datos del formulario del usuario sobre los globales si existen.
    String userCover = coverUrlFormulario.isNotEmpty
        ? coverUrlFormulario
        : globalCover;
    int userTotalPages = paginasTotalesFormulario > 0
        ? paginasTotalesFormulario
        : globalPages;

    batch.set(docRef, {
      'userId': user.uid,
      'bookId': bookId,
      'title': tituloNormalizado,
      'author': autorNormalizado,
      'bookCover': userCover,
      'shelf': estanteriaFinal,
      'progress': progresoFinal,
      'format': formato,
      'totalPages': userTotalPages,
      'currentPage': paginaActual,
      'rating': 0.0,
      'notes': '',
      'dateStarted': fechaInicio ?? FieldValue.serverTimestamp(),
      'dateFinished': estanteriaFinal == 'Leído'
          ? (fechaFin ?? FieldValue.serverTimestamp())
          : null,
    });

    // C. Actualizar estadísticas del usuario (Incremento atómico).
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
        campoStats: FieldValue.increment(1),
        'lastActivity': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Genera un ID único para un libro basado en su identidad intrínseca.
  /// Prioriza ISBN si existe, sino usa Título_Autor normalizado.
  static String generarBookId({
    required String titulo,
    String? autor,
    String? isbn,
  }) {
    if (isbn != null && isbn.isNotEmpty) return isbn.trim();

    final t = titulo.trim().toLowerCase();
    final a = (autor != null && autor.isNotEmpty)
        ? autor.trim().toLowerCase()
        : "desconocido";
    return "${t}_$a".replaceAll(' ', '_').replaceAll('__', '_');
  }

  /// Elimina un libro de la biblioteca del usuario y decrementa sus estadísticas.
  static Future<void> eliminarLibro(String docId, String estanteria) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = _db.batch();
      final libroRef = _db.collection('user_books').doc(docId);
      final userRef = _db.collection('users').doc(user.uid);

      batch.delete(libroRef);

      // Decremento atómico del contador correspondiente.
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
  }

  /// Actualiza el progreso de lectura y sincroniza automáticamente la estantería y estadísticas.
  /// También sincroniza el progreso con el club si el libro está vinculado a uno.
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
      // Leemos estado actual para calcular deltas correctos.
      final bookDoc = await bookRef.get();
      if (!bookDoc.exists) return;

      final currentData = bookDoc.data() as Map<String, dynamic>;
      final String currentShelf = currentData['shelf'] ?? 'Por leer';

      // Cálculo de progreso según formato.
      double progresoFinal = 0;
      if (formato.toLowerCase() == 'digital') {
        progresoFinal = porcentaje ?? 0;
      } else {
        final pActual = paginaActual ?? 0;
        final pTotal = totalPaginas ?? 1;
        progresoFinal = pTotal > 0 ? (pActual / pTotal) * 100 : 0.0;
      }
      progresoFinal = progresoFinal.clamp(0.0, 100.0);

      // Determinación automática de estantería.
      String newShelf = currentShelf;
      if (progresoFinal >= 100) {
        newShelf = 'Leído';
      } else if (progresoFinal > 0) {
        newShelf = 'Leyendo';
      } else {
        newShelf = 'Por leer';
      }

      // Preparación de datos para user_books.
      Map<String, dynamic> bookUpdates = {
        'progress': progresoFinal,
        'shelf': newShelf,
        'lastUpdate': FieldValue.serverTimestamp(),
      };

      if (formato.toLowerCase() == 'digital') {
        bookUpdates['format'] = 'Digital';
      } else {
        bookUpdates['format'] = 'Papel';
        bookUpdates['currentPage'] = paginaActual ?? 0;
        bookUpdates['totalPages'] = totalPaginas ?? 0;
      }

      // Gestión de fecha de finalización.
      if (newShelf == 'Leído' && currentData['dateFinished'] == null) {
        bookUpdates['dateFinished'] = FieldValue.serverTimestamp();
      } else if (newShelf != 'Leído') {
        bookUpdates['dateFinished'] = null;
      }

      batch.update(bookRef, bookUpdates);

      // Actualización de estadísticas si cambió la estantería.
      if (currentShelf != newShelf) {
        Map<String, dynamic> statsUpdates = {};

        // Restar de la antigua.
        if (currentShelf == 'Leído') {
          statsUpdates['stats.read'] = FieldValue.increment(-1);
        } else if (currentShelf == 'Leyendo') {
          statsUpdates['stats.inProgress'] = FieldValue.increment(-1);
        } else if (currentShelf == 'Por leer') {
          statsUpdates['stats.toRead'] = FieldValue.increment(-1);
        }

        // Sumar a la nueva.
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
            'club_members.${user.uid}.progress': progresoFinal,
            'club_members.${user.uid}.goalReached': progresoFinal >= 100,
          },
        );
      }

      await batch.commit();
    } catch (e) {
      debugPrint("Error actualizando progreso: $e");
    }
  }

  /// Crea un club completo: Documento principal, meta inicial, comentario de bienvenida y vincula al creador.
  static Future<void> crearClub({
    required String nombre,
    String descripcion = "Club de lectura sin descripción",
    required String libro,
    required String autorLibro,
    String? bookId,
    String? portadaLibro,
    required int maxMiembros,
    String status = 'activo',
    String? clubImageUrl,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Generación de código de invitación único.
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

      // Snapshot de estadísticas del admin para mostrar en la lista de miembros.
      final userDoc = await _db.collection('users').doc(user.uid).get();
      final userStats = userDoc.data()?['stats'] ?? {};
      final statsSnapshot = {
        'booksRead': userStats['read'] ?? 0,
        'currentlyReading': userStats['inProgress'] ?? 0,
      };

      // 1. Crear Club.
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
            'userName': user.displayName ?? "Anfitrión",
            'userPhoto': user.photoURL ?? "",
            'progress': 0.0,
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

      // 2. Crear Meta Inicial.
      batch.set(initialGoalRef, {
        'goalName': "¡Bienvenidos al club!",
        'endDate': null,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'activa',
      });

      // 3. Crear Comentario de Bienvenida.
      batch.set(commentRef, {
        'text':
            "¡Hola! En esta sección vamos a comentar la meta actual del club. Recordad no hacer spoilers.",
        'userName': user.displayName ?? "Anfitrión",
        'userId': user.uid,
        'userPhoto': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 4. Vincular club al usuario.
      batch.set(_db.collection('users').doc(user.uid), {
        'my_clubs': FieldValue.arrayUnion([clubRef.id]),
      }, SetOptions(merge: true));

      // 5. Gestionar libro en biblioteca del admin.
      await _gestionarLibroAlUnirse(
        batch,
        user.uid,
        libro,
        autorLibro,
        clubRef.id,
      );

      await batch.commit();
    } catch (e) {
      throw Exception("Error al crear el club: $e");
    }
  }

  /// Permite a un usuario unirse a un club mediante código.
  /// Gestiona automáticamente la adición del libro a su biblioteca si no lo tenía.
  static Future<void> unirseAClub(String codigo) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw "Debes iniciar sesión.";

    final userDoc = await _db.collection('users').doc(user.uid).get();
    final userData = userDoc.data() as Map<String, dynamic>;

    final snapshot = await _db
        .collection('clubs')
        .where('code', isEqualTo: codigo.trim())
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) throw "Club no encontrado.";

    final clubDoc = snapshot.docs.first;
    final clubData = clubDoc.data();

    // Validación de capacidad.
    final int maxMembers = clubData['maxMembers'] ?? 999;
    final int currentMembers = (clubData['membersCount'] ?? 0) as int;
    if (currentMembers >= maxMembers) {
      throw "El club está completo ($currentMembers/$maxMembers miembros).";
    }

    final String tituloLibro = clubData['book'] ?? "Sin título";
    final batch = _db.batch();

    // Añade el libro a la biblioteca del usuario si es necesario.
    await _gestionarLibroAlUnirse(
      batch,
      user.uid,
      tituloLibro,
      clubData['bookAuthor'] ?? '',
      clubDoc.id,
    );

    // Captura stats actuales para el snapshot del miembro.
    final statsActuales = userData['stats'] ?? {};
    final statsSnapshot = {
      'booksRead': statsActuales['read'] ?? 0,
      'currentlyReading': statsActuales['inProgress'] ?? 0,
    };

    // Actualiza datos del club y añade al miembro.
    batch.update(clubDoc.reference, {
      'members': FieldValue.arrayUnion([user.uid]),
      'membersCount': FieldValue.increment(1),
      'club_members.${user.uid}': {
        'userName': userData['name'] ?? 'Usuario',
        'userPhoto': userData['photoURL'] ?? "",
        'joinedAt': FieldValue.serverTimestamp(),
        'role': 'miembro',
        'progress': 0.0,
        'format': null,
        'goalReached': false,
        'statsSnapshot': statsSnapshot,
      },
    });

    batch.set(userDoc.reference, {
      'my_clubs': FieldValue.arrayUnion([clubDoc.id]),
    }, SetOptions(merge: true));

    await batch.commit();
  }

  /// Lógica interna compartida: Asegura que el usuario tenga el libro del club en su biblioteca.
  /// Si ya lo tiene, lo vincula. Si no, lo crea en estado 'Leyendo'.
  static Future<void> _gestionarLibroAlUnirse(
    WriteBatch batch,
    String uid,
    String tituloLibro,
    String autorLibro,
    String clubId,
  ) async {
    final userBooksRef = _db.collection('user_books');
    final userRef = _db.collection('users').doc(uid);

    String autorFinal = autorLibro;
    int paginasTotales = 0;
    String coverUrl = '';

    // 1. ¿Tiene el usuario este libro ya?
    final queryLibro = await userBooksRef
        .where('userId', isEqualTo: uid)
        .where('title', isEqualTo: tituloLibro)
        .limit(1)
        .get();

    if (queryLibro.docs.isNotEmpty) {
      // CASO A: Ya existe. Actualizamos vínculo y estantería si es necesario.
      final doc = queryLibro.docs.first;
      final estanteriaActual = doc.data()['shelf'];

      if (estanteriaActual == 'Leyendo') {
        batch.update(doc.reference, {'id_club': clubId});
      } else {
        // Si estaba en 'Por leer' o 'Leído', lo pasamos a 'Leyendo' y ajustamos stats.
        Map<String, dynamic> statsUpdate = {
          'stats.inProgress': FieldValue.increment(1),
        };
        if (estanteriaActual == 'Por leer') {
          statsUpdate['stats.toRead'] = FieldValue.increment(-1);
        }
        if (estanteriaActual == 'Leído') {
          statsUpdate['stats.read'] = FieldValue.increment(-1);
        }

        batch.update(userRef, statsUpdate);
        batch.update(doc.reference, {
          'shelf': 'Leyendo',
          'id_club': clubId,
          'progress': 0,
        });
      }
    } else {
      // CASO B: Libro nuevo para el usuario. Buscar en catálogo global.
      final bookInfo = await _db
          .collection('books')
          .where('title', isEqualTo: tituloLibro)
          .limit(1)
          .get();

      if (bookInfo.docs.isNotEmpty) {
        final data = bookInfo.docs.first.data();
        autorFinal = data['author'] ?? autorLibro;
        paginasTotales = data['pages'] ?? 0;
        coverUrl = data['bookCover'] ?? '';
      } else {
        // CASO C: Libro totalmente nuevo. Crear en catálogo global.
        final bookId = DatabaseService.generarBookId(
          titulo: tituloLibro,
          autor: autorFinal,
        );
        final bookRef = _db.collection('books').doc(bookId);
        await bookRef.set({
          'title': tituloLibro,
          'author': autorFinal,
          'pages': paginasTotales,
          'bookCover': coverUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'synopsis': null,
          'isbn': null,
        });
      }

      // Crear entrada en user_books.
      String bookId = DatabaseService.generarBookId(
        titulo: tituloLibro,
        autor: autorFinal,
      );
      batch.set(userBooksRef.doc("${uid}_$bookId"), {
        'userId': uid,
        'bookId': bookId,
        'title': tituloLibro,
        'author': autorFinal,
        'shelf': 'Leyendo',
        'progress': 0,
        'id_club': clubId,
        'format': null,
        'dateStarted': FieldValue.serverTimestamp(),
        'bookCover': coverUrl,
        'currentPage': 0,
        'totalPages': paginasTotales,
        'rating': 0,
        'notes': '',
        'dateFinished': null,
      });

      batch.update(userRef, {'stats.inProgress': FieldValue.increment(1)});
    }
  }

  /// Finaliza un club: Cierra metas, libera libros a bibliotecas personales y marca fecha de fin.
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
          'id_club': FieldValue.delete(),
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

      // Cálculo de Delta Neto para estadísticas (evita race conditions).
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

    // 2. Borrar subcolecciones (Metas y Comentarios).
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

      // Desvincular libro del club.
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

  static Future<void> registrarActividadEnClub(
    String clubId,
    String userId,
  ) async {
    await _db.collection('clubs').doc(clubId).update({
      'club_members.$userId.lastActivity': FieldValue.serverTimestamp(),
    });
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

  static Future<void> guardarProgresoUsuario(
    String clubId,
    String userId,
    double progreso,
    bool esDigital,
  ) async {
    try {
      await _db.collection('clubs').doc(clubId).update({
        'club_members.$userId.progress': progreso,
        'club_members.$userId.format': esDigital ? 'Digital' : 'Papel',
        'club_members.$userId.lastUpdate': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw "Error al guardar el progreso: $e";
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

  static Future<void> forzarVinculacionLibro({
    required String userId,
    required String titulo,
    required int totalPaginas,
  }) async {
    final tituloNorm = capitalizarTitulo(titulo);
    final bookId = generarBookId(titulo: tituloNorm);
    final docId = "${userId}_$bookId";
    final ref = _db.collection('user_books').doc(docId);

    final snapshot = await ref.get();
    if (snapshot.exists) {
      await ref.update({'format': 'Digital', 'progress': 0});
    } else {
      await ref.set({
        'userId': userId,
        'bookId': bookId,
        'title': tituloNorm,
        'author': 'Autor del club',
        'shelf': 'Leyendo',
        'progress': 0,
        'format': 'Digital',
        'totalPages': totalPaginas,
        'currentPage': 0,
        'dateStarted': FieldValue.serverTimestamp(),
        'rating': 0,
        'notes': '',
        'dateFinished': null,
      });
      await _db.collection('users').doc(userId).update({
        'stats.inProgress': FieldValue.increment(1),
      });
    }
  }

  static String _obtenerCampoStats(String estanteria) {
    if (estanteria == 'Leído') return "stats.read";
    if (estanteria == 'Leyendo') return "stats.inProgress";
    if (estanteria == 'Por leer') return "stats.toRead";
    return "";
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
}

// --- UTILIDADES DE TEXTO ---

/// Capitaliza solo la primera letra del título.
String capitalizarTitulo(String texto) {
  if (texto.isEmpty) return '';
  String limpio = texto.trim();
  return limpio[0].toUpperCase() + limpio.substring(1);
}

/// Capitaliza la primera letra de cada palabra del autor.
String capitalizarAutor(String texto) {
  if (texto.isEmpty) return '';
  return texto
      .split(' ')
      .map((palabra) {
        if (palabra.isEmpty) return palabra;
        return palabra[0].toUpperCase() + palabra.substring(1).toLowerCase();
      })
      .join(' ');
}
