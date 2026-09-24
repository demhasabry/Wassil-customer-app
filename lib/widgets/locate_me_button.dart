import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../theme/app_colors.dart';

/// A small circular "recenter on my location" button meant to be layered as
/// a Positioned overlay on top of a MapWidget. [mapboxMap] is a getter (not
/// a fixed instance) since the map is normally created asynchronously after
/// this button is first built, and may be recreated later (e.g. a fresh
/// order's map in create_request_screen.dart).
class LocateMeButton extends StatefulWidget {
  final MapboxMap? Function() mapboxMap;
  const LocateMeButton({super.key, required this.mapboxMap});

  @override
  State<LocateMeButton> createState() => _LocateMeButtonState();
}

class _LocateMeButtonState extends State<LocateMeButton> {
  bool _isLocating = false;

  Future<void> _locate() async {
    if (_isLocating) return;
    setState(() => _isLocating = true);
    try {
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        return;
      }

      geo.Position position;
      try {
        position = await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.high,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } on TimeoutException {
        final lastKnown = await geo.Geolocator.getLastKnownPosition();
        if (lastKnown == null) rethrow;
        position = lastKnown;
      }

      final map = widget.mapboxMap();
      if (map == null) return;
      await map.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(position.longitude, position.latitude)),
          zoom: 15.0,
        ),
        MapAnimationOptions(duration: 700),
      );
    } catch (_) {
      // Locating is a convenience, not a blocking requirement — fail
      // silently, same as the existing auto-detect-pickup pattern.
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: _locate,
        child: SizedBox(
          width: 42,
          height: 42,
          child: _isLocating
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              : const Icon(Icons.my_location, color: AppColors.primary, size: 21),
        ),
      ),
    );
  }
}
