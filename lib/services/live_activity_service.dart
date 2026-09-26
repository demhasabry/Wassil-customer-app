import 'package:flutter/services.dart';

/// Talks directly to a small custom native Swift bridge
/// (ios/Runner/LiveActivityChannel.swift) rather than the `live_activities`
/// package. That package's content is delivered via a shared App Group
/// UserDefaults container, which needs an App Groups entitlement — and
/// registering a NEW App Group identifier turned out to require enrollment
/// in Apple's paid Developer Program (confirmed directly against
/// developer.apple.com with this project's free Apple ID, which this whole
/// sideloading setup depends on). ActivityKit's own ContentState sync
/// between the app and widget extension processes is a separate,
/// OS-guaranteed mechanism that needs no such entitlement, so this bridges
/// straight to that instead.
///
/// Deliberately best-effort throughout — every call is wrapped so a failure
/// (unsupported iOS version, Live Activities disabled in Settings, running
/// on Android where the native handler isn't registered at all) never
/// breaks the actual delivery-tracking flow this sits alongside. The
/// Dynamic Island itself only exists on iPhone 14 Pro and later; everything
/// else just gets the same content as a Lock Screen card, which iOS handles
/// automatically — nothing here needs to know which case it is.
class LiveActivityService {
  LiveActivityService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.customerApp/liveActivity');

  static Future<void> startOrUpdate({
    required String requestId,
    required String statusText,
    String? etaText,
    String? riderName,
  }) async {
    try {
      await _channel.invokeMethod('startOrUpdate', {
        'requestId': requestId,
        'statusText': statusText,
        'etaText': etaText ?? '',
        'riderName': riderName ?? '',
      });
    } catch (_) {
      // A single missed update is not worth surfacing — the next Firestore
      // snapshot retries with fresh data moments later regardless.
    }
  }

  static Future<void> end(String requestId) async {
    try {
      await _channel.invokeMethod('end', {'requestId': requestId});
    } catch (_) {}
  }
}
