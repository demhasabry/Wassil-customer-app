import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_typography.dart';

/// Shows a bottom sheet asking the user to pick (or type) a reason for
/// cancelling. Returns the chosen reason as a string, or null if they backed
/// out — matches the design handoff's cancel/report sheet (grabber, full-
/// width stacked actions) rather than a centered AlertDialog.
Future<String?> showCancelReasonDialog(
  BuildContext context, {
  required String title,
  required List<String> reasons,
}) async {
  String? selectedReason;
  final otherController = TextEditingController();

  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      return StatefulBuilder(
        builder: (context, setState) {
          final isOther = selectedReason == l10n.reasonOther;
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
                  Text(title, style: AppTypography.title(size: 20)),
                  const SizedBox(height: 16),
                  Text(l10n.reasonLabel, style: AppTypography.label(color: AppColors.mutedLight)),
                  const SizedBox(height: 8),
                  ...reasons.map(
                    (reason) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ReasonRow(
                        label: reason,
                        selected: selectedReason == reason,
                        onTap: () => setState(() => selectedReason = reason),
                      ),
                    ),
                  ),
                  if (isOther)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: TextField(
                        controller: otherController,
                        decoration: InputDecoration(hintText: l10n.tellUsMoreHint),
                        minLines: 3,
                        maxLines: 3,
                      ),
                    ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                    onPressed: selectedReason == null
                        ? null
                        : () {
                            final finalReason = isOther && otherController.text.trim().isNotEmpty
                                ? '${l10n.reasonOther}: ${otherController.text.trim()}'
                                : selectedReason!;
                            Navigator.pop(context, finalReason);
                          },
                    child: Text(l10n.confirmCancellationButton),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(l10n.keepItButton),
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

/// The design handoff's reason-row: a selectable row with a circular radio
/// glyph (filled + checkmark when selected, dashed outline otherwise),
/// shared with report_problem_dialog.dart rather than duplicated.
class ReasonRow extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const ReasonRow({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderDashed,
            width: selected ? 1.5 : 1,
          ),
          color: selected ? AppColors.primaryFocusBg : null,
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: selected ? null : Border.all(color: AppColors.borderDashed, width: 1.5),
              ),
              child: selected ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: AppTypography.body(size: 13.5))),
          ],
        ),
      ),
    );
  }
}
