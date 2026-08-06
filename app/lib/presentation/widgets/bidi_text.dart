import 'package:flutter/material.dart';

/// Text whose direction follows its own content.
///
/// The UI is Persian and right-to-left (section 8.2), but a lot of the data
/// comes from IMDb in English — plots, episode names, character names. Rendering
/// an English sentence inside an RTL paragraph pushes its full stop to the wrong
/// end («.family's future»), which reads as broken. This picks the direction
/// from the letters actually in the string.
class BidiText extends StatelessWidget {
  const BidiText(this.data, {super.key, this.style, this.maxLines, this.overflow});

  final String data;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// The Unicode "first strong character" rule — the same one browsers use for
  /// `dir="auto"`. Digits and punctuation are neutral, so a line that opens in
  /// Persian stays Persian even when it ends in an English episode name, and a
  /// line with no letters at all falls back to the app's own direction.
  static TextDirection directionOf(String text) {
    for (final rune in text.runes) {
      final isRtl =
          (rune >= 0x0590 && rune <= 0x08FF) ||
          (rune >= 0xFB1D && rune <= 0xFDFF) ||
          (rune >= 0xFE70 && rune <= 0xFEFF);
      if (isRtl) return TextDirection.rtl;
      final isLtr = (rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A);
      if (isLtr) return TextDirection.ltr;
    }
    return TextDirection.rtl;
  }

  @override
  Widget build(BuildContext context) {
    final direction = directionOf(data);
    return Text(
      data,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
      textDirection: direction,
      textAlign: direction == TextDirection.ltr ? TextAlign.left : TextAlign.right,
    );
  }
}
