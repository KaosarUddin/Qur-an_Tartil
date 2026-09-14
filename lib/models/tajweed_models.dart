import 'dart:typed_data';

class TajweedSegment {
  final String text;
  final String? rule;

  const TajweedSegment({required this.text, this.rule});
}

class IndoPakTajweedMapper {
  static List<TajweedSegment> map({
    required String indoPakText,
    required String uthmaniMarkup,
  }) {
    final sourceLetters = _sourceLetters(uthmaniMarkup);
    final target = _targetUnits(indoPakText);
    final targetLetters = target
        .where((unit) => unit.normalizedLetter != null)
        .map((unit) => unit.normalizedLetter!)
        .toList(growable: false);

    if (sourceLetters.isEmpty || targetLetters.isEmpty) {
      return [TajweedSegment(text: indoPakText)];
    }

    final sourceToTarget = _align(
      sourceLetters.map((letter) => letter.normalized).toList(growable: false),
      targetLetters,
    );
    final matched =
        sourceToTarget.where((targetIndex) => targetIndex != null).length;
    final shorterLength = sourceLetters.length < targetLetters.length
        ? sourceLetters.length
        : targetLetters.length;
    if (matched / shorterLength < 0.85) {
      return [TajweedSegment(text: indoPakText)];
    }

    final rulesByTargetLetter = <int, String>{};
    for (var sourceIndex = 0;
        sourceIndex < sourceLetters.length;
        sourceIndex++) {
      final targetIndex = sourceToTarget[sourceIndex];
      final rule = sourceLetters[sourceIndex].rule;
      if (targetIndex != null && rule != null) {
        rulesByTargetLetter.putIfAbsent(targetIndex, () => rule);
      }
    }

    final segments = <TajweedSegment>[];
    var targetLetterIndex = 0;
    for (final unit in target) {
      final rule = unit.normalizedLetter == null
          ? null
          : rulesByTargetLetter[targetLetterIndex++];
      if (segments.isNotEmpty && segments.last.rule == rule) {
        final previous = segments.removeLast();
        segments.add(
            TajweedSegment(text: '${previous.text}${unit.text}', rule: rule));
      } else {
        segments.add(TajweedSegment(text: unit.text, rule: rule));
      }
    }
    return List<TajweedSegment>.unmodifiable(segments);
  }

  static List<_SourceLetter> _sourceLetters(String markup) {
    final letters = <_SourceLetter>[];
    for (final segment in TajweedMarkupParser.parse(markup)) {
      for (final rune in segment.text.runes) {
        final normalized = _normalizeLetter(rune);
        if (normalized != null) {
          letters.add(_SourceLetter(normalized, segment.rule));
        } else if (segment.rule != null &&
            letters.isNotEmpty &&
            !_isWhitespace(rune)) {
          letters.last.rule ??= segment.rule;
        }
      }
    }
    return letters;
  }

  static List<_TargetUnit> _targetUnits(String text) {
    final units = <_TargetUnit>[];
    _TargetUnit? currentLetter;

    void finishCurrent() {
      if (currentLetter != null) {
        units.add(currentLetter!);
        currentLetter = null;
      }
    }

    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      final normalized = _normalizeLetter(rune);
      if (normalized != null) {
        finishCurrent();
        currentLetter = _TargetUnit(character, normalized);
      } else if (currentLetter != null &&
          !_isWhitespace(rune) &&
          !_isStandaloneQuranMark(rune)) {
        currentLetter!.text += character;
      } else {
        finishCurrent();
        if (units.isNotEmpty && units.last.normalizedLetter == null) {
          units.last.text += character;
        } else {
          units.add(_TargetUnit(character, null));
        }
      }
    }
    finishCurrent();
    return units;
  }

  static List<int?> _align(List<String> source, List<String> target) {
    final rowWidth = target.length + 1;
    final directions = Uint8List((source.length + 1) * rowWidth);
    var previous = List<int>.generate(rowWidth, (index) => index);
    for (var column = 1; column < rowWidth; column++) {
      directions[column] = 3;
    }

    for (var row = 1; row <= source.length; row++) {
      final current = List<int>.filled(rowWidth, 0)..[0] = row;
      directions[row * rowWidth] = 2;
      for (var column = 1; column <= target.length; column++) {
        final equal = source[row - 1] == target[column - 1];
        final diagonal = previous[column - 1] + (equal ? 0 : 2);
        final deleteSource = previous[column] + 1;
        final insertTarget = current[column - 1] + 1;

        if (diagonal <= deleteSource && diagonal <= insertTarget) {
          current[column] = diagonal;
          directions[row * rowWidth + column] = 1;
        } else if (deleteSource <= insertTarget) {
          current[column] = deleteSource;
          directions[row * rowWidth + column] = 2;
        } else {
          current[column] = insertTarget;
          directions[row * rowWidth + column] = 3;
        }
      }
      previous = current;
    }

    final mapping = List<int?>.filled(source.length, null);
    var row = source.length;
    var column = target.length;
    while (row > 0 || column > 0) {
      final direction = directions[row * rowWidth + column];
      if (direction == 1) {
        if (source[row - 1] == target[column - 1]) {
          mapping[row - 1] = column - 1;
        }
        row--;
        column--;
      } else if (direction == 2) {
        row--;
      } else {
        column--;
      }
    }
    return mapping;
  }

  static String? _normalizeLetter(int rune) {
    if (rune == 0x0621 ||
        rune == 0x0640 ||
        rune == 0x0670 ||
        rune == 0x06E5 ||
        rune == 0x06E6) {
      return null;
    }
    final isArabicLetter = (rune >= 0x0622 && rune <= 0x063A) ||
        (rune >= 0x0641 && rune <= 0x064A) ||
        (rune >= 0x066E && rune <= 0x06D3) ||
        (rune >= 0x06FA && rune <= 0x06FC);
    if (!isArabicLetter) return null;

    return switch (rune) {
      0x0622 || 0x0623 || 0x0625 || 0x0671 || 0x0672 => 'ا',
      0x0626 || 0x0649 || 0x066E || 0x06CC || 0x06D2 => 'ي',
      0x06A9 || 0x06AA => 'ك',
      0x06C1 || 0x06BE || 0x06C0 => 'ه',
      _ => String.fromCharCode(rune),
    };
  }

  static bool _isWhitespace(int rune) =>
      rune == 0x20 || rune == 0x0A || rune == 0x0D || rune == 0x09;

  static bool _isStandaloneQuranMark(int rune) =>
      (rune >= 0x06D6 && rune <= 0x06E0) ||
      rune == 0x06E9 ||
      (rune >= 0x06EA && rune <= 0x06ED);
}

class _SourceLetter {
  final String normalized;
  String? rule;

  _SourceLetter(this.normalized, this.rule);
}

class _TargetUnit {
  String text;
  final String? normalizedLetter;

  _TargetUnit(this.text, this.normalizedLetter);
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
