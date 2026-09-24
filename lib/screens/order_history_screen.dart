import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_shadows.dart';
import '../theme/app_typography.dart';
import 'order_detail_screen.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  Color _statusColor(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.successText;
      case 'cancelled':
        return AppColors.danger;
      case 'open':
      case 'assigned':
      case 'picked_up':
        return AppColors.accentInk;
      default:
        return AppColors.muted;
    }
  }

  Color _statusBg(String status) {
    switch (status) {
      case 'delivered':
        return AppColors.successTint;
      case 'cancelled':
        return AppColors.dangerTint;
      case 'open':
      case 'assigned':
      case 'picked_up':
        return AppColors.accentTint;
      default:
        return AppColors.surfaceAlt;
    }
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'open':
        return l10n.statusOpen;
      case 'assigned':
        return l10n.statusAssigned;
      case 'picked_up':
        return l10n.statusPickedUp;
      case 'delivered':
        return l10n.statusDelivered;
      case 'cancelled':
        return l10n.statusCancelled;
      default:
        return l10n.statusUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.orderHistoryTitle)),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('delivery_requests')
            .where('customerId', isEqualTo: uid)
            // Sorted client-side below, not via .orderBy() — a compound
            // where()+orderBy()-on-a-different-field query like this one
            // was observed to hang indefinitely against the Firestore web
            // client; see bid.dart's watchBids() for the full story.
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.toList()
            ..sort((a, b) {
              final aAt = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final bAt = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (aAt == null || bAt == null) return 0;
              return bAt.compareTo(aAt); // descending
            });

          Widget newRequestButton() => SafeArea(
                top: false,
                minimum: const EdgeInsets.all(16),
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  child: Text(l10n.newDeliveryRequestTitle),
                ),
              );

          if (docs.isEmpty) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: Text(l10n.noPastOrdersYet, style: AppTypography.body(color: AppColors.mutedLight)),
                  ),
                ),
                newRequestButton(),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final status = data['status'] as String? ?? 'unknown';
              final packageInfo = data['packageInfo'] as Map<String, dynamic>? ?? {};
              final description = packageInfo['description'] as String? ?? l10n.noDescriptionPlaceholder;
              final createdAt = data['createdAt'] as Timestamp?;
              final dateLabel = createdAt != null
                  ? DateFormat('MMM d, y • h:mm a').format(createdAt.toDate())
                  : '';
              final stars = data['customerRatingStars'] as int?;
              final price = ((data['finalPrice'] ?? data['suggestedPrice']) as num?)?.toDouble();

              return InkWell(
                borderRadius: AppRadii.cardRadius,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(data: data)),
                ),
                child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadii.cardRadius,
                  border: Border.all(color: AppColors.borderAlt),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            description,
                            style: AppTypography.body(size: 14, color: AppColors.ink).copyWith(fontWeight: FontWeight.w500),
                          ),
                        ),
                        if (price != null) ...[
                          const SizedBox(width: 10),
                          Text(price.toStringAsFixed(0), style: AppTypography.amount(size: 15, color: AppColors.ink)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: Text(dateLabel, style: AppTypography.caption(color: AppColors.mutedLight))),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusBg(status),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            _statusLabel(l10n, status),
                            style: AppTypography.label(size: 11.5, color: _statusColor(status)),
                          ),
                        ),
                      ],
                    ),
                    if (stars != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          5,
                          (i) => Icon(
                            i < stars ? Icons.star : Icons.star_border,
                            size: 14,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                ),
              );
            },
          )),
              newRequestButton(),
            ],
          );
        },
      ),
    );
  }
}
