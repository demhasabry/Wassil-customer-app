import 'package:live_activities/live_activities.dart';

/// Thin wrapper around the `live_activities` plugin, scoped to exactly what
/// tracking_screen.dart needs: one Live Activity per delivery request,
/// keyed by requestId (the plugin's own flexible id-matching means the same
/// string can be reused across create/update/end calls without tracking the
/// native-generated activity id ourselves).
///
/// Deliberately iOS-only in spirit — every call is wrapped so a failure
/// (unsupported iOS version, Live Activities disabled in Settings, or
/// simply running on Android where this plugin is a no-op-ish shim) never
/// breaks the actual delivery-tracking flow this sits alongside. The
/// Dynamic Island itself only exists on iPhone 14 Pro and later (all
/// iPhone 15/16 models); everything else just gets the same content as a
/// Lock Screen card, which iOS handles automatically — nothing here needs
/// to know which case it is.
class LiveActivityService {
  LiveActivityService._();

  // Must exactly match the App Group string baked into DeliveryWidget's
  // entitlements, Runner's entitlements, and
  // DeliveryLiveActivityWidget.swift's UserDefaults(suiteName:) call.
  static const _appGroupId = 'group.com.example.customerApp.liveactivity';

  static final LiveActivities _plugin = LiveActivities();
  static bool _initialized = false;

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    try {
      await _plugin.init(appGroupId: _appGroupId);
      _initialized = true;
    } catch (_) {
      // Leave _initialized false — every call below no-ops until a future
      // attempt succeeds, rather than ever throwing into tracking_screen.
    }
  }

  static Future<void> startOrUpdate({
    required String requestId,
    required String statusText,
    String? etaText,
    String? riderName,
  }) async {
    await _ensureInit();
    if (!_initialized) return;
    try {
      await _plugin.createOrUpdateActivity(
        requestId,
        {
          'statusText': statusText,
          'etaText': etaText ?? '',
          'riderName': riderName ?? '',
        },
        // No server-push updates — this app updates the activity directly
        // from the Firestore listener already driving tracking_screen.dart
        // while it's foregrounded/backgrounded-but-running, and enabling
        // this would require the Push Notifications capability, which free
        // Apple ID signing (this app's whole sideloading setup) cannot be
        // granted.
        iOSEnableRemoteUpdates: false,
      );
    } catch (_) {
      // A single missed update is not worth surfacing — the next Firestore
      // snapshot retries with fresh data moments later regardless.
    }
  }

  static Future<void> end(String requestId) async {
    if (!_initialized) return;
    try {
      await _plugin.endActivity(requestId);
    } catch (_) {}
  }
}
