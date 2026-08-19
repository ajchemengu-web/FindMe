import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../theme/tokens.dart';
import '../devices/situation_room_screen.dart' show alertsRepositoryProvider, situationRoomProvider;

final alertsListProvider = FutureProvider.autoDispose<List<Alert>>((ref) async {
  try {
    return await ref.read(alertsRepositoryProvider).fetchAlerts(limit: 50);
  } catch (_) {
    // Ported 1:1 -- the original swallows load failures (console.warn only, no
    // user-facing error). Known gap, not one this port silently fixes.
    return [];
  }
});

/// Ported 1:1 from findme_app/app/(app)/alerts.tsx.
class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  Future<void> _markRead(WidgetRef ref, String id) async {
    try {
      await ref.read(alertsRepositoryProvider).markAlertRead(id);
    } catch (_) {
      // Same as load: swallowed in the original, ported as-is.
    } finally {
      ref.invalidate(alertsListProvider);
      ref.invalidate(situationRoomProvider); // unread count shown there needs to move too
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = ref.watch(alertsListProvider);

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Alert Log', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(alertsListProvider),
                child: alerts.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (e, _) => const Center(child: Text('Could not load alerts.', style: TextStyle(color: AppColors.ink3))),
                  data: (rows) => rows.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                              child: Text(
                                'No alerts yet -- these are generated server-side (geofence crossings, low battery, '
                                'threat-proximity checks, consent requests) once the geofence-evaluation function and location data are flowing.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.ink3, fontSize: 12, height: 1.4),
                              ),
                            ),
                          ],
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                          itemCount: rows.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, i) => _AlertRow(alert: rows[i], onTap: () => _markRead(ref, rows[i].id)),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  final Alert alert;
  final VoidCallback onTap;
  const _AlertRow({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final sevColor = switch (alert.severity) {
      'critical' => AppColors.critical,
      'warning' => AppColors.warning,
      _ => AppColors.good,
    };
    return InkWell(
      onTap: alert.read ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: alert.read ? null : Border.all(color: const Color(0x4D3987E5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 8, height: 8, margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: sevColor, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(alert.message, style: const TextStyle(color: AppColors.ink, fontSize: 13, height: 1.3)),
                  const SizedBox(height: 4),
                  Text(DateFormat.yMMMd().add_jm().format(alert.createdAt), style: const TextStyle(color: AppColors.ink3, fontSize: 10.5, fontFamily: 'monospace')),
                ],
              ),
            ),
            if (!alert.read) Container(margin: const EdgeInsets.only(top: 6), width: 7, height: 7, decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
          ],
        ),
      ),
    );
  }
}
