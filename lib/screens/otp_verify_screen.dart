import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:firebase_auth/firebase_auth.dart';
import '../services/phone_auth_completion.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';

class OtpVerifyScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  // Only used when isNewAccount is true — a brand-new signup creates the
  // Firestore user doc here and needs a name for it.
  final String? name;
  // false for an existing account re-verifying via OTP (legacy account
  // forced to set a password for the first time, or forgot-password) — in
  // that case the user doc already exists and must not be recreated.
  final bool isNewAccount;

  const OtpVerifyScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    this.name,
    required this.isNewAccount,
  });

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isVerifying = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length < 6) {
      setState(() => _errorText = AppLocalizations.of(context)!.enterSixDigitCode);
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorText = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: code,
      );
      await completePhoneAuthSignIn(
        context: context,
        credential: credential,
        isNewAccount: widget.isNewAccount,
        phoneNumber: widget.phoneNumber,
        name: widget.name,
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isVerifying = false;
        _errorText = e.message ?? AppLocalizations.of(context)!.invalidCodeError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 22, 26, 26),
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
              const SizedBox(height: 30),
              Text(l10n.otpTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 26, color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(l10n.otpCodeSentTo(widget.phoneNumber), style: const TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 30),
              _OtpBoxRow(controller: _codeController, focusNode: _focusNode, color: AppColors.primary),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_errorText!, style: const TextStyle(color: AppColors.danger)),
                ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _isVerifying ? null : _verifyCode,
                child: _isVerifying
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.verifyButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The design handoff's six-box OTP entry — a hidden field captures real
/// keystrokes (so the OS keyboard/autofill still works) while these boxes
/// render its value; tapping anywhere on the row focuses the hidden field.
/// Always LTR even inside an RTL layout, per the handoff (digits read
/// left-to-right regardless of locale).
class _OtpBoxRow extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Color color;
  static const int length = 6;

  const _OtpBoxRow({required this.controller, required this.focusNode, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        children: [
          SizedBox(
            width: 0,
            height: 0,
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: length,
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                onChanged: (_) {},
              ),
            ),
          ),
          Directionality(
            textDirection: TextDirection.ltr,
            child: AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final value = controller.text;
                return Row(
                  children: [
                    for (var i = 0; i < length; i++) ...[
                      if (i > 0) const SizedBox(width: 9),
                      Expanded(child: _OtpBox(digit: i < value.length ? value[i] : null, active: i == value.length, color: color)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String? digit;
  final bool active;
  final Color color;
  const _OtpBox({required this.digit, required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    final filled = digit != null;
    return Container(
      height: 60,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? const Color(0xFFF3F6FE) : (active ? Colors.white : AppColors.surfaceAlt),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: (filled || active) ? color : AppColors.border, width: (filled || active) ? 1.5 : 1),
      ),
      child: filled
          ? Text(digit!, style: TextStyle(fontFamily: 'IBM Plex Mono', fontWeight: FontWeight.w600, fontSize: 22, color: AppColors.ink))
          : (active ? Container(width: 2, height: 24, color: color) : null),
    );
  }
}
