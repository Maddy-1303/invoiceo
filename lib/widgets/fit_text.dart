import 'package:flutter/material.dart';

/// One line of text that shrinks a little when it does not fit, instead of
/// being cut off with "…". For labels in tight spots (table headers, cards,
/// chips) whose Tamil words are much longer than the English ones.
///
/// Needs a width limit from its parent (an Expanded, a SizedBox...); without
/// one it is plain one-line text. Works inside IntrinsicHeight, unlike a
/// LayoutBuilder.
class FitText extends StatelessWidget {
  const FitText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (textAlign) {
      TextAlign.center => Alignment.center,
      TextAlign.right || TextAlign.end => AlignmentDirectional.centerEnd,
      _ => AlignmentDirectional.centerStart,
    };
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(text, maxLines: 1, softWrap: false, style: style, textAlign: textAlign),
    );
  }
}
