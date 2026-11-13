import 'package:flutter/material.dart';

/// Shared timing for every value that eases to its new figure.
const motionDuration = Duration(milliseconds: 320);
const motionCurve = Curves.easeOutCubic;

Duration motionFor(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : motionDuration;

/// A number that eases from its old value to the new one, so the eye can
/// tell which figures moved after an input change. Shows the value as-is on
/// first build.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.textDirection = TextDirection.ltr,
  });

  final double value;
  final String Function(double) format;
  final TextStyle? style;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: motionFor(context),
      curve: motionCurve,
      builder: (context, v, _) =>
          Text(format(v), textDirection: textDirection, style: style),
    );
  }
}
