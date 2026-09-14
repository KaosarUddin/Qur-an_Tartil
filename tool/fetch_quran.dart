import 'dart:convert';
import 'dart:io';

const _expectedAyahCount = 6236;
const _basmala = 'بِسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';
const _basmalaWithIdgham = 'بِّسْمِ ٱللَّهِ ٱلرَّحْمَـٰنِ ٱلرَّحِيمِ';

final _quranUri = Uri.https(
  'tanzil.net',
  '/pub/download/index.php',
  {
    'quranType': 'uthmani',
    'outType': 'txt-2',
    'marks': 'true',
    'sajdah': 'true',
    'tatweel': 'true',
    'agree': 'true',
  },
);

final _metadataUri =
    Uri.parse('https://tanzil.net/res/text/metadata/quran-data.xml');

Future<void> main() async {
  final outputDirectory = Directory('assets/quran');
  await outputDirectory.create(recursive: true);

  final quranBytes = await _download(_quranUri);
  _validateQuranText(utf8.decode(quranBytes));
  await File('${outputDirectory.path}/quran-uthmani.txt')
      .writeAsBytes(quranBytes, flush: true);

  final metadataBytes = await _download(_metadataUri);
  _validateMetadata(utf8.decode(metadataBytes));
  await File('${outputDirectory.path}/quran-data.xml')
      .writeAsBytes(metadataBytes, flush: true);

  stdout.writeln(
    'Downloaded and validated $_expectedAyahCount ayahs across 114 surahs.',
  );
}

Future<List<int>> _download(Uri uri) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(uri);
    request.headers
        .set(HttpHeaders.userAgentHeader, 'Quran-Tartil data fetcher');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Download failed with HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    return await response.fold<List<int>>(<int>[], (bytes, chunk) {
      bytes.addAll(chunk);
      return bytes;
    });
  } finally {
    client.close();
  }
}

void _validateQuranText(String content) {
  final ayahs = <(int, int, String)>[];
  for (final line in const LineSplitter().convert(content)) {
    if (line.isEmpty || line.startsWith('#')) continue;
    final parts = line.split('|');
    if (parts.length < 3) {
      throw const FormatException('Unexpected Quran text line format.');
    }
    ayahs.add((
      int.parse(parts[0]),
      int.parse(parts[1]),
      parts.sublist(2).join('|'),
    ));
  }

  if (ayahs.length != _expectedAyahCount) {
    throw FormatException(
      'Expected $_expectedAyahCount ayahs, found ${ayahs.length}.',
    );
  }
  if (ayahs.map((ayah) => ayah.$1).toSet().length != 114) {
    throw const FormatException('Expected exactly 114 surahs.');
  }

  for (var surah = 1; surah <= 114; surah++) {
    final firstAyah = ayahs.firstWhere(
      (ayah) => ayah.$1 == surah && ayah.$2 == 1,
    );
    final hasBasmala = firstAyah.$3.startsWith(_basmala) ||
        firstAyah.$3.startsWith(_basmalaWithIdgham);
    if (surah == 9 ? hasBasmala : !hasBasmala) {
      throw FormatException(
        'Unexpected basmala format for surah $surah: ${firstAyah.$3}',
      );
    }
  }

  final anNaml30 = ayahs.firstWhere(
    (ayah) => ayah.$1 == 27 && ayah.$2 == 30,
  );
  if (!anNaml30.$3.contains(_basmala)) {
    throw const FormatException('The basmala in An-Naml 27:30 is missing.');
  }
  if (!content
      .contains('PLEASE DO NOT REMOVE OR CHANGE THIS COPYRIGHT BLOCK')) {
    throw const FormatException('Tanzil copyright notice is missing.');
  }
}

void _validateMetadata(String content) {
  final surahCount = RegExp(r'<sura\s').allMatches(content).length;
  if (surahCount != 114) {
    throw FormatException('Expected 114 metadata entries, found $surahCount.');
  }
}
