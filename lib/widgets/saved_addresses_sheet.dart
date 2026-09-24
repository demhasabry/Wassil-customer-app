import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

class SavedAddress {
  final String id;
  final String label;
  final String address;
  final GeoPoint location;

  SavedAddress({required this.id, required this.label, required this.address, required this.location});

  factory SavedAddress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SavedAddress(
      id: doc.id,
      label: data['label'] as String,
      address: data['address'] as String,
      location: data['location'] as GeoPoint,
    );
  }
}

CollectionReference<Map<String, dynamic>> savedAddressesRef() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance.collection('users').doc(uid).collection('savedAddresses');
}

Future<void> saveAddress({required String label, required String address, required GeoPoint location}) async {
  await savedAddressesRef().add({
    'label': label,
    'address': address,
    'location': location,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

const int _maxRecentLocations = 5;

/// Called after a request is successfully submitted (both pickup and
/// drop-off) so the next request can quickly reuse the same spot. Stored as
/// a plain capped array on the user doc — this is a best-effort convenience
/// list, not data worth a subcollection/transaction over; de-duplicated by
/// address text and kept most-recent-first.
Future<void> recordRecentLocation({required String address, required GeoPoint location}) async {
  final trimmedAddress = address.trim();
  if (trimmedAddress.isEmpty) return;

  final uid = FirebaseAuth.instance.currentUser!.uid;
  final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
  final doc = await userRef.get();
  final existing = (doc.data()?['recentLocations'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  final updated = [
    {'address': trimmedAddress, 'location': location},
    ...existing.where((e) => e['address'] != trimmedAddress),
  ].take(_maxRecentLocations).toList();

  await userRef.update({'recentLocations': updated});
}

Future<List<SavedAddress>> fetchRecentLocations() async {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
  final raw = (doc.data()?['recentLocations'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  return [
    for (var i = 0; i < raw.length; i++)
      SavedAddress(
        id: 'recent-$i',
        label: raw[i]['address'] as String,
        address: raw[i]['address'] as String,
        location: raw[i]['location'] as GeoPoint,
      ),
  ];
}

/// Shows a bottom sheet listing saved addresses. If the user picks one, it's
/// returned. If they choose to save the current pin as a new saved address
/// instead, that happens inline and the sheet closes with null (nothing to
/// "apply" — they were saving, not selecting).
Future<SavedAddress?> showSavedAddressesSheet(
  BuildContext context, {
  required String title,
  GeoPoint? currentPosition,
  String? currentAddressText,
}) {
  return showModalBottomSheet<SavedAddress>(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final l10n = AppLocalizations.of(context)!;
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.bottomSheetRadius,
            ),
            child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.borderDashed,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(title, style: AppTypography.title(size: 21)),
                const SizedBox(height: 12),
                if (currentPosition != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: Text(l10n.saveCurrentPinButton),
                    onPressed: () async {
                      final label = await _promptForLabel(context);
                      if (label == null || label.trim().isEmpty) return;
                      await saveAddress(
                        label: label.trim(),
                        address: currentAddressText?.trim().isNotEmpty == true
                            ? currentAddressText!.trim()
                            : label.trim(),
                        location: currentPosition,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppLocalizations.of(context)!.addressSavedMessage)),
                        );
                      }
                    },
                  ),
                const SizedBox(height: 12),
                const Divider(color: AppColors.divider),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      FutureBuilder<List<SavedAddress>>(
                        future: fetchRecentLocations(),
                        builder: (context, recentSnap) {
                          final recents = recentSnap.data ?? [];
                          if (recents.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4, top: 8),
                                child: Text(l10n.recentLocationsHeading, style: AppTypography.heading(size: 15)),
                              ),
                              ...recents.map((recent) => ListTile(
                                    leading: const Icon(Icons.history, color: AppColors.mutedLight),
                                    title: Text(recent.address, style: AppTypography.body(size: 13.5)),
                                    onTap: () => Navigator.pop(context, recent),
                                  )),
                              const Divider(color: AppColors.divider),
                            ],
                          );
                        },
                      ),
                      StreamBuilder<QuerySnapshot>(
                        stream: savedAddressesRef().orderBy('createdAt', descending: true).snapshots(),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final docs = snapshot.data!.docs;
                          if (docs.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                l10n.noSavedAddressesYet,
                                style: AppTypography.body(color: AppColors.mutedLight),
                              ),
                            );
                          }
                          return Column(
                            children: docs.map((doc) {
                              final saved = SavedAddress.fromFirestore(doc);
                              return ListTile(
                                leading: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryTint,
                                    borderRadius: AppRadii.smallTileRadius,
                                  ),
                                  child: const Icon(Icons.bookmark_outline, size: 18, color: AppColors.primary),
                                ),
                                title: Text(
                                  saved.label,
                                  style: AppTypography.body(size: 13.5).copyWith(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  saved.address,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(color: AppColors.mutedLight),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.mutedLight),
                                  onPressed: () => savedAddressesRef().doc(saved.id).delete(),
                                ),
                                onTap: () => Navigator.pop(context, saved),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> _promptForLabel(BuildContext context) {
  final controller = TextEditingController();
  final l10n = AppLocalizations.of(context)!;
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.nameAddressTitle),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.addressLabelHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelButton)),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(l10n.saveButton),
        ),
      ],
    ),
  );
}
