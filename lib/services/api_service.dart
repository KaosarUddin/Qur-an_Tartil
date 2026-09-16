import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quran_models.dart';
import 'api_platform.dart';

class ApiService {
  static String? get baseUrl => recitationApiBaseUrl;

  Future<RecitationResult> analyzeRecitation({
    required int surah,
    required int ayah,
    required String expectedText,
    String? audioPath,
  }) async {
    final endpoint = baseUrl;
    if (endpoint == null) return _localDemo(expectedText);

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$endpoint/v1/recitation/analyze'),
      )
        ..fields['surah'] = '$surah'
        ..fields['ayah'] = '$ayah'
        ..fields['expected_text'] = expectedText;

      await attachRecordedAudio(request, audioPath);

      final streamed =
          await request.send().timeout(const Duration(seconds: 10));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return RecitationResult.fromJson(
            jsonDecode(body) as Map<String, dynamic>);
      }
    } catch (_) {
      // Fall through to the local demo result so the MVP remains testable offline.
    }
    return _localDemo(expectedText);
  }

  RecitationResult _localDemo(String text) {
    final tokens =
        text.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final words = <WordFeedback>[];
    for (var i = 0; i < tokens.length; i++) {
      final status = i % 5 == 4
          ? WordStatus.incorrect
          : i % 3 == 2
              ? WordStatus.improve
              : WordStatus.correct;
      final issue = switch (status) {
        WordStatus.correct => null,
        WordStatus.improve when (i ~/ 3).isOdd => const FeedbackIssue(
            type: FeedbackIssueType.tajweed,
            title: 'Tajweed timing',
            detail: 'The timing or nasal quality may need attention.',
            rule: 'Madd / ghunnah',
            suggestion:
                'Compare the held sound with the reference and repeat slowly.',
          ),
        WordStatus.improve => const FeedbackIssue(
            type: FeedbackIssueType.pronunciation,
            title: 'Letter pronunciation',
            detail: 'A letter articulation point may need more clarity.',
            suggestion: 'Listen to the reference, then repeat the word slowly.',
          ),
        WordStatus.incorrect => const FeedbackIssue(
            type: FeedbackIssueType.missingLetter,
            title: 'Possible missing letter',
            detail: 'One part of the word did not align strongly enough.',
            suggestion: 'Recite slowly and make every written letter audible.',
          ),
      };
      words.add(WordFeedback(
        word: tokens[i],
        status: status,
        score: switch (status) {
          WordStatus.correct => .96,
          WordStatus.improve => .76,
          WordStatus.incorrect => .49,
        },
        tip: switch (status) {
          WordStatus.correct => 'Clear pronunciation.',
          WordStatus.improve =>
            'Repeat slowly and compare with the teacher audio.',
          WordStatus.incorrect =>
            'Retry this word; the pronunciation did not align closely enough.',
        },
        issues: issue == null ? const [] : [issue],
      ));
    }
    final avg = words.isEmpty
        ? 0.0
        : words.map((e) => e.score).reduce((a, b) => a + b) / words.length;
    return RecitationResult(
      overallScore: avg,
      words: words,
      engine: 'local-demo',
    );
  }
}
