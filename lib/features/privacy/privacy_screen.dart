import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../theme/tokens.dart';
import '../auth/auth_controller.dart';

/// Real (not placeholder) since the sign-out affordance needs to live somewhere for
/// the app to be usable end to end -- full Privacy Center content (consent scopes,
/// account settings) ports in task #6.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(title: const Text('Privacy Center')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (user != null) ...[
              Text(user.displayName ?? user.username, style: const TextStyle(color: AppColors.ink, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(user.email, style: const TextStyle(color: AppColors.ink3, fontSize: 12)),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Phone verification', style: TextStyle(color: AppColors.ink, fontSize: 13)),
                subtitle: Text(
                  user.phoneVerified ? 'Verified · ${user.phone ?? ''}' : 'Not verified',
                  style: TextStyle(color: user.phoneVerified ? AppColors.good : AppColors.warning, fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right, color: AppColors.ink3),
                onTap: () => context.push('/verify-phone'),
              ),
              const SizedBox(height: 8),
            ],
            const Text(
              'Consent scopes, geofence privacy settings, and account controls -- coming next.',
              style: TextStyle(color: AppColors.ink3, fontSize: 13, height: 1.4),
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}
