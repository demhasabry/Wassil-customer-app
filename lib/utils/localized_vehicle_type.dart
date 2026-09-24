import 'package:flutter/material.dart';

/// Vehicle type documents (vehicleTypes/{typeId}) are admin-entered, same
/// pattern as zones — `name` is whatever the admin typed (usually English),
/// with an optional `nameAr` for the Arabic label. The stored/matched value
/// everywhere else (delivery_requests.vehicleType, riders.vehicleType) stays
/// the document id (a lowercase slug); this only changes what's *displayed*.
String localizedVehicleTypeName(BuildContext context, Map<String, dynamic> typeData) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final nameAr = typeData['nameAr'] as String?;
  if (isArabic && nameAr != null && nameAr.trim().isNotEmpty) {
    return nameAr;
  }
  return typeData['name'] as String? ?? '';
}
