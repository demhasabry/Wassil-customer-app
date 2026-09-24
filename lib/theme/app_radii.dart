import 'package:flutter/material.dart';

/// Wassil design tokens — corner radii.
///
/// Avatars aren't listed here — the spec gives them as "50%", not a fixed
/// px value, so call sites use `BoxShape.circle` or
/// `BorderRadius.circular(999)` directly instead of a named constant.
class AppRadii {
  AppRadii._();

  static const double control = 9;
  static const double smallTile = 11;
  static const double smallTileAlt = 13;
  static const double field = 14; // shared with the primary/secondary button
  static const double card = 16;
  static const double cardLarge = 18;
  static const double bottomSheet = 20;
  static const double bottomSheetLarge = 22;
  static const double splash = 24;
  static const double splashLarge = 32;

  static BorderRadius get controlRadius => BorderRadius.circular(control);
  static BorderRadius get smallTileRadius => BorderRadius.circular(smallTile);
  static BorderRadius get smallTileAltRadius => BorderRadius.circular(smallTileAlt);
  static BorderRadius get fieldRadius => BorderRadius.circular(field);
  static BorderRadius get cardRadius => BorderRadius.circular(card);
  static BorderRadius get cardLargeRadius => BorderRadius.circular(cardLarge);
  static const BorderRadius bottomSheetRadius =
      BorderRadius.vertical(top: Radius.circular(bottomSheet));
  static const BorderRadius bottomSheetLargeRadius =
      BorderRadius.vertical(top: Radius.circular(bottomSheetLarge));
}
