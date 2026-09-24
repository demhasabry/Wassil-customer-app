import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
import 'bid_list_screen.dart';
import 'tracking_screen.dart';
import 'customer_profile_screen.dart';
import 'location_picker_screen.dart';
import '../widgets/saved_addresses_sheet.dart' show recordRecentLocation;
import '../services/pricing_service.dart';
import '../services/geocoding_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/localized_zone_name.dart';
import '../utils/localized_vehicle_type.dart';
import '../utils/bearing.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/locate_me_button.dart';

/// Atbara's approximate center — used as the map's default camera position.
final Position _atbaraCenter = Position(33.9962, 17.7020); // (lng, lat)

class CreateRequestScreen extends StatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  State<CreateRequestScreen> createState() => _CreateRequestScreenState();
}

class _CreateRequestScreenState extends State<CreateRequestScreen> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  CircleAnnotation? _pickupAnnotation;
  CircleAnnotation? _dropoffAnnotation;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _routeLine;

  // Nearby online riders, shown on this map before the request even exists
  // yet — previously only visible after submitting, on bid_list_screen.dart
  // 's own nearby-riders map. Same icon set/rasterization as that screen.
  PointAnnotationManager? _riderManager;
  final Map<String, PointAnnotation> _riderAnnotations = {};
  // Previous known position per rider — compared against each new update to
  // compute a bearing, so the marker rotates to face its direction of
  // travel instead of always pointing the same static way.
  final Map<String, Position> _riderLastPosition = {};
  final Map<String, Uint8List> _vehicleIcons = {};
  Uint8List? _fallbackVehicleIcon;
  StreamSubscription<QuerySnapshot>? _nearbyRidersSubscription;

  Position? _pickupPosition;
  Position? _dropoffPosition;
  final _pickupAddressController = TextEditingController();
  final _dropoffAddressController = TextEditingController();
  final _packageDescController = TextEditingController();
  final _purchaseBudgetController = TextEditingController();
  // Only shown/required for tuk-tuk and truck (see _requiresWeightEstimate)
  // — a loaded truck burns meaningfully more fuel than an empty one, so
  // pricing needs to account for actual cargo weight instead of a vague
  // small/medium/large label that has zero effect on the price.
  final _estimatedWeightController = TextEditingController();
  final _pickupPhoneController = TextEditingController();
  final _receiverPhoneController = TextEditingController();
  String _sizeCategory = 'small';
  bool _isSubmitting = false;

  // Base price is calculated automatically (distance × the zone's current
  // price-per-km, floored at the zone's minimum) — no longer typed in by
  // the customer, which previously let anyone suggest an unrealistically
  // low price. Riders can still bid, just capped at 3x this value
  // (enforced server-side in submitBid.js).
  double? _computedBasePrice;
  double? _distanceKm;
  bool _isCalculatingPrice = false;
  String? _priceCalculationError;

  // The actual road-following path from the same Directions call that
  // computes distance/price — drawn on the map instead of a straight line
  // between the two pins, which used to cut through buildings.
  List<Position>? _routeCoordinates;

  // A redeemed-but-unused promo code, if any (see redeemPromoCode.js and
  // customer_profile_screen.dart's redeem dialog) — applied to the price
  // shown here and consumed once this request is successfully created.
  Map<String, dynamic>? _pendingPromoDiscount;

  // The customer's own name/phone — defaults the pickup contact field so
  // most orders (picking up their own package) need no manual typing
  // (re-applied in _onMapCreated since that clears the field on every fresh
  // order), and denormalized onto the request doc itself so the rider app
  // can show/call the customer without needing a cross-user read of
  // users/{customerId} (blocked by that collection's own security rules —
  // see the identical issue this caused in tracking_screen.dart's
  // rider-facing contact bar).
  String? _myName;
  String? _myPhone;
  String? _myPhotoUrl;

  double? get _promoDiscountAmount =>
      _pendingPromoDiscount != null ? (_pendingPromoDiscount!['amount'] as num).toDouble() : null;

  double? get _effectivePrice {
    if (_computedBasePrice == null) return null;
    final discount = _promoDiscountAmount ?? 0;
    return (_computedBasePrice! - discount).clamp(0, _computedBasePrice!);
  }

  // Zone is picked per-request (it's about where the delivery happens, not
  // a permanent account setting) — this used to be hardcoded to "atbara",
  // which won't work once Khartoum goes live alongside it.
  List<QueryDocumentSnapshot> _zoneDocs = [];
  String? _selectedZoneName;

  // Which vehicle type this request is priced/eligible for — see
  // pricing_service.dart's priceMultiplier and submitBid.js's matching
  // check (only riders with this exact vehicle type can bid).
  List<QueryDocumentSnapshot> _vehicleTypeDocs = [];
  String? _selectedVehicleType;

  // Created ONCE, not on every build() — otherwise every setState() (e.g.
  // every map tap) would create a brand-new stream, briefly flipping this
  // screen to a loading state and destroying/recreating the map widget
  // underneath it, which is what caused the annotation-delete crash.
  late final Stream<QuerySnapshot> _activeRequestStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _activeRequestStream = FirebaseFirestore.instance
        .collection('delivery_requests')
        .where('customerId', isEqualTo: uid)
        .where('status', whereIn: ['open', 'assigned', 'picked_up'])
        .limit(1)
        .snapshots();
    _loadZones();
    _loadVehicleTypes();
    _loadPromoDiscount();
    _loadMyProfile();
    // Recompute the price surcharge as-you-type — cheap (no network call,
    // unlike a full _recalculatePrice()) since the route distance is
    // already cached in _distanceKm.
    _estimatedWeightController.addListener(_applyWeightSurcharge);
  }

  @override
  void dispose() {
    _nearbyRidersSubscription?.cancel();
    _estimatedWeightController.dispose();
    super.dispose();
  }

  void _applyWeightSurcharge() {
    if (_distanceKm == null) return;
    setState(() {
      _computedBasePrice = computeBasePrice(
        _distanceKm!,
        _selectedVehicleTypePricePerKm,
        _selectedVehicleTypeMinimumPrice,
        weightSurcharge: _weightSurchargeAmount,
      );
    });
  }

  Future<void> _loadMyProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!mounted) return;
    _myName = doc.data()?['name'] as String?;
    _myPhone = doc.data()?['phone'] as String?;
    _myPhotoUrl = doc.data()?['photoUrl'] as String?;
    if (_myPhone != null && _pickupPhoneController.text.isEmpty) {
      setState(() => _pickupPhoneController.text = _myPhone!);
    }
  }

  Future<void> _loadPromoDiscount() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final discount = doc.data()?['pendingPromoDiscount'] as Map<String, dynamic>?;
    if (mounted) setState(() => _pendingPromoDiscount = discount);
  }

  // Persists the customer's last-picked zone across orders — every new
  // order is a brand-new CreateRequestScreen instance (pushAndRemoveUntil
  // after a cancel, push after a completed delivery's rating screen), so a
  // plain in-memory field here would silently reset to whichever zone
  // happens to sort first on every single order.
  static const _lastZonePrefsKey = 'last_selected_zone';

  Future<void> _loadZones() async {
    final snap = await FirebaseFirestore.instance.collection('zones').where('active', isEqualTo: true).get();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final savedZone = prefs.getString(_lastZonePrefsKey);
    if (!mounted) return;
    setState(() {
      _zoneDocs = snap.docs;
      final zoneNames = _zoneDocs.map((d) => (d.data() as Map<String, dynamic>)['name'] as String?);
      final savedZoneStillValid = savedZone != null && zoneNames.contains(savedZone);
      _selectedZoneName ??= savedZoneStillValid
          ? savedZone
          : (_zoneDocs.isNotEmpty ? (_zoneDocs.first.data() as Map<String, dynamic>)['name'] as String? : null);
      _correctVehicleTypeForZone();
    });
    // This can resolve after _onMapCreated already ran (its own nearby-
    // riders subscribe attempt found _selectedZoneName still null at that
    // point) — (re)subscribe now that a zone is actually known.
    _subscribeToNearbyRiders();

    // _onMapCreated's own camera set (via _initialCameraCenter) almost
    // always fires before this async Firestore + SharedPreferences load
    // finishes, so it locks the map onto the hardcoded Atbara fallback
    // before the remembered zone is even known — nothing corrected it
    // afterward, which is why the map visually looked like it "always
    // resets to default" on every login even though _selectedZoneName
    // itself was restored correctly. Re-centering here, now that the real
    // zone is known, is the fix (same call _onZoneChanged already makes
    // when the customer picks a zone manually).
    _mapboxMap?.setCamera(CameraOptions(center: Point(coordinates: _initialCameraCenter), zoom: 13.0));
  }

  // Same reasoning as _lastZonePrefsKey — every new order is a brand-new
  // CreateRequestScreen instance, so without this a plain in-memory field
  // would silently reset to whichever vehicle type sorts first on every
  // single order instead of staying on what the customer actually uses.
  static const _lastVehicleTypePrefsKey = 'last_selected_vehicle_type';

  Future<void> _loadVehicleTypes() async {
    final snap = await FirebaseFirestore.instance.collection('vehicleTypes').where('active', isEqualTo: true).get();
    if (!mounted) return;
    final prefs = await SharedPreferences.getInstance();
    final savedVehicleType = prefs.getString(_lastVehicleTypePrefsKey);
    if (!mounted) return;
    setState(() {
      _vehicleTypeDocs = snap.docs;
      final savedTypeStillValid = savedVehicleType != null && _vehicleTypeDocs.any((d) => d.id == savedVehicleType);
      _selectedVehicleType ??= savedTypeStillValid
          ? savedVehicleType
          : (_vehicleTypeDocs.isNotEmpty ? _vehicleTypeDocs.first.id : null);
      // _correctVehicleTypeForZone below still has final say — a remembered
      // type that this zone doesn't allow gets swapped out the same as any
      // other now-invalid selection.
      _correctVehicleTypeForZone();
    });
    // Same reasoning as _loadZones()'s identical call — this can resolve
    // after _onMapCreated's own nearby-riders subscribe attempt found
    // _selectedVehicleType still null.
    _subscribeToNearbyRiders();
  }

  // Zones and vehicle types load in parallel from initState with no fixed
  // order, so the very first auto-selected pairing (first zone × first
  // vehicle type) isn't guaranteed to be valid — this re-checks it whenever
  // either finishes loading, or a zone is explicitly changed. Must be called
  // from inside a setState block (it only mutates state, no setState of its
  // own) since both call sites already are.
  void _correctVehicleTypeForZone() {
    if (_selectedVehicleType == null || _isVehicleTypeAllowed(_selectedVehicleType!)) return;
    final allowed = _allowedVehicleTypesForZone;
    final firstAllowedDoc = _vehicleTypeDocs.where((d) => allowed == null || allowed.contains(d.id));
    _selectedVehicleType = firstAllowedDoc.isNotEmpty ? firstAllowedDoc.first.id : null;
  }

  Map<String, dynamic>? get _selectedVehicleTypeData {
    final match = _vehicleTypeDocs.where((d) => d.id == _selectedVehicleType);
    if (match.isEmpty) return null;
    return match.first.data() as Map<String, dynamic>;
  }

  Map<String, dynamic>? get _selectedZoneData {
    final match = _zoneDocs.where((d) => (d.data() as Map<String, dynamic>)['name'] == _selectedZoneName);
    if (match.isEmpty) return null;
    return match.first.data() as Map<String, dynamic>;
  }

  // null means the zone doesn't restrict vehicle types at all — matches the
  // same convention already used in rider_app/home_screen.dart and
  // submitBid.js (a missing/unset field is "all types allowed", not "none").
  List<String>? get _allowedVehicleTypesForZone => (_selectedZoneData?['allowedVehicleTypes'] as List?)?.cast<String>();

  bool _isVehicleTypeAllowed(String typeId) {
    final allowed = _allowedVehicleTypesForZone;
    return allowed == null || allowed.contains(typeId);
  }

  double get _selectedVehicleTypePricePerKm =>
      (_selectedVehicleTypeData?['pricePerKm'] as num?)?.toDouble() ?? 50;

  double get _selectedVehicleTypeMinimumPrice =>
      (_selectedVehicleTypeData?['minimumPrice'] as num?)?.toDouble() ?? 300;

  double get _selectedVehicleTypeWeightSurchargePerKg =>
      (_selectedVehicleTypeData?['weightSurchargePerKg'] as num?)?.toDouble() ?? 0;

  // Same substring heuristic already used for vehicle icons (_vehicleTypeIcon
  // below) — tuk-tuk and truck are the vehicle types that actually carry
  // bulk cargo where load weight meaningfully changes fuel cost; a
  // motorbike/car/bicycle delivery doesn't need this.
  bool get _requiresWeightEstimate {
    final id = '${_selectedVehicleType ?? ''} ${_selectedVehicleTypeData?['name'] ?? ''}'.toLowerCase();
    return id.contains('tuk') || id.contains('rickshaw') || id.contains('truck') || id.contains('lorry');
  }

  double get _weightSurchargeAmount {
    if (!_requiresWeightEstimate) return 0;
    final kg = double.tryParse(_estimatedWeightController.text.trim()) ?? 0;
    return kg * _selectedVehicleTypeWeightSurchargePerKg;
  }

  Future<void> _onVehicleTypeChanged(String? newType) async {
    if (newType == null || newType == _selectedVehicleType) return;
    setState(() {
      _selectedVehicleType = newType;
      _computedBasePrice = null;
    });
    // Best-effort, not awaited before continuing — see _lastVehicleTypePrefsKey.
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_lastVehicleTypePrefsKey, newType));
    // The nearby-riders layer is scoped to whichever vehicle type is
    // currently selected — switching from Bicycle to Tuk-tuk should swap
    // which markers show, not just leave the old ones up.
    _subscribeToNearbyRiders();
    if (_pickupPosition != null && _dropoffPosition != null) {
      await _recalculatePrice();
      // The routing profile depends on vehicle type (see
      // _mapboxProfileFor) — the line on the map needs redrawing with the
      // new route geometry _recalculatePrice just fetched, not left showing
      // the previous vehicle type's path.
      await _updateRouteLine();
    }
  }

  Position get _initialCameraCenter {
    if (_selectedZoneName != null) {
      final match = _zoneDocs.where((d) => (d.data() as Map<String, dynamic>)['name'] == _selectedZoneName);
      if (match.isNotEmpty) {
        final data = match.first.data() as Map<String, dynamic>;
        final lat = (data['centerLat'] as num?)?.toDouble();
        final lng = (data['centerLng'] as num?)?.toDouble();
        if (lat != null && lng != null) return Position(lng, lat);
      }
    }
    return _atbaraCenter;
  }

  Future<void> _onZoneChanged(String? newZone) async {
    if (newZone == null || newZone == _selectedZoneName) return;
    setState(() => _selectedZoneName = newZone);
    // Best-effort, not awaited before continuing — see _lastZonePrefsKey.
    SharedPreferences.getInstance().then((prefs) => prefs.setString(_lastZonePrefsKey, newZone));

    // Pins placed for the previous zone don't make sense anymore — clear
    // them rather than silently submitting a request with a pickup pin in
    // the wrong city.
    final manager = _circleAnnotationManager;
    if (manager != null) {
      if (_pickupAnnotation != null) await manager.delete(_pickupAnnotation!);
      if (_dropoffAnnotation != null) await manager.delete(_dropoffAnnotation!);
    }
    final lineManager = _polylineAnnotationManager;
    if (lineManager != null && _routeLine != null) {
      await lineManager.delete(_routeLine!);
    }
    setState(() {
      _pickupAnnotation = null;
      _dropoffAnnotation = null;
      _routeLine = null;
      _pickupPosition = null;
      _dropoffPosition = null;
      _computedBasePrice = null;
      _distanceKm = null;
      _routeCoordinates = null;
      _priceCalculationError = null;
      // The vehicle type the customer had picked may not be allowed in the
      // new zone (e.g. bicycles only in one zone, trucks in another) —
      // silently switch to the first vehicle type this zone does allow
      // rather than leaving a now-invalid selection highlighted.
      _correctVehicleTypeForZone();
    });
    _subscribeToNearbyRiders();

    _mapboxMap?.setCamera(CameraOptions(center: Point(coordinates: _initialCameraCenter), zoom: 13.0));
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    // This map fills the screen (Positioned.fill, inset below the status
    // bar) and is a passive preview only — tapping does nothing, nothing
    // here rotates the map. Mapbox's default compass ornament sits 4px from
    // the map's own top-right corner; disabling it removes a control that
    // served no purpose here anyway rather than letting it collide with
    // something else later.
    unawaited(mapboxMap.compass.updateSettings(CompassSettings(enabled: false)));
    // "You are here" puck, separate from the pickup pin — lets the customer
    // see their own live position for orientation even after they've
    // dragged/re-picked the pickup pin away from it.
    unawaited(mapboxMap.location.updateSettings(
      LocationComponentSettings(enabled: true, pulsingEnabled: true),
    ));
    _circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();
    _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    _riderManager = await mapboxMap.annotations.createPointAnnotationManager();
    _riderAnnotations.clear();
    if (_fallbackVehicleIcon == null) {
      final fallbackData = await rootBundle.load('assets/motorcycle_icon.png');
      _fallbackVehicleIcon = fallbackData.buffer.asUint8List();
      for (final entry in const {
        'bicycle': 'assets/vehicle_markers/bicycle.png',
        'motorcycle': 'assets/vehicle_markers/motorcycle.png',
        'tuktuk': 'assets/vehicle_markers/tuktuk.png',
        'truck': 'assets/vehicle_markers/truck.png',
      }.entries) {
        final data = await rootBundle.load(entry.value);
        _vehicleIcons[entry.key] = data.buffer.asUint8List();
      }
    }
    _subscribeToNearbyRiders();
    // Reset everything — this form's State object survives across multiple
    // orders (it's the persistent root screen, not recreated each time), but
    // the map/annotations underneath it ARE torn down and rebuilt between
    // orders. Without this, a second order could silently submit with the
    // first order's pins, address text, and package details still sitting
    // in these fields, or crash trying to delete an annotation that no
    // longer exists on this new map instance.
    _pickupAnnotation = null;
    _dropoffAnnotation = null;
    _routeLine = null;
    _pickupPosition = null;
    _dropoffPosition = null;
    _pickupAddressController.clear();
    _dropoffAddressController.clear();
    _packageDescController.clear();
    _purchaseBudgetController.clear();
    _estimatedWeightController.clear();
    _pickupPhoneController.text = _myPhone ?? '';
    _receiverPhoneController.clear();
    _computedBasePrice = null;
    _distanceKm = null;
    _routeCoordinates = null;
    _priceCalculationError = null;
    if (mounted) setState(() => _sizeCategory = 'small');

    // Deferred, not called directly here: requesting the location permission
    // (which shows a system dialog) while this callback is still inside the
    // native map plugin's own creation/attachment sequence is what caused
    // the black-screen bug — the permission prompt was racing the native
    // map surface's own setup. Waiting for a frame to render, plus a short
    // buffer, lets the map view finish settling first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 400), _detectCurrentLocationForPickup);
    });
  }

  Future<bool> _ensureLocationPermission() async {
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    return permission == geo.LocationPermission.always || permission == geo.LocationPermission.whileInUse;
  }

  // Defaults the pickup pin to the customer's current location so most
  // orders need zero manual pin-dropping for pickup — silently does nothing
  // if permission is denied or detection fails, since the map-pin icon and
  // address search remain available as manual fallbacks either way.
  Future<void> _detectCurrentLocationForPickup() async {
    try {
      final hasPermission = await _ensureLocationPermission();
      if (!hasPermission) return;

      // A fresh GPS fix can hang for a long time indoors or with poor
      // signal, leaving pickup unset the whole time — fall back to the
      // last-known (cached, instant) position so pickup still defaults to
      // somewhere reasonable rather than nothing.
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
      if (!mounted || _pickupPosition != null) return; // user may have already picked one while we awaited

      final mapboxPosition = Position(position.longitude, position.latitude);
      await _placePin(true, mapboxPosition);
      _mapboxMap?.setCamera(CameraOptions(center: Point(coordinates: mapboxPosition), zoom: 15.0));

      final address = await reverseGeocode(mapboxPosition);
      if (mounted) {
        // Falling back to raw coordinates when reverse geocoding fails
        // (network hiccup, or the fix landed just outside Mapbox's
        // country=SD results) — pickup was still genuinely captured (the
        // pin above is real and price calculation works off the coordinate,
        // not this text), so leaving the box blank here was misleading:
        // it read as "detection failed" when it hadn't.
        _pickupAddressController.text = address ?? _coordinateLabel(mapboxPosition);
        setState(() {});
      }
    } catch (_) {
      // Location unavailable (denied, disabled, timed out) — leave pickup
      // unset; the customer can still set it manually.
    }
  }

  Future<void> _placePin(bool isPickup, Position position) async {
    final manager = _circleAnnotationManager;
    if (manager == null) return;

    if (isPickup) {
      if (_pickupAnnotation != null) {
        await manager.delete(_pickupAnnotation!);
      }
      _pickupAnnotation = await manager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: position),
          // Pickup is an accent-colored circle per the design handoff — the
          // matching drop-off square isn't achievable with a plain circle
          // annotation; that needs a custom marker image, left for later.
          circleColor: AppColors.accent.toARGB32(),
          circleRadius: 8.0,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2.0,
        ),
      );
      setState(() => _pickupPosition = position);
    } else {
      if (_dropoffAnnotation != null) {
        await manager.delete(_dropoffAnnotation!);
      }
      _dropoffAnnotation = await manager.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: position),
          circleColor: AppColors.primary.toARGB32(),
          circleRadius: 8.0,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2.0,
        ),
      );
      setState(() => _dropoffPosition = position);
    }

    if (_pickupPosition != null && _dropoffPosition != null) {
      await _recalculatePrice();
      await _updateRouteLine();
      await _fitCameraToPins();
    }
  }

  // The actual road-following path (set by _recalculatePrice alongside the
  // distance, from the same Directions call) — falls back to a straight
  // line only if that call failed, so there's still some visual connection
  // between the pins rather than none.
  Future<void> _updateRouteLine() async {
    final manager = _polylineAnnotationManager;
    final pickup = _pickupPosition;
    final dropoff = _dropoffPosition;
    if (manager == null || pickup == null || dropoff == null) return;

    if (_routeLine != null) {
      await manager.delete(_routeLine!);
    }
    _routeLine = await manager.create(
      PolylineAnnotationOptions(
        geometry: LineString(coordinates: _routeCoordinates ?? [pickup, dropoff]),
        lineColor: AppColors.primary.toARGB32(),
        lineWidth: 3.0,
      ),
    );
  }

  // Lets the customer see who's around before they've even submitted a
  // request — previously nearby riders only appeared after submission, on
  // bid_list_screen.dart's own map. Re-subscribes (cancelling any previous
  // listener) whenever the zone changes, since "nearby" only makes sense
  // relative to a specific zone.
  void _subscribeToNearbyRiders() {
    _nearbyRidersSubscription?.cancel();
    final zone = _selectedZoneName;
    final vehicleType = _selectedVehicleType;
    if (zone == null || vehicleType == null) return;
    // riders.activeZone is written lowercased everywhere it's set
    // (rider_profile_screen.dart, otp_verify_screen.dart,
    // profile_setup_screen.dart) — _selectedZoneName here is the raw,
    // properly-cased zone name from the dropdown (e.g. "Khartoum"), so an
    // exact-match query against it silently matched nothing. The
    // delivery_requests.zone field this same query is modeled on (see
    // bid_list_screen.dart's _NearbyRidersMap) only worked because the
    // create-request submit path lowercases it before writing — do the same
    // here instead of writing it out.
    //
    // Also scoped to the currently-selected vehicle type — only a rider on
    // that same vehicle type can actually bid on this request once it's
    // submitted (submitBid.js rejects a mismatch), so showing every online
    // rider regardless of vehicle type here was misleading: a customer
    // picking "Tuk-tuk" doesn't care that 5 bicycles are nearby if zero
    // tuk-tuks are.
    _nearbyRidersSubscription = FirebaseFirestore.instance
        .collection('riders')
        .where('isOnline', isEqualTo: true)
        .where('activeZone', isEqualTo: zone.toLowerCase())
        .where('vehicleType', isEqualTo: vehicleType)
        .snapshots()
        .listen(_onNearbyRidersUpdate);
  }

  // Matches _vehicleTypeIcon's substring heuristic, resolved against
  // _vehicleTypeDocs (already loaded for the vehicle-type chips) instead of
  // a separate cache.
  Uint8List _iconForVehicleType(String? typeId) {
    final match = _vehicleTypeDocs.where((d) => d.id == typeId);
    final name = match.isNotEmpty ? (match.first.data() as Map<String, dynamic>)['name'] as String? : null;
    final id = '${typeId ?? ''} ${name ?? ''}'.toLowerCase();
    // "motorbike" contains "bike" as a substring, so a bare id.contains
    // ('bike') check here matched the doc id admin's default seed actually
    // uses for motorcycles ("motorbike") — every motorbike silently got the
    // bicycle icon. Excluding "motor" fixes it without breaking the
    // legitimate "bike" match for a genuine e-bike/moped type name.
    if (id.contains('bicycle') || (id.contains('bike') && !id.contains('motor'))) {
      return _vehicleIcons['bicycle'] ?? _fallbackVehicleIcon!;
    }
    if (id.contains('tuk') || id.contains('rickshaw')) return _vehicleIcons['tuktuk'] ?? _fallbackVehicleIcon!;
    if (id.contains('truck') || id.contains('lorry')) return _vehicleIcons['truck'] ?? _fallbackVehicleIcon!;
    if (id.contains('moto') || id.contains('scooter')) return _vehicleIcons['motorcycle'] ?? _fallbackVehicleIcon!;
    return _fallbackVehicleIcon!;
  }

  Future<void> _onNearbyRidersUpdate(QuerySnapshot snapshot) async {
    final manager = _riderManager;
    if (manager == null || _fallbackVehicleIcon == null) return;

    final seenIds = <String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final location = data['currentLocation'] as GeoPoint?;
      if (location == null) continue;
      seenIds.add(doc.id);

      final position = Position(location.longitude, location.latitude);
      final existing = _riderAnnotations[doc.id];
      final lastPosition = _riderLastPosition[doc.id];
      if (existing != null) {
        // Below ~3m is GPS noise, not real movement — rotating the icon on
        // every tiny jitter made it spin in place instead of holding a
        // heading while the rider is briefly stopped.
        if (lastPosition != null) {
          final movedMeters = geo.Geolocator.distanceBetween(
            lastPosition.lat.toDouble(), lastPosition.lng.toDouble(),
            position.lat.toDouble(), position.lng.toDouble(),
          );
          if (movedMeters > 3) {
            existing.iconRotate = bearingBetween(
              lastPosition.lat.toDouble(), lastPosition.lng.toDouble(),
              position.lat.toDouble(), position.lng.toDouble(),
            );
          }
        }
        existing.geometry = Point(coordinates: position);
        await manager.update(existing);
      } else {
        final created = await manager.create(
          PointAnnotationOptions(
            geometry: Point(coordinates: position),
            image: _iconForVehicleType(data['vehicleType'] as String?),
            iconSize: 0.16,
          ),
        );
        _riderAnnotations[doc.id] = created;
      }
      _riderLastPosition[doc.id] = position;
    }

    final staleIds = _riderAnnotations.keys.where((id) => !seenIds.contains(id)).toList();
    for (final id in staleIds) {
      final annotation = _riderAnnotations.remove(id);
      _riderLastPosition.remove(id);
      if (annotation != null) await manager.delete(annotation);
    }
  }

  // The bottom sheet in this map-first layout covers roughly the lower half
  // of the screen — bias the camera toward the top so the route and both
  // pins land in the visible band above it instead of partly hidden
  // underneath (see design_handoff_wassil/CREATE-REQUEST-1a.md).
  Future<void> _fitCameraToPins() async {
    final map = _mapboxMap;
    final pickup = _pickupPosition;
    final dropoff = _dropoffPosition;
    if (map == null || pickup == null || dropoff == null || !mounted) return;
    // Fits the whole route, not just the two endpoints — a routed path can
    // bow out from the straight line between them (a road looping around a
    // block), and fitting only the endpoints could crop part of it.
    final routePoints = (_routeCoordinates ?? [pickup, dropoff]).map((p) => Point(coordinates: p)).toList();
    final camera = await map.cameraForCoordinatesPadding(
      routePoints,
      CameraOptions(),
      MbxEdgeInsets(
        top: 90,
        left: 60,
        right: 60,
        bottom: MediaQuery.sizeOf(context).height * 0.44,
      ),
      null,
      null,
    );
    if (mounted) await map.setCamera(camera);
  }

  Future<void> _recalculatePrice() async {
    final pickup = _pickupPosition;
    final dropoff = _dropoffPosition;
    if (pickup == null || dropoff == null) return;

    setState(() {
      _isCalculatingPrice = true;
      _priceCalculationError = null;
    });

    final route = await fetchRoute(
      pickup,
      dropoff,
      profile: _mapboxProfileFor(_selectedVehicleType ?? '', _selectedVehicleTypeData),
    );
    if (route == null) {
      if (mounted) {
        setState(() {
          _isCalculatingPrice = false;
          _priceCalculationError = AppLocalizations.of(context)!.priceCalculationError;
        });
      }
      return;
    }

    final basePrice = computeBasePrice(
      route.distanceKm,
      _selectedVehicleTypePricePerKm,
      _selectedVehicleTypeMinimumPrice,
      weightSurcharge: _weightSurchargeAmount,
    );

    if (mounted) {
      setState(() {
        _distanceKm = route.distanceKm;
        _routeCoordinates = route.coordinates;
        _computedBasePrice = basePrice;
        _isCalculatingPrice = false;
      });
    }
  }

  Future<void> _pickLocationOnMap(bool isPickup) async {
    final l10n = AppLocalizations.of(context)!;
    final initialPosition = (isPickup ? _pickupPosition : _dropoffPosition) ?? _initialCameraCenter;
    final picked = await Navigator.push<Position>(
      context,
      MaterialPageRoute(
        builder: (_) => LocationPickerScreen(
          initialPosition: initialPosition,
          title: isPickup ? l10n.pickupAddressTitle : l10n.dropoffAddressTitle,
        ),
      ),
    );
    if (picked == null) return;

    await _placePin(isPickup, picked);
    // Once both pins are placed, _placePin already fits the camera to both
    // of them — recentering on just this one pin afterward would undo that.
    if (_pickupPosition == null || _dropoffPosition == null) {
      _mapboxMap?.setCamera(CameraOptions(center: Point(coordinates: picked), zoom: 15.0));
    }

    final address = await reverseGeocode(picked);
    if (!mounted) return;
    // Falls back to raw coordinates when reverse geocoding fails — see the
    // identical fallback in _detectCurrentLocationForPickup. The pin itself
    // is always placed regardless; this only affects the display text.
    (isPickup ? _pickupAddressController : _dropoffAddressController).text = address ?? _coordinateLabel(picked);
    // The floating address card reads the controller's .text directly
    // (not via a live TextField), so it needs an explicit rebuild to
    // pick up the address set above.
    setState(() {});
  }

  String _coordinateLabel(Position position) =>
      '${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)}';

  Future<void> _submitRequest() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedZoneName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectZoneError)),
      );
      return;
    }
    if (_selectedVehicleType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.selectVehicleTypeError)),
      );
      return;
    }
    if (_pickupPosition == null || _dropoffPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.setPickupDropoffError)),
      );
      return;
    }
    if (_packageDescController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.describePackageError)),
      );
      return;
    }
    final estimatedWeightKg = double.tryParse(_estimatedWeightController.text.trim());
    if (_requiresWeightEstimate && (estimatedWeightKg == null || estimatedWeightKg <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.estimatedWeightRequiredError)),
      );
      return;
    }
    if (_computedBasePrice == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.priceStillCalculatingError)),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final suggestedPrice = _effectivePrice;
    final redeemedPromoCode = _pendingPromoDiscount != null;

    // Without this try/catch, any failure here (a permission error, a
    // dropped connection to the emulator, etc.) left _isSubmitting stuck
    // true forever — the button would just spin with no way to recover.
    try {
      final docRef = await FirebaseFirestore.instance.collection('delivery_requests').add({
        'customerId': uid,
        'customerName': _myName,
        'customerPhone': _myPhone,
        'customerPhotoUrl': _myPhotoUrl,
        'pickup': {
          // Position is (lng, lat); Firestore GeoPoint is (lat, lng) — don't mix these up.
          'geopoint': GeoPoint(_pickupPosition!.lat.toDouble(), _pickupPosition!.lng.toDouble()),
          'address': _pickupAddressController.text.trim(),
        },
        'dropoff': {
          'geopoint': GeoPoint(_dropoffPosition!.lat.toDouble(), _dropoffPosition!.lng.toDouble()),
          'address': _dropoffAddressController.text.trim(),
        },
        'packageInfo': {
          'description': _packageDescController.text.trim(),
          'sizeCategory': _sizeCategory,
          'purchaseBudget': double.tryParse(_purchaseBudgetController.text.trim()),
          'estimatedWeightKg': _requiresWeightEstimate ? estimatedWeightKg : null,
        },
        'suggestedPrice': suggestedPrice,
        'status': 'open',
        'zone': (_selectedZoneName ?? 'atbara').toLowerCase(),
        'vehicleType': _selectedVehicleType,
        'createdAt': FieldValue.serverTimestamp(),
        'biddingClosesAt': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 5))),
        'pickupContactPhone': _pickupPhoneController.text.trim().isEmpty ? null : _pickupPhoneController.text.trim(),
        'receiverContactPhone':
            _receiverPhoneController.text.trim().isEmpty ? null : _receiverPhoneController.text.trim(),
      });

      // Consume the discount now that it's baked into this request's price —
      // a plain client write is fine here (Firestore rules only allow the
      // owner to clear this field to null, never set a real value themselves).
      if (redeemedPromoCode) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({'pendingPromoDiscount': null});
      }

      // Best-effort, not awaited — lets the next request quickly reuse
      // pickup/drop-off without holding up navigation to the bid screen.
      recordRecentLocation(
        address: _pickupAddressController.text.trim(),
        location: GeoPoint(_pickupPosition!.lat.toDouble(), _pickupPosition!.lng.toDouble()),
      );
      recordRecentLocation(
        address: _dropoffAddressController.text.trim(),
        location: GeoPoint(_dropoffPosition!.lat.toDouble(), _dropoffPosition!.lng.toDouble()),
      );

      if (!mounted) return;

      // pushReplacement (not push): this screen's own StreamBuilder listens
      // for an active request and would otherwise flip to the "Active Order"
      // branch — re-mounting its embedded Mapbox map — the instant the write
      // above lands, racing the map already being created inside the new
      // BidListScreen. Two concurrent native Mapbox views is exactly what
      // caused the black-screen bug fixed earlier in location_picker_screen;
      // replacing (not covering) this route removes it from the tree
      // immediately instead of waiting on that async race.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => BidListScreen(requestId: docRef.id)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      // A suspended customer's request write is rejected by firestore.rules
      // (isCurrentlySuspended check) as a permission-denied error — worth
      // its own message rather than the generic "something went wrong",
      // since there's nothing to retry here.
      final isSuspended = e is FirebaseException && e.code == 'permission-denied';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isSuspended ? l10n.accountSuspendedError : l10n.submitRequestError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<QuerySnapshot>(
      stream: _activeRequestStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final activeDocs = snapshot.data?.docs ?? [];
        if (activeDocs.isNotEmpty) {
          final data = activeDocs.first.data() as Map<String, dynamic>;
          final requestId = activeDocs.first.id;
          final status = data['status'] as String;
          final assignedRiderId = data['assignedRiderId'] as String?;

          return Scaffold(
            appBar: AppBar(title: Text(l10n.activeOrderTitle)),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 56),
                    const SizedBox(height: 16),
                    Text(
                      l10n.activeDeliveryInProgress,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (status == 'open') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => BidListScreen(requestId: requestId)),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TrackingScreen(
                                requestId: requestId,
                                riderId: assignedRiderId ?? '',
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(l10n.viewOrderButton),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return _buildCreateForm(context);
      },
    );
  }

  Widget _buildCreateForm(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      // Every non-map child below is explicitly Positioned — a Stack with
      // any non-positioned child instead sizes itself to that child's own
      // size, not to the full Scaffold body.
      body: Stack(
        children: [
          // Passive preview of the placed pins — picking a location happens
          // in the full-screen picker (tapping either row of the floating
          // address card below), not by tapping this map. Used to render
          // truly full-bleed under the status bar, but the map is still
          // interactive (pan/zoom enabled) there, and its gesture
          // recognizer was swallowing the system's swipe-down-for-
          // notifications gesture in that strip — bottom:false SafeArea
          // insets just the map layer below the status bar to fix that.
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: MapWidget(
                key: const ValueKey('createRequestMap'),
                cameraOptions: CameraOptions(center: Point(coordinates: _initialCameraCenter), zoom: 13.0),
                styleUri: MapboxStyles.MAPBOX_STREETS,
                onMapCreated: _onMapCreated,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _profileAvatar(),
                        const SizedBox(width: 10),
                        Expanded(child: _titlePill(l10n)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Padding(
                    padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
                    child: _buildFloatingAddressCard(l10n),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: LocateMeButton(mapboxMap: () => _mapboxMap),
                    ),
                  ),
                ],
              ),
            ),
          ),
          PositionedDirectional(
            start: 0,
            end: 0,
            bottom: 0,
            child: ConstrainedBox(
              // A safety net for very small devices only — normally this
              // sheet's content comfortably fits above the map without
              // needing to scroll at all (that's the point of this layout).
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(context).height - 165).clamp(320.0, double.infinity),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  // Warm sand ground, not white — individual blocks below
                  // (white cards / the tinted price panel) supply the only
                  // white/tinted areas against it. Do not flatten this back
                  // to AppColors.surface.
                  color: AppColors.sheetGround,
                  borderRadius: AppRadii.bottomSheetLargeRadius,
                  boxShadow: [
                    BoxShadow(color: Color.fromRGBO(16, 21, 32, 0.18), offset: Offset(0, -10), blurRadius: 30),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsetsDirectional.fromSTEB(18, 14, 18, 20 + MediaQuery.viewPaddingOf(context).bottom),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9D3C8),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildPackageDescField(l10n),
                      const SizedBox(height: 10),
                      if (_vehicleTypeDocs.isNotEmpty) _buildVehicleChips(),
                      if (_requiresWeightEstimate) ...[
                        const SizedBox(height: 10),
                        _buildWeightField(l10n),
                      ],
                      const SizedBox(height: 10),
                      _buildPricePanel(l10n),
                      const SizedBox(height: 14),
                      _buildPostButton(l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Replaces the old back arrow: create-request is the customer's home
  // screen, so there is nothing behind it to go back to (the system back
  // gesture still works) — the corner is worth the profile entry point
  // instead. The initial is derived from the signed-in customer's own name,
  // not the prototype's hard-coded "A".
  Widget _profileAvatar() {
    final initial = (_myName?.trim().isNotEmpty ?? false) ? _myName!.trim()[0].toUpperCase() : '';
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerProfileScreen())),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Color.fromRGBO(16, 21, 32, 0.24), offset: Offset(0, 3), blurRadius: 12),
          ],
        ),
        child: Text(initial, style: AppTypography.heading(size: 16, color: Colors.white)),
      ),
    );
  }

  Widget _titlePill(AppLocalizations l10n) {
    return Container(
      height: 44,
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.fieldRadius,
        boxShadow: AppShadows.mapFloat,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppLogo(variant: AppLogoVariant.pin, color: AppLogoColor.blue, height: 16),
          const SizedBox(width: 9),
          Text(l10n.newDeliveryRequestTitle, style: AppTypography.heading(size: 13, color: AppColors.ink)),
        ],
      ),
    );
  }

  Widget _buildFloatingAddressCard(AppLocalizations l10n) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.smallTileAltRadius,
        boxShadow: const [
          BoxShadow(color: Color.fromRGBO(16, 21, 32, 0.16), offset: Offset(0, 4), blurRadius: 16),
        ],
      ),
      child: Column(
        children: [
          _floatingAddressRow(
            well: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.pricePanel, borderRadius: AppRadii.controlRadius),
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
              ),
            ),
            label: l10n.pickupAddressTitle,
            labelColor: AppColors.warmInkAlt,
            value: _pickupAddressController.text,
            placeholder: l10n.pickupAddressHint,
            onTap: () => _pickLocationOnMap(true),
          ),
          // Inset to 54px (not the well's own 30px + padding) so the divider
          // aligns to the text column below it, not to the well/icon above.
          const Padding(
            padding: EdgeInsetsDirectional.only(start: 54),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _floatingAddressRow(
            well: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: AppRadii.controlRadius),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            label: l10n.dropoffAddressTitle,
            labelColor: AppColors.primary,
            value: _dropoffAddressController.text,
            placeholder: l10n.dropoffAddressHint,
            onTap: () => _pickLocationOnMap(false),
          ),
        ],
      ),
    );
  }

  Widget _floatingAddressRow({
    required Widget well,
    required String label,
    required Color labelColor,
    required String value,
    required String placeholder,
    required VoidCallback onTap,
  }) {
    final hasValue = value.trim().isNotEmpty;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            well,
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: AppTypography.label(size: 13, color: labelColor)),
                  const SizedBox(height: 4),
                  Text(
                    hasValue ? value : placeholder,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(
                      size: 14,
                      color: hasValue ? AppColors.ink : AppColors.placeholder,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.border),
          ],
        ),
      ),
    );
  }

  static const List<double> _weightQuickPicks = [50, 200, 500, 1000];

  Widget _buildWeightField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: AppRadii.fieldRadius,
          ),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.scale_outlined, size: 15, color: AppColors.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: TextField(
                  controller: _estimatedWeightController,
                  keyboardType: TextInputType.number,
                  style: AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: l10n.estimatedWeightHint,
                    hintStyle: AppTypography.body(size: 14, color: AppColors.placeholder),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _weightQuickPicks.map((kg) {
            return InkWell(
              borderRadius: AppRadii.controlRadius,
              // Not wrapped in setState — the controller listener
              // (_applyWeightSurcharge) already rebuilds when its text
              // changes, and the TextField itself is driven by the same
              // controller.
              onTap: () => _estimatedWeightController.text = kg.toStringAsFixed(0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: AppColors.border),
                ),
                child: Text('~${kg.toStringAsFixed(0)} kg', style: AppTypography.label(size: 12, color: AppColors.bodyText)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPackageDescField(AppLocalizations l10n) {
    // A white card on the sand ground — the container itself is the field,
    // not a TextFormField with Material decoration.
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: AppRadii.fieldRadius,
      ),
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: TextField(
              controller: _packageDescController,
              style: AppTypography.body(size: 14, color: AppColors.ink),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: l10n.packageDescHelper,
                hintStyle: AppTypography.body(size: 14, color: AppColors.placeholder),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Always "driving" — the "cycling" profile used for two/three-wheelers
  // produced inaccurate routes in this region (odd detours); "driving" is
  // what the truck always used and is the only consistently accurate one.
  String _mapboxProfileFor(String typeId, [Map<String, dynamic>? data]) => 'driving';

  // Matches against the doc id AND the English name — an admin-created
  // vehicle type's doc id isn't guaranteed to contain these substrings (it
  // depends on how the admin dashboard slugifies the name), and every
  // vehicle type silently falling through to the same generic truck icon
  // reads as "these all look the same".
  IconData _vehicleTypeIcon(String typeId, [Map<String, dynamic>? data]) {
    final id = '$typeId ${data?['name'] ?? ''}'.toLowerCase();
    // See _iconForVehicleType's comment — "motorbike" contains "bike".
    if (id.contains('bicycle') || (id.contains('bike') && !id.contains('motor'))) return Icons.pedal_bike;
    if (id.contains('moto') || id.contains('scooter')) return Icons.two_wheeler;
    if (id.contains('tuk') || id.contains('rickshaw')) return Icons.electric_rickshaw;
    if (id.contains('truck') || id.contains('lorry')) return Icons.local_shipping;
    if (id.contains('car')) return Icons.directions_car;
    return Icons.local_shipping_outlined;
  }

  // The vehicle-selector chip icon — real photo art for tuk-tuk only (per
  // request, replacing its Twemoji glyph with the actual reference vehicle),
  // the original colored Twemoji glyphs for everything else. Map markers
  // use a completely separate, fully photo-based set (see
  // _iconForVehicleType) — deliberately not shared with this selector.
  Widget? _vehicleTypeChipIcon(String typeId, Map<String, dynamic>? data, {required double size}) {
    final id = '$typeId ${data?['name'] ?? ''}'.toLowerCase();
    if (id.contains('tuk') || id.contains('rickshaw')) {
      return Image.asset('assets/vehicles/tuktuk.png', width: size, height: size, fit: BoxFit.contain);
    }
    if (id.contains('bicycle') || (id.contains('bike') && !id.contains('motor'))) {
      return SvgPicture.asset('assets/vehicles/bicycle.svg', width: size, height: size);
    }
    if (id.contains('moto') || id.contains('scooter')) {
      return SvgPicture.asset('assets/vehicles/motorcycle.svg', width: size, height: size);
    }
    if (id.contains('truck') || id.contains('lorry')) {
      return SvgPicture.asset('assets/vehicles/truck.svg', width: size, height: size);
    }
    return null;
  }

  Widget _buildVehicleChips() {
    return Row(
      children: _vehicleTypeDocs.asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
        final data = doc.data() as Map<String, dynamic>;
        final selected = _selectedVehicleType == doc.id;
        final allowed = _isVehicleTypeAllowed(doc.id);
        // A zone can restrict which vehicle types may serve it (e.g.
        // bicycles only) — matches the same allowedVehicleTypes check
        // already enforced by rider_app/home_screen.dart and submitBid.js;
        // disabled here instead of letting the customer pick it and only
        // failing later when no rider can ever bid on it.
        final iconColor = !allowed
            ? AppColors.mutedLight
            : (selected ? Colors.white : AppColors.bodyText);
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: index != _vehicleTypeDocs.length - 1 ? 7 : 0),
            child: Opacity(
              opacity: allowed ? 1.0 : 0.5,
              child: InkWell(
                onTap: allowed ? () => _onVehicleTypeChanged(doc.id) : null,
                borderRadius: AppRadii.smallTileAltRadius,
                child: Container(
                  // Tall enough for a 2-line label (maxLines: 2 below) at
                  // this font's 1.0 line-height — a name like "Motorcycle"
                  // genuinely needs both lines at this chip width, and the
                  // previous 62 was too short for that, causing a real
                  // (pre-existing, not icon-related) bottom overflow.
                  height: 78,
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
                  decoration: BoxDecoration(
                    // Selected is a solid primary fill, not a pale tint — this
                    // chip row is the screen's main colour anchor.
                    color: selected && allowed ? AppColors.primary : AppColors.surface,
                    borderRadius: AppRadii.smallTileAltRadius,
                    border: selected && allowed ? null : Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _vehicleTypeChipIcon(doc.id, data, size: 20) ??
                          Icon(_vehicleTypeIcon(doc.id, data), size: 17, color: iconColor),
                      const SizedBox(height: 7),
                      Text(
                        localizedVehicleTypeName(context, data),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.label(size: 13, color: iconColor),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  bool get _hasMoreOptionsSet =>
      _sizeCategory != 'small' ||
      _purchaseBudgetController.text.trim().isNotEmpty ||
      _pickupPhoneController.text.trim().isNotEmpty ||
      _receiverPhoneController.text.trim().isNotEmpty;

  bool get _canSubmitNow =>
      _pickupPosition != null &&
      _dropoffPosition != null &&
      !_isCalculatingPrice &&
      _computedBasePrice != null &&
      _priceCalculationError == null &&
      !_isSubmitting;

  Widget _buildMoreOptionsButton(AppLocalizations l10n) {
    // IntrinsicWidth is required here: as a plain (non-Expanded) Row child
    // this Stack otherwise receives unbounded width, which crashes
    // OutlinedButton's internal layout ("BoxConstraints forces an infinite
    // width") instead of sizing to the button's own content.
    return IntrinsicWidth(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: () => _showMoreOptionsSheet(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.warmInkAlt,
                // Warm-toned (not the neutral AppColors.border) so this
                // button reads as belonging to the price panel it sits in,
                // rather than floating on top of it.
                side: const BorderSide(color: Color(0xFFE5D3C4), width: 1),
                shape: RoundedRectangleBorder(borderRadius: AppRadii.fieldRadius),
                textStyle: AppTypography.label(size: 13),
              ),
              child: Text(l10n.moreOptionsButton),
            ),
          ),
          if (_hasMoreOptionsSet)
            const PositionedDirectional(
              top: -2,
              end: -2,
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                child: SizedBox(width: 8, height: 8),
              ),
            ),
        ],
      ),
    );
  }

  // A single warm card carrying price, distance, and the More options
  // entry — replaces the old bare price row. There is deliberately no
  // bid-ceiling note here anymore: the ceiling is already explained in the
  // FAQ and on the bidding screen, so repeating it cost a block of body
  // text directly under the primary action.
  Widget _buildPricePanel(AppLocalizations l10n) {
    final hasDistance = _pickupPosition != null && _dropoffPosition != null && _distanceKm != null;
    Widget amount;
    if (_isCalculatingPrice) {
      amount = const SizedBox(
        height: 28,
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      );
    } else if (_priceCalculationError != null) {
      amount = Text(
        _priceCalculationError!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.body(size: 13, color: AppColors.danger),
      );
    } else if (_computedBasePrice == null) {
      amount = Text('—', style: AppTypography.amount(size: 28, color: AppColors.mutedLight));
    } else {
      final discount = _promoDiscountAmount;
      amount = Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (discount != null) ...[
              Text(
                _computedBasePrice!.toStringAsFixed(0),
                style: AppTypography.amount(size: 17, color: AppColors.warmInk)
                    .copyWith(decoration: TextDecoration.lineThrough),
              ),
              const SizedBox(width: 6),
            ],
            Text(_effectivePrice!.toStringAsFixed(0), style: AppTypography.amount(size: 28, color: AppColors.accent)),
            const SizedBox(width: 4),
            Text('SDG', style: AppTypography.caption(size: 12, color: AppColors.warmInk)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 15, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.pricePanel,
        border: Border.all(color: AppColors.pricePanelBorder),
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                    ),
                    const SizedBox(width: 7),
                    Text(l10n.basePriceWord, style: AppTypography.label(size: 13, color: AppColors.warmInk)),
                    if (hasDistance) ...[
                      const SizedBox(width: 7),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6EADF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${_distanceKm!.toStringAsFixed(1)} km',
                            style: AppTypography.amount(size: 12, color: AppColors.warmInk),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                amount,
              ],
            ),
          ),
          const SizedBox(width: 14),
          _buildMoreOptionsButton(l10n),
        ],
      ),
    );
  }

  Widget _buildPostButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _canSubmitNow ? _submitRequest : null,
        style: ElevatedButton.styleFrom(
          // #C7CEDE is this button's own corrected disabled color from the
          // design handoff, distinct from the theme's default disabled fill.
          disabledBackgroundColor: const Color(0xFFC7CEDE),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(l10n.postRequestButton),
      ),
    );
  }

  Widget _buildSizeChips(AppLocalizations l10n, {VoidCallback? afterChange}) {
    final sizes = [
      ('small', l10n.sizeSmall),
      ('medium', l10n.sizeMedium),
      ('large', l10n.sizeLarge),
    ];
    return Row(
      children: sizes.map((entry) {
        final (value, label) = entry;
        final selected = _sizeCategory == value;
        return Expanded(
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: value != 'large' ? 8 : 0),
            child: InkWell(
              onTap: () {
                setState(() => _sizeCategory = value);
                afterChange?.call();
              },
              borderRadius: AppRadii.controlRadius,
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primaryTint : AppColors.surfaceAlt,
                  borderRadius: AppRadii.controlRadius,
                  border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
                ),
                child: Text(
                  label,
                  style: AppTypography.body(size: 13, color: selected ? AppColors.primary : AppColors.bodyText),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Everything demoted from the main screen — zone, package size, purchase
  // budget, the two contact phones, and the redeemed promo (if any).
  // Nothing here is new functionality, only moved.
  Future<void> _showMoreOptionsSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.bottomSheetLargeRadius),
      builder: (sheetContext) {
        final l10n = AppLocalizations.of(sheetContext)!;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: const EdgeInsetsDirectional.fromSTEB(22, 16, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4,
                          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(l10n.moreOptionsTitle, style: AppTypography.heading(size: 16, color: AppColors.ink)),
                      const SizedBox(height: 20),
                      if (_zoneDocs.length > 1) ...[
                        DropdownButtonFormField<String>(
                          value: _selectedZoneName,
                          isDense: true,
                          decoration: InputDecoration(labelText: l10n.zoneLabel),
                          items: _zoneDocs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] as String;
                            return DropdownMenuItem(value: name, child: Text(localizedZoneName(context, data)));
                          }).toList(),
                          onChanged: (value) async {
                            await _onZoneChanged(value);
                            setSheetState(() {});
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                      Text(l10n.packageSizeLabel, style: AppTypography.label(color: AppColors.mutedLight)),
                      const SizedBox(height: 8),
                      _buildSizeChips(l10n, afterChange: () => setSheetState(() {})),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _purchaseBudgetController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l10n.purchaseBudgetLabel,
                          // `helperText:` (a plain String) hardcodes
                          // TextOverflow.ellipsis inside Flutter's own
                          // InputDecorator regardless of helperMaxLines —
                          // the longer helper strings here truncate with
                          // "…" instead of wrapping. `helper:` takes a
                          // widget instead, so this Text controls its own
                          // wrapping.
                          helper: Text(l10n.purchaseBudgetHelper, style: AppTypography.caption(color: AppColors.mutedLight)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _pickupPhoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        decoration: InputDecoration(
                          labelText: l10n.pickupPhoneLabel,
                          helper: Text(l10n.pickupPhoneHelper, style: AppTypography.caption(color: AppColors.mutedLight)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _receiverPhoneController,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.left,
                        decoration: InputDecoration(
                          labelText: l10n.receiverPhoneLabel,
                          helper: Text(l10n.receiverPhoneHelper, style: AppTypography.caption(color: AppColors.mutedLight)),
                        ),
                      ),
                      if (_pendingPromoDiscount != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsetsDirectional.symmetric(horizontal: 13, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.successTint,
                            border: Border.all(color: AppColors.successBorder),
                            borderRadius: AppRadii.smallTileAltRadius,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_offer_outlined, size: 16, color: AppColors.successText),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.promoAppliedBanner(_promoDiscountAmount!.toStringAsFixed(0)),
                                  style: AppTypography.body(size: 13, color: AppColors.successText),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(l10n.doneButton),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    // Values changed inside the sheet (size, budget, phones) are already
    // bound to shared controllers/fields — this just refreshes the main
    // screen's More-options badge dot now that the sheet is closed.
    if (mounted) setState(() {});
  }
}
