import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/saved_addresses_sheet.dart';

/// Customer wallet screen — balance (read-only; there's no customer-side
/// top-up flow in this app, payment happens in cash/bank at delivery, so no
/// "top up" action is shown here), plus saved addresses and recent
/// locations pulled together in one place per the design handoff, instead
/// of only being reachable from inside the create-request address picker.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Future<List<SavedAddress>>? _recentLocationsFuture;

  @override
  void initState() {
    super.initState();
    _recentLocationsFuture = fetchRecentLocations();
  }

  Future<void> _addAddress() async {
    final l10n = AppLocalizations.of(context)!;
    final labelController = TextEditingController();
    final addressController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.nameAddressTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: labelController, decoration: InputDecoration(hintText: l10n.addressLabelHint)),
            const SizedBox(height: 8),
            TextField(controller: addressController, decoration: InputDecoration(hintText: l10n.savedAddressesHeading)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancelButton)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.saveButton)),
        ],
      ),
    );
    if (result != true || !mounted) return;
    if (labelController.text.trim().isEmpty || addressController.text.trim().isEmpty) return;
    // No map pin available from this screen (unlike the picker sheet, which
    // captures one from the live map) — center is a harmless placeholder
    // until the address is actually used to create a request, at which
    // point the picker's own flow captures the real location.
    await saveAddress(
      label: labelController.text.trim(),
      address: addressController.text.trim(),
      location: const GeoPoint(0, 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletTitle)),
      body: ListView(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snapshot) {
              final balance = snapshot.hasData && snapshot.data!.exists
                  ? ((snapshot.data!.data() as Map<String, dynamic>)['walletBalance'] as num?)?.toDouble() ?? 0
                  : 0.0;
              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.walletBalanceLabel, style: const TextStyle(color: Color(0xFFB9C9F4), fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(balance.toStringAsFixed(0), style: AppTypography.amount(size: 34, color: Colors.white)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.savedAddressesHeading, style: AppTypography.heading()),
                TextButton(onPressed: _addAddress, child: Text(l10n.addNewAddressAction)),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: savedAddressesRef().orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(l10n.noSavedAddressesYet, style: AppTypography.body(color: AppColors.mutedLight)),
                );
              }
              return Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderAlt),
                ),
                child: Column(
                  children: [
                    for (final doc in docs)
                      _AddressRow(
                        address: SavedAddress.fromFirestore(doc),
                        isLast: doc == docs.last,
                        onDelete: () => savedAddressesRef().doc(doc.id).delete(),
                      ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(l10n.recentLocationsHeading, style: AppTypography.heading()),
          ),
          FutureBuilder<List<SavedAddress>>(
            future: _recentLocationsFuture,
            builder: (context, snapshot) {
              final recents = snapshot.data ?? [];
              if (recents.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  for (final recent in recents)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primaryBorder),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                recent.address,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(size: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final SavedAddress address;
  final bool isLast;
  final VoidCallback onDelete;
  const _AddressRow({required this.address, required this.isLast, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.primaryTint, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.bookmark_outline, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(address.label, style: AppTypography.body(size: 13.5).copyWith(fontWeight: FontWeight.w600)),
                Text(
                  address.address,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(color: AppColors.mutedLight),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.mutedLight),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
