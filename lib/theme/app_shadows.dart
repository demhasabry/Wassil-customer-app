import 'package:flutter/material.dart';

/// Wassil design tokens — shadows.
///
/// `primaryButton` is a function, not a const, because the glow color
/// differs by app (customer primary vs rider accent) — each app's
/// `app_theme.dart` calls it with its own brand color.
class AppShadows {
  AppShadows._();

  static List<BoxShadow> primaryButton(Color brandColor) => [
        BoxShadow(
          color: brandColor.withValues(alpha: 0.26),
          offset: const Offset(0, 8),
          blurRadius: 20,
        ),
      ];

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color.fromRGBO(16, 21, 32, 0.04),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const List<BoxShadow> recommendedCard = [
    BoxShadow(
      color: Color.fromRGBO(37, 81, 202, 0.10),
      offset: Offset(0, 6),
      blurRadius: 18,
    ),
  ];

  static const List<BoxShadow> bottomSheet = [
    BoxShadow(
      color: Color.fromRGBO(16, 21, 32, 0.10),
      offset: Offset(0, -8),
      blurRadius: 24,
    ),
  ];

  static const List<BoxShadow> mapFloat = [
    BoxShadow(
      color: Color.fromRGBO(16, 21, 32, 0.16),
      offset: Offset(0, 3),
      blurRadius: 12,
    ),
  ];
}
