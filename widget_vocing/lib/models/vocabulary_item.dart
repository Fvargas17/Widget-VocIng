class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.word,
    required this.pronunciation,
    required this.description,
    required this.translation,
    required this.example,
  });

  final String id;
  final String word;
  final String pronunciation;
  final String description;
  final String translation;
  final String example;

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      id: json['id'] as String,
      word: json['word'] as String,
      pronunciation: json['pronunciation'] as String,
      description: json['description'] as String,
      translation: json['translation'] as String,
      example: json['example'] as String,
    );
  }
}
