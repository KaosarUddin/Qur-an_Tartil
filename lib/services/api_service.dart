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
    if (audioPath == null || audioPath.isEmpty) {
      throw const RecitationAnalysisException(
        'Record the selected Ayah before requesting analysis.',
      );
    }

    final endpoint = baseUrl;
    if (endpoint == null) {
      throw const RecitationAnalysisException(
        'The real recitation analyzer is not connected. Use the Windows app '
        'with the local backend, or configure RECITATION_API_URL for the web app.',
      );
    }

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
}
