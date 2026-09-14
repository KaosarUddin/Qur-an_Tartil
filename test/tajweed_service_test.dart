import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quran_tutor_mvp/services/tajweed_service.dart';

void main() {
  test('loads a surah and prepends the annotated basmala where required',
      () async {
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
    final service = TajweedService(client: client);

    final result = await service.loadSurah(surah: 2, expectedAyahCount: 1);

    expect(result[1], startsWith('بِسْمِ'));
    expect(result[1], contains('class=madda_necessary'));
    service.dispose();
  });

  test('rejects incomplete Tajweed data', () async {
    final service = TajweedService(
      client: MockClient((_) async => _jsonResponse(const [])),
    );

    expect(
      service.loadSurah(surah: 1, expectedAyahCount: 7),
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
