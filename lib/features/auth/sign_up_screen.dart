import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/password_strength.dart';
import '../../theme/tokens.dart';
import '../../widgets/brand_header.dart';
import 'auth_controller.dart';

const _strengthColors = [AppColors.critical, AppColors.critical, AppColors.warning, AppColors.good, AppColors.accent];

/// Ported 1:1 from findme_app/app/(auth)/sign-up.tsx, including the live password
/// strength meter (core/password_strength.dart mirrors lib/passwordStrength.ts exactly).
class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _ack = false;
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _password.addListener(() => setState(() {}));
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

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandHeader(),
              const SizedBox(height: 24),
              _field('Username', _username, hint: 'e.g. ali_j'),
              _field('Email', _email, hint: 'you@example.com', keyboardType: TextInputType.emailAddress),
              _field('Phone number', _phone, hint: '+1 555 010 1234', keyboardType: TextInputType.phone),
              const Padding(
                padding: EdgeInsets.only(bottom: 14),
                child: Text(
                  'Verified by SMS code after sign-up -- this is also how others will find and invite you.',
                  style: TextStyle(color: AppColors.ink3, fontSize: 11, height: 1.3),
                ),
              ),
              _field('Password', _password, hint: 'At least 10 characters, mixed case, a number & symbol', obscure: true),
              if (_password.text.isNotEmpty) ...[
                Row(
                  children: List.generate(4, (i) {
                    final active = i < strength.score;
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                        decoration: BoxDecoration(
                          color: active ? _strengthColors[strength.score] : AppColors.line,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 6),
                Text(strength.label, style: TextStyle(color: _strengthColors[strength.score], fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                  strength.issues.isEmpty ? 'Meets every requirement.' : strength.issues.join('  ·  '),
                  style: TextStyle(color: strength.issues.isEmpty ? AppColors.good : AppColors.ink3, fontSize: 10.5, height: 1.3),
                ),
                const SizedBox(height: 14),
              ] else
                const Padding(
                  padding: EdgeInsets.only(bottom: 14),
                  child: Text(
                    'At least 10 characters, mixed case, a number, and a symbol -- not a common password.',
                    style: TextStyle(color: AppColors.ink3, fontSize: 11, height: 1.3),
                  ),
                ),
              InkWell(
                onTap: () => setState(() => _ack = !_ack),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    color: Colors.white.withValues(alpha: 0.03),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        margin: const EdgeInsets.only(top: 2, right: 10),
                        decoration: BoxDecoration(
                          color: _ack ? AppColors.accent : Colors.transparent,
                          border: Border.all(color: _ack ? AppColors.accent : AppColors.line),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(color: AppColors.ink2, fontSize: 12, height: 1.4),
                            children: [
                              TextSpan(text: 'I understand FindMe can only track '),
                              TextSpan(text: 'my own devices', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold)),
                              TextSpan(
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
                Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 12)),
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
                  child: const Text.rich(
                    TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(color: AppColors.ink3, fontSize: 12),
                      children: [TextSpan(text: 'Sign in', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold))],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {required String hint, TextInputType? keyboardType, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label.toUpperCase(), style: const TextStyle(color: AppColors.ink3, fontSize: 10.5, letterSpacing: 1)),
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
