class VocabularyItem {
  const VocabularyItem({
    required this.word,
    required this.description,
    required this.translation,
    required this.example,
  });

  final String word;
  final String description;
  final String translation;
  final String example;

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      word: json['word'] as String,
      description: json['description'] as String,
      translation: json['translation'] as String,
      example: json['example'] as String,
    );
  }
}
