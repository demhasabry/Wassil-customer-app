/// A deterministic, internal-only "email" derived from a phone number, used
/// solely to link a password credential to an otherwise phone-only Firebase
/// Auth account (Firebase has no native phone+password sign-in method). This
/// is never shown to the user and is unrelated to the real, optional contact
/// email stored on the user's profile.
String syntheticAuthEmail(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  return '$digits@phone.deliveryplatform.internal';
}
