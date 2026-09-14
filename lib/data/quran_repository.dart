import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/quran_models.dart';

class QuranRepository {
  static const _quranAsset = 'assets/quran/quran-uthmani.txt';
  static const _metadataAsset = 'assets/quran/quran-data.xml';
  static const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
  static const _basmalaWithIdgham = 'بِّسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

  static Future<List<Surah>>? _cachedQuran;

  static Future<List<Surah>> load() => _cachedQuran ??= _load();

  static Future<List<Surah>> _load() async {
    final results = await Future.wait([
      rootBundle.loadString(_quranAsset),
      rootBundle.loadString(_metadataAsset),
    ]);
    final metadata = _parseMetadata(results[1]);
    final ayahsBySurah = <int, List<Ayah>>{};

    for (final rawLine in const LineSplitter().convert(results[0])) {
      final line = rawLine.replaceFirst('\ufeff', '');
      if (line.isEmpty || line.startsWith('#')) continue;

      final parts = line.split('|');
      if (parts.length < 3) {
        throw const FormatException('Unexpected Quran text line format.');
      }
      final surahNumber = int.parse(parts[0]);
      final ayahNumber = int.parse(parts[1]);
      final arabic = parts.sublist(2).join('|');
      ayahsBySurah.putIfAbsent(surahNumber, () => <Ayah>[]).add(
            Ayah(number: ayahNumber, arabic: arabic),
          );
    }

    if (metadata.length != 114 || ayahsBySurah.length != 114) {
      throw const FormatException('The Quran dataset must contain 114 surahs.');
    }

    return List<Surah>.unmodifiable(metadata.map((entry) {
      final sourceAyahs = ayahsBySurah[entry.number] ?? const <Ayah>[];
      if (sourceAyahs.length != entry.ayahCount) {
        throw FormatException(
          'Surah ${entry.number} expected ${entry.ayahCount} ayahs, '
          'but found ${sourceAyahs.length}.',
        );
      }
      String? basmala;
      var ayahs = sourceAyahs;
      if (entry.number != 1 && entry.number != 9) {
        final first = sourceAyahs.first;
        basmala = first.arabic.startsWith(_basmalaWithIdgham)
            ? _basmalaWithIdgham
            : first.arabic.startsWith(_basmala)
                ? _basmala
                : null;
        if (basmala == null) {
          throw FormatException(
            'Surah ${entry.number} does not start with the expected basmala.',
          );
        }
        ayahs = [
          Ayah(
            number: first.number,
            arabic: first.arabic.substring(basmala.length).trimLeft(),
            translation: first.translation,
          ),
          ...sourceAyahs.skip(1),
        ];
      }
      return Surah(
        number: entry.number,
        nameEnglish: entry.transliteratedName,
        nameArabic: entry.arabicName,
        revelation: '${entry.revelationType} • ${ayahs.length} Ayahs',
        basmala: basmala,
        ayahs: List<Ayah>.unmodifiable(ayahs),
      );
    }));
  }

  static List<_SurahMetadata> _parseMetadata(String xml) {
    final entries = <_SurahMetadata>[];
    final surahPattern = RegExp(r'<sura\s+([^>]+?)\s*/>');
    final attributePattern = RegExp(r'''(\w+)="([^"]*)"''');

    for (final match in surahPattern.allMatches(xml)) {
      final attributes = <String, String>{};
      for (final attribute in attributePattern.allMatches(match.group(1)!)) {
        attributes[attribute.group(1)!] = _decodeXml(attribute.group(2)!);
      }
      entries.add(
        _SurahMetadata(
          number: int.parse(attributes['index']!),
          ayahCount: int.parse(attributes['ayas']!),
          arabicName: attributes['name']!,
          transliteratedName: attributes['tname']!,
          revelationType: attributes['type']!,
        ),
      );
    }
    return entries;
  }

  static String _decodeXml(String value) => value
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

class _SurahMetadata {
  final int number;
  final int ayahCount;
  final String arabicName;
  final String transliteratedName;
  final String revelationType;

  const _SurahMetadata({
    required this.number,
    required this.ayahCount,
    required this.arabicName,
    required this.transliteratedName,
    required this.revelationType,
  });
}
