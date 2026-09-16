import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/quran_models.dart';
import 'api_platform.dart';

class RecitationAnalysisException implements Exception {
  final String message;

  const RecitationAnalysisException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static String? get baseUrl => recitationApiBaseUrl;

  Future<RecitationResult> analyzeRecitation({
    required int surah,
    required int ayah,
    required String expectedText,
    String? tajweedMarkup,
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
      if (tajweedMarkup != null && tajweedMarkup.isNotEmpty) {
        request.fields['tajweed_markup'] = tajweedMarkup;
      }

      await attachRecordedAudio(request, audioPath);

      final streamed = await request.send().timeout(const Duration(minutes: 3));
      final body = await streamed.stream.bytesToString();
      if (streamed.statusCode >= 200 && streamed.statusCode < 300) {
        return RecitationResult.fromJson(
            jsonDecode(body) as Map<String, dynamic>);
      }
      final payload = jsonDecode(body);
      final detail = payload is Map ? payload['detail'] : null;
      throw RecitationAnalysisException(
        detail?.toString() ??
            'Analysis failed with HTTP ${streamed.statusCode}.',
      );
    } on RecitationAnalysisException {
      rethrow;
    } catch (error) {
      throw RecitationAnalysisException(
        'Could not reach the recitation server. Start the backend and try '
        'again. ($error)',
      );
    }
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
      assessmentNotice:
          'Demo only: connect a Quran ASR backend for recording-based feedback.',
    );
  }
}
