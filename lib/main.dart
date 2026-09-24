import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'screens/splash_screen.dart';
import 'services/fcm_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'l10n/locale_controller.dart';
import 'widgets/app_logo.dart';

// Toggle this off once you're ready to test against your real Firebase
// project instead of the local emulator suite.
const bool useLocalEmulators = true;

// Public token — safe to embed in client code, this is what it's for.
// Only grants read access to map styles/tiles, not account control.
const String _mapboxPublicToken =
    'pk.eyJ1IjoiZGVtaGFzYWJyeTEzIiwiYSI6ImNtdHJ4cHdkZTA4MDYyeHNodzAydTB4OHEifQ.nK4Qu3jycEZkjLQUnQB6og';

void main() {
  // Deliberately synchronous up to runApp() — Firebase init, emulator
  // wiring, and loading the saved locale all involve native channel calls
  // that can take real time (worse under the emulator/resource-contention
  // issues already seen on this machine). Awaiting them here, before the
  // first frame is ever painted, left Android's Choreographer with nothing
  // to draw for that whole stretch, which is exactly what shows up as a
  // "Skipped N frames" warning at launch. AppStartup below does that work
  // instead, after runApp() has already put a frame on screen.
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken(_mapboxPublicToken);
  runApp(const CustomerApp());
}

Future<void> _initializeApp() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await localeController.loadSaved();

  // kDebugMode alone used to gate this, but iOS 14+ refuses to launch a
  // debug-mode Flutter build standalone (outside Xcode/Flutter tooling) at
  // all — a CI-built .ipa sideloaded via AltStore has to be --profile or
  // --release to even open. USE_LOCAL_EMULATORS lets a profile/release
  // build still opt into emulator mode explicitly via --dart-define,
  // independent of build mode, without changing anything about the normal
  // `flutter run` debug workflow (kDebugMode is still true there, so this
  // dart-define isn't needed for that path).
  const forceLocalEmulators = bool.fromEnvironment('USE_LOCAL_EMULATORS');
  if ((kDebugMode || forceLocalEmulators) && useLocalEmulators) {
    // 10.0.2.2 is the special alias the Android emulator uses to reach
    // "localhost" on the machine it's running on — the default, so the
    // usual `flutter run` on the emulator needs no flag. Testing on a real
    // physical phone instead: pass your computer's LAN IP (run `ipconfig`,
    // look for the Wi-Fi adapter) via --dart-define=EMULATOR_HOST=<ip>. To
    // test over USB only (no Wi-Fi at all), run `adb reverse tcp:PORT
    // tcp:PORT` for each of 9099/8080/5001/9199 and use
    // --dart-define=EMULATOR_HOST=127.0.0.1 — automaticHostMapping: false
    // below is required for that case: without it, every one of these
    // plugins silently rewrites "127.0.0.1"/"localhost" to "10.0.2.2" on
    // Android (see e.g. cloud_functions's firebase_functions.dart), which
    // is not a real address on a physical device and breaks adb reverse.
    const emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099, automaticHostMapping: false);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080, automaticHostMapping: false);
    FirebaseFunctions.instance.useFunctionsEmulator(emulatorHost, 5001, automaticHostMapping: false);
    await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199, automaticHostMapping: false);
  }
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app when the language changes — either from the
    // in-app switcher or (on first load) the saved override.
    return AnimatedBuilder(
      animation: localeController,
      builder: (context, _) {
        return MaterialApp(
          title: 'Wassil',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          // null locale means "follow the system" — Flutter automatically
          // matches the phone's language against supportedLocales below.
          locale: localeController.overrideLocale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AppStartup(),
        );
      },
    );
  }
}

/// Runs Firebase/emulator/locale setup after the first frame is already on
/// screen (see the comment in main() above), then hands off to SplashScreen,
/// which resolves whether to land on PhoneLoginScreen or straight past login
/// (via resolveHomeDestination) — keeping the user signed in across app
/// restarts instead of always forcing a fresh OTP verification.
class AppStartup extends StatefulWidget {
  const AppStartup({super.key});

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  late final Future<void> _initFuture = _initializeApp();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          // A static brand frame while Firebase/emulator wiring completes —
          // SplashScreen can't mount yet since it calls FirebaseAuth as soon
          // as it's built, which isn't safe until _initFuture resolves. This
          // window is normally brief; the real animated entrance starts the
          // moment SplashScreen takes over below.
          return const Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(
              child: AppLogo(variant: AppLogoVariant.wordmark, color: AppLogoColor.white, width: 150),
            ),
          );
        }
        return const SplashScreen();
      },
    );
  }
}
