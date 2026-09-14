import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_tutor_mvp/services/quran_script_service.dart';

void main() {
  test('loads Tajweed ayahs without merging in the basmala', () async {
    final client = MockClient((request) async {
      if (request.url.queryParameters['verse_key'] == '1:1') {
        return _jsonResponse([
          {
            'verse_key': '1:1',
            'text_uthmani_tajweed':
                'بِسْمِ <tajweed class=ham_wasl>ٱ</tajweed>للَّهِ '
                    '<span class=end>١</span>',
          },
        ]);
      }
      expect(request.url.path, endsWith('/uthmani_tajweed'));
      expect(request.url.queryParameters['chapter_number'], '2');
      return _jsonResponse([
        {
          'verse_key': '2:1',
          'text_uthmani_tajweed':
              '<tajweed class=madda_necessary>الٓمٓ</tajweed> '
                  '<span class=end>١</span>',
        },
      ]);
    });
    final service = QuranScriptService(client: client);

    final result = await service.loadSurah(
      script: QuranOnlineScript.tajweed,
      surah: 2,
      expectedAyahCount: 1,
    );

    expect(result[1], isNot(startsWith('بِسْمِ')));
    expect(result[1], contains('class=madda_necessary'));
    service.dispose();
  });

  test('loads Indo-Pak ayahs without merging in the basmala', () async {
    final client = MockClient((request) async {
      if (request.url.queryParameters['verse_key'] == '1:1') {
        return _jsonResponse([
          {
            'verse_key': '1:1',
            'text_indopak': 'بِسۡمِ اللهِ الرَّحۡمٰنِ الرَّحِيۡمِ',
          },
        ]);
      }
      expect(request.url.path, endsWith('/indopak'));
      return _jsonResponse([
        {'verse_key': '2:1', 'text_indopak': 'الٓمّٓۚ'},
      ]);
    });
    final service = QuranScriptService(client: client);

    final result = await service.loadSurah(
      script: QuranOnlineScript.indoPak,
      surah: 2,
      expectedAyahCount: 1,
    );

    expect(result[1], 'الٓمّٓۚ');
    service.dispose();
  });

  test('loads each script-specific basmala separately', () async {
    final client = MockClient((request) async {
      expect(request.url.queryParameters['verse_key'], '1:1');
      if (request.url.path.endsWith('/uthmani_tajweed')) {
        return _jsonResponse([
          {
            'verse_key': '1:1',
            'text_uthmani_tajweed':
                'بِسْمِ <tajweed class=ham_wasl>ٱ</tajweed>للَّهِ '
                    '<span class=end>١</span>',
          },
        ]);
      }
      return _jsonResponse([
        {
          'verse_key': '1:1',
          'text_indopak': 'بِسۡمِ اللهِ الرَّحۡمٰنِ الرَّحِيۡمِ',
        },
      ]);
    });
    final service = QuranScriptService(client: client);

    final tajweed = await service.loadBasmala(QuranOnlineScript.tajweed);
    final indoPak = await service.loadBasmala(QuranOnlineScript.indoPak);

    expect(tajweed, isNot(contains('class=end')));
    expect(tajweed, isNot(contains('<span')));
    expect(indoPak, 'بِسۡمِ اللهِ الرَّحۡمٰنِ الرَّحِيۡمِ');
    service.dispose();
  });

  test('does not prepend a basmala to At-Tawbah', () async {
    final service = QuranScriptService(
      client: MockClient(
        (_) async => _jsonResponse([
          {'verse_key': '9:1', 'text_indopak': 'بَرَآءَةٌ'},
        ]),
      ),
    );

    final result = await service.loadSurah(
      script: QuranOnlineScript.indoPak,
      surah: 9,
      expectedAyahCount: 1,
    );

    expect(result[1], 'بَرَآءَةٌ');
    service.dispose();
  });

  test('rejects incomplete online script data', () async {
    final service = QuranScriptService(
      client: MockClient((_) async => _jsonResponse(const [])),
    );

    await expectLater(
      service.loadSurah(
        script: QuranOnlineScript.tajweed,
        surah: 1,
        expectedAyahCount: 7,
      ),
      throwsA(isA<FormatException>()),
    );
    service.dispose();
  });
}

http.Response _jsonResponse(List<Map<String, String>> verses) => http.Response(
      jsonEncode({'verses': verses, 'meta': const {}}),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
