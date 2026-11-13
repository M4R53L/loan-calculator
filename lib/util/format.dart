import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final NumberFormat _money2 = NumberFormat('#,##0.00', 'en_US');
final NumberFormat _money0 = NumberFormat('#,##0', 'en_US');
final NumberFormat _percent = NumberFormat('0.00', 'en_US');

/// "12,345.67 ₪" (Hebrew convention: symbol after the amount)
String money(double value, {bool cents = true}) =>
    '${(cents ? _money2 : _money0).format(value)} ₪';

String amount(double value, {bool cents = true}) =>
    (cents ? _money2 : _money0).format(value);

String percent(double value) => '${_percent.format(value)}%';

/// Parses user input that may contain thousands separators.
double? parseNumber(String text) =>
    double.tryParse(text.replaceAll(',', '').trim());

/// Digits only, shown with thousands separators while typing.
class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = _money0.format(int.parse(digits));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// A decimal number with at most one dot (and optionally a leading minus).
class DecimalFormatter extends TextInputFormatter {
  DecimalFormatter({this.allowNegative = false});

  final bool allowNegative;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final pattern = allowNegative ? r'^-?\d*\.?\d*$' : r'^\d*\.?\d*$';
    return RegExp(pattern).hasMatch(newValue.text) ? newValue : oldValue;
  }
}
