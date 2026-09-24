import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'fcm_service.dart';
import 'post_login_router.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/set_password_screen.dart';

/// Everything that needs to happen once a [PhoneAuthCredential] is proven
/// valid — sign in, create the Firestore user doc for a brand-new account,
/// register for push, and navigate on to SetPasswordScreen. There are two
/// ways a credential reaches this point: the customer types the 6-digit
/// code (otp_verify_screen.dart) or Android auto-retrieves it without ever
/// showing that screen (verificationCompleted, in phone_login_screen.dart /
/// forgot_password_screen.dart) — both must do the exact same thing after,
/// which is why this lives here instead of being duplicated a third time.
/// Previously the auto-retrieval path only signed in and stopped, leaving
/// the screen looking frozen while the account was actually already
/// authenticated underneath.
Future<void> completePhoneAuthSignIn({
  required BuildContext context,
  required PhoneAuthCredential credential,
  required bool isNewAccount,
  required String phoneNumber,
  String? name,
}) async {
  final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
  final uid = userCredential.user!.uid;

  if (isNewAccount) {
    // Does NOT set role/walletBalance to anything privileged — those
    // default server-side conventions live in Cloud Functions if you want
    // stricter control later.
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'phone': phoneNumber,
      'name': name,
      'role': 'customer',
      'rating': 0,
      'ratingCount': 0,
      'walletBalance': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Deliberately NOT awaited — a real network call to Google's servers,
  // which can be slow or hang on an emulator; login should never wait on
  // it. If it fails, initForUser() catches its own errors internally.
  FcmService.initForUser(uid);

  if (!context.mounted) return;
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => SetPasswordScreen(
        phone: phoneNumber,
        onSuccess: isNewAccount
            ? (ctx) async => Navigator.of(ctx).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                  (route) => false,
                )
            : (ctx) => routeAfterLogin(ctx, uid),
      ),
    ),
    (route) => false,
  );
}
