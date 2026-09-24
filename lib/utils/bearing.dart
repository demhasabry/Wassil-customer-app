import 'dart:math';

/// Initial great-circle bearing (degrees, 0-360, 0 = north) from one
/// lat/lng point to another — used to rotate a vehicle marker to face its
/// direction of travel between two consecutive location updates.
double bearingBetween(double fromLat, double fromLng, double toLat, double toLng) {
  final phi1 = fromLat * pi / 180;
  final phi2 = toLat * pi / 180;
  final deltaLambda = (toLng - fromLng) * pi / 180;
  final y = sin(deltaLambda) * cos(phi2);
  final x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda);
  final theta = atan2(y, x);
  return (theta * 180 / pi + 360) % 360;
}
