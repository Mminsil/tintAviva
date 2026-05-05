class BookModel {
  final String id;
  final String title;
  final String author;
  final String? genre;
  final int? pages;
  final String? coverUrl;
  final String? synopsis;
  final String? isbn;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    this.genre,
    this.pages,
    this.coverUrl,
    this.synopsis,
    this.isbn,
  });
  
      
  factory BookModel.fromMap(Map<String, dynamic> data, String documentId) {
    return BookModel(
      id: documentId,
      title: data['title'] ?? 'Sin título',
      author: data['author'] ?? 'Autor desconocido',
      genre: data['genre'],
      pages: data['pages'] is int
          ? data['pages']
          : int.tryParse(data['pages']?.toString() ?? ''),
      synopsis: data['synopsis'],
      coverUrl: data['coverUrl'],
      isbn: data['isbn'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'author': author,
      if (genre != null) 'genre': genre,
      if (pages != null) 'pages': pages,
      if (coverUrl != null) 'coverUrl': coverUrl,
      if (synopsis != null) 'synopsis': synopsis,
      if (isbn != null) 'isbn': isbn,
    };
  }
}
