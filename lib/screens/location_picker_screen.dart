import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' show Position;
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';
import '../services/geocoding_service.dart';
import '../widgets/saved_addresses_sheet.dart';

// Same public token used everywhere else in this app — reused here as a
// Mapbox raster tile source so this screen's map still looks like the same
// Mapbox Streets style, while rendering through flutter_map (plain Flutter
// widgets, not a native platform view) rather than Mapbox's own MapWidget.
// Deliberately NOT the same native map plugin as the rest of the app: a
// second concurrent Mapbox MapWidget instance (this screen is pushed on top
// of create_request_screen's own map, which stays mounted underneath) was
// causing a black screen — two live native map surfaces at once is a known
// problem class for platform-view-backed maps. flutter_map sidesteps it
// entirely since it never creates a second native surface.
const String _mapboxPublicToken =
    'pk.eyJ1IjoiZGVtaGFzYWJyeTEzIiwiYSI6ImNtdHJ4cHdkZTA4MDYyeHNodzAydTB4OHEifQ.nK4Qu3jycEZkjLQUnQB6og';

/// A full-screen map with a pin fixed at the center of the screen — the
/// user pans/zooms the map underneath it, then confirms to pick whatever
/// coordinate ends up under the pin. Returns the picked [Position], or null
/// if they back out (system back button / app bar back arrow).
class LocationPickerScreen extends StatefulWidget {
  final Position initialPosition;
  final String title;

  const LocationPickerScreen({super.key, required this.initialPosition, required this.title});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final _searchController = TextEditingController();
  final _labelController = TextEditingController();
  StreamSubscription<MapEvent>? _mapEventSub;
  Timer? _reverseGeocodeDebounce;

  String? _resolvedAddress;
  bool _isReverseGeocoding = false;
  bool _isSearching = false;
  bool _saveThisAddress = false;

  @override
  void initState() {
    super.initState();
    _reverseGeocodeCurrentCenter();
    _mapEventSub = _mapController.mapEventStream.listen((_) {
      _reverseGeocodeDebounce?.cancel();
      _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 500), _reverseGeocodeCurrentCenter);
    });
  }

  @override
  void dispose() {
    _mapEventSub?.cancel();
    _reverseGeocodeDebounce?.cancel();
    _searchController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Position get _currentCenterPosition {
    final center = _mapController.camera.center;
    return Position(center.longitude, center.latitude);
  }

  Future<void> _reverseGeocodeCurrentCenter() async {
    setState(() => _isReverseGeocoding = true);
    final address = await reverseGeocode(_currentCenterPosition);
    if (!mounted) return;
    setState(() {
      _isReverseGeocoding = false;
      _resolvedAddress = address;
    });
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    setState(() => _isSearching = true);
    final position = await geocodeAddress(query);
    if (!mounted) return;
    setState(() => _isSearching = false);
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.addressNotFoundError)),
      );
      return;
    }
    _mapController.move(latlong.LatLng(position.lat.toDouble(), position.lng.toDouble()), 15.0);
  }

  void _useSavedAddress(SavedAddress saved) {
    _mapController.move(latlong.LatLng(saved.location.latitude, saved.location.longitude), 15.0);
    setState(() => _resolvedAddress = saved.address);
  }

  Future<void> _confirm() async {
    final position = _currentCenterPosition;
    if (_saveThisAddress && _labelController.text.trim().isNotEmpty) {
      await saveAddress(
        label: _labelController.text.trim(),
        address: _resolvedAddress?.trim().isNotEmpty == true ? _resolvedAddress!.trim() : _labelController.text.trim(),
        location: GeoPoint(position.lat.toDouble(), position.lng.toDouble()),
      );
    }
    if (!mounted) return;
    Navigator.pop(context, position);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: latlong.LatLng(
                widget.initialPosition.lat.toDouble(),
                widget.initialPosition.lng.toDouble(),
              ),
              initialZoom: 15.0,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
                additionalOptions: const {'accessToken': _mapboxPublicToken},
                userAgentPackageName: 'delivery_customer_app',
              ),
            ],
          ),
          // Fixed at the exact screen center — shifted up by half its own
          // height so the pin's bottom tip (not its bounding-box center)
          // lands on center, matching where _mapController.camera.center
          // reads from.
          IgnorePointer(
            child: Center(
              child: Transform.translate(
                offset: const Offset(0, -16),
                child: const _CenterPin(),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        borderRadius: BorderRadius.circular(21),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            shape: BoxShape.circle,
                            boxShadow: AppShadows.mapFloat,
                          ),
                          child: Icon(
                            Directionality.of(context) == TextDirection.rtl
                                ? Icons.arrow_forward
                                : Icons.arrow_back,
                            size: 20,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 42,
                          padding: const EdgeInsetsDirectional.only(start: 16, end: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: AppRadii.fieldRadius,
                            boxShadow: AppShadows.mapFloat,
                          ),
                          // Center, not just the Container's default top-alignment —
                          // isCollapsed:true strips the InputDecorator's own
                          // vertical centering, which otherwise left the hint
                          // text sitting at the top of this 42px box instead
                          // of level with the circular buttons beside it.
                          child: Center(
                            child: TextField(
                              controller: _searchController,
                              textInputAction: TextInputAction.search,
                              onSubmitted: (_) => _searchAddress(),
                              style: AppTypography.body(size: 14, color: AppColors.ink),
                              decoration: InputDecoration(
                                isCollapsed: true,
                                border: InputBorder.none,
                                hintText: l10n.addressSearchHelper,
                                hintMaxLines: 1,
                                hintStyle: AppTypography.caption(color: AppColors.mutedLight),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: _searchAddress,
                        borderRadius: BorderRadius.circular(21),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: _isSearching
                              ? const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.search, size: 20, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: savedAddressesRef().orderBy('createdAt', descending: true).limit(6).snapshots(),
                    builder: (context, snapshot) {
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) return const SizedBox.shrink();
                      final saved = docs.map(SavedAddress.fromFirestore).toList();
                      return SizedBox(
                        height: 40,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: saved.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final address = saved[index];
                            return InkWell(
                              onTap: () => _useSavedAddress(address),
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: AppShadows.mapFloat,
                                ),
                                child: Text(
                                  address.label,
                                  style: AppTypography.label(size: 13, color: AppColors.ink),
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.bottomSheetRadius,
                boxShadow: AppShadows.bottomSheet,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(widget.title, style: AppTypography.label(size: 11, color: AppColors.mutedLight)),
                  const SizedBox(height: 4),
                  _isReverseGeocoding
                      ? Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(l10n.resolvingAddressPlaceholder, style: AppTypography.body(size: 14, color: AppColors.mutedLight)),
                          ],
                        )
                      : Text(
                          _resolvedAddress ?? '—',
                          style: AppTypography.body(size: 15, color: AppColors.ink).copyWith(fontWeight: FontWeight.w600),
                        ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () => setState(() => _saveThisAddress = !_saveThisAddress),
                    child: Row(
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: _saveThisAddress ? AppColors.primary : Colors.transparent,
                            border: Border.all(color: _saveThisAddress ? AppColors.primary : AppColors.border, width: 1.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _saveThisAddress ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
                        ),
                        const SizedBox(width: 10),
                        Text(l10n.saveThisAddressLabel, style: AppTypography.body(size: 14, color: AppColors.ink)),
                      ],
                    ),
                  ),
                  if (_saveThisAddress) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _labelController,
                      style: AppTypography.body(size: 14, color: AppColors.ink),
                      decoration: InputDecoration(hintText: l10n.addressLabelHint),
                    ),
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _confirm,
                    child: Text(l10n.confirmLocationButton),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The design handoff's teardrop map pin: a square with three rounded
/// corners rotated -45° so the one sharp corner becomes the downward tip,
/// plus a soft ground-shadow ellipse beneath it.
class _CenterPin extends StatelessWidget {
  const _CenterPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -45 * 3.14159265 / 180,
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.accent,
              border: Border.all(color: Colors.white, width: 3),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(13),
                topRight: Radius.circular(13),
                bottomRight: Radius.circular(13),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color.fromRGBO(16, 21, 32, 0.35),
                  offset: Offset(0, 3),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(16, 21, 32, 0.24),
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}
