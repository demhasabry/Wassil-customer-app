import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

/// Shown when tapping a past order in order_history_screen.dart — that list
/// only has room for a one-line summary, so this fills in the rest (full
/// addresses, contact numbers, price) from the same document data it
/// already fetched, no extra query needed.
class OrderDetailScreen extends StatelessWidget {
  final Map<String, dynamic> data;

  const OrderDetailScreen({super.key, required this.data});

  Widget _row(BuildContext context, String label, String value, {bool mono = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTypography.label(color: AppColors.mutedLight)),
          ),
          Expanded(
            child: Directionality(
              textDirection: mono ? TextDirection.ltr : Directionality.of(context),
              child: Text(value, style: AppTypography.body(size: 14, color: AppColors.ink)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final pickup = data['pickup'] as Map<String, dynamic>? ?? {};
    final dropoff = data['dropoff'] as Map<String, dynamic>? ?? {};
    final packageInfo = data['packageInfo'] as Map<String, dynamic>? ?? {};
    final price = ((data['finalPrice'] ?? data['agreedPrice'] ?? data['suggestedPrice']) as num?)?.toDouble();
    final pickupPhone = data['pickupContactPhone'] as String?;
    final receiverPhone = data['receiverContactPhone'] as String?;
    final createdAt = data['createdAt'] as Timestamp?;
    final dateLabel = createdAt != null ? DateFormat('MMM d, y • h:mm a').format(createdAt.toDate()) : '';

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderDetailTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: AppColors.borderAlt),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  packageInfo['description'] as String? ?? l10n.noDescriptionPlaceholder,
                  style: AppTypography.heading(size: 16),
                ),
                if (dateLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(dateLabel, style: AppTypography.caption(color: AppColors.mutedLight)),
                ],
                const Divider(height: 28),
                _row(context, l10n.pickupAddressTitle, pickup['address'] as String? ?? '—'),
                _row(context, l10n.dropoffAddressTitle, dropoff['address'] as String? ?? '—'),
                if (pickupPhone != null) _row(context, l10n.pickupPhoneLabel, pickupPhone, mono: true),
                if (receiverPhone != null) _row(context, l10n.receiverPhoneLabel, receiverPhone, mono: true),
                if (price != null) _row(context, l10n.priceLabel, '${price.toStringAsFixed(0)} SDG', mono: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
