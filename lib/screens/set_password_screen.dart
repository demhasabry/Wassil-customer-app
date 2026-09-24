import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/generated/app_localizations.dart';
import '../theme/app_colors.dart';
import '../utils/synthetic_email.dart';

/// Shared by three call sites: a brand-new signup (right after OTP), a
/// legacy account that predates password login (forced to set one the first
/// time it signs in), and the forgot-password flow (also forced, right after
/// re-verifying via OTP). Which of those it is only matters for what happens
/// next, so the caller supplies [onSuccess] rather than this screen hardcoding
/// a destination.
class SetPasswordScreen extends StatefulWidget {
  final String phone;
  final Future<void> Function(BuildContext context) onSuccess;

  const SetPasswordScreen({super.key, required this.phone, required this.onSuccess});

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;
  bool _obscure = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_onChanged);
    _confirmController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _lengthOk => _passwordController.text.length >= 6;
  bool get _matchOk => _passwordController.text.isNotEmpty && _passwordController.text == _confirmController.text;

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 6) {
      setState(() => _errorText = l10n.passwordTooShortError);
      return;
    }
    if (password != confirm) {
      setState(() => _errorText = l10n.passwordsDontMatchError);
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final email = syntheticAuthEmail(widget.phone);
      final hasPasswordProvider = user.providerData.any((p) => p.providerId == 'password');

      if (hasPasswordProvider) {
        await user.updatePassword(password);
      } else {
        await user.linkWithCredential(EmailAuthProvider.credential(email: email, password: password));
      }

      if (!mounted) return;
      await widget.onSuccess(context);
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isSaving = false;
        _errorText = e.message ?? l10n.setPasswordError;
      });
    }
  }

  Widget _passwordField({
    required TextEditingController controller,
    required bool showToggle,
    bool showMismatchError = false,
  }) {
    final hasMismatchError = showMismatchError && _confirmController.text.isNotEmpty && !_matchOk;
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: hasMismatchError ? const Color(0xFFFDF7F6) : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasMismatchError ? AppColors.danger : AppColors.primary,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: _obscure,
              style: const TextStyle(fontFamily: 'IBM Plex Mono', fontSize: 16, color: AppColors.ink),
              // The app theme sets its own enabledBorder/focusedBorder/
              // errorBorder (each an OutlineInputBorder) — those take
              // precedence over the generic `border:` below in whichever
              // state the field is in, so setting only `border: none` still
              // left a themed rounded-rect outline drawn by the TextField
              // itself inside this Container's own border ("a box inside
              // the box"). Every border variant needs to be none.
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                filled: false,
              ),
            ),
          ),
          if (showToggle)
            GestureDetector(
              onTap: () => setState(() => _obscure = !_obscure),
              child: Text(
                AppLocalizations.of(context)!.showPasswordWord,
                style: const TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _ruleRow(String label, bool met) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 17,
            height: 17,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: met ? AppColors.success : const Color(0xFFC7CEDE),
            ),
            child: Icon(met ? Icons.check : Icons.close, size: 11, color: Colors.white),
          ),
          const SizedBox(width: 9),
          Text(label, style: TextStyle(fontSize: 13, color: met ? AppColors.successText : AppColors.mutedLight)),
        ],
      ),
    );
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
              Text(l10n.setPasswordTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 26, color: AppColors.ink)),
              const SizedBox(height: 10),
              Text(l10n.setPasswordInstruction, style: const TextStyle(color: AppColors.muted, fontSize: 14, height: 1.6)),
              const SizedBox(height: 26),
              Text(l10n.newPasswordHint, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _passwordField(controller: _passwordController, showToggle: true),
              const SizedBox(height: 16),
              Text(l10n.confirmPasswordHint, style: const TextStyle(fontSize: 12.5, color: AppColors.muted, fontWeight: FontWeight.w500)),
              const SizedBox(height: 8),
              _passwordField(controller: _confirmController, showToggle: false, showMismatchError: true),
              if (_confirmController.text.isNotEmpty && !_matchOk) ...[
                const SizedBox(height: 8),
                Text(l10n.passwordsDontMatchError, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              _ruleRow(l10n.pwRuleLength, _lengthOk),
              _ruleRow(l10n.pwRuleMatch, _matchOk),
              if (_errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_errorText!, style: const TextStyle(color: AppColors.danger)),
                ),
              const SizedBox(height: 26),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l10n.savePasswordButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
