import 'package:flutter_test/flutter_test.dart';
import 'package:quran_tutor_mvp/services/quran_audio_service.dart';

void main() {
  test('builds the standard Mishary Alafasy ayah URL', () {
    final tracks = QuranAudioService.referenceQueue(surah: 27, ayah: 30);

    expect(tracks, hasLength(1));
    expect(
      tracks.single.toString(),
      'https://everyayah.com/data/Alafasy_128kbps/027030.mp3',
    );
  });

  test('queues the basmala before a first ayah that includes it', () {
    final tracks = QuranAudioService.referenceQueue(surah: 2, ayah: 1);

    expect(
      tracks.map((track) => track.toString()),
      [
        'https://everyayah.com/data/Alafasy_128kbps/002000.mp3',
        'https://everyayah.com/data/Alafasy_128kbps/002001.mp3',
      ],
    );
  });

  test('does not queue a basmala for At-Tawbah', () {
    final tracks = QuranAudioService.referenceQueue(surah: 9, ayah: 1);

    expect(tracks, hasLength(1));
    expect(tracks.single.toString(), endsWith('/009001.mp3'));
  });
}
