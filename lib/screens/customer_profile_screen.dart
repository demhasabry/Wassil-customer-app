import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_controller.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';
import '../widgets/saved_addresses_sheet.dart';
import 'faq_screen.dart';
import 'contact_support_screen.dart';
import 'phone_login_screen.dart';
import 'wallet_screen.dart';
import 'order_history_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  bool _isSavingField = false;
  bool _isUploadingPhoto = false;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final _picker = ImagePicker();

  // Photo is optional and only ever set once, at profile_setup_screen.dart
  // — this is the only way to change it afterward. Mirrors rider_app's
  // rider_profile_screen.dart._editPhoto() exactly (same storage path
  // convention, so a re-upload simply overwrites the previous photo).
  Future<void> _editPhoto() async {
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.takePhotoOption),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.chooseFromGalleryOption),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked = await _picker.pickImage(source: source, imageQuality: 70);
    if (picked == null || !mounted) return;

    setState(() => _isUploadingPhoto = true);
    try {
      // Force a fresh ID token before uploading — the Storage SDK doesn't
      // refresh/attach tokens as eagerly as Auth/Firestore do, which caused
      // uploads to fail with storage/unauthorized on iOS despite a
      // perfectly valid session and correct rules.
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
      final ref = FirebaseStorage.instance.ref('profile_pictures/$_uid/photo.jpg');
      await ref.putFile(File(picked.path));
      final photoUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(_uid).update({'photoUrl': photoUrl});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileUpdated)));
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.logoutButton)),
        ],
      ),
    );
    if (confirmed != true) return;

    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // Not popUntil(isFirst) — that only works once SplashScreen's own
    // authStateChanges() listener has already rebuilt the root route to show
    // PhoneLoginScreen, and that rebuild isn't reliably reflected on screen
    // until the next full repaint (e.g. backgrounding and reopening the app
    // forces one; simply popping back to the stale root route doesn't).
    // Navigating to a known destination directly sidesteps that timing
    // entirely.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const PhoneLoginScreen()),
      (route) => false,
    );
  }

  Future<void> _redeemPromoCode() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.redeemPromoCodeButton),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(hintText: l10n.promoCodeHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelButton)),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l10n.redeemButton),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty || !mounted) return;

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('redeemPromoCode');
      final result = await callable.call({'code': code});
      if (!mounted) return;
      final amount = (result.data['amount'] as num).toStringAsFixed(0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.promoRedeemedMessage(amount))),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? l10n.promoRedeemError)),
      );
    }
  }

  Future<void> _editName(String currentName) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.fullNameLabel),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.name,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[0-9]'))],
          decoration: InputDecoration(labelText: l10n.fullNameLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.saveChangesButton)),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    setState(() => _isSavingField = true);
    await FirebaseFirestore.instance.collection('users').doc(_uid).update({'name': controller.text.trim()});
    if (!mounted) return;
    setState(() => _isSavingField = false);
  }

  Future<void> _editEmail(String currentEmail) async {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: currentEmail);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.emailLabel),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: l10n.emailLabel),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.saveChangesButton)),
        ],
      ),
    );
    if (saved != true || !mounted) return;

    final email = controller.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidEmailError)));
      return;
    }
    setState(() => _isSavingField = true);
    await FirebaseFirestore.instance.collection('users').doc(_uid).update({'email': email.isEmpty ? null : email});
    if (!mounted) return;
    setState(() => _isSavingField = false);
  }

  // Also persisted to Firestore (not just the local pref) — Cloud Functions
  // read users/{uid}.languagePreference to send a single-language push
  // instead of a bilingual one (see localizeNotification.js). Best-effort,
  // not awaited — a slow/failed write shouldn't hold up switching the
  // in-app language, which localeController.setLocale already applies
  // synchronously from local prefs.
  void _setLanguage(Locale? locale) {
    localeController.setLocale(locale);
    FirebaseFirestore.instance.collection('users').doc(_uid).update({
      'languagePreference': locale?.languageCode,
    });
  }

  void _showLanguagePicker(AppLocalizations l10n, String? current) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.languageLabel, style: AppTypography.heading(size: 16)),
            ),
            RadioListTile<String?>(
              title: Text(l10n.languageSystemDefault),
              value: null,
              groupValue: current,
              onChanged: (_) {
                _setLanguage(null);
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: Text(l10n.languageEnglish),
              value: 'en',
              groupValue: current,
              onChanged: (_) {
                _setLanguage(const Locale('en'));
                Navigator.pop(context);
              },
            ),
            RadioListTile<String?>(
              title: Text(l10n.languageArabic),
              value: 'ar',
              groupValue: current,
              onChanged: (_) {
                _setLanguage(const Locale('ar'));
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(_uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.exists ? snapshot.data!.data() as Map<String, dynamic> : const {};
          final name = data['name'] as String? ?? '';
          final email = data['email'] as String? ?? '';
          final phone = data['phone'] as String?;
          final photoUrl = data['photoUrl'] as String?;
          final balance = (data['walletBalance'] as num?)?.toDouble() ?? 0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _isUploadingPhoto ? null : _editPhoto,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          CircleAvatar(
                            radius: 31,
                            backgroundColor: AppColors.primary,
                            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                            child: _isUploadingPhoto
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : photoUrl == null
                                    ? Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 24),
                                      )
                                    : null,
                          ),
                          Positioned(
                            bottom: -2,
                            right: -2,
                            child: Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Icon(Icons.camera_alt, size: 12, color: AppColors.ink),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: _isSavingField ? null : () => _editName(name),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(name, style: AppTypography.heading(size: 16, color: AppColors.ink)),
                          const SizedBox(width: 4),
                          const Icon(Icons.edit_outlined, size: 14, color: AppColors.mutedLight),
                        ],
                      ),
                    ),
                    if (phone != null)
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(phone, style: AppTypography.amount(size: 14, color: AppColors.muted)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Text(
                l10n.accountSectionLabel.toUpperCase(),
                style: AppTypography.label(size: 12, color: AppColors.mutedLight),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.borderAlt),
                ),
                child: Column(
                  children: [
                    _SettingsRow(
                      icon: Icons.history,
                      label: l10n.orderHistoryTooltip,
                      onTap: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const OrderHistoryScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: l10n.walletButton,
                      value: balance.toStringAsFixed(0),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen())),
                    ),
                    StreamBuilder<QuerySnapshot>(
                      stream: savedAddressesRef().snapshots(),
                      builder: (context, savedSnap) {
                        final count = savedSnap.data?.docs.length ?? 0;
                        return _SettingsRow(
                          icon: Icons.bookmark_outline,
                          label: l10n.savedAddressesTooltip,
                          value: l10n.savedAddressesCountLabel(count),
                          onTap: () => showSavedAddressesSheet(context, title: l10n.savedAddressesHeading),
                        );
                      },
                    ),
                    AnimatedBuilder(
                      animation: localeController,
                      builder: (context, _) {
                        final current = localeController.overrideLocale?.languageCode;
                        final label = switch (current) {
                          'en' => l10n.languageEnglish,
                          'ar' => l10n.languageArabic,
                          _ => l10n.languageSystemDefault,
                        };
                        return _SettingsRow(
                          icon: Icons.language,
                          label: l10n.languageLabel,
                          value: label,
                          onTap: () => _showLanguagePicker(l10n, current),
                        );
                      },
                    ),
                    _SettingsRow(
                      icon: Icons.mail_outline,
                      label: l10n.emailLabel,
                      value: email.isEmpty ? null : email,
                      onTap: _isSavingField ? () {} : () => _editEmail(email),
                    ),
                    _SettingsRow(
                      icon: Icons.help_outline,
                      label: l10n.faqButton,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FaqScreen())),
                    ),
                    _SettingsRow(
                      icon: Icons.support_agent,
                      label: l10n.contactSupportButton,
                      onTap: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactSupportScreen())),
                      isLast: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.accentTint,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.accentBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined, color: AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l10n.redeemPromoCodeButton, style: AppTypography.body(color: AppColors.accentInk)),
                    ),
                    TextButton(
                      onPressed: _redeemPromoCode,
                      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                      child: Text(l10n.redeemButton),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _logout,
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.dangerBorder)),
                icon: const Icon(Icons.logout),
                label: Text(l10n.logoutButton),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool isLast;
  const _SettingsRow({required this.icon, required this.label, this.value, required this.onTap, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTypography.body(size: 14, color: AppColors.ink))),
            if (value != null) ...[
              Text(value!, style: AppTypography.body(size: 13, color: AppColors.mutedLight)),
              const SizedBox(width: 6),
            ],
            Icon(
              Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right,
              size: 18,
              color: AppColors.mutedLight,
            ),
          ],
        ),
      ),
    );
  }
}
