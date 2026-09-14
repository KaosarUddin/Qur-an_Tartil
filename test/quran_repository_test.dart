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

  test('preserves Tanzil basmala conventions', () async {
    final surahs = await QuranRepository.load();
    final basmalaOpening = RegExp(r'ب[ِّ]+سْمِ');

    for (final surah in surahs) {
      final firstAyah = surah.ayahs.first.arabic;
      if (surah.number == 9) {
        expect(firstAyah, isNot(contains(basmalaOpening)));
      } else {
        expect(firstAyah, contains(basmalaOpening));
      }
    }

    expect(surahs[26].ayahs[29].arabic, contains(basmalaOpening));
  });
}
