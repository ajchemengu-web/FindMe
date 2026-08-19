import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme_mode_controller.dart';
import '../../theme/app_colors_data.dart';
import '../../theme/tokens.dart';
import '../auth/auth_controller.dart';
import '../billing/referrals_repository.dart';

final referralsRepositoryProvider = Provider((ref) => ReferralsRepository());
final referralStatsProvider = FutureProvider.autoDispose((ref) => ref.read(referralsRepositoryProvider).fetchStats());

/// Ported from findme_app/app/(app)/privacy.tsx's basics (profile summary, phone
/// verification entry point, sign out), plus a Plan & Billing entry point (into the
/// M-Pesa billing modal), a Referrals section (new -- see referralStatsProvider's doc
/// comment for why), and an Appearance section (new -- the app previously forced dark
/// mode regardless of preference). Consent scopes and geofence privacy settings from
/// the original screen aren't built yet. Theme-reactive.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final referrals = ref.watch(referralStatsProvider);
    final themeMode = ref.watch(themeModeProvider);
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.page,
      appBar: AppBar(title: const Text('Privacy Center')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (user != null) ...[
            Text(user.displayName ?? user.username, style: TextStyle(color: colors.ink, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(user.email, style: TextStyle(color: colors.ink3, fontSize: 12)),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Phone verification', style: TextStyle(color: colors.ink, fontSize: 13)),
              subtitle: Text(
                user.phoneVerified ? 'Verified · ${user.phone ?? ''}' : 'Not verified',
                style: TextStyle(color: user.phoneVerified ? colors.good : colors.warning, fontSize: 11),
              ),
              trailing: Icon(Icons.chevron_right, color: colors.ink3),
              onTap: () => context.push('/verify-phone'),
            ),
            Divider(color: colors.line, height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Plan & Billing', style: TextStyle(color: colors.ink, fontSize: 13)),
              subtitle: Text('${user.planTier[0].toUpperCase()}${user.planTier.substring(1)} plan', style: TextStyle(color: colors.ink3, fontSize: 11)),
              trailing: Icon(Icons.chevron_right, color: colors.ink3),
              onTap: () => context.push('/billing'),
            ),
            Divider(color: colors.line, height: 1),
          ],
          const SizedBox(height: 20),
          Text('APPEARANCE', style: TextStyle(color: colors.ink3, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 10),
          _ThemeModeSelector(current: themeMode, onChanged: (mode) => ref.read(themeModeProvider.notifier).setMode(mode)),
          const SizedBox(height: 24),
          Text('REFERRALS', style: TextStyle(color: colors.ink3, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 10),
          referrals.when(
            loading: () => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: CircularProgressIndicator(color: colors.accent)),
            error: (e, _) => Text('Could not load referral stats.', style: TextStyle(color: colors.ink3, fontSize: 12)),
            data: (r) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('YOUR CODE', style: TextStyle(color: colors.ink3, fontSize: 10, letterSpacing: 0.6)),
                  const SizedBox(height: 4),
                  Text(r.referralCode, style: TextStyle(color: colors.accent, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
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
                    Text('KES ${(r.pendingCommissionCents / 100).toStringAsFixed(0)} pending', style: TextStyle(color: colors.warning, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Consent scopes and geofence privacy settings -- coming next.',
            style: TextStyle(color: colors.ink3, fontSize: 13, height: 1.4),
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

class _ThemeModeSelector extends StatelessWidget {
  final ThemeMode current;
  final ValueChanged<ThemeMode> onChanged;
  const _ThemeModeSelector({required this.current, required this.onChanged});

  static const _options = [
    (mode: ThemeMode.system, label: 'System', icon: Icons.brightness_auto),
    (mode: ThemeMode.light, label: 'Light', icon: Icons.light_mode),
    (mode: ThemeMode.dark, label: 'Dark', icon: Icons.dark_mode),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      children: [
        for (final opt in _options)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: opt.mode != ThemeMode.dark ? 8 : 0),
              child: InkWell(
                onTap: () => onChanged(opt.mode),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: current == opt.mode ? colors.accentDim : Colors.transparent,
                    border: Border.all(color: current == opt.mode ? colors.accent : colors.line),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt.icon, size: 18, color: current == opt.mode ? colors.accent : colors.ink2),
                      const SizedBox(height: 4),
                      Text(opt.label, style: TextStyle(fontSize: 11, color: current == opt.mode ? colors.accent : colors.ink2, fontWeight: current == opt.mode ? FontWeight.bold : FontWeight.normal)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: TextStyle(color: colors.ink, fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: colors.ink3, fontSize: 10.5)),
      ],
    );
  }
}
