import 'package:flutter/material.dart';

/// Wassil design tokens — typography.
///
/// The design handoff specifies type in per-screen sizes within named
/// "roles" (e.g. Title ranges 21–26px depending on screen), which doesn't
/// map onto Flutter's fixed 13-slot `TextTheme` — and that TextTheme has no
/// "mono" slot at all for the Amount role. So this is two tiers:
/// [textTheme] gives Material widgets a single representative size per role
/// for default chrome, while the static methods below let a screen ask for
/// the exact size the handoff specifies for that screen.
class AppTypography {
  AppTypography._();

  static const String arabicLatinFamily = 'IBM Plex Sans Arabic';
  static const String latinChromeFamily = 'IBM Plex Sans';
  static const String monoFamily = 'IBM Plex Mono';

  /// Material widgets (buttons, inputs, app bars, etc.) pick this up
  /// automatically via `ThemeData.textTheme` — one representative size per
  /// role, all in [arabicLatinFamily] since that's the single family the
  /// handoff specifies for both scripts.
  static TextTheme textTheme(Color bodyColor) => TextTheme(
        headlineMedium: display(),
        titleLarge: title(),
        titleMedium: heading(),
        bodyMedium: body(color: bodyColor),
        labelLarge: label(),
        bodySmall: caption(),
      ).apply(fontFamily: arabicLatinFamily);

  static TextStyle display({double size = 27, Color? color}) => TextStyle(
        fontFamily: arabicLatinFamily,
        fontSize: size,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Title ranges 21–26px across screens in the handoff — pass [size] for a
  /// specific screen's value, defaults to the middle of that range.
  static TextStyle title({double size = 24, Color? color}) => TextStyle(
        fontFamily: arabicLatinFamily,
        fontSize: size,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Heading ranges 15–18px across screens — defaults to 16.
  static TextStyle heading({double size = 16, Color? color}) => TextStyle(
        fontFamily: arabicLatinFamily,
        fontSize: size,
        height: 1.2,
        fontWeight: FontWeight.w600,
        color: color,
      );

  /// Body ranges 13.5–14.5px across screens — defaults to 14.
  static TextStyle body({double size = 14, Color? color}) => TextStyle(
        fontFamily: arabicLatinFamily,
        fontSize: size,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: color,
      );

  static TextStyle label({double size = 12.5, Color? color}) => TextStyle(
        fontFamily: arabicLatinFamily,
        fontSize: size,
        height: 1.0,
        fontWeight: FontWeight.w500,
        color: color,
      );

  /// Caption ranges 11–12px across screens — defaults to 11.5.
  static TextStyle caption({double size = 11.5, Color? color}) => TextStyle(
        fontFamily: arabicLatinFamily,
        fontSize: size,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: color,
      );

  /// Money, IDs, phone numbers, references. Tabular figures are load-bearing
  /// here, not cosmetic — they're what keeps bid columns and price stacks
  /// aligned when digits change. Amount ranges 17–38px across screens —
  /// defaults to 20 (the bid-card price size).
  static TextStyle amount({double size = 20, Color? color, FontWeight weight = FontWeight.w600}) =>
      TextStyle(
        fontFamily: monoFamily,
        fontSize: size,
        height: 1.0,
        fontWeight: weight,
        color: color,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Latin-only UI chrome (the handoff's "IBM Plex Sans for Latin-only UI
  /// chrome" role) — distinct from [arabicLatinFamily], which is used
  /// wherever Arabic might appear.
  static TextStyle latinChrome({double size = 14, FontWeight weight = FontWeight.w400, Color? color}) =>
      TextStyle(
        fontFamily: latinChromeFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
      );
}
