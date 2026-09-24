import 'package:flutter/material.dart';

/// Zone documents are admin-entered free text — `name` is whatever the admin
/// typed (usually English), with an optional `nameAr` for the Arabic label.
/// The stored/matched value everywhere else (delivery_requests.zone,
/// riders.activeZone, pricing lookups) stays the lowercase English `name`
/// slug; this only changes what's *displayed* to the user.
String localizedZoneName(BuildContext context, Map<String, dynamic> zoneData) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final nameAr = zoneData['nameAr'] as String?;
  if (isArabic && nameAr != null && nameAr.trim().isNotEmpty) {
    return nameAr;
  }
  return zoneData['name'] as String? ?? '';
}
