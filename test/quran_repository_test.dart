import 'package:flutter_test/flutter_test.dart';
import 'package:quran_tutor_mvp/data/quran_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads the complete verified Quran dataset', () async {
    final surahs = await QuranRepository.load();

    expect(surahs, hasLength(114));
    expect(
      surahs.fold<int>(0, (total, surah) => total + surah.ayahs.length),
      6236,
    );
    expect(surahs.first.ayahs, hasLength(7));
    expect(surahs.last.ayahs, hasLength(6));
  });

  test('separates each opening basmala without changing ayah numbering',
      () async {
    final surahs = await QuranRepository.load();
    final basmalaOpening = RegExp(r'ب[ِّ]+سْمِ');

    for (final surah in surahs) {
      final firstAyah = surah.ayahs.first.arabic;
      if (surah.number == 1) {
        expect(surah.basmala, isNull);
        expect(firstAyah, contains(basmalaOpening));
      } else if (surah.number == 9) {
        expect(surah.basmala, isNull);
        expect(firstAyah, isNot(contains(basmalaOpening)));
      } else {
        expect(surah.basmala, contains(basmalaOpening));
        expect(firstAyah, isNot(contains(basmalaOpening)));
        expect(firstAyah, isNotEmpty);
      }
    }

    expect(surahs[1].ayahs.first.arabic, 'الٓمٓ');
    expect(surahs[26].ayahs[29].arabic, contains(basmalaOpening));
  });
}
