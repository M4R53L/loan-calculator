import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/loan_result.dart';
import '../theme/app_theme.dart';
import '../util/format.dart';

/// Month-by-month repayment schedule (לוח סילוקין).
class ScheduleTable extends StatefulWidget {
  const ScheduleTable({super.key, required this.result});

  final LoanResult result;

  @override
  State<ScheduleTable> createState() => _ScheduleTableState();
}

class _ScheduleTableState extends State<ScheduleTable> {
  static const int _previewRows = 12;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final result = widget.result;
    final schedule = result.schedule ?? const <AmortizationRow>[];
    final showLinkage = result.isCpiLinked;
    final canExpand = schedule.length > _previewRows;
    final visible = _expanded || !canExpand
        ? schedule
        : schedule.take(_previewRows).toList();

    final headers = [
      'חודש',
      'תשלום',
      'ריבית',
      'קרן',
      if (showLinkage) 'הצמדה',
      'יתרה',
    ];

    TextStyle cell({bool strong = false, Color? color}) => TextStyle(
          fontSize: 14,
          fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
          color: color ?? t.ink,
          fontFeatures: tabular,
        );

    Widget pad(Widget child, {bool first = false}) => Padding(
          padding: EdgeInsetsDirectional.fromSTEB(first ? 20 : 12, 11, 12, 11),
          child: Align(
            alignment: first
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            child: child,
          ),
        );

    Widget num(double value, {bool strong = false, Color? color}) => Text(
          amount(value),
          textDirection: TextDirection.ltr,
          style: cell(strong: strong, color: color),
        );

    return Container(
      decoration: BoxDecoration(
        color: t.panel,
        borderRadius: BorderRadius.circular(AppTokens.panelRadius),
        border: Border.all(color: t.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('לוח סילוקין',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: t.ink)),
                const SizedBox(height: 4),
                Text(
                  result.graceMonths > 0
                      ? 'בחודשי הגרייס (מודגשים) הריבית לא משולמת ומתווספת ליתרה. הסכומים בשקלים.'
                      : 'הסכומים בשקלים.',
                  style: TextStyle(fontSize: 13.5, color: t.muted),
                ),
              ],
            ),
          ),
          LayoutBuilder(builder: (context, constraints) {
            final minWidth = showLinkage ? 720.0 : 620.0;
            final width = constraints.maxWidth < minWidth
                ? minWidth
                : constraints.maxWidth;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: width,
                child: Table(
                  columnWidths: const {0: FlexColumnWidth(0.6)},
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  children: [
                    TableRow(
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: t.line)),
                      ),
                      children: [
                        for (int i = 0; i < headers.length; i++)
                          pad(
                            Text(headers[i],
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: t.muted)),
                            first: i == 0,
                          ),
                      ],
                    ),
                    for (final row in visible)
                      TableRow(
                        decoration: BoxDecoration(
                          color: row.month <= result.graceMonths
                              ? t.accentWeak
                              : row.month.isEven
                                  ? t.sunken.withValues(alpha: 0.45)
                                  : null,
                        ),
                        children: [
                          pad(Text('${row.month}', style: cell(color: t.muted)),
                              first: true),
                          pad(num(row.payment, strong: true)),
                          pad(num(row.interestPortion)),
                          pad(num(row.principalPortion)),
                          if (showLinkage) pad(num(row.linkage)),
                          pad(num(row.remainingBalance)),
                        ],
                      ),
                  ],
                ),
              ),
            );
          }),
          if (canExpand)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() => _expanded = !_expanded);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: t.accent,
                    textStyle: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTokens.controlRadius),
                    ),
                  ),
                  child: Text(_expanded
                      ? 'הצגת 12 החודשים הראשונים בלבד'
                      : 'הצגת כל ${schedule.length} החודשים'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
