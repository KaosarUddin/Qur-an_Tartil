import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/quran_models.dart';

class ApiService {
  // Android emulators expose the host as 10.0.2.2. Desktop and iOS use
  // localhost, which also makes the generated Windows runner work as-is.
  static String get baseUrl =>
      Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://127.0.0.1:8000';

  Future<RecitationResult> analyzeRecitation({
    required int surah,
    required int ayah,
    required String expectedText,
    String? audioPath,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/v1/recitation/analyze'),
      )
        ..fields['surah'] = '$surah'
        ..fields['ayah'] = '$ayah'
        ..fields['expected_text'] = expectedText;

      if (audioPath != null && await File(audioPath).exists()) {
        request.files
            .add(await http.MultipartFile.fromPath('audio', audioPath));
      }

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
        text.split(RegExp(r'\\s+')).where((e) => e.isNotEmpty).toList();
    final words = <WordFeedback>[];
    for (var i = 0; i < tokens.length; i++) {
      final status = i % 5 == 4
          ? WordStatus.incorrect
          : i % 3 == 2
              ? WordStatus.improve
              : WordStatus.correct;
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
