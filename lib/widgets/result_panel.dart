import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../models/loan_result.dart';
import '../models/scenario.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import 'animated_number.dart';
import 'pressable.dart';
import 'track_selector.dart';

class ResultPanel extends StatelessWidget {
  const ResultPanel({
    super.key,
    required this.result,
    this.saved,
    this.onSave,
    this.onClearSaved,
  });

  /// Null while the inputs are incomplete or invalid.
  final LoanResult? result;

  /// The pinned loan to compare against, if any.
  final SavedScenario? saved;
  final VoidCallback? onSave;
  final VoidCallback? onClearSaved;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final r = result;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(AppTokens.panelRadius),
        border: Border.all(color: t.line),
      ),
      child: r == null
          ? _EmptyState()
          : _Result(
              result: r,
              saved: saved,
              onSave: onSave,
              onClearSaved: onClearSaved,
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'אין עדיין חישוב',
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: t.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'תקנו את השדות המסומנים, וההחזר החודשי יופיע כאן.',
            style: TextStyle(fontSize: 14.5, color: t.muted, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.result,
    this.saved,
    this.onSave,
    this.onClearSaved,
  });

  final LoanResult result;
  final SavedScenario? saved;
  final VoidCallback? onSave;
  final VoidCallback? onClearSaved;

  String? get _paymentNote {
    final notes = <String>[];
    switch (result.repaymentType) {
      case RepaymentType.spitzer:
        break;
      case RepaymentType.balloon:
        notes.add('ריבית בלבד. הקרן משולמת בתשלום האחרון');
        break;
      case RepaymentType.grace:
        notes.add('החל מחודש ${result.graceMonths + 1}, '
            'אחרי ${result.graceMonths} חודשי גרייס');
        break;
    }
    if (result.isCpiLinked) {
      notes.add('התשלום יתעדכן לפי המדד');
    }
    return notes.isEmpty ? null : notes.join('. ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final note = _paymentNote;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('תשלום חודשי',
            style: TextStyle(
                fontSize: 14.5, fontWeight: FontWeight.w500, color: t.muted)),
        const SizedBox(height: 4),
        _HeadlineAmount(value: result.monthlyPayment),
        if (note != null) ...[
          const SizedBox(height: 4),
          Text(note,
              style: TextStyle(fontSize: 13.5, color: t.muted, height: 1.45)),
        ],
        const SizedBox(height: 28),
        Divider(color: t.line),
        const SizedBox(height: 24),
        _Breakdown(result: result),
        const SizedBox(height: 28),
        _Figures(result: result),
        if (onSave != null) ...[
          const SizedBox(height: 20),
          _Compare(
            result: result,
            saved: saved,
            onSave: onSave!,
            onClear: onClearSaved,
          ),
        ],
      ],
    );
  }
}

/// The headline number. Eases between values so a change reads as a change.
class _HeadlineAmount extends StatelessWidget {
  const _HeadlineAmount({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: motionFor(context),
      curve: motionCurve,
      builder: (context, v, _) {
        final text = amount(v);
        final dot = text.indexOf('.');
        return Text.rich(
          TextSpan(children: [
            TextSpan(
              text: text.substring(0, dot),
              style: TextStyle(
                fontSize: 52,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.2,
                height: 1.1,
                color: t.ink,
              ),
            ),
            TextSpan(
              text: text.substring(dot),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: t.muted,
              ),
            ),
            TextSpan(
              text: ' ₪',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w500,
                color: t.muted,
              ),
            ),
          ]),
          textDirection: TextDirection.ltr,
          style: const TextStyle(fontFeatures: tabular),
        );
      },
    );
  }
}

class _Part {
  const _Part(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

/// What the total is made of, as one composition bar plus a legend. Segments
/// grow and shrink with the numbers, and new ones grow in from zero.
class _Breakdown extends StatelessWidget {
  const _Breakdown({required this.result});

  final LoanResult result;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final duration = motionFor(context);
    final parts = [
      _Part('קרן', result.principal, t.accent),
      _Part('ריבית', result.totalInterest, t.interest),
      if (result.isCpiLinked)
        _Part('הפרשי הצמדה', result.totalLinkage, t.linkage),
      if (result.fee > 0) _Part('עמלת פתיחת תיק', result.fee, t.fee),
    ].where((p) => p.value > 0).toList();

    final numberStyle = TextStyle(
      fontSize: 14.5,
      color: t.ink,
      fontFeatures: tabular,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(
              child: Text('סך הכול תשלמו',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
            ),
            AnimatedNumber(
              value: result.totalPaid,
              format: money,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: t.ink,
                fontFeatures: tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Flex keeps the segments inside the row whatever the count is
        SizedBox(
          height: 10,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < parts.length; i++) ...[
                if (i > 0) const SizedBox(width: 3),
                TweenAnimationBuilder<double>(
                  key: ValueKey(parts[i].label),
                  tween: Tween(begin: 0, end: parts[i].value),
                  duration: duration,
                  curve: motionCurve,
                  builder: (context, v, child) => Expanded(
                    flex: max(1, v.round()),
                    child: child!,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: parts[i].color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final part in parts)
          Padding(
            key: ValueKey(part.label),
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: part.color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(part.label,
                      style: TextStyle(fontSize: 14.5, color: t.ink)),
                ),
                AnimatedNumber(
                    value: part.value, format: money, style: numberStyle),
              ],
            ),
          ),
      ],
    );
  }
}

class _Figure {
  const _Figure(this.label, this.value, this.format, this.caption);
  final String label;
  final double? value;
  final String Function(double) format;
  final String caption;
}

/// Rates and the final payment, in a two-column grid.
class _Figures extends StatelessWidget {
  const _Figures({required this.result});

  final LoanResult result;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final paying = result.months - result.graceMonths;
    final figures = [
      _Figure('ריבית שנתית', result.annualRate, percent, 'פריים ועוד מרווח'),
      _Figure('עלות אשראי שנתית', result.effectiveAnnualCost, percent,
          'כולל עמלות וריבית דריבית'),
      _Figure(
        'תשלום אחרון',
        result.finalPayment,
        money,
        result.repaymentType == RepaymentType.balloon
            ? 'כולל החזר הקרן'
            : 'בחודש ${result.months}',
      ),
      _Figure(
        'מספר תשלומים',
        paying.toDouble(),
        (v) => '${v.round()}',
        result.graceMonths > 0
            ? 'מתוך ${result.months} חודשים'
            : 'תשלום בכל חודש',
      ),
    ];
    final valueStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: t.ink,
      fontFeatures: tabular,
    );

    return Container(
      decoration: BoxDecoration(
        color: t.sunken.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 1 : 2;
        final width = (constraints.maxWidth - 4 * (columns - 1)) / columns;
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final f in figures)
              SizedBox(
                width: width,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(f.label,
                          style: TextStyle(fontSize: 13, color: t.muted)),
                      const SizedBox(height: 4),
                      f.value == null
                          ? Text('לא זמין', style: valueStyle)
                          : AnimatedNumber(
                              value: f.value!,
                              format: f.format,
                              style: valueStyle),
                      const SizedBox(height: 2),
                      Text(f.caption,
                          style: TextStyle(fontSize: 12.5, color: t.muted)),
                    ],
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}

/// Pin the current loan, then see how other inputs compare with it.
class _Compare extends StatelessWidget {
  const _Compare({
    required this.result,
    required this.saved,
    required this.onSave,
    required this.onClear,
  });

  final LoanResult result;
  final SavedScenario? saved;
  final VoidCallback onSave;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = saved;

    if (s == null) {
      return Pressable(
        onTap: onSave,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.controlRadius),
            border: Border.all(color: t.line),
          ),
          child: Text('שמירה להשוואה',
              style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: t.accent)),
        ),
      );
    }

    final summary = '${amount(s.principal).split('.').first} ₪, '
        '${s.months} חודשים, ${TrackSelector.labels[s.repaymentType]}, '
        'ריבית ${percent(s.annualRate)}';

    Widget delta(String label, double diff) {
      final same = diff.abs() < 0.005;
      final color = same ? t.muted : (diff < 0 ? t.accent : t.danger);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 14.5, color: t.ink))),
            same
                ? Text('ללא שינוי',
                    style: TextStyle(fontSize: 14.5, color: color))
                : AnimatedNumber(
                    value: diff,
                    format: (v) => '${v < 0 ? '−' : '+'}${money(v.abs())}',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                      fontFeatures: tabular,
                    ),
                  ),
          ],
        ),
      );
    }

    final actionStyle = TextButton.styleFrom(
      foregroundColor: t.accent,
      minimumSize: const Size(44, 44),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTokens.controlRadius),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('לעומת התרחיש השמור',
              style: TextStyle(
                  fontSize: 14.5, fontWeight: FontWeight.w600, color: t.ink)),
          const SizedBox(height: 2),
          Text(summary, style: TextStyle(fontSize: 12.5, color: t.muted)),
          const SizedBox(height: 8),
          delta('תשלום חודשי', result.monthlyPayment - s.monthlyPayment),
          delta('סך הכול', result.totalPaid - s.totalPaid),
          Row(
            children: [
              TextButton(
                onPressed: onSave,
                style: actionStyle,
                child: const Text('שמירת הנוכחי במקומו'),
              ),
              const Spacer(),
              TextButton(
                onPressed: onClear,
                style: actionStyle.copyWith(
                    foregroundColor: WidgetStatePropertyAll(t.muted)),
                child: const Text('הסרה'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
