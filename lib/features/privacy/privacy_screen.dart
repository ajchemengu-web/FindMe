import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/tokens.dart';
import '../auth/auth_controller.dart';
import '../billing/referrals_repository.dart';

final referralsRepositoryProvider = Provider((ref) => ReferralsRepository());
final referralStatsProvider = FutureProvider.autoDispose((ref) => ref.read(referralsRepositoryProvider).fetchStats());

/// Ported from findme_app/app/(app)/privacy.tsx's basics (profile summary, phone
/// verification entry point, sign out), plus a Plan & Billing entry point (into the
/// M-Pesa billing modal) and a Referrals section -- the latter had no UI anywhere in
/// the original app despite the backend supporting it (GET /referrals/stats), so it's
/// new here rather than a port. Consent scopes and geofence privacy settings from the
/// original screen aren't built yet.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final referrals = ref.watch(referralStatsProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(title: const Text('Privacy Center')),
      body: ListView(
        padding: const EdgeInsets.all(24),
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
            const Divider(color: AppColors.line, height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Plan & Billing', style: TextStyle(color: AppColors.ink, fontSize: 13)),
              subtitle: Text('${user.planTier[0].toUpperCase()}${user.planTier.substring(1)} plan', style: const TextStyle(color: AppColors.ink3, fontSize: 11)),
              trailing: const Icon(Icons.chevron_right, color: AppColors.ink3),
              onTap: () => context.push('/billing'),
            ),
            const Divider(color: AppColors.line, height: 1),
          ],
          const SizedBox(height: 20),
          const Text('REFERRALS', style: TextStyle(color: AppColors.ink3, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 10),
          referrals.when(
            loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator(color: AppColors.accent)),
            error: (e, _) => const Text('Could not load referral stats.', style: TextStyle(color: AppColors.ink3, fontSize: 12)),
            data: (r) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('YOUR CODE', style: TextStyle(color: AppColors.ink3, fontSize: 10, letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text(r.referralCode, style: const TextStyle(color: AppColors.accent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _StatBlock(label: 'Referrals', value: '${r.totalReferrals}'),
                      const SizedBox(width: 20),
                      _StatBlock(label: 'Paying', value: '${r.payingReferrals}'),
                      const SizedBox(width: 20),
                      _StatBlock(label: 'Earned', value: 'KES ${(r.paidCommissionCents / 100).toStringAsFixed(0)}'),
                    ],
                  ),
                  if (r.pendingCommissionCents > 0) ...[
                    const SizedBox(height: 8),
                    Text('KES ${(r.pendingCommissionCents / 100).toStringAsFixed(0)} pending', style: const TextStyle(color: AppColors.warning, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Consent scopes and geofence privacy settings -- coming next.',
            style: TextStyle(color: AppColors.ink3, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: AppColors.ink, fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: AppColors.ink3, fontSize: 10.5)),
      ],
    );
  }
}
