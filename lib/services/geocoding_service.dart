import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;

// Same public token used everywhere else in this app.
const String _mapboxPublicToken =
    'pk.eyJ1IjoiZGVtaGFzYWJyeTEzIiwiYSI6ImNtdHJ4cHdkZTA4MDYyeHNodzAydTB4OHEifQ.nK4Qu3jycEZkjLQUnQB6og';

/// Attempts to turn a typed address into coordinates via Mapbox's forward
/// geocoding API, constrained to Sudan for relevance. Returns null if
/// nothing matched — callers MUST treat null as "couldn't find it, ask the
/// user to drop the pin manually" rather than a silent failure. This is a
/// convenience layer over pin-dropping, not a replacement for it: hyperlocal
/// Sudanese addresses (a specific shop, a named alley) often won't resolve
/// through a global geocoder the way a city name or major road will.
Future<Position?> geocodeAddress(String query) async {
  if (query.trim().isEmpty) return null;
  try {
    final encoded = Uri.encodeComponent(query.trim());
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/$encoded.json'
      '?access_token=$_mapboxPublicToken&country=SD&limit=1',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) return null;

    final center = features[0]['center'] as List<dynamic>?;
    if (center == null || center.length != 2) return null;

    final lng = (center[0] as num).toDouble();
    final lat = (center[1] as num).toDouble();
    return Position(lng, lat);
  } catch (_) {
    return null;
  }
}

/// Turns a coordinate back into a human-readable address via Mapbox's
/// reverse geocoding API — used to fill the address field after a pin is
/// placed via the map picker or auto-detected from the device's current
/// location, so the customer sees text instead of a blank field. Returns
/// null on failure; callers should leave the address field as-is (or empty)
/// rather than show an error, since the pin itself is still valid either way.
Future<String?> reverseGeocode(Position position) async {
  try {
    final url = Uri.parse(
      'https://api.mapbox.com/geocoding/v5/mapbox.places/${position.lng},${position.lat}.json'
      '?access_token=$_mapboxPublicToken&country=SD&limit=1',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final features = data['features'] as List<dynamic>?;
    if (features == null || features.isEmpty) return null;

    return features[0]['place_name'] as String?;
  } catch (_) {
    return null;
  }
}
