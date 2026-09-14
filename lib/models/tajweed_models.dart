class TajweedSegment {
  final String text;
  final String? rule;

  const TajweedSegment({required this.text, this.rule});
}

class TajweedMarkupParser {
  static final RegExp _annotationPattern = RegExp(
    r'<tajweed class=([^ >]+)>(.*?)</tajweed>|<span class=end>.*?</span>',
    dotAll: true,
  );

  static List<TajweedSegment> parse(String markup) {
    final segments = <TajweedSegment>[];
    var cursor = 0;

    for (final match in _annotationPattern.allMatches(markup)) {
      if (match.start > cursor) {
        _addSegment(segments, markup.substring(cursor, match.start));
      }

      final rule = match.group(1);
      final annotatedText = match.group(2);
      if (rule != null && annotatedText != null) {
        _addSegment(segments, annotatedText, rule);
      }
      cursor = match.end;
    }

    if (cursor < markup.length) {
      _addSegment(segments, markup.substring(cursor));
    }
    return List<TajweedSegment>.unmodifiable(segments);
  }

  static void _addSegment(
    List<TajweedSegment> segments,
    String text, [
    String? rule,
  ]) {
    if (text.isEmpty) return;
    segments.add(TajweedSegment(text: _decodeEntities(text), rule: rule));
  }

  static String _decodeEntities(String value) => value
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}
