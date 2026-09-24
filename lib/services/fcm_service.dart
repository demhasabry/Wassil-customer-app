import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Global key so foreground notifications can show a SnackBar from
/// anywhere, without needing a BuildContext passed down through every screen.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class FcmService {
  /// Call once, right after a user signs in. Requests notification
  /// permission, saves the device's FCM token to their user doc (this is
  /// what was missing before — Cloud Functions send pushes by reading
  /// `users/{uid}.fcmToken`, which was always empty until now), and keeps it
  /// updated if the token ever refreshes.
  static Future<void> initForUser(String uid) async {
    final messaging = FirebaseMessaging.instance;

    try {
      await messaging.requestPermission(alert: true, badge: true, sound: true).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('Permission request timed out'),
      );

      final token = await messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw Exception('getToken timed out'),
      );
      if (token != null) {
        await _saveToken(uid, token);
      }

      messaging.onTokenRefresh.listen((newToken) => _saveToken(uid, newToken));
    } catch (e) {
      // Push notifications are a nice-to-have, not a login requirement.
      // If this fails or times out (unreliable Play Services setup on an
      // emulator, no network, etc.), the app should keep working normally —
      // just without push notifications until it succeeds on a later launch.
      debugPrint('FCM setup failed or timed out, continuing without it: $e');
    }

    // Foreground messages don't show a system notification automatically on
    // Android — without this listener, a push sent while the app is open
    // would silently do nothing. This shows it as an in-app SnackBar instead.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? 'Notification';
      final body = message.notification?.body ?? '';
      // Silent — every event that has its own distinct sound already plays
      // it directly off a live Firestore listener the relevant screen holds
      // (bid_list_screen.dart's own bid stream, tracking_screen.dart's own
      // status field), which is reliable regardless of push timing. This
      // banner is just a fallback visual notice for a foregrounded app, not
      // a place to play a generic ding on top of whatever else is playing.
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Text('$title\n$body'),
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  static Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({'fcmToken': token});
  }
}
