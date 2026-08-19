import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/password_strength.dart';
import '../../theme/app_colors_data.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand_header.dart';
import 'auth_controller.dart';
import 'google_button/google_sign_in_button.dart';

List<Color> _strengthColors(AppColorsData c) => [c.critical, c.critical, c.warning, c.good, c.accent];

/// Ported 1:1 from findme_app/app/(auth)/sign-up.tsx, including the live password
/// strength meter (core/password_strength.dart mirrors lib/passwordStrength.ts exactly).
/// Theme-reactive, same as sign_in_screen.dart.
class SignUpScreen extends ConsumerStatefulWidget {
  /// Prefilled from a shared invite link's `?ref=` query param (see app_router.dart)
  /// so following someone's invite is actually one-tap -- previously the backend
  /// accepted a referral code at signup but nothing in the UI ever exposed a way to
  /// enter one, so referral tracking was dead on the client side.
  final String? initialReferralCode;
  const SignUpScreen({super.key, this.initialReferralCode});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  late final TextEditingController _referralCode;
  bool _ack = false;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
    _referralCode = TextEditingController(text: widget.initialReferralCode ?? '');
  }

  bool get _canSubmit =>
      _username.text.trim().isNotEmpty &&
      _email.text.trim().isNotEmpty &&
      _phone.text.trim().isNotEmpty &&
      checkPasswordStrength(_password.text).meetsMinimum &&
      _ack &&
      !_submitting;

  Future<void> _onSubmit() async {
    if (!_canSubmit) {
      setState(() {
        _error = checkPasswordStrength(_password.text).meetsMinimum
            ? 'Fill in every field and acknowledge the consent policy.'
            : 'Choose a stronger password -- see the requirements below the password field.';
      });
      return;
    }
    setState(() {
      _error = null;
      _submitting = true;
    });
    final error = await ref.read(authControllerProvider.notifier).signUp(
          email: _email.text.trim(),
          username: _username.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
          referralCode: _referralCode.text.trim().isEmpty ? null : _referralCode.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final strength = checkPasswordStrength(_password.text);
    final googleBusy = ref.watch(authControllerProvider).isLoading;
    final googleError = ref.watch(googleSignInErrorProvider);
    final colors = context.colors;
    final strengthColors = _strengthColors(colors);

    return Scaffold(
      backgroundColor: colors.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandHeader()),
                  const SizedBox(height: 24),
                  AbsorbPointer(
                    absorbing: googleBusy,
                    child: Opacity(opacity: googleBusy ? 0.6 : 1, child: const GoogleSignInButton()),
                  ),
                  if (googleError != null) ...[
                    const SizedBox(height: 8),
                    Text(googleError, style: TextStyle(color: colors.critical, fontSize: 12)),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: colors.line)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR SIGN UP WITH EMAIL', style: TextStyle(color: colors.ink3, fontSize: 9.5, letterSpacing: 0.8)),
                      ),
                      Expanded(child: Divider(color: colors.line)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _field(colors, 'Username', _username, hint: 'e.g. ali_j'),
                  _field(colors, 'Email', _email, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
                  _field(colors, 'Phone number', _phone, hint: '+1 555 010 1234', keyboardType: TextInputType.phone),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Verified by SMS code after sign-up -- this is also how others will find and invite you.',
                      style: TextStyle(color: colors.ink3, fontSize: 11, height: 1.3),
                    ),
                  ),
                  _field(colors, 'Password', _password, hint: 'At least 10 characters, mixed case, a number & symbol', obscure: true),
                  if (_password.text.isNotEmpty) ...[
                    Row(
                      children: List.generate(4, (i) {
                        final active = i < strength.score;
                        return Expanded(
                          child: Container(
                            height: 4,
                            margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                            decoration: BoxDecoration(
                              color: active ? strengthColors[strength.score] : colors.line,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(strength.label, style: TextStyle(color: strengthColors[strength.score], fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(
                      strength.issues.isEmpty ? 'Meets every requirement.' : strength.issues.join('  ·  '),
                      style: TextStyle(color: strength.issues.isEmpty ? colors.good : colors.ink3, fontSize: 10.5, height: 1.3),
                    ),
                    const SizedBox(height: 14),
                  ] else
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        'At least 10 characters, mixed case, a number, and a symbol -- not a common password.',
                        style: TextStyle(color: colors.ink3, fontSize: 11, height: 1.3),
                      ),
                    ),
                  _field(colors, 'Referral code (optional)', _referralCode, hint: 'e.g. ALI4X9K'),
                  InkWell(
                    onTap: () => setState(() => _ack = !_ack),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.line),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        color: colors.ink.withValues(alpha: 0.03),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            margin: const EdgeInsets.only(top: 2, right: 10),
                            decoration: BoxDecoration(
                              color: _ack ? colors.accent : Colors.transparent,
                              border: Border.all(color: _ack ? colors.accent : colors.line),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                style: TextStyle(color: colors.ink2, fontSize: 12, height: 1.4),
                                children: [
                                  const TextSpan(text: 'I understand FindMe can only track '),
                                  TextSpan(text: 'my own devices', style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold)),
                                  const TextSpan(
                                    text:
                                        ' automatically. Tracking any other person requires them to explicitly accept a consent request, which they can revoke at any time.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    Text(_error!, style: TextStyle(color: colors.critical, fontSize: 12)),
                    const SizedBox(height: 10),
                  ],
                  ElevatedButton(
                    onPressed: _canSubmit ? _onSubmit : null,
                    child: _submitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create Account'),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/sign-in'),
                      child: Text.rich(
                        TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: colors.ink3, fontSize: 12),
                          children: [TextSpan(text: 'Sign in', style: TextStyle(color: colors.accent, fontWeight: FontWeight.bold))],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(AppColorsData colors, String label, TextEditingController controller, {required String hint, TextInputType? keyboardType, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label.toUpperCase(), style: TextStyle(color: colors.ink3, fontSize: 10.5, letterSpacing: 1)),
          ),
          TextField(
            controller: controller,
            decoration: InputDecoration(hintText: hint),
            keyboardType: keyboardType,
            obscureText: obscure,
            autocorrect: false,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }
}
