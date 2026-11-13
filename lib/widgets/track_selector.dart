import 'package:flutter/material.dart';

import '../models/loan_result.dart';
import '../theme/app_theme.dart';
import 'animated_number.dart';
import 'pressable.dart';

/// Segmented control for the repayment track. The highlight slides between
/// options, the way iOS segmented controls do.
class TrackSelector extends StatelessWidget {
  const TrackSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final RepaymentType value;
  final ValueChanged<RepaymentType> onChanged;

  static const Map<RepaymentType, String> labels = {
    RepaymentType.spitzer: 'שפיצר',
    RepaymentType.balloon: 'בלון',
    RepaymentType.grace: 'גרייס',
  };

  /// Comfortably above the 44pt minimum touch target.
  static const double height = 48;
  static const double _inset = 3;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const types = RepaymentType.values;
    final index = types.indexOf(value);
    // -1 is the start edge (right in Hebrew), 1 the end edge
    final x = types.length == 1 ? 0.0 : -1 + 2 * index / (types.length - 1);

    return Container(
      height: height,
      padding: const EdgeInsets.all(_inset),
      decoration: BoxDecoration(
        color: t.sunken,
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            alignment: AlignmentDirectional(x, 0),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            child: FractionallySizedBox(
              widthFactor: 1 / types.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: t.panel,
                  borderRadius:
                      BorderRadius.circular(AppTokens.controlRadius - _inset),
                  boxShadow: [
                    BoxShadow(
                      color: t.ink.withValues(alpha: 0.10),
                      blurRadius: 6,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final type in types)
                Expanded(
                  child: Pressable(
                    selected: type == value,
                    onTap: () {
                      if (type != value) onChanged(type);
                    },
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: motionFor(context),
                        curve: motionCurve,
                        style: TextStyle(
                          fontFamily: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.fontFamily,
                          fontSize: 15,
                          fontWeight:
                              type == value ? FontWeight.w600 : FontWeight.w500,
                          color: type == value ? t.ink : t.muted,
                        ),
                        child: Text(labels[type]!),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
