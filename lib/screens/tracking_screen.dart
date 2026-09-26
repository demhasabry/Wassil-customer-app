import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import '../widgets/cancel_dialog.dart';
import '../widgets/report_problem_dialog.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/localized_vehicle_type.dart';
import '../utils/vehicle_color.dart';
import '../services/pricing_service.dart' show fetchRoute;
import '../services/sound_service.dart';
import '../services/callable_function.dart';
import '../services/live_activity_service.dart';
import 'bid_list_screen.dart';
import 'create_request_screen.dart';
import 'rate_rider_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String requestId;
  final String riderId;

  const TrackingScreen({super.key, required this.requestId, required this.riderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isCancelling = false;
  bool _hasNavigatedAway = false;
  bool _hasNavigatedToRating = false;
  // Only calls into LiveActivityService when this actually changes — the
  // outer StreamBuilder rebuilds on every rider GPS ping, and re-sending an
  // identical update on each one would be pure waste (extra UserDefaults
  // writes, extra ActivityKit churn) for a value that hasn't moved.
  String? _lastLiveActivitySignature;
  // Guards the 'delivered' branch's end() call the same way _hasNavigatedAway
  // guards 'open' — that branch's alreadyRated path returns early on every
  // rebuild with no other one-shot marker to hook into.
  bool _hasEndedLiveActivity = false;
  // Fetched once — vehicle type name/color labels only need this to render
  // a display name, not to react live to admin edits mid-delivery.
  Map<String, Map<String, dynamic>> _vehicleTypesCache = {};

  // The rider-arrived loop starts once, on hasArrived's false->true edge
  // (not every rebuild), and plays until the customer taps "I'm Coming".
  // Same 5-minute grace period startWaitingFee.js enforces server-side —
  // this is purely the display countdown, the server check is what
  // actually gates whether the rider can start a waiting fee.
  bool _hasStartedArrivalLoop = false;
  bool _acknowledgedArrival = false;
  Timer? _arrivalTicker;
  static const _arrivalGracePeriod = Duration(minutes: 5);

  // Set once, the first time hasArrived is observed true — deliberately
  // this device's own clock, not the server's arrivedAt timestamp compared
  // against DateTime.now() (the same clock-skew bug already found and
  // fixed for the bid countdown in bid_list_screen.dart: a real phone can
  // be meaningfully out of sync with the machine running the
  // emulator/backend, which made this countdown count down wrong — too
  // fast, too slow, or starting already expired).
  DateTime? _arrivedAtLocalRef;

  @override
  void initState() {
    super.initState();
    FirebaseFirestore.instance.collection('vehicleTypes').get().then((snap) {
      if (!mounted) return;
      setState(() => _vehicleTypesCache = {for (final d in snap.docs) d.id: d.data()});
    });
    // Ticks the countdown text below without waiting on the next Firestore
    // update — nothing else would otherwise trigger a rebuild while the
    // grace period just counts down. 1s (not 15s) so the M:SS display
    // actually counts down smoothly instead of jumping in 15-second steps.
    _arrivalTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _arrivalTicker?.cancel();
    // Safety net — if the customer navigates away (or the delivery moves
    // on) before tapping "I'm Coming", the loop shouldn't keep playing.
    SoundService.stopDriverArrivedLoop();
    // Best-effort, not awaited — a screen being torn down shouldn't wait on
    // a native call. The delivered/cancelled branches below also end it
    // explicitly, so this is mainly a safety net for other exits (e.g. the
    // customer backgrounding then killing the app mid-delivery).
    LiveActivityService.end(widget.requestId);
    super.dispose();
  }

  void _acknowledgeArrival() {
    // Stop the sound and update the local UI immediately — don't wait on
    // the network round-trip below for either of those.
    SoundService.stopDriverArrivedLoop();
    setState(() => _acknowledgedArrival = true);
    _sendArrivalAcknowledgment();
  }

  // Previously this was local-only, so the rider had no way to know the
  // customer had actually seen the notice — best-effort, not awaited by
  // the caller.
  Future<void> _sendArrivalAcknowledgment() async {
    try {
      await callFunction('acknowledgeArrival', {'requestId': widget.requestId});
    } catch (_) {}
  }

  Future<void> _cancelRequest() async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await showCancelReasonDialog(
      context,
      title: l10n.cancelDeliveryDialogTitle,
      reasons: [
        l10n.reasonChangedMind,
        l10n.reasonRiderTakingTooLong,
        l10n.reasonNoLongerNeeded,
        l10n.reasonOther,
      ],
    );
    if (reason == null) return;

    setState(() => _isCancelling = true);
    try {
      await callFunction('cancelRequest', {'requestId': widget.requestId, 'reason': reason});
      SoundService.cancellation();
      if (!mounted) return;
      // Go all the way back to a fresh create-request screen, not just one
      // level up — this screen is reached via pushReplacement calls (create
      // request -> bid list -> tracking), so create-request is no longer
      // underneath in the stack to pop back to; rebuild it instead.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
        (route) => false,
      );
    } on FirebaseFunctionsException catch (e) {
      setState(() => _isCancelling = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.cancelDeliveryError)),
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
        SnackBar(content: Text(l10n.cancelDeliveryError)),
      );
    }
  }

  Widget _cancelOrReportAction(AppLocalizations l10n, String? status) {
    // Cancellation only makes sense before the rider has physically picked
    // up the package — after that, this is the "something went wrong" path
    // instead: report it for an admin to look at, rather than a self-serve
    // cancel/undo.
    // Was a bare white Icon with nothing behind it — invisible against the
    // light MAPBOX_STREETS map underneath. A solid circular backing (same
    // panel color as the status banner) keeps it legible regardless of the
    // map style/colors beneath it.
    if (status == 'assigned') {
      return _actionChip(
        onTap: _isCancelling ? null : _cancelRequest,
        child: _isCancelling
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.close, color: Colors.white, size: 20),
      );
    }
    if (status == 'picked_up' || status == 'delivered') {
      return _actionChip(
        onTap: () => showReportProblemDialog(
          context,
          requestId: widget.requestId,
          reporterRole: 'customer',
          reasons: [
            l10n.reportReasonItemDamaged,
            l10n.reportReasonWrongItem,
            l10n.reportReasonRiderUnprofessional,
            l10n.reportReasonNeverReceived,
            l10n.reasonOther,
          ],
        ),
        child: const Icon(Icons.flag_outlined, color: Colors.white, size: 20),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _actionChip({required VoidCallback? onTap, required Widget child}) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.inkPanel,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('riders').doc(widget.riderId).snapshots(),
        builder: (context, riderSnap) {
          if (!riderSnap.hasData || !riderSnap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final riderData = riderSnap.data!.data() as Map<String, dynamic>;
          final GeoPoint? location = riderData['currentLocation'] as GeoPoint?;

          return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('delivery_requests')
                    .doc(widget.requestId)
                    .snapshots(),
                builder: (context, requestSnap) {
                  final requestData = requestSnap.hasData && requestSnap.data!.exists
                      ? requestSnap.data!.data() as Map<String, dynamic>
                      : <String, dynamic>{};
                  // Denormalized onto the request doc by acceptBid.js — a
                  // direct read of users/{riderId} here would silently fail,
                  // since that collection's rules only let a user read their
                  // own doc, not the customer reading their assigned rider's.
                  final riderName = requestData['assignedRiderName'] as String?;
                  final riderPhone = requestData['assignedRiderPhone'] as String?;
                  final riderVehicleType = requestData['assignedRiderVehicleType'] as String?;
                  final riderPlateNumber = requestData['assignedRiderPlateNumber'] as String?;
                  final riderVehicleColor = requestData['assignedRiderVehicleColor'] as String?;
                  final riderPhotoUrl = requestData['assignedRiderPhotoUrl'] as String?;
                  final status = requestData['status'] as String? ?? 'assigned';
                  final hasArrived = requestData['hasArrived'] == true;
                  final alreadyRated = requestData['ratedByCustomer'] == true;

                  // Rising edge only — starts the loop exactly once per
                  // delivery, not on every rebuild while hasArrived stays
                  // true (this build method re-runs often, e.g. from the
                  // rider's live location updates).
                  if (hasArrived && !_hasStartedArrivalLoop) {
                    _hasStartedArrivalLoop = true;
                    _arrivedAtLocalRef = DateTime.now();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_acknowledgedArrival) SoundService.startDriverArrivedLoop();
                    });
                  }
                  final etaToPickup = (requestData['etaToPickupMinutes'] as num?)?.toInt();
                  final etaToDropoff = (requestData['etaToDropoffMinutes'] as num?)?.toInt();
                  final confirmationCode = requestData['deliveryConfirmationCode'] as String?;
                  final agreedPrice = (requestData['agreedPrice'] as num?)?.toDouble();

                  // The rider backed out — cancelRequest reopens the request
                  // (status flips back to "open") instead of cancelling it
                  // outright, so the customer should land back on the live bid
                  // list rather than being stuck on a tracking screen for a
                  // rider who's no longer coming.
                  if (status == 'open' && !_hasNavigatedAway) {
                    _hasNavigatedAway = true;
                    LiveActivityService.end(widget.requestId);
                    // Same reliability fix as orderCompleted below — driven
                    // by this screen's own live status field rather than the
                    // "request_reopened" FCM push, which only fires while
                    // foregrounded.
                    SoundService.cancellation();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => BidListScreen(requestId: widget.requestId)),
                      );
                    });
                  }

                  if (status == 'delivered') {
                    if (!_hasEndedLiveActivity) {
                      _hasEndedLiveActivity = true;
                      LiveActivityService.end(widget.requestId);
                    }
                    if (alreadyRated) {
                      return Column(children: [_ThankYouCard(amount: agreedPrice)]);
                    }
                    // Unlike the rider app (which pushes its rating screen
                    // right after the action that completes the delivery),
                    // the customer only learns "delivered" happened by
                    // watching this stream — so the navigation is driven
                    // from here instead, once, the first time this status is
                    // observed.
                    if (!_hasNavigatedToRating) {
                      _hasNavigatedToRating = true;
                      // Triggered directly off this screen's own live status
                      // field, not the "delivered" FCM push — the push only
                      // fires while foregrounded, and this branch already
                      // proves the customer is looking at exactly this
                      // screen right now regardless.
                      SoundService.orderCompleted();
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RateRiderScreen(
                              requestId: widget.requestId,
                              collectedAmount: agreedPrice,
                              riderName: riderName,
                            ),
                          ),
                        );
                      });
                    }
                    return const Center(child: CircularProgressIndicator());
                  }

                  final etaMinutes = status == 'assigned' ? etaToPickup : etaToDropoff;
                  final destination = (status == 'assigned'
                      ? requestData['pickup']
                      : requestData['dropoff']) as Map<String, dynamic>?;
                  final destinationPoint = destination?['geopoint'] as GeoPoint?;

                  // Mirrors _StatusBanner's own wording below so the Lock
                  // Screen / Dynamic Island card never disagrees with the
                  // in-app banner. Signature-gated because this whole
                  // builder re-runs on every rider GPS ping (see
                  // _lastLiveActivitySignature's own doc comment), and only
                  // status/eta/rider changes are worth pushing natively.
                  final liveActivityStatusText = status == 'assigned'
                      ? (hasArrived ? l10n.statusRiderArrived : l10n.statusHeadingToPickup)
                      : (status == 'picked_up' ? l10n.statusPickedUpOnWay : l10n.statusTrackingOrder);
                  final liveActivityEtaText = status == 'assigned' && !hasArrived && etaToPickup != null
                      ? l10n.etaToPickupLabel(etaToPickup)
                      : (status == 'picked_up' && etaToDropoff != null ? l10n.etaToDropoffLabel(etaToDropoff) : null);
                  final liveActivitySignature = '$status|$hasArrived|$etaToPickup|$etaToDropoff|$riderName';
                  if (liveActivitySignature != _lastLiveActivitySignature) {
                    _lastLiveActivitySignature = liveActivitySignature;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      LiveActivityService.startOrUpdate(
                        requestId: widget.requestId,
                        statusText: liveActivityStatusText,
                        etaText: liveActivityEtaText,
                        riderName: riderName,
                      );
                    });
                  }

                  // Everything before "delivered" is the dark tracking view
                  // per the design handoff — the rating/thank-you screen
                  // above is deliberately the app's normal light theme. Map
                  // fills the background; every Stack child below is
                  // explicitly Positioned (see the same fix across the other
                  // map-header screens — an un-Positioned child would size
                  // the whole Stack to itself instead of the full screen).
                  return Container(
                    width: double.infinity,
                    color: AppColors.inkAlt,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          // bottom:false SafeArea on the map layer only — an
                          // interactive Mapbox view starting right at the
                          // very top of the screen let its own pan/zoom
                          // gesture recognizer swallow the system's
                          // swipe-down-for-notifications gesture in that
                          // strip.
                          child: location == null
                              ? Center(
                                  child: Text(
                                    l10n.waitingForRiderLocation,
                                    style: const TextStyle(color: AppColors.mutedOnDark),
                                  ),
                                )
                              : SafeArea(
                                  bottom: false,
                                  child: _RiderLocationMap(
                                    location: location,
                                    destination: destinationPoint,
                                    vehicleType: riderVehicleType,
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
                                children: [
                                  Expanded(child: _StatusBanner(status: status, hasArrived: hasArrived, etaToPickup: etaToPickup, etaToDropoff: etaToDropoff)),
                                  const SizedBox(width: 10),
                                  _cancelOrReportAction(l10n, status),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.62),
                            decoration: const BoxDecoration(
                              color: AppColors.inkPanel,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                              border: Border(top: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.09))),
                            ),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (riderName != null || riderPhone != null)
                                    _ContactBar(
                                      name: riderName ?? l10n.yourRiderFallbackName,
                                      phone: riderPhone,
                                      photoUrl: riderPhotoUrl,
                                      vehicleColorKey: riderVehicleColor,
                                      vehicleLabel: riderVehicleType != null
                                          ? (_vehicleTypesCache[riderVehicleType] != null
                                              ? localizedVehicleTypeName(context, _vehicleTypesCache[riderVehicleType]!)
                                              : riderVehicleType)
                                          : null,
                                      plateNumber: riderPlateNumber,
                                    ),
                                  _StatusTimeline(status: status),
                                  if (agreedPrice != null || etaMinutes != null) ...[
                                    Row(
                                      children: [
                                        if (etaMinutes != null)
                                          Expanded(
                                            child: _StatTile(
                                              label: l10n.etaTileLabel,
                                              value: l10n.etaApproxMinutes(etaMinutes),
                                            ),
                                          ),
                                        if (etaMinutes != null && agreedPrice != null) const SizedBox(width: 10),
                                        if (agreedPrice != null)
                                          Expanded(
                                            child: _StatTile(
                                              label: l10n.amountDueLabel,
                                              value: '${agreedPrice.toStringAsFixed(0)} SDG',
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (status == 'assigned' && hasArrived) ...[
                                    _ArrivalNotice(
                                      acknowledged: _acknowledgedArrival,
                                      arrivedAt: _arrivedAtLocalRef,
                                      gracePeriod: _arrivalGracePeriod,
                                      onImComing: _acknowledgeArrival,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (confirmationCode != null) _ConfirmationCodeBanner(code: confirmationCode),
                                  // Mirrors the small X icon already in the
                                  // header (kept for quick access) with an
                                  // unmissable, clearly-labeled action —
                                  // "assigned" is the same window
                                  // cancelRequest.js's server-side check
                                  // already allows (open or assigned; once
                                  // picked_up it's a dispute/support flow
                                  // instead), just after the customer has
                                  // accepted a bid, not before.
                                  if (status == 'assigned') ...[
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _isCancelling ? null : _cancelRequest,
                                        icon: _isCancelling
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.dangerOnDark),
                                              )
                                            : const Icon(Icons.close, size: 18, color: AppColors.dangerOnDark),
                                        label: Text(l10n.cancelDeliveryButton),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.dangerOnDark,
                                          side: const BorderSide(color: AppColors.dangerOnDark),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.mutedOnDark, fontSize: 12)),
          const SizedBox(height: 4),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(value, style: AppTypography.amount(size: 16, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationCodeBanner extends StatelessWidget {
  final String code;
  const _ConfirmationCodeBanner({required this.code});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.confirmationCodeInstruction,
            style: const TextStyle(color: AppColors.accentOnDark, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final digit in code.split(''))
                  Container(
                    width: 26,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      digit,
                      style: AppTypography.amount(size: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown once the rider has marked arrival, until the customer taps "I'm
/// Coming" — the button is what actually stops the looping arrival sound
/// (see SoundService.stopDriverArrivedLoop). The 5-minute countdown here is
/// purely informational: once it runs out, the choice to cancel or start a
/// waiting fee belongs to the rider (active_delivery_screen.dart), not a
/// button on this screen.
class _ArrivalNotice extends StatelessWidget {
  final bool acknowledged;
  final DateTime? arrivedAt;
  final Duration gracePeriod;
  final VoidCallback onImComing;
  const _ArrivalNotice({
    required this.acknowledged,
    required this.arrivedAt,
    required this.gracePeriod,
    required this.onImComing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final elapsed = arrivedAt != null ? DateTime.now().difference(arrivedAt!) : Duration.zero;
    final remaining = gracePeriod - elapsed;
    final graceExpired = remaining <= Duration.zero;
    final color = graceExpired ? AppColors.dangerOnDark : AppColors.successOnDark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            graceExpired ? l10n.arrivalGraceExpiredMessage : l10n.arrivalGracePeriodMessage(_formatMinSec(remaining)),
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (!acknowledged) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onImComing,
                icon: const Icon(Icons.directions_walk, size: 18),
                label: Text(l10n.imComingButton),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatMinSec(Duration d) {
    final clamped = d.isNegative ? Duration.zero : d;
    final minutes = clamped.inMinutes;
    final seconds = clamped.inSeconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _ContactBar extends StatelessWidget {
  final String name;
  final String? phone;
  final String? photoUrl;
  final String? vehicleColorKey;
  final String? vehicleLabel;
  final String? plateNumber;
  const _ContactBar({
    required this.name,
    this.phone,
    this.photoUrl,
    this.vehicleColorKey,
    this.vehicleLabel,
    this.plateNumber,
  });

  Future<void> _call(BuildContext context) async {
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.phoneDialerError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        // Same alpha-white-on-dark treatment as _StatTile below — the panel
        // behind this is also inkPanel, so a matching solid color here was
        // visually indistinguishable from the background (only a faint
        // border hinted anything was there).
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null ? const Icon(Icons.delivery_dining, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                if (vehicleLabel != null || plateNumber != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (vehicleColorKey != null) ...[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: vehicleColorSwatch(vehicleColorKey) ?? Colors.white,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 0.5),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          [
                            if (vehicleColorKey != null) localizedVehicleColorName(context, vehicleColorKey!),
                            if (vehicleLabel != null) vehicleLabel!,
                            if (plateNumber != null) plateNumber!,
                          ].join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (phone != null)
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                onPressed: () => _call(context),
                style: IconButton.styleFrom(backgroundColor: AppColors.success, shape: const CircleBorder()),
                icon: const Icon(Icons.call, size: 18, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

// Always "driving" — matches create_request_screen.dart's
// _mapboxProfileFor and the server-side mapboxDirections.js.
String _mapboxProfileForVehicleType(String? vehicleTypeId) => 'driving';

class _RiderLocationMap extends StatefulWidget {
  final GeoPoint location;
  final GeoPoint? destination;
  final String? vehicleType;
  const _RiderLocationMap({required this.location, this.destination, this.vehicleType});

  @override
  State<_RiderLocationMap> createState() => _RiderLocationMapState();
}

class _RiderLocationMapState extends State<_RiderLocationMap> {
  MapboxMap? _mapboxMap;
  CircleAnnotationManager? _circleAnnotationManager;
  CircleAnnotation? _riderAnnotation;
  CircleAnnotation? _destinationAnnotation;
  PolylineAnnotationManager? _polylineAnnotationManager;
  PolylineAnnotation? _routeLine;

  // Re-fetching the real route on every single Firestore location update
  // would hammer the Directions API for no visible benefit — the rider dot
  // itself still moves on every update (cheap, no network call); only the
  // road-following line refreshes at this throttle.
  Position? _lastRouteFetchOrigin;
  DateTime? _lastRouteFetchAt;
  static const _routeRefetchMinInterval = Duration(seconds: 20);
  static const _routeRefetchMinMeters = 60.0;

  Future<void> _drawLine(List<Position> coordinates) async {
    final lineManager = _polylineAnnotationManager;
    if (lineManager == null) return;
    if (_routeLine != null) {
      _routeLine!.geometry = LineString(coordinates: coordinates);
      await lineManager.update(_routeLine!);
    } else {
      _routeLine = await lineManager.create(
        PolylineAnnotationOptions(
          geometry: LineString(coordinates: coordinates),
          lineColor: AppColors.primary.toARGB32(),
          lineWidth: 3.0,
        ),
      );
    }
  }

  Future<void> _fetchAndDrawRoute(Position origin) async {
    final destination = widget.destination;
    if (destination == null || _polylineAnnotationManager == null) return;
    _lastRouteFetchOrigin = origin;
    _lastRouteFetchAt = DateTime.now();
    final destPosition = Position(destination.longitude, destination.latitude);

    // A straight line first, drawn immediately with no network round trip —
    // the Directions fetch below can take a couple of seconds (or fail
    // outright on a flaky connection), and leaving the map blank until then
    // reads as "no line at all", not "still loading a better one".
    await _drawLine([origin, destPosition]);

    final route = await fetchRoute(origin, destPosition, profile: _mapboxProfileForVehicleType(widget.vehicleType));
    if (!mounted || _polylineAnnotationManager == null || route == null) return;
    await _drawLine(route.coordinates);
  }

  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    // Passive preview map, not interactive/rotatable — the default compass
    // ornament otherwise sits 4px from the map's own top-right corner,
    // which overlaps the status bar on this full-bleed map.
    unawaited(mapboxMap.compass.updateSettings(CompassSettings(enabled: false)));
    _polylineAnnotationManager = await mapboxMap.annotations.createPolylineAnnotationManager();
    final origin = Position(widget.location.longitude, widget.location.latitude);
    unawaited(_fetchAndDrawRoute(origin));

    _circleAnnotationManager = await mapboxMap.annotations.createCircleAnnotationManager();
    final destination = widget.destination;
    if (destination != null) {
      _destinationAnnotation = await _circleAnnotationManager!.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: Position(destination.longitude, destination.latitude)),
          circleColor: AppColors.accent.toARGB32(),
          circleRadius: 8.0,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 2.0,
        ),
      );
    }
    _riderAnnotation = await _circleAnnotationManager!.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: origin),
        circleColor: AppColors.primary.toARGB32(),
        circleRadius: 9.0,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 2.0,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant _RiderLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The map itself is created once and reused for the rider's whole trip
    // (assigned -> picked_up -> delivered) rather than torn down on every
    // update, so the rider dot can move smoothly. But that means a genuine
    // change in destination — pickup -> dropoff, once the rider marks the
    // package picked up — has to be handled explicitly here too: the pin
    // was previously only ever placed once in _onMapCreated, and the route
    // refetch below was only ever triggered by the RIDER moving, not by the
    // destination itself changing. If the rider marked picked-up while
    // stationary (having just arrived at pickup), neither ever fired, and
    // the customer kept seeing a stale route/pin pointed at the old pickup
    // location even after the status flipped to picked_up.
    final destinationChanged = widget.destination != oldWidget.destination;

    final newPosition = Position(widget.location.longitude, widget.location.latitude);
    final manager = _circleAnnotationManager;
    final annotation = _riderAnnotation;
    if (manager != null && annotation != null) {
      annotation.geometry = Point(coordinates: newPosition);
      manager.update(annotation);
    }
    // Deliberately NOT re-centering the camera here on every update — that
    // fought any manual pan/zoom the customer did, snapping straight back
    // to the rider a moment later. The moving dot above is enough on its
    // own; _RecenterOnRiderButton below covers "the rider moved off-screen
    // and I want to find them again."

    if (destinationChanged && manager != null) {
      final destination = widget.destination;
      if (destination == null) {
        if (_destinationAnnotation != null) {
          manager.delete(_destinationAnnotation!);
          _destinationAnnotation = null;
        }
      } else {
        final destPosition = Point(coordinates: Position(destination.longitude, destination.latitude));
        if (_destinationAnnotation != null) {
          _destinationAnnotation!.geometry = destPosition;
          manager.update(_destinationAnnotation!);
        } else {
          manager
              .create(CircleAnnotationOptions(
                geometry: destPosition,
                circleColor: AppColors.accent.toARGB32(),
                circleRadius: 8.0,
                circleStrokeColor: Colors.white.toARGB32(),
                circleStrokeWidth: 2.0,
              ))
              .then((created) => _destinationAnnotation = created);
        }
      }
    }

    final lastOrigin = _lastRouteFetchOrigin;
    final lastFetchAt = _lastRouteFetchAt;
    final movedMeters = lastOrigin == null
        ? double.infinity
        : Geolocator.distanceBetween(lastOrigin.lat.toDouble(), lastOrigin.lng.toDouble(), newPosition.lat.toDouble(), newPosition.lng.toDouble());
    final elapsed = lastFetchAt == null ? null : DateTime.now().difference(lastFetchAt);
    if (destinationChanged || movedMeters > _routeRefetchMinMeters || elapsed == null || elapsed > _routeRefetchMinInterval) {
      unawaited(_fetchAndDrawRoute(newPosition));
    }
  }

  Future<void> _recenterOnRider() async {
    final map = _mapboxMap;
    if (map == null) return;
    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(widget.location.longitude, widget.location.latitude)),
        zoom: 15.0,
      ),
      MapAnimationOptions(duration: 700),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          key: const ValueKey('trackingMap'),
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(widget.location.longitude, widget.location.latitude)),
            zoom: 15.0,
          ),
          styleUri: MapboxStyles.MAPBOX_STREETS,
          onMapCreated: _onMapCreated,
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsetsDirectional.only(end: 16),
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _recenterOnRider,
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(Icons.near_me, color: AppColors.primary, size: 20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final bool hasArrived;
  final int? etaToPickup;
  final int? etaToDropoff;
  const _StatusBanner({required this.status, this.hasArrived = false, this.etaToPickup, this.etaToDropoff});

  String _label(AppLocalizations l10n) {
    switch (status) {
      case 'assigned':
        return hasArrived ? l10n.statusRiderArrived : l10n.statusHeadingToPickup;
      case 'picked_up':
        return l10n.statusPickedUpOnWay;
      case 'delivered':
        return l10n.statusDeliveredThankYou;
      default:
        return l10n.statusTrackingOrder;
    }
  }

  String? _etaLabel(AppLocalizations l10n) {
    if (status == 'assigned' && !hasArrived && etaToPickup != null) {
      return l10n.etaToPickupLabel(etaToPickup!);
    }
    if (status == 'picked_up' && etaToDropoff != null) {
      return l10n.etaToDropoffLabel(etaToDropoff!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final etaLabel = _etaLabel(l10n);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      // Was a near-transparent white tint (Colors.white.withValues(alpha:
      // 0.1)) — designed for a dark map style, but the map actually loads
      // MAPBOX_STREETS (light), which made this all but invisible. A solid
      // panel color reads clearly regardless of what's under it.
      decoration: BoxDecoration(
        color: AppColors.inkPanel,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, size: 8, color: AppColors.successOnDark),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(l10n),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                if (etaLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      etaLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.mutedOnDark, fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The design handoff's status timeline, adapted to this app's actual
/// status values (there's no separate "arrived at pickup" status here —
/// only assigned / picked_up / delivered).
class _StatusTimeline extends StatelessWidget {
  final String status;
  const _StatusTimeline({required this.status});

  static const _steps = ['assigned', 'picked_up', 'delivered'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentIndex = _steps.indexOf(status).clamp(0, _steps.length - 1);
    final labels = [l10n.statusHeadingToPickup, l10n.statusPickedUpOnWay, l10n.statusDeliveredThankYou];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.inkPanel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _steps.length; i++)
            _TimelineRow(
              label: labels[i],
              done: i <= currentIndex,
              isLast: i == _steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final bool done;
  final bool isLast;
  const _TimelineRow({required this.label, required this.done, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done ? AppColors.successOnDark : Colors.transparent,
                  border: done ? null : Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.5),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: done ? const Color.fromRGBO(74, 222, 155, 0.34) : Colors.white.withValues(alpha: 0.14),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              label,
              style: TextStyle(color: done ? Colors.white : AppColors.mutedOnDark, fontSize: 13.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThankYouCard extends StatelessWidget {
  final double? amount;
  const _ThankYouCard({this.amount});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(color: AppColors.successTint, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: AppColors.success, size: 32),
              ),
              const SizedBox(height: 16),
              Text(l10n.deliveredExclamation, style: AppTypography.title(size: 22)),
              const SizedBox(height: 8),
              if (amount != null)
                Text(l10n.deliveredAmountCollected(amount!.toStringAsFixed(0)), style: AppTypography.body()),
              const SizedBox(height: 4),
              Text(l10n.thanksForRatingMessage, style: AppTypography.body(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}
