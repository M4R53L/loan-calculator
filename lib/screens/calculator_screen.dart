import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/loan_result.dart';
import '../models/scenario.dart';
import '../services/input_store.dart';
import '../services/loan_calculator.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';
import '../widgets/animated_number.dart';
import '../widgets/labeled_field.dart';
import '../widgets/pressable.dart';
import '../widgets/result_panel.dart';
import '../widgets/schedule_table.dart';
import '../widgets/track_selector.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  static const _defaults = {
    'principal': '50,000',
    'months': '60',
    'prime': '4.75',
    'margin': '6.75',
    'fee': '490',
    'inflation': '3',
  };

  late final Map<String, TextEditingController> _fields = {
    for (final e in _defaults.entries)
      e.key: TextEditingController(text: e.value),
  };
  TextEditingController get _principal => _fields['principal']!;
  TextEditingController get _months => _fields['months']!;
  TextEditingController get _prime => _fields['prime']!;
  TextEditingController get _margin => _fields['margin']!;
  TextEditingController get _fee => _fields['fee']!;
  TextEditingController get _inflation => _fields['inflation']!;

  RepaymentType _track = RepaymentType.spitzer;
  bool _cpiLinked = false;
  SavedScenario? _saved;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  /// Brings back the last session's inputs and pinned comparison.
  Future<void> _restore() async {
    final inputs = await InputStore.loadInputs();
    final saved = await InputStore.loadSaved();
    if (!mounted) return;
    setState(() {
      if (inputs != null) {
        for (final e in _fields.entries) {
          final v = inputs[e.key];
          if (v != null) e.value.text = v;
        }
        _track = RepaymentType.values
                .where((t) => t.name == inputs['track'])
                .firstOrNull ??
            _track;
        _cpiLinked = inputs['cpi'] == 'true';
      }
      _saved = saved;
    });
  }

  void _persist() => InputStore.saveInputs({
        for (final e in _fields.entries) e.key: e.value.text,
        'track': _track.name,
        'cpi': '$_cpiLinked',
      });

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _changed([Object? _]) {
    setState(() {});
    _persist();
  }

  void _setPrincipal(double v) {
    _principal.text = amount(v).split('.').first;
    _changed();
  }

  void _setMonths(int v) {
    _months.text = '$v';
    _changed();
  }

  void _reset() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    setState(() {
      for (final e in _defaults.entries) {
        _fields[e.key]!.text = e.value;
      }
      _track = RepaymentType.spitzer;
      _cpiLinked = false;
    });
    InputStore.clearInputs();
  }

  void _setSaved(SavedScenario? s) {
    HapticFeedback.lightImpact();
    setState(() => _saved = s);
    InputStore.setSaved(s);
  }

  // Field validation. Messages are shown under the field they belong to.

  String? get _principalError {
    final v = parseNumber(_principal.text);
    if (v == null) return 'הזינו את סכום ההלוואה';
    if (v < LoanCalculator.minPrincipal || v > LoanCalculator.maxPrincipal) {
      return 'הסכום צריך להיות 15,000 עד 400,000 ₪';
    }
    return null;
  }

  String? get _monthsError {
    final v = int.tryParse(_months.text);
    if (v == null) return 'הזינו מספר חודשים';
    if (v < LoanCalculator.minMonths || v > LoanCalculator.maxMonths) {
      return '12 עד 100 חודשים';
    }
    return null;
  }

  String? _rateError(TextEditingController c, String name) {
    final v = parseNumber(c.text);
    if (v == null) return 'הזינו $name';
    if (v < 0) return 'לא יכול להיות שלילי';
    return null;
  }

  String? get _primeError => _rateError(_prime, 'ריבית פריים');

  String? get _marginError {
    final own = _rateError(_margin, 'מרווח');
    if (own != null) return own;
    final total = (parseNumber(_prime.text) ?? 0) + parseNumber(_margin.text)!;
    if (total > 50) return 'ריבית שנתית מעל 50% אינה סבירה';
    return null;
  }

  String? get _feeError {
    final v = parseNumber(_fee.text);
    if (v == null) return 'הזינו עמלה, או 0';
    final principal = parseNumber(_principal.text);
    if (principal != null && v >= principal) {
      return 'העמלה צריכה להיות קטנה מסכום ההלוואה';
    }
    return null;
  }

  String? get _inflationError {
    if (!_cpiLinked) return null;
    final v = parseNumber(_inflation.text);
    if (v == null) return 'הזינו שיעור מדד משוער';
    if (v < -10 || v > 30) return 'מינוס 10% עד 30%';
    return null;
  }

  LoanResult? get _result {
    final errors = [
      _principalError,
      _monthsError,
      _primeError,
      _marginError,
      _feeError,
      _inflationError,
    ];
    if (errors.any((e) => e != null)) return null;

    return LoanCalculator.calculate(
      principal: parseNumber(_principal.text)!,
      prime: parseNumber(_prime.text)!,
      margin: parseNumber(_margin.text)!,
      months: int.parse(_months.text),
      repaymentType: _track,
      fee: parseNumber(_fee.text)!,
      annualInflationPercent: _cpiLinked ? parseNumber(_inflation.text)! : 0,
      generateSchedule: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final result = _result;
    final narrow = MediaQuery.sizeOf(context).width < 920;

    // Tapping anywhere outside a field closes the keyboard. The iOS number
    // pad has no return key, so this is the only way to put it away.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        // On narrow screens the result sits below the form, so keep the
        // monthly payment in view while editing.
        bottomNavigationBar:
            narrow && result != null ? _PaymentBar(result: result) : null,
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 920;
            final gutter = constraints.maxWidth < 600 ? 16.0 : 32.0;

            final inputs = _InputsPanel(
              principal: _principal,
              months: _months,
              prime: _prime,
              margin: _margin,
              fee: _fee,
              inflation: _inflation,
              track: _track,
              cpiLinked: _cpiLinked,
              errors: _Errors(
                principal: _principalError,
                months: _monthsError,
                prime: _primeError,
                margin: _marginError,
                fee: _feeError,
                inflation: _inflationError,
              ),
              onChanged: _changed,
              onPrincipalSlide: _setPrincipal,
              onMonthsPick: _setMonths,
              onTrackChanged: (v) {
                _track = v;
                _changed();
              },
              onCpiChanged: (v) {
                HapticFeedback.selectionClick();
                _cpiLinked = v;
                _changed();
              },
              onReset: _reset,
            );
            final results = ResultPanel(
              result: result,
              saved: _saved,
              onSave: result == null
                  ? null
                  : () => _setSaved(SavedScenario.fromResult(result)),
              onClearSaved: () => _setSaved(null),
            );

            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(gutter, wide ? 48 : 24, gutter, 48),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'מחשבון הלוואה',
                        style: TextStyle(
                          fontSize: wide ? 34 : 28,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.4,
                          color: t.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'כמה תשלמו בכל חודש, ומה ההלוואה עולה באמת.',
                        style: TextStyle(fontSize: 16, color: t.muted),
                      ),
                      SizedBox(height: wide ? 36 : 24),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 5, child: inputs),
                            const SizedBox(width: 24),
                            Expanded(flex: 6, child: results),
                          ],
                        )
                      else ...[
                        inputs,
                        const SizedBox(height: 16),
                        results,
                      ],
                      if (result != null) ...[
                        const SizedBox(height: 24),
                        ScheduleTable(result: result),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _PaymentBar extends StatelessWidget {
  const _PaymentBar({required this.result});

  final LoanResult result;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('תשלום חודשי',
                        style: TextStyle(fontSize: 13, color: t.muted)),
                    Text(
                      'עלות אשראי ${percent(result.effectiveAnnualCost ?? result.annualRate)}',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: t.muted,
                          fontFeatures: tabular),
                    ),
                  ],
                ),
              ),
              AnimatedNumber(
                value: result.monthlyPayment,
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
        ),
      ),
    );
  }
}

class _Errors {
  const _Errors({
    this.principal,
    this.months,
    this.prime,
    this.margin,
    this.fee,
    this.inflation,
  });

  final String? principal, months, prime, margin, fee, inflation;
}

class _InputsPanel extends StatelessWidget {
  const _InputsPanel({
    required this.principal,
    required this.months,
    required this.prime,
    required this.margin,
    required this.fee,
    required this.inflation,
    required this.track,
    required this.cpiLinked,
    required this.errors,
    required this.onChanged,
    required this.onPrincipalSlide,
    required this.onMonthsPick,
    required this.onTrackChanged,
    required this.onCpiChanged,
    required this.onReset,
  });

  static const _termPicks = [24, 36, 48, 60, 84];

  final TextEditingController principal, months, prime, margin, fee, inflation;
  final RepaymentType track;
  final bool cpiLinked;
  final _Errors errors;
  final ValueChanged<String> onChanged;
  final ValueChanged<double> onPrincipalSlide;
  final ValueChanged<int> onMonthsPick;
  final ValueChanged<RepaymentType> onTrackChanged;
  final ValueChanged<bool> onCpiChanged;
  final VoidCallback onReset;

  static String _trackHint(RepaymentType type) {
    switch (type) {
      case RepaymentType.spitzer:
        return 'תשלום קבוע בכל חודש. בהתחלה רובו ריבית, ובהמשך רובו קרן.';
      case RepaymentType.balloon:
        return 'משלמים רק ריבית בכל חודש, ואת כל הקרן בתשלום האחרון.';
      case RepaymentType.grace:
        return 'שלושה חודשים ראשונים בלי תשלומים. '
            'הריבית שנצברת מתווספת לחוב ונפרסת על שאר התקופה.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final decimal = [DecimalFormatter()];

    Widget group(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: t.ink)),
            const SizedBox(height: 16),
            ...children,
          ],
        );

    Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(AppTokens.panelRadius),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          group('ההלוואה', [
            LabeledField(
              label: 'סכום ההלוואה',
              controller: principal,
              onChanged: onChanged,
              suffix: '₪',
              helper: '15,000 עד 400,000 ₪',
              error: errors.principal,
              inputFormatters: [ThousandsFormatter()],
            ),
            _StepSlider(
              value: parseNumber(principal.text) ?? LoanCalculator.minPrincipal,
              min: LoanCalculator.minPrincipal,
              max: LoanCalculator.maxPrincipal,
              step: 5000,
              semanticFormat: (v) => '${amount(v).split('.').first} שקלים',
              onChanged: onPrincipalSlide,
            ),
            const SizedBox(height: 8),
            LabeledField(
              label: 'תקופה',
              controller: months,
              onChanged: onChanged,
              suffix: 'חודשים',
              helper: '12 עד 100 תשלומים',
              error: errors.months,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            _StepSlider(
              value: (int.tryParse(months.text) ?? LoanCalculator.minMonths)
                  .toDouble(),
              min: LoanCalculator.minMonths.toDouble(),
              max: LoanCalculator.maxMonths.toDouble(),
              step: 1,
              semanticFormat: (v) => '${v.round()} חודשים',
              onChanged: (v) => onMonthsPick(v.round()),
            ),
            Row(
              children: [
                for (int i = 0; i < _termPicks.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _TermChip(
                      months: _termPicks[i],
                      selected: int.tryParse(months.text) == _termPicks[i],
                      onTap: () => onMonthsPick(_termPicks[i]),
                    ),
                  ),
                ],
              ],
            ),
          ]),
          const SizedBox(height: 28),
          group('ריבית', [
            pair(
              LabeledField(
                label: 'ריבית פריים',
                controller: prime,
                onChanged: onChanged,
                suffix: '%',
                error: errors.prime,
                inputFormatters: decimal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              LabeledField(
                label: 'מרווח מעל הפריים',
                controller: margin,
                onChanged: onChanged,
                suffix: '%',
                error: errors.margin,
                inputFormatters: decimal,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ]),
          const SizedBox(height: 28),
          group('מסלול החזר', [
            TrackSelector(value: track, onChanged: onTrackChanged),
            const SizedBox(height: 10),
            Text(
              _trackHint(track),
              style: TextStyle(fontSize: 13.5, color: t.muted, height: 1.5),
            ),
          ]),
          const SizedBox(height: 28),
          group('עמלות והצמדה', [
            LabeledField(
              label: 'עמלת פתיחת תיק',
              controller: fee,
              onChanged: onChanged,
              suffix: '₪',
              helper: 'נכללת בעלות האשראי השנתית',
              error: errors.fee,
              inputFormatters: [ThousandsFormatter()],
            ),
            const SizedBox(height: 12),
            MergeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('צמוד למדד',
                            style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                color: t.ink)),
                        Text('הקרן מתעדכנת לפי מדד המחירים לצרכן',
                            style: TextStyle(fontSize: 12.5, color: t.muted)),
                      ],
                    ),
                  ),
                  Switch(value: cpiLinked, onChanged: onCpiChanged),
                ],
              ),
            ),
            AnimatedSize(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: AlignmentDirectional.topStart,
              child: cpiLinked
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: LabeledField(
                        label: 'מדד שנתי משוער',
                        controller: inflation,
                        onChanged: onChanged,
                        suffix: '%',
                        helper: 'הערכה בלבד. המדד בפועל ישנה את התשלומים.',
                        error: errors.inflation,
                        inputFormatters: [
                          DecimalFormatter(allowNegative: true)
                        ],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ]),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                foregroundColor: t.muted,
                minimumSize: const Size(44, 44),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              child: const Text('איפוס לערכי ברירת המחדל'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Slider under a typed field, for coarse changes with the thumb. Ticks the
/// haptic engine on each step. Typed values outside the range pin the thumb
/// to the nearest end without touching the text.
class _StepSlider extends StatelessWidget {
  const _StepSlider({
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.semanticFormat,
    required this.onChanged,
  });

  final double value, min, max, step;
  final String Function(double) semanticFormat;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = value.clamp(min, max).toDouble();
    return SizedBox(
      height: 44,
      child: Slider(
        value: current,
        min: min,
        max: max,
        divisions: ((max - min) / step).round(),
        semanticFormatterCallback: semanticFormat,
        onChanged: (v) {
          if ((v - current).abs() >= step / 2) {
            HapticFeedback.selectionClick();
            onChanged(v);
          }
        },
      ),
    );
  }
}

/// One-tap common loan term.
class _TermChip extends StatelessWidget {
  const _TermChip({
    required this.months,
    required this.selected,
    required this.onTap,
  });

  final int months;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Pressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$months חודשים',
      child: AnimatedContainer(
        duration: motionFor(context),
        curve: motionCurve,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? t.accentWeak : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTokens.controlRadius),
          border: Border.all(color: selected ? t.accent : t.line),
        ),
        child: ExcludeSemantics(
          child: Text(
            '$months',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? t.accent : t.ink,
              fontFeatures: tabular,
            ),
          ),
        ),
      ),
    );
  }
}
