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

enum FeedbackIssueType {
  missingWord,
  missingLetter,
  extraLetter,
  pronunciation,
  tajweed,
  other,
}

class FeedbackIssue {
  final FeedbackIssueType type;
  final String title;
  final String detail;
  final String? expected;
  final String? observed;
  final String? rule;
  final String suggestion;

  const FeedbackIssue({
    required this.type,
    required this.title,
    required this.detail,
    this.expected,
    this.observed,
    this.rule,
    required this.suggestion,
  });

  factory FeedbackIssue.fromJson(Map<String, dynamic> json) => FeedbackIssue(
        type: switch (json['type'] as String?) {
          'missing_word' => FeedbackIssueType.missingWord,
          'missing_letter' => FeedbackIssueType.missingLetter,
          'extra_letter' => FeedbackIssueType.extraLetter,
          'pronunciation' => FeedbackIssueType.pronunciation,
          'tajweed' => FeedbackIssueType.tajweed,
          _ => FeedbackIssueType.other,
        },
        title: json['title'] as String? ?? 'Needs attention',
        detail: json['detail'] as String? ?? '',
        expected: json['expected'] as String?,
        observed: json['observed'] as String?,
        rule: json['rule'] as String?,
        suggestion: json['suggestion'] as String? ?? '',
      );
}

class WordFeedback {
  final String word;
  final WordStatus status;
  final double score;
  final String tip;
  final String? observed;
  final List<FeedbackIssue> issues;
  final List<String> rules;

  const WordFeedback({
    required this.word,
    required this.status,
    required this.score,
    required this.tip,
    this.observed,
    this.issues = const [],
    this.rules = const [],
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
      observed: json['observed'] as String?,
      issues: ((json['issues'] as List?) ?? const [])
          .map((e) =>
              FeedbackIssue.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(growable: false),
      rules: ((json['rules'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
    );
  }
}

class RecitationResult {
  final double overallScore;
  final List<WordFeedback> words;
  final String engine;
  final String? transcript;
  final List<String> extraWords;
  final String? assessmentNotice;

  const RecitationResult({
    required this.overallScore,
    required this.words,
    required this.engine,
    this.transcript,
    this.extraWords = const [],
    this.assessmentNotice,
  });

  bool get isDemo => engine == 'local-demo' || engine.startsWith('mock');
  bool get isExperimental => engine.contains('experimental');

  factory RecitationResult.fromJson(Map<String, dynamic> json) =>
      RecitationResult(
        overallScore: (json['overall_score'] as num? ?? 0).toDouble(),
        words: ((json['words'] as List?) ?? const [])
            .map((e) =>
                WordFeedback.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        engine: json['engine'] as String? ?? 'unknown',
        transcript: json['transcript'] as String?,
        extraWords: ((json['extra_words'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        assessmentNotice: json['assessment_notice'] as String?,
      );
}
