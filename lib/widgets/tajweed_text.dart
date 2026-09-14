import 'package:flutter/material.dart';

import '../models/tajweed_models.dart';

class TajweedText extends StatelessWidget {
  final String markup;
  final String? displayText;
  final TextStyle? style;

  const TajweedText({
    super.key,
    required this.markup,
    this.displayText,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final segments = displayText == null
        ? TajweedMarkupParser.parse(markup)
        : IndoPakTajweedMapper.map(
            indoPakText: displayText!,
            uthmaniMarkup: markup,
          );
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: segments
            .map(
              (segment) => TextSpan(
                text: segment.text,
                style: segment.rule == null
                    ? null
                    : TextStyle(
                        color: TajweedPalette.colorFor(
                          segment.rule!,
                          Theme.of(context).brightness,
                        ),
                        fontWeight: FontWeight.w600,
                      ),
              ),
            )
            .toList(growable: false),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.rtl,
    );
  }
}

class TajweedLegend extends StatelessWidget {
  const TajweedLegend({super.key});

  static const _items = <(String, String)>[
    ('madda_normal', 'Madd'),
    ('ghunnah', 'Ghunnah'),
    ('ikhafa', 'Ikhfa'),
    ('iqlab', 'Iqlab'),
    ('idgham_ghunnah', 'Idgham'),
    ('qalaqah', 'Qalqalah'),
    ('slnt', 'Silent / connecting'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _items
          .map(
            (item) => Chip(
              visualDensity: VisualDensity.compact,
              avatar: CircleAvatar(
                backgroundColor: TajweedPalette.colorFor(
                  item.$1,
                  Theme.of(context).brightness,
                ),
              ),
              label: Text(item.$2),
            ),
          )
          .toList(growable: false),
    );
  }
}

class TajweedPalette {
  static Color colorFor(String rule, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (rule) {
      'ham_wasl' ||
      'laam_shamsiyah' ||
      'slnt' =>
        dark ? const Color(0xFFBDBDBD) : const Color(0xFF858585),
      'madda_normal' =>
        dark ? const Color(0xFF82A7FF) : const Color(0xFF4267C9),
      'madda_permissible' =>
        dark ? const Color(0xFF738CFF) : const Color(0xFF4050DF),
      'madda_necessary' ||
      'madda_obligatory' =>
        dark ? const Color(0xFFAAB7FF) : const Color(0xFF172DA8),
      'qalaqah' => dark ? const Color(0xFFFF7378) : const Color(0xFFC71920),
      'ghunnah' => dark ? const Color(0xFFFFAE57) : const Color(0xFFE26700),
      'ikhafa' ||
      'ikhafa_shafawi' =>
        dark ? const Color(0xFFE08AEE) : const Color(0xFF9223A5),
      'iqlab' => dark ? const Color(0xFF62DDEB) : const Color(0xFF007E90),
      'idgham_ghunnah' ||
      'idgham_wo_ghunnah' ||
      'idgham_mutajanisayn' ||
      'idgham_mutaqaribayn' ||
      'idgham_shafawi' =>
        dark ? const Color(0xFF72D69A) : const Color(0xFF147B42),
      _ => dark ? const Color(0xFFE0E0E0) : const Color(0xFF424242),
    };
  }
}
