# Customer App

## Screen flow
```
PhoneLoginScreen → OtpVerifyScreen → CreateRequestScreen → BidListScreen → TrackingScreen
```

- **phone_login_screen.dart** — enters phone number, normalizes to +249 (Sudan) format, sends OTP via Firebase Auth
- **otp_verify_screen.dart** — verifies the 6-digit code, creates the `users/{uid}` profile doc on first login
- **create_request_screen.dart** — tap the map to set pickup/drop-off pins, describe the package, optional suggested price, posts to `delivery_requests`
- **bid_list_screen.dart** — live-streams incoming bids (cheapest first) with a 60s countdown, calls the `acceptBid` Cloud Function when the customer taps Accept
- **tracking_screen.dart** — live map of the assigned rider's location, status banner (assigned → picked up → delivered)

## Placeholder branding
`lib/theme/app_theme.dart` holds the one place to swap colors/logo once you
upload the real visual identity — nothing else needs to change. Look for the
`AppLogoPlaceholder` widget and `AppTheme.primarySeedColor`.

## Before this runs
This code assumes a Flutter project has been initialized with FlutterFire
(`flutterfire configure`), which generates `firebase_options.dart` — that
file isn't included here since it's tied to your specific Firebase project
credentials. I'll generate the full runnable project (with that config wired
in) once you're ready to actually run this on a device/emulator.

## Not yet built (comes with rider app / later polish)
- Rating screen after delivery
- Wallet top-up flow
- Order history list
- Push notification handling in foreground (currently only background/closed via FCM)
