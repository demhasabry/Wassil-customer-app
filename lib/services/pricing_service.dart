import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;

// Same public token used everywhere else in this app.
const String _mapboxPublicToken =
    'pk.eyJ1IjoiZGVtaGFzYWJyeTEzIiwiYSI6ImNtdHJ4cHdkZTA4MDYyeHNodzAydTB4OHEifQ.nK4Qu3jycEZkjLQUnQB6og';

/// Road distance in kilometers plus the actual route geometry (the roads it
/// follows), from a single Mapbox Directions call — `coordinates` is what
/// lets the map draw a real routed line instead of a straight one cutting
/// through buildings.
class RouteResult {
  final double distanceKm;
  final List<Position> coordinates;
  const RouteResult({required this.distanceKm, required this.coordinates});
}

/// Road distance and route geometry between two points via Mapbox
/// Directions — used both for the price calculation (distance) and for
/// drawing the actual route on the map (coordinates), in one API call.
///
/// [profile] picks which Mapbox Directions profile computes the route.
/// Every caller now passes "driving" regardless of vehicle type — routing
/// two/three-wheelers via the "cycling" profile produced inaccurate routes
/// (footpaths/alleys a real vehicle wouldn't take), while "driving" (what
/// the truck always used) was consistently accurate, so it's used for all
/// vehicle types now, not just truck/car.
Future<RouteResult?> fetchRoute(Position from, Position to, {String profile = 'driving'}) async {
  try {
    final url = Uri.parse(
      'https://api.mapbox.com/directions/v5/mapbox/$profile/'
      '${from.lng},${from.lat};${to.lng},${to.lat}'
      '?access_token=$_mapboxPublicToken&overview=full&geometries=geojson',
    );
    final response = await http.get(url);
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = data['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) return null;

    final route = routes[0] as Map<String, dynamic>;
    final distanceMeters = (route['distance'] as num?)?.toDouble();
    final coordinates = (route['geometry'] as Map<String, dynamic>?)?['coordinates'] as List<dynamic>?;
    if (distanceMeters == null || coordinates == null || coordinates.isEmpty) return null;

    return RouteResult(
      distanceKm: distanceMeters / 1000,
      coordinates: coordinates.map((pair) {
        final p = pair as List<dynamic>;
        return Position((p[0] as num).toDouble(), (p[1] as num).toDouble());
      }).toList(),
    );
  } catch (_) {
    return null;
  }
}

/// The actual base-price calculation: distance × the selected vehicle type's
/// price/km (a car costs more per km than a bicycle — set per vehicle type
/// in the admin dashboard's Vehicle Types tab, the same rate in every zone),
/// plus [weightSurcharge] (estimated cargo kg × that vehicle type's
/// weightSurchargePerKg — only nonzero for tuk-tuk/truck, where a loaded
/// vehicle genuinely burns more fuel than an empty one), floored at that
/// vehicle type's minimum price so very short trips still make sense for a
/// rider to accept. Rounded to the nearest whole SDG.
double computeBasePrice(double distanceKm, double pricePerKm, double minimumPrice, {double weightSurcharge = 0}) {
  final raw = distanceKm * pricePerKm + weightSurcharge;
  return raw < minimumPrice ? minimumPrice.roundToDouble() : raw.roundToDouble();
}
