import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Short, fire-and-forget UI sound effects. A fresh AudioPlayer per one-shot
/// call (not a shared/reused instance) so two overlapping triggers don't cut
/// each other off — each disposes itself once playback finishes. The one
/// looping sound (driverArrivedLoop) is the exception — only one of those
/// plays at a time, tracked separately so it can be stopped on demand.
class SoundService {
  SoundService._();

  // stayAwake keeps playback going while the screen is locked or the app is
  // backgrounded (still running, not force-closed) — on Android this asks
  // for a PARTIAL_WAKE_LOCK; on iOS it needs the UIBackgroundModes "audio"
  // key already added to Info.plist. Without this, every sound below only
  // reliably played while the app was in the foreground.
  static final AudioContext _bgContext = AudioContextConfig(stayAwake: true).build();

  static Future<void> _play(String assetFileName) async {
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.release);
      unawaited(
        player.play(AssetSource('sounds/$assetFileName'), ctx: _bgContext).catchError((_) {}),
      );
      player.onPlayerComplete.first.then((_) => player.dispose());
    } catch (_) {
      // Sound is a nice-to-have — never let a playback failure (missing
      // audio focus, a muted device, an unsupported platform) affect
      // anything else in the app.
    }
  }

  /// A push notification arrived while the app was in the foreground for an
  /// event that doesn't have its own distinct sound below (picked up, bid
  /// rejected, etc.) — the OS only plays its own notification sound
  /// automatically in the background, so this fills the foreground gap the
  /// SnackBar fallback already covers visually.
  static Future<void> notification() => _play('notification.wav');

  /// A rider just submitted a bid on this customer's open request.
  static Future<void> bidReceived() => _play('bid_received.mp3');

  /// This customer just accepted a rider's bid.
  static Future<void> bidAccepted() => _play('bid_accepted.mp3');

  /// A ride (this customer's own cancel, or the rider backing out) was
  /// cancelled.
  static Future<void> cancellation() => _play('cancellation.mp3');

  /// The delivery was marked complete.
  static Future<void> orderCompleted() => _play('order_completed.mp3');

  /// Plays once on the splash screen.
  static Future<void> splash() => _play('splash.mp3');

  // ---- Looping: the assigned rider has arrived at pickup ----
  // Plays on repeat until the customer acknowledges (taps "I'm coming" on
  // the tracking screen) — a one-shot ping was too easy to miss if the
  // phone was in a pocket.
  //
  // Deliberately NOT using ReleaseMode.loop — that only played once in
  // practice (a known unreliable spot in audioplayers across platform
  // implementations). Manually restarting on every onPlayerComplete is the
  // bulletproof version: it doesn't depend on the native player's own loop
  // support working correctly at all.
  static AudioPlayer? _loopingPlayer;
  static StreamSubscription<void>? _loopingSubscription;

  static const String _driverArrivedAsset = 'sounds/driver_arrived.mp3';

  static Future<void> startDriverArrivedLoop() async {
    await stopDriverArrivedLoop();
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      _loopingPlayer = player;
      _loopingSubscription = player.onPlayerComplete.listen((_) {
        // A full play() call again, not seek(zero)+resume() — the latter
        // was found to only restart reliably on Android; on iOS, once a
        // player reaches "completed", resume() after a seek doesn't
        // reliably resume playback (an AVAudioPlayer state-transition quirk
        // distinct from Android's ExoPlayer/MediaPlayer backend), so the
        // loop played once and then silently stopped. Re-issuing play()
        // works identically on both platforms.
        if (_loopingPlayer == player) {
          player.play(AssetSource(_driverArrivedAsset), ctx: _bgContext);
        }
      });
      await player.play(AssetSource(_driverArrivedAsset), ctx: _bgContext);
    } catch (_) {
      _loopingPlayer = null;
    }
  }

  static Future<void> stopDriverArrivedLoop() async {
    final player = _loopingPlayer;
    _loopingPlayer = null;
    await _loopingSubscription?.cancel();
    _loopingSubscription = null;
    if (player == null) return;
    try {
      await player.stop();
      await player.dispose();
    } catch (_) {
      // Already gone — nothing left to clean up.
    }
  }
}
