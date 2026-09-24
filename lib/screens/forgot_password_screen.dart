import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/phone_auth_completion.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radii.dart';
import 'otp_verify_screen.dart';

/// Re-verifies phone ownership via OTP, then hands off to OtpVerifyScreen
/// with isNewAccount: false — identical to how a legacy passwordless account
/// is forced to set a password, since both cases are "existing account,
/// proven via OTP, now (re)set the password."
class ForgotPasswordScreen extends StatefulWidget {
  final String phone;
  const ForgotPasswordScreen({super.key, required this.phone});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const String _dialCode = '+249';

  bool _isSubmitting = false;
  String? _errorText;

  String get _localNumber =>
      widget.phone.startsWith(_dialCode) ? widget.phone.substring(_dialCode.length) : widget.phone;

  Future<void> _sendCode() async {
    setState(() {
      _isSubmitting = true;
      _errorText = null;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: widget.phone,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Android auto-retrieval case — skips the OTP screen entirely, so
        // this has to do everything OtpVerifyScreen._verifyCode() does.
        try {
          await completePhoneAuthSignIn(
            context: context,
            credential: credential,
            isNewAccount: false,
            phoneNumber: widget.phone,
          );
        } on FirebaseAuthException catch (e) {
          if (!mounted) return;
          setState(() {
            _isSubmitting = false;
            _errorText = e.message ?? AppLocalizations.of(context)!.verificationFailedError;
          });
        }
      },
      verificationFailed: (FirebaseAuthException e) {
        if (!mounted) return;
        setState(() {
          _isSubmitting = false;
          _errorText = e.message ?? AppLocalizations.of(context)!.verificationFailedError;
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerifyScreen(
              verificationId: verificationId,
              phoneNumber: widget.phone,
              isNewAccount: false,
            ),
          ),
        );
      },
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s26, AppSpacing.s22, AppSpacing.s26, AppSpacing.s26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderAlt),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back, size: 18, color: AppColors.ink),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.s30),
              Text(l10n.forgotPasswordTitle, style: AppTypography.title(size: 26, color: AppColors.ink)),
              const SizedBox(height: AppSpacing.s10),
              Text(
                l10n.forgotPasswordInstruction(widget.phone),
                style: AppTypography.body(size: 14, color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.s22),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: AppRadii.fieldRadius,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Text(
                        _dialCode,
                        style: TextStyle(fontFamily: AppTypography.monoFamily, fontSize: 15, color: AppColors.ink),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.s10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s16),
                        alignment: AlignmentDirectional.centerStart,
                        decoration: BoxDecoration(
                          color: AppColors.primaryFocusBg,
                          borderRadius: AppRadii.fieldRadius,
                          border: Border.all(color: AppColors.primary, width: 1.5),
                        ),
                        child: Text(
                          _localNumber,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                              fontFamily: AppTypography.monoFamily, fontSize: 15, color: AppColors.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8),
                  child: Text(_errorText!, style: const TextStyle(color: AppColors.danger)),
                ),
              const SizedBox(height: AppSpacing.s16),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _sendCode,
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.sendCodeButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
