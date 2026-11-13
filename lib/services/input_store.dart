import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/scenario.dart';

/// Remembers the last inputs and the pinned comparison between launches.
/// Storage failures are swallowed: the calculator works without them.
class InputStore {
  static const _inputsKey = 'inputs.v1';
  static const _savedKey = 'saved.v1';

  static Future<Map<String, String>?> loadInputs() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_inputsKey);
      if (raw == null) return null;
      return (jsonDecode(raw) as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, '$v'));
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveInputs(Map<String, String> inputs) async {
    try {
      await (await SharedPreferences.getInstance())
          .setString(_inputsKey, jsonEncode(inputs));
    } catch (_) {}
  }

  static Future<SavedScenario?> loadSaved() async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(_savedKey);
      if (raw == null) return null;
      return SavedScenario.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setSaved(SavedScenario? s) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (s == null) {
        await prefs.remove(_savedKey);
      } else {
        await prefs.setString(_savedKey, jsonEncode(s.toJson()));
      }
    } catch (_) {}
  }

  static Future<void> clearInputs() async {
    try {
      await (await SharedPreferences.getInstance()).remove(_inputsKey);
    } catch (_) {}
  }
}
