import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

// Mirrors main.dart's exact same emulator-detection flags — kept as a
// separate read (not imported from main.dart) since these are compile-time
// constants and this avoids coupling this service to main.dart's file
// structure.
const bool _isLocalEmulator = kDebugMode || bool.fromEnvironment('USE_LOCAL_EMULATORS');
const String _emulatorHost = String.fromEnvironment('EMULATOR_HOST', defaultValue: '10.0.2.2');
const int _emulatorFunctionsPort = 5001;
const String _projectId = 'delivery-platform-atbara';
const String _region = 'us-central1';

/// Duck-types HttpsCallableResult (just a `.data` getter) so existing call
/// sites doing `result.data['field']` keep working unchanged regardless of
/// which path below actually served the call.
class CallableResult {
  final dynamic data;
  const CallableResult(this.data);
}

/// Calls a Cloud Function exactly like `httpsCallable(name).call(data)`,
/// except while connected to the local emulator it bypasses the
/// `cloud_functions` plugin's own network layer entirely — like
/// firebase_storage, it was confirmed (via the emulator's own callable
/// verification log showing `"auth":"MISSING"` for an actually-signed-in
/// user) not to reliably attach the caller's auth token to emulator
/// requests on iOS. A plain authenticated HTTP POST works correctly in
/// every case tested; production is unaffected since it still goes through
/// the normal SDK call.
Future<CallableResult> callFunction(String name, [Map<String, dynamic>? data]) async {
  if (!_isLocalEmulator) {
    final result = await FirebaseFunctions.instance.httpsCallable(name).call(data);
    return CallableResult(result.data);
  }

  final idToken = await FirebaseAuth.instance.currentUser?.getIdToken(true);
  final url = Uri.parse('http://$_emulatorHost:$_emulatorFunctionsPort/$_projectId/$_region/$name');
  final response = await http.post(
    url,
    headers: {
      'Content-Type': 'application/json',
      if (idToken != null) 'Authorization': 'Bearer $idToken',
    },
    body: jsonEncode({'data': data ?? {}}),
  );

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  if (json.containsKey('error')) {
    final error = json['error'] as Map<String, dynamic>;
    final status = (error['status'] as String? ?? 'INTERNAL').toLowerCase().replaceAll('_', '-');
    // ignore: invalid_use_of_protected_member
    throw FirebaseFunctionsException(
      code: status,
      message: error['message'] as String? ?? 'Unknown error',
    );
  }
  return CallableResult(json['result']);
}
