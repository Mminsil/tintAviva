class ClubModel {
  final String id;
  final String name;
  final String description;
  final String currentBookId; // ID del libro que se está leyendo actualmente
  final String inviteCode; // Código único para unirse al club
  final int maxMembers; // Número máximo de miembros permitido
  final String ownerId; // ID del usuario que creó el club
  final Map<String, String> clubMembers; // Mapa de de IDs de usuarios a sus nombres para mostrar

  ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.currentBookId,
    required this.inviteCode,
    required this.maxMembers,
    required this.ownerId,
    required this.clubMembers,
  });

  factory ClubModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ClubModel(
      id: documentId,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      currentBookId: data['currentBookId'] ?? '',
      inviteCode: data['inviteCode'] ?? '',
      maxMembers: data['maxMembers'] ?? 0,
      ownerId: data['ownerId'] ?? '',
      clubMembers: Map<String, String>.from(data['clubMembers'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'currentBookId': currentBookId,
      'inviteCode': inviteCode,
      'maxMembers': maxMembers,
    };
  }
}