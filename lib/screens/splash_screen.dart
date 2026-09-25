import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/post_login_router.dart';
import '../services/sound_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_logo.dart';
import 'phone_login_screen.dart';

/// Full-bleed brand splash shown once at cold start, replacing the bare
/// spinner `AppStartup`/`AuthGateScreen` used to show. Runs the entrance
/// animation from the design handoff (logo → rule → tagline) on a fixed
/// timeline regardless of how fast Firebase/auth resolution finishes, then
/// crossfades into whichever destination that resolution lands on — so a
/// slow network doesn't cut the animation short, and a fast one doesn't
/// skip it entirely.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  static const _timeline = Duration(milliseconds: 2100);
  static const _crossfade = Duration(milliseconds: 280);

  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _timeline)..forward();
    SoundService.splash();
    _scheduleNavigation();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _scheduleNavigation() async {
    // _resolveDestination() starts running immediately (it's already an
    // in-flight Future by the time this line finishes) — awaiting the
    // timeline delay first, then the destination, waits for whichever is
    // actually longer without needing Future.wait's type-inference dance
    // (which broke: `Future.delayed(duration)` with no computation only
    // works when its inferred type is nullable, and mixing it into
    // Future.wait<Object> with _resolveDestination()'s Future<Widget> forced
    // a non-nullable Object, crashing on the implicit null result).
    final destinationFuture = _resolveDestination();
    await Future.delayed(_timeline);
    final destination = await destinationFuture;
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: _crossfade,
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Reads currentUser directly (synchronous, already populated by the time
  /// _initializeApp() -> Firebase.initializeApp() has completed) rather than
  /// awaiting authStateChanges().first — that stream's first emission was
  /// observed to never fire on a real iOS device freshly connected to the
  /// local Auth emulator (useAuthEmulator was just called moments earlier in
  /// the same startup sequence), hanging the splash screen indefinitely.
  /// Login screens navigate away with pushAndRemoveUntil rather than relying
  /// on a stream firing again mid-session (see the comment in
  /// customer_profile_screen.dart's logout), so a one-time synchronous read
  /// here is just as correct.
  Future<Widget> _resolveDestination() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const PhoneLoginScreen();
    try {
      // A cached session whose token no longer means anything to the
      // backend it's pointed at (e.g. a local emulator that's since been
      // restarted/wiped, or — in production — a genuinely revoked token)
      // must never be able to hang this screen forever: the Firestore read
      // inside resolveHomeDestination can hang indefinitely trying to
      // refresh a token the backend doesn't recognize. Timing out and
      // signing out falls back to a fresh login instead.
      return await resolveHomeDestination(user.uid).timeout(const Duration(seconds: 8));
    } catch (_) {
      await FirebaseAuth.instance.signOut();
      return const PhoneLoginScreen();
    }
  }

  /// Raw 0..1 progress through [beginMs, endMs] of the timeline, clamped —
  /// individual UI pieces apply their own curve to this.
  double _rawT(double beginMs, double endMs) {
    final begin = beginMs / _timeline.inMilliseconds;
    final end = endMs / _timeline.inMilliseconds;
    final v = _controller.value;
    if (v <= begin) return 0;
    if (v >= end) return 1;
    return (v - begin) / (end - begin);
  }

  /// Approximates the handoff's `.88 -> 1.02 -> 1.0` overshoot-and-settle.
  double _logoScale(double t) {
    if (t < 0.7) {
      return 0.88 + (1.02 - 0.88) * Curves.easeOut.transform((t / 0.7).clamp(0.0, 1.0));
    }
    // Floating-point division here (e.g. (t-0.7)/0.3) can land a hair above
    // 1.0 — Curve.transform asserts its input is exactly within [0, 1] and
    // throws otherwise, so this clamp isn't optional.
    return 1.02 + (1.0 - 1.02) * Curves.easeIn.transform(((t - 0.7) / 0.3).clamp(0.0, 1.0));
  }

  Widget _decorCircle(double diameter, double opacity) => Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          Positioned(top: -80, right: -60, child: _decorCircle(320, 0.055)),
          Positioned(bottom: -100, left: -80, child: _decorCircle(260, 0.04)),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final logoT = _rawT(0, 520);
                final logoOpacity = Curves.easeOut.transform(logoT);
                final ruleT = _rawT(500, 900);
                final ruleScaleX = Curves.ease.transform(ruleT);
                final tagT = _rawT(720, 1220);
                final tagOpacity = Curves.easeOut.transform(tagT);

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: logoOpacity,
                      child: Transform.scale(
                        scale: _logoScale(logoT),
                        child: const AppLogo(
                          variant: AppLogoVariant.wordmark,
                          color: AppLogoColor.white,
                          width: 150,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()..scaleByDouble(ruleScaleX, 1.0, 1.0, 1.0),
                      child: Container(
                        width: 56,
                        height: 2,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: tagOpacity,
                      child: Transform.translate(
                        offset: Offset(0, 9 * (1 - tagOpacity)),
                        child: Text(
                          l10n.splashTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: isArabic ? 21 : 16,
                            height: isArabic ? 1.6 : 1.5,
                            fontWeight: isArabic ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
