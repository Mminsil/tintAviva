import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String photoURL;
  final DateTime? registrationDate;
  final List<String> myClubs;
  // Estadísticas que se ven en tu captura
  final int inProgress;
  final int read;
  final int toRead;

  UserModel({
    required this.uid,
    required this.email,
    required this.name,
    required this.photoURL,
    this.registrationDate,
    required this.myClubs,
    this.inProgress = 0,
    this.read = 0,
    this.toRead = 0,
  });

  // El famoso fromMap que te sugería VSC
  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    // Extraemos el mapa interno de 'stats' de tu captura
    final stats = data['stats'] as Map<String, dynamic>? ?? {};

    return UserModel(
      uid: documentId,
      email: data['email'] ?? '',
      name: data['name'] ?? 'Usuario',
      photoURL: data['photoURL'] ?? 'assets/avatares/ava1.png',
      // Convertimos el Timestamp de Firebase a DateTime de Dart
      registrationDate: (data['registrationDate'] as Timestamp?)?.toDate(),
      myClubs: List<String>.from(data['my_clubs'] ?? []),
      inProgress: stats['inProgress'] ?? 0,
      read: stats['read'] ?? 0,
      toRead: stats['toRead'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'photoURL': photoURL,
      'registrationDate': registrationDate != null ? Timestamp.fromDate(registrationDate!) : null,
      'my_clubs': myClubs,
      'stats': {
        'inProgress': inProgress,
        'read': read,
        'toRead': toRead,
      },
    };
  }
}