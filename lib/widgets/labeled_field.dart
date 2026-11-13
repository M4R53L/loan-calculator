import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Text field with its label above the input, helper and error below.
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    required this.controller,
    required this.onChanged,
    this.suffix,
    this.helper,
    this.error,
    this.inputFormatters = const [],
    this.keyboardType = TextInputType.number,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? suffix;
  final String? helper;
  final String? error;
  final List<TextInputFormatter> inputFormatters;
  final TextInputType keyboardType;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w500,
            color: t.ink,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: t.ink,
            fontFeatures: tabular,
          ),
          decoration: InputDecoration(
            suffixText: suffix,
            helperText: error == null ? helper : null,
            errorText: error,
            helperMaxLines: 2,
            errorMaxLines: 2,
          ),
        ),
      ],
    );
  }
}
