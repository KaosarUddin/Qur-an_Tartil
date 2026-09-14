class Ayah {
  final int number;
  final String arabic;
  final String translation;

  const Ayah({
    required this.number,
    required this.arabic,
    this.translation = '',
  });
}

class Surah {
  final int number;
  final String nameEnglish;
  final String nameArabic;
  final String revelation;
  final String? basmala;
  final List<Ayah> ayahs;

  const Surah({
    required this.number,
    required this.nameEnglish,
    required this.nameArabic,
    required this.revelation,
    this.basmala,
    required this.ayahs,
  });
}

enum WordStatus { correct, improve, incorrect }

class WordFeedback {
  final String word;
  final WordStatus status;
  final double score;
  final String tip;

  const WordFeedback({
    required this.word,
    required this.status,
    required this.score,
    required this.tip,
  });

  factory WordFeedback.fromJson(Map<String, dynamic> json) {
    final raw = json['status'] as String? ?? 'improve';
    return WordFeedback(
      word: json['word'] as String? ?? '',
      status: switch (raw) {
        'correct' => WordStatus.correct,
        'incorrect' => WordStatus.incorrect,
        _ => WordStatus.improve,
      },
      score: (json['score'] as num? ?? 0).toDouble(),
      tip: json['tip'] as String? ?? '',
    );
  }
}

class RecitationResult {
  final double overallScore;
  final List<WordFeedback> words;
  final String engine;

  const RecitationResult({
    required this.overallScore,
    required this.words,
    required this.engine,
  });

  bool get isDemo => engine == 'local-demo' || engine.startsWith('mock');

  factory RecitationResult.fromJson(Map<String, dynamic> json) =>
      RecitationResult(
        overallScore: (json['overall_score'] as num? ?? 0).toDouble(),
        words: ((json['words'] as List?) ?? const [])
            .map((e) =>
                WordFeedback.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        engine: json['engine'] as String? ?? 'unknown',
      );
}
