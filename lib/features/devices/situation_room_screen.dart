import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/models.dart';
import '../../theme/tokens.dart';
import '../alerts/alerts_repository.dart';
import '../auth/auth_controller.dart';
import '../map/map_repository.dart';
import 'devices_repository.dart';

final devicesRepositoryProvider = Provider((ref) => DevicesRepository());
final alertsRepositoryProvider = Provider((ref) => AlertsRepository());
final mapRepositoryProvider = Provider((ref) => MapRepository());

class SituationRoomData {
  final List<ThreatZoneGeo> zones;
  final int deviceCount;
  final int unreadAlertCount;
  SituationRoomData({required this.zones, required this.deviceCount, required this.unreadAlertCount});
}

const _severityRank = {'critical': 2, 'serious': 1, 'warning': 0};

final situationRoomProvider = FutureProvider.autoDispose<SituationRoomData>((ref) async {
  final results = await Future.wait([
    ref.read(mapRepositoryProvider).fetchThreatZonesGeo(),
    ref.read(devicesRepositoryProvider).listDevices(),
    ref.read(alertsRepositoryProvider).fetchAlerts(limit: 100),
  ]);
  final zones = (results[0] as List<ThreatZoneGeo>).toList()
    ..sort((a, b) => (_severityRank[b.severity] ?? 0).compareTo(_severityRank[a.severity] ?? 0));
  final devices = results[1] as List<Device>;
  final alerts = results[2] as List<Alert>;
  return SituationRoomData(
    zones: zones.take(20).toList(),
    deviceCount: devices.length,
    unreadAlertCount: alerts.where((a) => !a.read).length,
  );
});

/// Ported 1:1 from findme_app/app/(app)/index.tsx -- the fast-scanning dashboard: stat
/// tiles + the highest-severity threat zones, with a link into the real interactive Map
/// tab.
class SituationRoomScreen extends ConsumerWidget {
  const SituationRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(situationRoomProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(situationRoomProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('FINDME', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2)),
                      Text(
                        'Situation Room${user != null ? ' · ${user.displayName ?? user.username}' : ''}',
                        style: const TextStyle(color: AppColors.ink3, fontSize: 11, letterSpacing: 1),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: data.when(
                  data: (d) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        Expanded(child: _StatTile(label: 'Tracked Devices', value: '${d.deviceCount}', accent: AppColors.accent)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatTile(label: 'Unread Alerts', value: '${d.unreadAlertCount}', accent: AppColors.warning)),
                        const SizedBox(width: 10),
                        Expanded(child: _StatTile(label: 'Watched Zones', value: '${d.zones.length}', accent: AppColors.critical)),
                      ],
                    ),
                  ),
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Text('Could not load dashboard: $e', style: const TextStyle(color: AppColors.ink3, fontSize: 12)),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
                sliver: SliverToBoxAdapter(
                  child: InkWell(
                    onTap: () => context.go('/map'),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('🌐 Global Threat Map', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 13)),
                          SizedBox(height: 6),
                          Text(
                            'Open the Map tab for the live, interactive view -- every device you can see, every threat '
                            'zone below plotted as a circle, and any device\'s geofences on tap.',
                            style: TextStyle(color: AppColors.ink3, fontSize: 12, height: 1.3),
                          ),
                          SizedBox(height: 10),
                          Text('Open Map →', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              data.when(
                data: (d) => d.zones.isEmpty
                    ? const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'No threat zone data yet -- run the ingest-conflict-events endpoint once it has a real API key configured.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.ink3, fontSize: 12),
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                        sliver: SliverList.separated(
                          itemCount: d.zones.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, i) => _ZoneCard(zone: d.zones[i]),
                        ),
                      ),
                loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
                error: (_, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  const _StatTile({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: AppColors.ink3, fontSize: 9.5, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: AppColors.ink, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _ZoneCard extends StatelessWidget {
  final ThreatZoneGeo zone;
  const _ZoneCard({required this.zone});

  @override
  Widget build(BuildContext context) {
    final sev = switch (zone.severity) {
      'critical' => Severity.critical,
      'serious' => Severity.serious,
      _ => Severity.warning,
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5, right: 10),
            decoration: BoxDecoration(color: AppColors.severity(sev), shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(zone.title, style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w600, fontSize: 13)),
                if (zone.summary != null) ...[
                  const SizedBox(height: 3),
                  Text(zone.summary!, style: const TextStyle(color: AppColors.ink2, fontSize: 12, height: 1.3)),
                ],
                const SizedBox(height: 6),
                Text(
                  '${zone.category.toUpperCase()} · ${zone.severity.toUpperCase()} · ${zone.source}',
                  style: const TextStyle(color: AppColors.ink3, fontSize: 10, fontFamily: 'monospace', letterSpacing: 0.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
