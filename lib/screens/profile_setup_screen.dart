import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/localized_zone_name.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'create_request_screen.dart';

/// Shown once, right after OTP verification, before the customer reaches
/// the main app. Gender and region are required; the photo is optional and
/// can be added later from the profile screen instead.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _picker = ImagePicker();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  String? _gender;
  String? _selectedRegion;
  List<Map<String, dynamic>> _regions = [];
  bool _isLoadingRegions = true;
  File? _photo;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    final snap = await FirebaseFirestore.instance.collection('zones').where('active', isEqualTo: true).get();
    if (!mounted) return;
    setState(() {
      _regions = snap.docs.map((d) => d.data()).toList();
      _isLoadingRegions = false;
    });
  }

  Future<void> _pickPhoto() async {
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
    if (picked == null) return;
    setState(() => _photo = File(picked.path));
  }

  // Region is only required when zones actually exist to choose from — on a
  // fresh install with no zones seeded yet in the admin dashboard, this
  // shouldn't block onboarding; the customer can set it later once zones
  // are configured.
  bool get _canContinue => _gender != null && (_regions.isEmpty || _selectedRegion != null);

  Future<void> _continue() async {
    setState(() => _isSaving = true);
    try {
      String? photoUrl;
      if (_photo != null) {
        final ref = FirebaseStorage.instance.ref('profile_pictures/$_uid/photo.jpg');
        await ref.putFile(_photo!);
        photoUrl = await ref.getDownloadURL();
      }

      final updates = <String, dynamic>{'gender': _gender};
      if (_selectedRegion != null) updates['region'] = _selectedRegion!.toLowerCase();
      if (photoUrl != null) updates['photoUrl'] = photoUrl;
      await FirebaseFirestore.instance.collection('users').doc(_uid).update(updates);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const CreateRequestScreen()));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      // TEMPORARY: showing the raw exception instead of the generic message
      // while diagnosing an iOS-only failure here — revert to just
      // l10n.profileSetupError once that's root-caused.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppLocalizations.of(context)!.profileSetupError}\n$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileSetupTitle), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryTint,
                      border: Border.all(color: AppColors.primaryBorder, width: 1.5),
                      image: _photo != null ? DecorationImage(image: FileImage(_photo!), fit: BoxFit.cover) : null,
                    ),
                    child: _photo == null ? const Icon(Icons.add, color: AppColors.primary, size: 28) : null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(l10n.photoOptionalHint, style: AppTypography.caption(color: AppColors.mutedLight)),
              ),
              const SizedBox(height: 24),
              Text(l10n.genderLabel, style: AppTypography.heading(size: 15)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _SegmentButton(
                      label: l10n.genderMale,
                      selected: _gender == 'male',
                      onTap: () => setState(() => _gender = 'male'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SegmentButton(
                      label: l10n.genderFemale,
                      selected: _gender == 'female',
                      onTap: () => setState(() => _gender = 'female'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_isLoadingRegions)
                const Center(child: CircularProgressIndicator())
              else if (_regions.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(l10n.noRegionsAvailableMessage, style: AppTypography.body(color: AppColors.mutedLight)),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedRegion,
                  decoration: InputDecoration(labelText: l10n.regionLabel),
                  items: _regions.map((data) {
                    final name = data['name'] as String;
                    return DropdownMenuItem(value: name, child: Text(localizedZoneName(context, data)));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedRegion = v),
                ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_canContinue && !_isSaving) ? _continue : null,
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.continueButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(13),
          border: selected ? null : Border.all(color: AppColors.border),
        ),
        child: Text(
          label,
          style: AppTypography.body(size: 14).copyWith(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
