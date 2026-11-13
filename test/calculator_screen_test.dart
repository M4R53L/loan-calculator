import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loan_calculator/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpAt(WidgetTester tester, Size size,
      {Map<String, Object> stored = const {}}) async {
    SharedPreferences.setMockInitialValues(stored);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const LoanCalculatorApp());
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester, int index) => tester
      .widget<TextField>(find.byType(TextField).at(index))
      .controller!
      .text;

  for (final size in const [Size(1240, 860), Size(390, 844)]) {
    testWidgets('renders every track at ${size.width.toInt()}px',
        (tester) async {
      await pumpAt(tester, size);
      expect(find.text('תשלום חודשי'), findsWidgets);
      expect(find.text('לוח סילוקין'), findsOneWidget);

      for (final track in ['בלון', 'גרייס', 'שפיצר']) {
        await tapVisible(tester, find.text(track));
        expect(tester.takeException(), isNull);
      }

      // CPI linkage adds the inflation field and a linkage column
      await tapVisible(tester, find.byType(Switch));
      expect(find.text('מדד שנתי משוער'), findsOneWidget);
      expect(find.text('הצמדה'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('invalid amount shows an inline error and the empty state',
      (tester) async {
    await pumpAt(tester, const Size(1240, 860));
    await tester.enterText(find.byType(TextField).first, '1000');
    await tester.pumpAndSettle();

    expect(find.text('הסכום צריך להיות 15,000 עד 400,000 ₪'), findsOneWidget);
    expect(find.text('אין עדיין חישוב'), findsOneWidget);
    expect(find.text('לוח סילוקין'), findsNothing);
  });

  testWidgets('term quick pick and slider set the inputs', (tester) async {
    await pumpAt(tester, const Size(390, 844));
    await tapVisible(tester, find.text('36'));
    expect(fieldText(tester, 1), '36');

    // Dragging the amount slider to its far end gives the maximum
    final slider = find.byType(Slider).first;
    await tester.ensureVisible(slider);
    await tester.pumpAndSettle();
    await tester.drag(slider, const Offset(-600, 0)); // RTL: end is left
    await tester.pumpAndSettle();
    expect(fieldText(tester, 0), '400,000');
    expect(tester.takeException(), isNull);
  });

  testWidgets('restores the last inputs and resets to defaults',
      (tester) async {
    await pumpAt(tester, const Size(390, 844), stored: {
      'inputs.v1': jsonEncode({
        'principal': '120,000',
        'months': '84',
        'prime': '4.75',
        'margin': '6.75',
        'fee': '0',
        'inflation': '3',
        'track': 'balloon',
        'cpi': 'false',
      }),
    });
    expect(fieldText(tester, 0), '120,000');
    expect(fieldText(tester, 1), '84');

    await tapVisible(tester, find.text('איפוס לערכי ברירת המחדל'));
    expect(fieldText(tester, 0), '50,000');
    expect(fieldText(tester, 3), '6.75');
  });

  testWidgets('saved scenario shows the difference', (tester) async {
    await pumpAt(tester, const Size(1240, 860));
    await tapVisible(tester, find.text('שמירה להשוואה'));
    expect(find.text('לעומת התרחיש השמור'), findsOneWidget);
    expect(find.text('ללא שינוי'), findsNWidgets(2));

    // A shorter term costs more per month and less in total
    await tapVisible(tester, find.text('36'));
    expect(find.text('ללא שינוי'), findsNothing);

    await tapVisible(tester, find.text('הסרה'));
    expect(find.text('לעומת התרחיש השמור'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
