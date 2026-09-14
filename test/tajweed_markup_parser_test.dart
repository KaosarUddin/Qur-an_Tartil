import 'package:flutter_test/flutter_test.dart';
import 'package:quran_tutor_mvp/models/tajweed_models.dart';

void main() {
  test('parses Tajweed tags and removes the duplicated ayah end marker', () {
    const markup = 'بِسْمِ <tajweed class=ham_wasl>ٱ</tajweed>للَّهِ '
        '<tajweed class=madda_normal>ـٰ</tajweed>'
        '<span class=end>١</span>';

    final segments = TajweedMarkupParser.parse(markup);

    expect(segments.map((segment) => segment.text).join(), 'بِسْمِ ٱللَّهِ ـٰ');
    expect(
      segments.where((segment) => segment.rule == 'ham_wasl').single.text,
      'ٱ',
    );
    expect(
      segments.where((segment) => segment.rule == 'madda_normal').single.text,
      'ـٰ',
    );
  });

  test('decodes safe text entities', () {
    final segments = TajweedMarkupParser.parse('A &amp; B');
    expect(segments.single.text, 'A & B');
  });
}
