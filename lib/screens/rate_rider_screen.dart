import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_radii.dart';
import 'create_request_screen.dart';

/// Shown to the customer once a delivery reaches "delivered" and hasn't
/// been rated yet — mirrors the rider app's `RateCustomerScreen`, but for
/// the customer rating the rider, and without a commission breakdown (that
/// split only applies on the rider's side of the transaction).
class RateRiderScreen extends StatefulWidget {
  final String requestId;
  final double? collectedAmount;
  final String? riderName;
  final String? riderPhotoUrl;

  const RateRiderScreen({
    super.key,
    required this.requestId,
    this.collectedAmount,
    this.riderName,
    this.riderPhotoUrl,
  });

  @override
  State<RateRiderScreen> createState() => _RateRiderScreenState();
}

class _RateRiderScreenState extends State<RateRiderScreen> {
  int _selectedStars = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorText;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedStars == 0) {
      setState(() => _errorText = l10n.tapStarToRateError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    try {
      final callable = FirebaseFunctions.instance.httpsCallable('submitRating');
      await callable.call({
        'requestId': widget.requestId,
        'stars': _selectedStars,
        'comment': _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      });
      if (!mounted) return;
      _finish();
    } on FirebaseFunctionsException catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorText = e.message ?? l10n.submitRatingError;
      });
    }
  }

  void _finish() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final collected = widget.collectedAmount;
    final riderName = widget.riderName ?? l10n.yourRiderFallbackName;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.deliveredExclamation),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: const BoxDecoration(color: AppColors.successTint, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: AppColors.success, size: 32),
            ),
            const SizedBox(height: 16),
            Text(l10n.deliveredExclamation, style: AppTypography.title(size: 22)),
            if (collected != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.deliveredAmountCollected(collected.toStringAsFixed(0)),
                style: AppTypography.body(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: AppRadii.cardRadius,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.primaryTint,
                    backgroundImage: widget.riderPhotoUrl != null ? NetworkImage(widget.riderPhotoUrl!) : null,
                    child: widget.riderPhotoUrl == null
                        ? const Icon(Icons.delivery_dining, color: AppColors.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      riderName,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(size: 14.5).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(l10n.howWasYourDeliveryTitle, style: AppTypography.heading()),
            const SizedBox(height: 16),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starNumber = index + 1;
                  final filled = starNumber <= _selectedStars;
                  return IconButton(
                    iconSize: 40,
                    icon: Icon(
                      filled ? Icons.star : Icons.star_border,
                      color: filled ? AppColors.accent : AppColors.starInactive,
                    ),
                    style: filled
                        ? IconButton.styleFrom(backgroundColor: AppColors.accentTintAlt, shape: const CircleBorder())
                        : null,
                    onPressed: _isSubmitting ? null : () => setState(() => _selectedStars = starNumber),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 2,
              decoration: InputDecoration(hintText: l10n.optionalCommentHint),
            ),
            if (_errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_errorText!, style: const TextStyle(color: AppColors.danger)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.submitRatingButton),
              ),
            ),
            TextButton(onPressed: _isSubmitting ? null : _finish, child: Text(l10n.skipButton)),
          ],
        ),
      ),
    );
  }
}
