import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

// Mirrors main.dart's exact same emulator-detection flags — kept as a
// separate read (not imported from main.dart) since these are compile-time
// constants and this avoids coupling this service to main.dart's file
// structure.
const bool _isLocalEmulator = kDebugMode || bool.fromEnvironment('USE_LOCAL_EMULATORS');
const String _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const int _emulatorStoragePort = 9199;

/// Uploads a file to Firebase Storage and returns its download URL.
///
/// Confirmed (via a direct authenticated REST call, both over localhost and
/// over the LAN IP a physical device actually uses) that the Storage
/// emulator itself correctly accepts these writes — the problem is
/// specifically the `firebase_storage` plugin's iOS native SDK failing to
/// attach the auth token when talking to a LOCAL EMULATOR (a known
/// FlutterFire/Firebase iOS SDK issue), which makes every real
/// `ref.putFile()` call fail with `storage/unauthorized` regardless of a
/// valid session or permissive rules. Production Storage is unaffected by
/// this bug, so this only takes the raw-HTTP path while connected to the
/// local emulator; a real deployment uses the normal, working SDK call.
Future<String> uploadToStorage({required File file, required String storagePath}) async {
  if (!_isLocalEmulator) {
    final ref = FirebaseStorage.instance.ref(storagePath);
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
  final bucket = FirebaseStorage.instance.bucket;
  final encodedName = Uri.encodeComponent(storagePath);
  final uploadUrl = Uri.parse('http://$_emulatorHost:$_emulatorStoragePort/v0/b/$bucket/o?name=$encodedName');

  final response = await http.post(
    uploadUrl,
    headers: {
      if (idToken != null) 'Authorization': 'Bearer $idToken',
      'Content-Type': 'image/jpeg',
    },
    body: await file.readAsBytes(),
  );

  if (response.statusCode != 200) {
    throw FirebaseException(
      plugin: 'storage-emulator-workaround',
      code: 'upload-failed',
      message: 'Emulator upload failed (${response.statusCode}): ${response.body}',
    );
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final downloadToken = json['downloadTokens'] as String?;
  return 'http://$_emulatorHost:$_emulatorStoragePort/v0/b/$bucket/o/$encodedName?alt=media&token=$downloadToken';
}
