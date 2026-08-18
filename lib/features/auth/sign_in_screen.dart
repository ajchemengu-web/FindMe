import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import 'auth_controller.dart';
import 'google_button/google_sign_in_button.dart';

/// Ported from findme_app/app/(auth)/sign-in.tsx, redesigned as a centered auth card
/// (brand mark front and center, like a proper landing/auth page) rather than the
/// original's top-anchored form -- the RN layout made sense on a phone-width screen;
/// this version also has to hold up centered on a wide web viewport.
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  String? _error;
  bool _submitting = false;

  Future<void> _onSubmit() async {
    setState(() {
      _error = null;
      _submitting = true;
    });
    final error = await ref.read(authControllerProvider.notifier).signIn(_identifier.text.trim(), _password.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final googleBusy = ref.watch(authControllerProvider).isLoading;
    final googleError = ref.watch(googleSignInErrorProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 36),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.ink, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to continue',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.ink3, fontSize: 12.5),
                        ),
                        const SizedBox(height: 22),
                        AbsorbPointer(
                          absorbing: googleBusy,
                          child: Opacity(opacity: googleBusy ? 0.6 : 1, child: const GoogleSignInButton()),
                        ),
                        if (googleError != null) ...[
                          const SizedBox(height: 8),
                          Text(googleError, style: const TextStyle(color: AppColors.critical, fontSize: 12)),
                        ],
                        const SizedBox(height: 20),
                        const _OrDivider(),
                        const SizedBox(height: 20),
                        _FieldLabel('Email, username, or phone'),
                        TextField(
                          controller: _identifier,
                          decoration: const InputDecoration(hintText: 'you@example.com · ali_j · +1 555 010 1234'),
                          autocorrect: false,
                        ),
                        const SizedBox(height: 14),
                        _FieldLabel('Password'),
                        TextField(
                          controller: _password,
                          decoration: const InputDecoration(hintText: 'Password'),
                          obscureText: true,
                          onSubmitted: (_) => _onSubmit(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 12)),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _submitting ? null : _onSubmit,
                          child: _submitting
                              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Sign In'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/sign-up'),
                      child: const Text.rich(
                        TextSpan(
                          text: 'New here? ',
                          style: TextStyle(color: AppColors.ink3, fontSize: 12),
                          children: [TextSpan(text: 'Create an account', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold))],
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
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: [BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: -4)],
          ),
          alignment: Alignment.center,
          child: const Text('FM', style: TextStyle(color: Color(0xFF04101F), fontWeight: FontWeight.bold, fontSize: 22)),
        ),
        const SizedBox(height: 16),
        const Text('FINDME', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 4)),
        const SizedBox(height: 6),
        const Text(
          'SECURE ACCESS · CONSENT-FIRST TRACKING NETWORK',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.ink3, fontSize: 10.5, letterSpacing: 1),
        ),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.line)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('OR CONTINUE WITH EMAIL', style: TextStyle(color: AppColors.ink3, fontSize: 9.5, letterSpacing: 0.8)),
        ),
        Expanded(child: Divider(color: AppColors.line)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text.toUpperCase(), style: const TextStyle(color: AppColors.ink3, fontSize: 10.5, letterSpacing: 1)),
    );
  }
}
