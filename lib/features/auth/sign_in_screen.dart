import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../../widgets/brand_header.dart';
import 'auth_controller.dart';

/// Ported 1:1 from findme_app/app/(auth)/sign-in.tsx. One field accepts email,
/// username, or phone -- the backend's POST /auth/login resolves whichever was typed.
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
    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BrandHeader(),
              const SizedBox(height: 28),
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
              const SizedBox(height: 16),
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
