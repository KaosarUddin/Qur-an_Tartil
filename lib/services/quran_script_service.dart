import 'dart:collection';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum QuranOnlineScript { tajweed, indoPak }

extension QuranOnlineScriptDetails on QuranOnlineScript {
  String get endpointName => switch (this) {
        QuranOnlineScript.tajweed => 'uthmani_tajweed',
        QuranOnlineScript.indoPak => 'indopak',
      };

  String get responseField => switch (this) {
        QuranOnlineScript.tajweed => 'text_uthmani_tajweed',
        QuranOnlineScript.indoPak => 'text_indopak',
      };
}

class QuranScriptService {
  static final sourceHomepage = Uri.parse('https://quran.foundation');
  static const _endpointRoot = 'https://api.quran.com/api/v4/quran/verses';
  static final RegExp _endMarker = RegExp(
    r'<span class=end>.*?</span>',
    dotAll: true,
  );

  final http.Client _client;
  final Map<(QuranOnlineScript, int), Future<Map<int, String>>> _surahCache =
      {};
  final Map<QuranOnlineScript, Future<String>> _basmalaCache = {};

  QuranScriptService({http.Client? client}) : _client = client ?? http.Client();

  Future<Map<int, String>> loadSurah({
    required QuranOnlineScript script,
    required int surah,
    required int expectedAyahCount,
  }) {
    if (surah < 1 || surah > 114) {
      throw RangeError.range(surah, 1, 114, 'surah');
    }
    return _surahCache.putIfAbsent(
      (script, surah),
      () => _loadSurah(script, surah, expectedAyahCount),
    );
  }

  Future<Map<int, String>> _loadSurah(
    QuranOnlineScript script,
    int surah,
    int expectedAyahCount,
  ) async {
    final verses = await _request(
      script,
      {'chapter_number': '$surah'},
    );
    if (verses.length != expectedAyahCount) {
      throw FormatException(
        'Expected $expectedAyahCount ${script.endpointName} ayahs for '
        'surah $surah, but received ${verses.length}.',
      );
    }

    final textByAyah = <int, String>{};
    for (final verse in verses) {
      final verseKey = verse['verse_key'] as String? ?? '';
      final keyParts = verseKey.split(':');
      final ayahNumber =
          keyParts.length == 2 ? int.tryParse(keyParts[1]) : null;
      final text = verse[script.responseField] as String?;
      if (ayahNumber == null || text == null || text.isEmpty) {
        throw FormatException('Invalid ${script.endpointName} verse data.');
      }
      textByAyah[ayahNumber] = text;
    }

    for (var ayah = 1; ayah <= expectedAyahCount; ayah++) {
      if (!textByAyah.containsKey(ayah)) {
        throw FormatException(
          '${script.endpointName} data is missing surah $surah, ayah $ayah.',
        );
      }
    }

    return UnmodifiableMapView(textByAyah);
  }

  Future<String> loadBasmala(QuranOnlineScript script) =>
      _basmalaCache.putIfAbsent(script, () => _loadBasmala(script));

  Future<String> _loadBasmala(QuranOnlineScript script) async {
    final verses = await _request(script, {'verse_key': '1:1'});
    if (verses.length != 1) {
      throw FormatException(
        'Could not load the ${script.endpointName} basmala.',
      );
    }
    final text = verses.single[script.responseField] as String?;
    if (text == null || text.isEmpty) {
      throw FormatException('The ${script.endpointName} basmala is empty.');
    }
    return script == QuranOnlineScript.tajweed
        ? text.replaceAll(_endMarker, '').trim()
        : text.trim();
  }

  Future<List<Map<String, dynamic>>> _request(
    QuranOnlineScript script,
    Map<String, String> queryParameters,
  ) async {
    final uri = Uri.parse('$_endpointRoot/${script.endpointName}')
        .replace(queryParameters: queryParameters);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw http.ClientException(
        '${script.endpointName} request failed with HTTP '
        '${response.statusCode}.',
        uri,
      );
    }

    final payload = jsonDecode(utf8.decode(response.bodyBytes));
    if (payload is! Map<String, dynamic> || payload['verses'] is! List) {
      throw FormatException(
        'Unexpected ${script.endpointName} response format.',
      );
    }
    return (payload['verses'] as List)
        .map((verse) => Map<String, dynamic>.from(verse as Map))
        .toList(growable: false);
  }

  void dispose() => _client.close();
}
