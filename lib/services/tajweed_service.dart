import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

class TajweedService {
  static final sourceHomepage = Uri.parse('https://quran.foundation');
  static final _endpoint = Uri.parse(
    'https://api.quran.com/api/v4/quran/verses/uthmani_tajweed',
  );
  static final RegExp _endMarker = RegExp(
    r'<span class=end>.*?</span>',
    dotAll: true,
  );

  final http.Client _client;
  final Map<int, Future<Map<int, String>>> _surahCache = {};
  Future<String>? _basmala;

  TajweedService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<int, String>> loadSurah({
    required int surah,
    required int expectedAyahCount,
  }) {
    if (surah < 1 || surah > 114) {
      throw RangeError.range(surah, 1, 114, 'surah');
    }
    return _surahCache.putIfAbsent(
      surah,
      () => _loadSurah(surah, expectedAyahCount),
    );
  }

  Future<Map<int, String>> _loadSurah(
    int surah,
    int expectedAyahCount,
  ) async {
    final verses = await _request({'chapter_number': '$surah'});
    if (verses.length != expectedAyahCount) {
      throw FormatException(
        'Expected $expectedAyahCount Tajweed ayahs for surah $surah, '
        'but received ${verses.length}.',
      );
    }

    final annotations = <int, String>{};
    for (final verse in verses) {
      final verseKey = verse['verse_key'] as String? ?? '';
      final keyParts = verseKey.split(':');
      final ayahNumber =
          keyParts.length == 2 ? int.tryParse(keyParts[1]) : null;
      final markup = verse['text_uthmani_tajweed'] as String?;
      if (ayahNumber == null || markup == null || markup.isEmpty) {
        throw const FormatException('Invalid Tajweed verse data.');
      }
      annotations[ayahNumber] = markup;
    }

    for (var ayah = 1; ayah <= expectedAyahCount; ayah++) {
      if (!annotations.containsKey(ayah)) {
        throw FormatException(
            'Tajweed data is missing surah $surah, ayah $ayah.');
      }
    }

    if (surah != 1 && surah != 9) {
      final basmala = await (_basmala ??= _loadBasmala());
      annotations[1] = '$basmala ${annotations[1]}';
    }
    return UnmodifiableMapView(annotations);
  }

  Future<String> _loadBasmala() async {
    final verses = await _request({'verse_key': '1:1'});
    if (verses.length != 1) {
      throw const FormatException('Could not load the Tajweed basmala.');
    }
    final markup = verses.single['text_uthmani_tajweed'] as String?;
    if (markup == null || markup.isEmpty) {
      throw const FormatException('The Tajweed basmala is empty.');
    }
    return markup.replaceAll(_endMarker, '').trim();
  }

  Future<List<Map<String, dynamic>>> _request(
    Map<String, String> queryParameters,
  ) async {
    final uri = _endpoint.replace(queryParameters: queryParameters);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Tajweed request failed with HTTP ${response.statusCode}.',
        uri,
      );
    }

    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic> || payload['verses'] is! List) {
      throw const FormatException('Unexpected Tajweed response format.');
    }
    return (payload['verses'] as List)
        .map((verse) => Map<String, dynamic>.from(verse as Map))
        .toList(growable: false);
  }

  void dispose() => _client.close();
}
