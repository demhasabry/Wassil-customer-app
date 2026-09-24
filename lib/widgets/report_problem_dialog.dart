import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';
import 'cancel_dialog.dart' show ReasonRow;

/// Shows a dialog for reporting a problem with an in-progress or completed
/// delivery, and writes it straight to Firestore's `disputes` collection —
/// no Cloud Function needed here since this is just creating a record for
/// admin review, not mutating money or delivery status.
Future<void> showReportProblemDialog(
  BuildContext context, {
  required String requestId,
  required String reporterRole, // 'customer' | 'rider'
  required List<String> reasons,
}) async {
  String? selectedReason;
  final detailsController = TextEditingController();

  final reason = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return StatefulBuilder(
        builder: (context, setState) {
          return Container(
            padding: EdgeInsets.fromLTRB(22, 14, 22, MediaQuery.of(context).viewInsets.bottom + 24),
            decoration: const BoxDecoration(color: AppColors.surface, borderRadius: AppRadii.bottomSheetLargeRadius),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  Text(l10n.reportProblemTitle, style: AppTypography.title(size: 20)),
                  const SizedBox(height: 16),
                  Text(l10n.reasonLabel, style: AppTypography.label(color: AppColors.mutedLight)),
                  const SizedBox(height: 8),
                  ...reasons.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ReasonRow(
                        label: r,
                        selected: selectedReason == r,
                        onTap: () => setState(() => selectedReason = r),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: TextField(
                      controller: detailsController,
                      decoration: InputDecoration(hintText: l10n.additionalDetailsHint),
                      minLines: 3,
                      maxLines: 3,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: selectedReason == null ? null : () => Navigator.pop(context, selectedReason),
                    child: Text(l10n.submitReportButton),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancelButton)),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (reason == null) return;

  final uid = FirebaseAuth.instance.currentUser!.uid;
  await FirebaseFirestore.instance.collection('disputes').add({
    'requestId': requestId,
    'reportedBy': uid,
    'reporterRole': reporterRole,
    'reason': reason,
    'details': detailsController.text.trim().isEmpty ? null : detailsController.text.trim(),
    'status': 'open',
    'createdAt': FieldValue.serverTimestamp(),
  });

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.reportSubmittedMessage)),
    );
  }
}
