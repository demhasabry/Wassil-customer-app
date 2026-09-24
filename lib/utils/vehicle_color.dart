import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

/// Matches the fixed dropdown the admin dashboard writes riders/{id}.vehicleColor
/// from during KYC review (a short fixed set rather than free text, so this
/// swatch mapping and the l10n label below can both stay exhaustive).
const Map<String, Color> _vehicleColorSwatches = {
  'white': Color(0xFFF5F5F5),
  'black': Color(0xFF1A1A1A),
  'silver': Color(0xFFC7C9CC),
  'red': Color(0xFFD1372E),
  'blue': Color(0xFF2A5BD7),
  'green': Color(0xFF2E9E4C),
  'yellow': Color(0xFFE6C22A),
  'grey': Color(0xFF8B8F94),
  'other': Color(0xFFB0A79A),
};

Color? vehicleColorSwatch(String? colorKey) => _vehicleColorSwatches[colorKey];

String localizedVehicleColorName(BuildContext context, String colorKey) {
  final l10n = AppLocalizations.of(context)!;
  switch (colorKey) {
    case 'white':
      return l10n.vehicleColorWhite;
    case 'black':
      return l10n.vehicleColorBlack;
    case 'silver':
      return l10n.vehicleColorSilver;
    case 'red':
      return l10n.vehicleColorRed;
    case 'blue':
      return l10n.vehicleColorBlue;
    case 'green':
      return l10n.vehicleColorGreen;
    case 'yellow':
      return l10n.vehicleColorYellow;
    case 'grey':
      return l10n.vehicleColorGrey;
    default:
      return l10n.vehicleColorOther;
  }
}
