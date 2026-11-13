import 'package:flutter/material.dart';

/// Design tokens.
///
/// One neutral family (cool grey), one accent (deep green), one radius system:
/// controls use [AppTokens.controlRadius], panels use [AppTokens.panelRadius].
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.canvas,
    required this.panel,
    required this.sunken,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.onAccent,
    required this.accentWeak,
    required this.interest,
    required this.linkage,
    required this.fee,
    required this.danger,
  });

  static const double controlRadius = 10;
  static const double panelRadius = 16;

  final Color canvas;
  final Color panel;
  final Color sunken;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color onAccent;
  final Color accentWeak;

  /// Breakdown colours: shades of the same accent plus the neutral ink,
  /// so the composition bar stays inside the single-accent palette.
  final Color interest;
  final Color linkage;
  final Color fee;
  final Color danger;

  static const light = AppTokens(
    canvas: Color(0xFFF3F4F2),
    panel: Color(0xFFFBFBFA),
    sunken: Color(0xFFE9EBE8),
    ink: Color(0xFF16181A),
    muted: Color(0xFF5B6166),
    line: Color(0xFFDADDD9),
    accent: Color(0xFF0E6B50),
    onAccent: Color(0xFFF4FAF7),
    accentWeak: Color(0xFFE1EEE8),
    interest: Color(0xFF7FB9A3),
    linkage: Color(0xFFB9D6CA),
    fee: Color(0xFF8A9096),
    danger: Color(0xFFB3261E),
  );

  static const dark = AppTokens(
    canvas: Color(0xFF101213),
    panel: Color(0xFF181A1C),
    sunken: Color(0xFF212427),
    ink: Color(0xFFE9EBEC),
    muted: Color(0xFF9BA1A6),
    line: Color(0xFF2C3033),
    accent: Color(0xFF46C295),
    onAccent: Color(0xFF07211A),
    accentWeak: Color(0xFF173129),
    interest: Color(0xFF2D7D62),
    linkage: Color(0xFF1F5444),
    fee: Color(0xFF6B7176),
    danger: Color(0xFFF2B8B5),
  );

  @override
  AppTokens copyWith() => this;

  @override
  AppTokens lerp(AppTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppTokens(
      canvas: mix(canvas, other.canvas),
      panel: mix(panel, other.panel),
      sunken: mix(sunken, other.sunken),
      ink: mix(ink, other.ink),
      muted: mix(muted, other.muted),
      line: mix(line, other.line),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      accentWeak: mix(accentWeak, other.accentWeak),
      interest: mix(interest, other.interest),
      linkage: mix(linkage, other.linkage),
      fee: mix(fee, other.fee),
      danger: mix(danger, other.danger),
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

/// Tabular figures so amounts line up and do not jitter while typing.
const List<FontFeature> tabular = [FontFeature.tabularFigures()];

class AppTheme {
  static const String fontFamily = 'IBM Plex Sans Hebrew';

  static ThemeData light() => _build(AppTokens.light, Brightness.light);
  static ThemeData dark() => _build(AppTokens.dark, Brightness.dark);

  static ThemeData _build(AppTokens t, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      secondary: t.accent,
      onSecondary: t.onAccent,
      error: t.danger,
      onError: t.panel,
      surface: t.panel,
      onSurface: t.ink,
      surfaceContainerHighest: t.sunken,
      outline: t.line,
      outlineVariant: t.line,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: fontFamily,
      scaffoldBackgroundColor: t.canvas,
      splashFactory: NoSplash.splashFactory,
      extensions: [t],
    );

    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTokens.controlRadius),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      textTheme: base.textTheme.apply(bodyColor: t.ink, displayColor: t.ink),
      dividerTheme: DividerThemeData(color: t.line, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.panel,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(t.line),
        enabledBorder: border(t.line),
        focusedBorder: border(t.accent, 1.5),
        errorBorder: border(t.danger),
        focusedErrorBorder: border(t.danger, 1.5),
        suffixStyle: TextStyle(color: t.muted, fontSize: 15),
        helperStyle: TextStyle(color: t.muted, fontSize: 12.5),
        errorStyle: TextStyle(color: t.danger, fontSize: 12.5),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? t.onAccent : t.muted),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? t.accent : t.sunken),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? t.accent : t.line),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: t.accent,
        inactiveTrackColor: t.sunken,
        thumbColor: t.accent,
        overlayColor: t.accent.withValues(alpha: 0.14),
        thumbShape: const RoundSliderThumbShape(
            enabledThumbRadius: 11, pressedElevation: 2),
        // Large invisible touch zone around the thumb
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
        trackShape: const RoundedRectSliderTrackShape(),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        showValueIndicator: ShowValueIndicator.never,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.accent,
        selectionColor: t.accent.withValues(alpha: 0.25),
      ),
    );
  }
}
