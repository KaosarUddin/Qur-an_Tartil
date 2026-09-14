class QuranAudioService {
  static const reciterName = 'Mishary Rashid Alafasy';
  static const sourceName = 'Verse By Verse Quran Project';
  static final sourceHomepage = Uri.parse('https://everyayah.com');

  static List<Uri> referenceQueue({
    required int surah,
    required int ayah,
  }) {
    if (surah < 1 || surah > 114 || ayah < 1) {
      throw RangeError('Invalid Quran reference $surah:$ayah');
    }

    return List<Uri>.unmodifiable([_audioUri(surah, ayah)]);
  }

  static Uri _audioUri(int surah, int ayah) {
    final chapter = surah.toString().padLeft(3, '0');
    final verse = ayah.toString().padLeft(3, '0');
    return Uri.parse(
      'https://everyayah.com/data/Alafasy_128kbps/$chapter$verse.mp3',
    );
  }
}
