import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/bid.dart';
import '../widgets/cancel_dialog.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';
import '../utils/localized_vehicle_type.dart';
import '../utils/vehicle_color.dart';
import '../utils/bearing.dart';
import '../services/sound_service.dart';
import '../widgets/draining_glass_indicator.dart';
import 'create_request_screen.dart';
import 'tracking_screen.dart';

class BidListScreen extends StatefulWidget {
  final String requestId;
  const BidListScreen({super.key, required this.requestId});

  @override
  State<BidListScreen> createState() => _BidListScreenState();
}

class _BidListScreenState extends State<BidListScreen> {
  String? _acceptingBidId;
  String? _rejectingBidId;
  late final Duration _remaining;
  Timer? _countdownTimer;
  // Matches create_request_screen.dart's biddingClosesAt window.
  int _secondsLeft = 5 * 60;
  // Anchors the countdown to this device's own clock at the moment it
  // started, rather than decrementing _secondsLeft by 1 on every tick — a
  // naive decrement assumes each Timer.periodic callback fires exactly on
  // schedule, which drifts (and visibly skips numbers) under frame jank,
  // GC pauses, or the app briefly backgrounding.
  DateTime? _countdownStartedAt;
  bool _isCancelling = false;
  GeoPoint? _pickupLocation;
  String? _zone;
  String? _requestVehicleType;
  bool _hasNavigatedToTracking = false;
  // Fetched once — vehicle types rarely change, just needed to show each
  // bid's vehicle type by its localized name instead of the raw doc id.
  Map<String, Map<String, dynamic>> _vehicleTypesCache = {};

  // Matches submitBid.js's BID_ACTIVE_WINDOW_MS — a bid is only shown (and
  // only blocks the rider from re-bidding) for 30s after it was sent, then
  // it clears from this list, freeing the rider to send an adjusted one.
  static const _bidActiveWindow = Duration(seconds: 30);

  // Deliberately timed from when THIS DEVICE first saw the bid, not from
  // bid.submittedAt (a server timestamp) compared against DateTime.now()
  // (the device's own clock) — on a real phone that can be meaningfully
  // out of sync with the machine running the emulator/backend, that
  // mismatch was draining the 30s bar in as little as 5s. The actual
  // enforcement (submitBid.js) only ever compares server time against
  // server time, so it's unaffected either way — this only governs the
  // visual countdown.
  final Map<String, DateTime> _bidFirstSeenAt = {};
  Duration _bidRemaining(Bid bid) {
    final firstSeen = _bidFirstSeenAt.putIfAbsent(bid.id, () => DateTime.now());
    final remaining = _bidActiveWindow - DateTime.now().difference(firstSeen);
    return remaining > Duration.zero ? remaining : Duration.zero;
  }

  bool _isBoostingPrice = false;

  // Mirrors rider_app/home_screen.dart's _seenRequestIds — null means "the
  // very first snapshot hasn't landed yet", so whatever's already pending
  // when this screen opens doesn't sound an alert, only a bid that arrives
  // afterward does. Driven directly by this screen's own live bid stream,
  // not the FCM 'new_bid' push — the push only fires while the app happens
  // to be foregrounded, and a customer watching this exact screen is the
  // one case that's guaranteed to be true regardless.
  Set<String>? _seenBidIds;

  // Created once, not inline in build() — the countdown timer below calls
  // setState() every second, and build() calling watchBids() fresh each time
  // would tear down and recreate the Firestore listener on every tick,
  // flashing the loading spinner every second instead of updating in place.
  late final Stream<List<Bid>> _bidsStream = watchBids(widget.requestId);

  @override
  void initState() {
    super.initState();
    _countdownStartedAt = DateTime.now();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      final remaining = (5 * 60) - DateTime.now().difference(_countdownStartedAt!).inSeconds;
      if (remaining <= 0) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft = remaining);
      }
    });
    _loadRequestLocation();
    _loadVehicleTypes();
  }

  Future<void> _loadVehicleTypes() async {
    final snap = await FirebaseFirestore.instance.collection('vehicleTypes').get();
    if (!mounted) return;
    setState(() => _vehicleTypesCache = {for (final d in snap.docs) d.id: d.data()});
  }

  // Matches against the doc id AND the English name — an admin-created
  // vehicle type's doc id isn't guaranteed to contain these substrings, and
  // every vehicle type silently falling through to the same generic truck
  // icon reads as "these all look the same" (matches create_request_screen
  // .dart's identical fix).
  IconData _vehicleTypeIcon(String typeId) {
    final id = '$typeId ${_vehicleTypesCache[typeId]?['name'] ?? ''}'.toLowerCase();
    // "motorbike" contains "bike" — excluding "motor" keeps that from
    // matching the bicycle branch (see _iconForVehicleType's fuller note).
    if (id.contains('bicycle') || (id.contains('bike') && !id.contains('motor'))) return Icons.pedal_bike;
    if (id.contains('moto') || id.contains('scooter')) return Icons.two_wheeler;
    if (id.contains('tuk') || id.contains('rickshaw')) return Icons.electric_rickshaw;
    if (id.contains('truck') || id.contains('lorry')) return Icons.local_shipping;
    if (id.contains('car')) return Icons.directions_car;
    return Icons.local_shipping_outlined;
  }

  // Matches create_request_screen.dart's identical helper — real photo art
  // for tuk-tuk only, the original Twemoji glyphs for everything else. Map
  // markers (_iconForVehicleType below) use a separate, fully photo-based
  // set — not shared with this selector.
  Widget? _vehicleTypeChipIcon(String typeId, {required double size}) {
    final id = '$typeId ${_vehicleTypesCache[typeId]?['name'] ?? ''}'.toLowerCase();
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

  String _formatCountdown(int seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  // Fetched once — pickup location and zone don't change over this screen's
  // lifetime, so there's no need for a live listener on the request doc here.
  Future<void> _loadRequestLocation() async {
    final doc = await FirebaseFirestore.instance
        .collection('delivery_requests')
        .doc(widget.requestId)
        .get();
    final data = doc.data();
    if (data == null || !mounted) return;
    setState(() {
      _pickupLocation = data['pickup']?['geopoint'] as GeoPoint?;
      _zone = data['zone'] as String?;
      _requestVehicleType = data['vehicleType'] as String?;
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _cancelRequest() async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await showCancelReasonDialog(
      context,
      title: l10n.cancelRequestDialogTitle,
      reasons: [
        l10n.reasonChangedMind,
        l10n.reasonNoLongerNeeded,
        l10n.reasonFoundAnotherWay,
        l10n.reasonOther,
      ],
    );
    if (reason == null) return;

    setState(() => _isCancelling = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('cancelRequest');
      await callable.call({'requestId': widget.requestId, 'reason': reason});
      if (!mounted) return;
      // This screen now reaches here via pushReplacement (create-request
      // screen is no longer underneath it in the stack), so popUntil(isFirst)
      // would just land back on this same screen — rebuild a fresh
      // CreateRequestScreen instead.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
        (route) => false,
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() => _isCancelling = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.cancelRequestError)),
      );
    } catch (e) {
      // Not every failure here surfaces as a FirebaseFunctionsException — a
      // dropped connection or a platform-channel hiccup throws a raw
      // PlatformException instead, which fell through uncaught before this
      // clause existed and crashed the screen with Flutter's red error
      // overlay (the reported "cancellation brings a red screen" bug).
      setState(() => _isCancelling = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.cancelRequestError)),
      );
    }
  }

  Future<void> _acceptBid(Bid bid) async {
    setState(() => _acceptingBidId = bid.id);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('acceptBid');
      await callable.call({'requestId': widget.requestId, 'bidId': bid.id});
      SoundService.bidAccepted();
      // Nothing to navigate here — the StreamBuilder in build() reactively
      // pushes TrackingScreen once the resulting Firestore update (status:
      // assigned) arrives, the same fix already applied to the rider app's
      // active_delivery_screen.dart for the identical race: this callable's
      // own HTTP response and the Firestore listener update travel over
      // separate channels, and the write (which happens before the function
      // returns) routinely reaches the client first — an eager push here
      // right after this await was found to just silently do nothing on
      // real devices often enough that customers stayed stuck on this
      // screen until they force-restarted the app.
    } on FirebaseFunctionsException catch (e) {
      setState(() => _acceptingBidId = null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? AppLocalizations.of(context)!.acceptBidError)),
      );
    }
  }

  Future<void> _rejectBid(Bid bid) async {
    setState(() => _rejectingBidId = bid.id);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('rejectBid');
      await callable.call({'requestId': widget.requestId, 'bidId': bid.id});
      // No further action needed — watchBids() already filters to
      // status == 'pending', so this row disappears on its own once
      // Firestore pushes the update.
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? AppLocalizations.of(context)!.bidRejectError)),
      );
    } finally {
      if (mounted) setState(() => _rejectingBidId = null);
    }
  }

  // Offered once the original 5-minute bidding window closes with zero
  // bids (see the empty-state branch in _buildScaffold below) — raises
  // suggestedPrice and gives the request a fresh 5-minute window via
  // boostRequestPrice.js, restarting this screen's own countdown to match.
  Future<void> _showBoostPriceDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final requestSnap = await FirebaseFirestore.instance.collection('delivery_requests').doc(widget.requestId).get();
    if (!mounted) return;
    final currentPrice = (requestSnap.data()?['suggestedPrice'] as num?)?.toDouble() ?? 0;
    final suggestedBoost = currentPrice > 0 ? (currentPrice * 1.25).roundToDouble() : 500.0;
    final controller = TextEditingController(text: suggestedBoost.toStringAsFixed(0));

    final newPrice = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.boostPriceDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.boostPriceDialogHint(currentPrice.toStringAsFixed(0))),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l10n.newPriceLabel, suffixText: 'SDG'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancelButton)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, double.tryParse(controller.text.trim())),
            child: Text(l10n.boostPriceConfirmButton),
          ),
        ],
      ),
    );
    if (newPrice == null || newPrice <= currentPrice) return;

    setState(() => _isBoostingPrice = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('boostRequestPrice');
      await callable.call({'requestId': widget.requestId, 'newPrice': newPrice});
      if (!mounted) return;
      // Restart this screen's own 5-minute countdown to match the fresh
      // biddingClosesAt the function just wrote server-side.
      _countdownTimer?.cancel();
      _countdownStartedAt = DateTime.now();
      setState(() => _secondsLeft = 5 * 60);
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        final remaining = (5 * 60) - DateTime.now().difference(_countdownStartedAt!).inSeconds;
        if (remaining <= 0) {
          t.cancel();
          setState(() => _secondsLeft = 0);
        } else {
          setState(() => _secondsLeft = remaining);
        }
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.boostPriceError)),
      );
    } finally {
      if (mounted) setState(() => _isBoostingPrice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const mapHeight = 280.0;
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('delivery_requests').doc(widget.requestId).snapshots(),
      builder: (context, requestSnap) {
        if (requestSnap.hasData && requestSnap.data!.exists) {
          final data = requestSnap.data!.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final assignedRiderId = data['assignedRiderId'] as String?;
          // Must be an allowlist, not "anything but open": status also
          // becomes "cancelled" here (the customer cancels from this very
          // screen, or closeBiddingWindow.js auto-cancels an unaccepted
          // request) with no assignedRiderId — the old "!= open" check
          // matched that too and pushed TrackingScreen with an empty
          // riderId, which crashed with "A document path must be a
          // non-empty string" the moment that screen tried to read it.
          final isAssignedOrBeyond = status == 'assigned' || status == 'picked_up' || status == 'delivered';
          if (isAssignedOrBeyond && !_hasNavigatedToTracking) {
            _hasNavigatedToTracking = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => TrackingScreen(requestId: widget.requestId, riderId: assignedRiderId ?? ''),
                ),
              );
            });
          }
        }
        return _buildScaffold(l10n, mapHeight);
      },
    );
  }

  Widget _buildScaffold(AppLocalizations l10n, double mapHeight) {
    return Scaffold(
      // Every Stack child below is explicitly Positioned — see the same fix
      // across the other map-header screens (an un-Positioned child sizes
      // the whole Stack to itself instead of the full screen).
      body: Stack(
        children: [
          if (_pickupLocation != null && _zone != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: mapHeight,
              // bottom:false SafeArea — the map is an interactive Mapbox
              // view, and starting it right at the very top of the screen
              // let its own pan/zoom gesture recognizer swallow the
              // system's swipe-down-for-notifications gesture in that
              // strip. Insetting it below the status bar fixes that
              // without needing to disable the map's own gestures.
              child: SafeArea(
                bottom: false,
                child: _NearbyRidersMap(
                  pickup: _pickupLocation!,
                  zone: _zone!,
                  vehicleType: _requestVehicleType,
                  vehicleTypesCache: _vehicleTypesCache,
                ),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(999)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.accent),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _secondsLeft > 0 ? l10n.biddingWaitingTitle(_formatCountdown(_secondsLeft)) : l10n.biddingClosedTitle,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(999), boxShadow: AppShadows.mapFloat),
                      child: TextButton(
                        onPressed: _isCancelling ? null : _cancelRequest,
                        child: _isCancelling
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(l10n.cancelButton, style: const TextStyle(color: AppColors.danger)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: mapHeight - 26,
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: StreamBuilder<List<Bid>>(
                stream: _bidsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // A bid older than 30s clears from view here — same
                  // active window submitBid.js enforces server-side to let
                  // the rider send an adjusted one. Recomputed on every
                  // rebuild (the countdown timer above already ticks this
                  // widget every second, so this needs no timer of its own).
                  final rawBids = snapshot.data ?? [];
                  _bidFirstSeenAt.removeWhere((id, _) => !rawBids.any((b) => b.id == id));

                  final rawBidIds = rawBids.map((b) => b.id).toSet();
                  if (_seenBidIds != null && rawBidIds.difference(_seenBidIds!).isNotEmpty) {
                    SoundService.bidReceived();
                  }
                  _seenBidIds = rawBidIds;

                  final bids = rawBids.where((b) => _bidRemaining(b) > Duration.zero).toList();

                  if (bids.isEmpty) {
                    final biddingClosed = _secondsLeft <= 0;
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              biddingClosed ? l10n.noBidsTimedOut : l10n.noBidsYetWaiting,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            // Nobody bid on the original price within the
                            // whole 5-minute window — offer the self-serve
                            // fix rather than leaving the customer stuck
                            // staring at "no bids".
                            if (biddingClosed) ...[
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _isBoostingPrice ? null : _showBoostPriceDialog,
                                icon: _isBoostingPrice
                                    ? const SizedBox(
                                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.trending_up),
                                label: Text(l10n.boostPriceButton),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: bids.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, rawIndex) {
                      if (rawIndex == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(l10n.bidsHeading, style: AppTypography.heading(size: 15)),
                              Text(l10n.cheapestFirstLabel, style: AppTypography.caption(color: AppColors.mutedLight)),
                            ],
                          ),
                        );
                      }
                      final index = rawIndex - 1;
                    final bid = bids[index];
                    // watchBids() already orders by price ascending, so the
                    // cheapest bid is always index 0 — it gets the
                    // "recommended" treatment (primaryBorder + shadow, filled
                    // primary avatar/accept button) per the design handoff;
                    // every other bid gets a neutral card and an ink accept
                    // button, deliberately not nudging toward one bid.
                    final isCheapest = index == 0;
                    final busy = _acceptingBidId != null || _rejectingBidId != null;

                    return Container(
                      key: ValueKey(bid.id),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: AppRadii.cardLargeRadius,
                        border: Border.all(color: isCheapest ? AppColors.primaryBorder : AppColors.borderAlt),
                        boxShadow: isCheapest ? AppShadows.recommendedCard : AppShadows.card,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 21,
                            backgroundColor: isCheapest ? AppColors.primary : AppColors.primaryTint,
                            backgroundImage: bid.riderPhotoUrl != null ? NetworkImage(bid.riderPhotoUrl!) : null,
                            child: bid.riderPhotoUrl == null
                                ? Text(
                                    bid.riderName.isNotEmpty ? bid.riderName[0] : '?',
                                    style: TextStyle(
                                      color: isCheapest ? Colors.white : AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(bid.riderName, style: AppTypography.heading(size: 14.5)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Directionality(
                                      textDirection: TextDirection.ltr,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star, size: 13, color: AppColors.accent),
                                          const SizedBox(width: 2),
                                          Text(
                                            // A rider with zero completed
                                            // deliveries has no real rating
                                            // yet — showing a numeric score
                                            // (even a low one) reads as an
                                            // actual review when there isn't
                                            // one.
                                            bid.riderRatingCount > 0 ? bid.riderRating.toStringAsFixed(1) : l10n.newRiderLabel,
                                            style: AppTypography.amount(size: 12, color: AppColors.accent),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text('  •  ', style: AppTypography.caption(color: AppColors.mutedLight)),
                                    Text(
                                      bid.etaMinutes != null
                                          ? l10n.etaMinutesLabel(bid.etaMinutes!)
                                          : l10n.etaUnavailable,
                                      style: AppTypography.caption(color: AppColors.mutedLight),
                                    ),
                                  ],
                                ),
                                if (bid.riderVehicleType != null ||
                                    bid.riderVehicleColor != null ||
                                    bid.riderPlateNumber != null) ...[
                                  const SizedBox(height: 4),
                                  Builder(builder: (context) {
                                    // Built as a list of small widgets joined by
                                    // " • " separators, rather than nested
                                    // if-chains per pair — a 3rd optional field
                                    // (vehicle colour) made the pairwise
                                    // separator logic unwieldy.
                                    final parts = <Widget>[];
                                    if (bid.riderVehicleType != null) {
                                      parts.add(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _vehicleTypeChipIcon(bid.riderVehicleType!, size: 14) ??
                                              Icon(_vehicleTypeIcon(bid.riderVehicleType!), size: 13, color: AppColors.mutedLight),
                                          const SizedBox(width: 4),
                                          Text(
                                            _vehicleTypesCache[bid.riderVehicleType] != null
                                                ? localizedVehicleTypeName(context, _vehicleTypesCache[bid.riderVehicleType]!)
                                                : bid.riderVehicleType!,
                                            style: AppTypography.caption(color: AppColors.mutedLight),
                                          ),
                                        ],
                                      ));
                                    }
                                    if (bid.riderVehicleColor != null) {
                                      parts.add(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: vehicleColorSwatch(bid.riderVehicleColor) ?? AppColors.mutedLight,
                                              border: Border.all(color: AppColors.border, width: 0.5),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            localizedVehicleColorName(context, bid.riderVehicleColor!),
                                            style: AppTypography.caption(color: AppColors.mutedLight),
                                          ),
                                        ],
                                      ));
                                    }
                                    if (bid.riderPlateNumber != null) {
                                      parts.add(Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(
                                          bid.riderPlateNumber!,
                                          style: AppTypography.caption(color: AppColors.mutedLight),
                                        ),
                                      ));
                                    }
                                    return Row(
                                      children: [
                                        for (var i = 0; i < parts.length; i++) ...[
                                          if (i != 0) Text('  •  ', style: AppTypography.caption(color: AppColors.mutedLight)),
                                          parts[i],
                                        ],
                                      ],
                                    );
                                  }),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: SizedBox(
                                        height: 40,
                                        child: ElevatedButton(
                                          style: isCheapest
                                              ? null
                                              : ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.ink,
                                                  foregroundColor: Colors.white,
                                                ),
                                          onPressed: busy ? null : () => _acceptBid(bid),
                                          child: _acceptingBidId == bid.id
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                                )
                                              : Text(l10n.acceptButton),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 86,
                                      height: 40,
                                      child: OutlinedButton(
                                        onPressed: busy ? null : () => _rejectBid(bid),
                                        child: _rejectingBidId == bid.id
                                            ? const SizedBox(
                                                width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                            : Text(l10n.rejectButton),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                bid.price.toStringAsFixed(0),
                                style: AppTypography.amount(size: 20, color: AppColors.ink),
                              ),
                              Text('SDG', style: AppTypography.caption(size: 10, color: AppColors.mutedLight)),
                              const SizedBox(height: 6),
                              // This offer clears on its own 30s after it
                              // was sent (see _bidRemaining/submitBid.js) —
                              // draining rather than a numeral countdown is
                              // the deliberately "creative" framing asked
                              // for, and it's the customer who needs the
                              // urgency cue to accept before it's gone, not
                              // the rider waiting on the other end.
                              DrainingGlassIndicator(
                                duration: _bidRemaining(bid),
                                onExpired: () {
                                  if (mounted) setState(() {});
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _NearbyRidersMap extends StatefulWidget {
  final GeoPoint pickup;
  final String zone;
  final String? vehicleType;
  final Map<String, Map<String, dynamic>> vehicleTypesCache;
  const _NearbyRidersMap({
    required this.pickup,
    required this.zone,
    required this.vehicleType,
    required this.vehicleTypesCache,
  });

  @override
  State<_NearbyRidersMap> createState() => _NearbyRidersMapState();
}

class _NearbyRidersMapState extends State<_NearbyRidersMap> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _pickupManager;
  CircleAnnotation? _pulseAnnotation;
  PointAnnotationManager? _riderManager;
  // Per-vehicle-type marker images, rasterized once from assets/vehicles/
  // — resolved per rider from their vehicleType at annotation-creation
  // time. _fallbackIcon (the original generic marker) covers any vehicle
  // type an admin adds later that isn't one of these 4.
  final Map<String, Uint8List> _vehicleIcons = {};
  Uint8List? _fallbackIcon;
  final Map<String, PointAnnotation> _riderAnnotations = {};
  // Previous known position per rider — compared against each new update to
  // compute a bearing so the marker rotates to face its direction of
  // travel, instead of always pointing the same static way.
  final Map<String, Position> _riderLastPosition = {};
  StreamSubscription<QuerySnapshot>? _ridersSubscription;

  // A "searching for nearby riders" pulse around the pickup pin — a second
  // circle annotation grown and faded out on a timer, underneath the solid
  // pickup dot. Driven by Timer.periodic at a modest ~16 updates/sec rather
  // than a 60fps AnimationController tick, since each frame is a real
  // platform-channel round trip to the native map view.
  Timer? _pulseTimer;
  double _pulsePhase = 0;
  static const _pulseTickMs = 60;
  static const _pulseCycleMs = 1600;

  void _startPulseAnimation() {
    _pulseTimer = Timer.periodic(const Duration(milliseconds: _pulseTickMs), (_) async {
      final manager = _pickupManager;
      final pulse = _pulseAnnotation;
      if (manager == null || pulse == null || !mounted) return;
      _pulsePhase = (_pulsePhase + _pulseTickMs / _pulseCycleMs) % 1.0;
      final eased = Curves.easeOut.transform(_pulsePhase);
      pulse.circleRadius = 9.0 + eased * 26.0;
      pulse.circleOpacity = (1.0 - eased) * 0.45;
      await manager.update(pulse);
    });
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    // Passive preview strip, not an interactive/rotatable map — the default
    // compass ornament otherwise sits 4px from the map's own top-right
    // corner, which overlaps the status bar on screens where this map
    // extends behind it.
    unawaited(mapboxMap.compass.updateSettings(CompassSettings(enabled: false)));

    // Load each vehicle-type marker image once, as raw bytes — real top/rear
    // -view photos, cropped and square-padded ahead of time (not rasterized
    // at runtime — already raster). PointAnnotation needs actual image
    // bytes, unlike CircleAnnotation which is just shapes.
    final fallbackData = await rootBundle.load('assets/motorcycle_icon.png');
    _fallbackIcon = fallbackData.buffer.asUint8List();
    for (final entry in const {
      'bicycle': 'assets/vehicle_markers/bicycle.png',
      'motorcycle': 'assets/vehicle_markers/motorcycle.png',
      'tuktuk': 'assets/vehicle_markers/tuktuk.png',
      'truck': 'assets/vehicle_markers/truck.png',
    }.entries) {
      final data = await rootBundle.load(entry.value);
      _vehicleIcons[entry.key] = data.buffer.asUint8List();
    }

    _pickupManager = await mapboxMap.annotations.createCircleAnnotationManager();
    // Created first so it renders underneath the solid pickup dot below.
    _pulseAnnotation = await _pickupManager!.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(widget.pickup.longitude, widget.pickup.latitude)),
        circleColor: AppColors.accent.toARGB32(),
        circleRadius: 9.0,
        circleOpacity: 0.45,
      ),
    );
    await _pickupManager!.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: Position(widget.pickup.longitude, widget.pickup.latitude)),
        circleColor: AppColors.accent.toARGB32(),
        circleRadius: 9.0,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.0,
      ),
    );
    _startPulseAnimation();

    _riderManager = await mapboxMap.annotations.createPointAnnotationManager();

    // Scoped to the request's own vehicle type — only a rider on that same
    // vehicle type can actually bid on this request (submitBid.js rejects a
    // mismatch), so showing every online rider regardless of type here was
    // misleading. Falls back to unfiltered only for pre-vehicleType-field
    // requests (vehicleType is null), rather than matching nothing.
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('riders')
        .where('isOnline', isEqualTo: true)
        .where('activeZone', isEqualTo: widget.zone);
    if (widget.vehicleType != null) {
      query = query.where('vehicleType', isEqualTo: widget.vehicleType);
    }
    _ridersSubscription = query.snapshots().listen(_onRidersUpdate);
  }

  // Matches create_request_screen.dart's / this file's own _vehicleTypeIcon
  // matching heuristic, against widget.vehicleTypesCache instead of a local
  // copy — read fresh each call rather than snapshotted at map-create time,
  // so a cache that finishes loading after this map is already up still
  // takes effect on the next Firestore update.
  Uint8List _iconForVehicleType(String? typeId) {
    final id = '${typeId ?? ''} ${widget.vehicleTypesCache[typeId]?['name'] ?? ''}'.toLowerCase();
    // "motorbike" contains "bike" — excluded "motor" keeps a motorbike from
    // matching the bicycle branch (this was returning the bicycle marker
    // for every motorbike rider on the map).
    if (id.contains('bicycle') || (id.contains('bike') && !id.contains('motor'))) return _vehicleIcons['bicycle'] ?? _fallbackIcon!;
    if (id.contains('tuk') || id.contains('rickshaw')) return _vehicleIcons['tuktuk'] ?? _fallbackIcon!;
    if (id.contains('truck') || id.contains('lorry')) return _vehicleIcons['truck'] ?? _fallbackIcon!;
    if (id.contains('moto') || id.contains('scooter')) return _vehicleIcons['motorcycle'] ?? _fallbackIcon!;
    return _fallbackIcon!;
  }

  Future<void> _onRidersUpdate(QuerySnapshot snapshot) async {
    final manager = _riderManager;
    if (manager == null || _fallbackIcon == null) return;

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
        // Below ~3m is GPS noise, not real movement — rotating on every tiny
        // jitter made the icon spin in place while the rider was stopped.
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

    // Remove riders who went offline or left the zone since the last update.
    final staleIds = _riderAnnotations.keys.where((id) => !seenIds.contains(id)).toList();
    for (final id in staleIds) {
      final annotation = _riderAnnotations.remove(id);
      _riderLastPosition.remove(id);
      if (annotation != null) await manager.delete(annotation);
    }
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _ridersSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapWidget(
      key: const ValueKey('nearbyRidersMap'),
      cameraOptions: CameraOptions(
        center: Point(coordinates: Position(widget.pickup.longitude, widget.pickup.latitude)),
        zoom: 13.0,
      ),
      styleUri: MapboxStyles.MAPBOX_STREETS,
      onMapCreated: _onMapCreated,
    );
  }
}
