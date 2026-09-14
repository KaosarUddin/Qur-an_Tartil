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

  test('maps verified Tajweed rules onto exact Indo-Pak text', () {
    const tajweed = 'ذ<tajweed class=madda_normal>َٲ</tajweed>لِكَ '
        '<tajweed class=ham_wasl>ٱ</tajweed>لْكِتَ'
        '<tajweed class=madda_normal>ـٰ</tajweed>بُ لَا رَيْبَ‌ۛ فِيهِ‌ۛ '
        'هُ<tajweed class=idgham_wo_ghunnah>دًى ل</tajweed>ِّلْمُتَّقِ'
        '<tajweed class=madda_permissible>ي</tajweed>نَ '
        '<span class=end>٢</span>';
    const indoPak =
        'ذٰلِكَ الۡڪِتٰبُ لَا رَيۡبَۛۚۖ فِيۡهِۛۚ هُدًى لِّلۡمُتَّقِيۡنَۙ‏';

    final segments = IndoPakTajweedMapper.map(
      indoPakText: indoPak,
      uthmaniMarkup: tajweed,
    );

    expect(segments.map((segment) => segment.text).join(), indoPak);
    expect(
      segments
          .where((segment) => segment.rule == 'madda_normal')
          .map((segment) => segment.text)
          .join(),
      contains('ذٰ'),
    );
    expect(
      segments.any((segment) => segment.rule == 'idgham_wo_ghunnah'),
      isTrue,
    );
    expect(
      segments.any((segment) => segment.rule == 'madda_permissible'),
      isTrue,
    );
  });

  test('leaves text plain when the two scripts do not align safely', () {
    final segments = IndoPakTajweedMapper.map(
      indoPakText: 'الرحمن',
      uthmaniMarkup: '<tajweed class=ghunnah>نص مختلف تماما</tajweed>',
    );

    expect(segments, hasLength(1));
    expect(segments.single.text, 'الرحمن');
    expect(segments.single.rule, isNull);
  });
}
