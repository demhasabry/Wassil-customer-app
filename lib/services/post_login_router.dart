import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/create_request_screen.dart';
import '../screens/profile_setup_screen.dart';

/// Decides where a signed-in user should land: straight into the app if
/// post-OTP profile setup (gender/region) was already completed, or back
/// into ProfileSetupScreen if not. Used both by the app's startup auth gate
/// (main.dart) and by every login path that doesn't already know which one
/// applies (password login, forgot-password, legacy set-password).
Future<Widget> resolveHomeDestination(String uid) async {
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final data = doc.data();
  final isProfileComplete = data != null && data['gender'] != null && data['region'] != null;
  return isProfileComplete ? const CreateRequestScreen() : const ProfileSetupScreen();
}

Future<void> routeAfterLogin(BuildContext context, String uid) async {
  final destination = await resolveHomeDestination(uid);
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => destination),
    (route) => false,
  );
}
