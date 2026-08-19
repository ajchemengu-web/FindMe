import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/models.dart';
import '../../theme/tokens.dart';
import '../auth/auth_controller.dart';
import 'consent_repository.dart';

final consentRepositoryProvider = Provider((ref) => ConsentRepository());

class PeopleData {
  final List<Device> devices;
  final List<Consent> incoming;
  final List<Consent> outgoingPending;
  PeopleData({required this.devices, required this.incoming, required this.outgoingPending});
}

final peopleDataProvider = FutureProvider.autoDispose<PeopleData>((ref) async {
  final repo = ref.read(consentRepositoryProvider);
  final results = await Future.wait([repo.fetchVisibleDevices(), repo.fetchMyConsents()]);
  final devices = results[0] as List<Device>;
  final consents = results[1] as MyConsents;
  return PeopleData(devices: devices, incoming: consents.incoming, outgoingPending: consents.outgoingPending);
});

/// Ported 1:1 from findme_app/app/(app)/people.tsx. An incoming consent request shows
/// up here, on the device owner's own screen, with real Approve/Deny actions -- unlike
/// the original HTML mockup, which simulated "here's what the other person sees" in a
/// demo modal since a static mockup has no other person to show it to.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  Future<void> _respond(String consentId, String decision) async {
    await ref.read(consentRepositoryProvider).respondToRequest(consentId, decision);
    ref.invalidate(peopleDataProvider);
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(peopleDataProvider);
    final userId = ref.watch(authControllerProvider).valueOrNull?.id;

    return Scaffold(
      backgroundColor: AppColors.page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('People & Devices', style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    onPressed: () async {
                      await context.push('/add-device');
                      ref.invalidate(peopleDataProvider);
                    },
                    child: const Text('+ Add', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(peopleDataProvider),
                child: data.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (e, _) => ListView(children: [
                    Padding(padding: const EdgeInsets.all(24), child: Text('Could not load: $e', style: const TextStyle(color: AppColors.ink3))),
                  ]),
                  data: (d) {
                    final myDevices = d.devices.where((dev) => dev.ownerId == userId).toList();
                    final watchedDevices = d.devices.where((dev) => dev.ownerId != userId).toList();
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
                      children: [
                        if (d.incoming.isNotEmpty)
                          _Section(
                            title: 'Incoming requests (${d.incoming.length})',
                            children: d.incoming.map((c) => _RequestRow(consent: c, onRespond: _respond)).toList(),
                          ),
                        _Section(
                          title: 'Your devices',
                          children: myDevices.isEmpty
                              ? [const _EmptyText('No devices yet -- tap + Add to register your own device.')]
                              : myDevices.map((dev) => _DeviceRow(device: dev)).toList(),
                        ),
                        _Section(
                          title: "People you're watching",
                          children: watchedDevices.isEmpty
                              ? [const _EmptyText("Nobody yet -- tap + Add to request access to someone else's device.")]
                              : watchedDevices.map((dev) => _DeviceRow(device: dev)).toList(),
                        ),
                        if (d.outgoingPending.isNotEmpty)
                          _Section(
                            title: 'Pending (sent by you) -- ${d.outgoingPending.length}',
                            children: d.outgoingPending
                                .map((c) => _PlainRow(
                                      title: 'Waiting for approval',
                                      meta: 'Requested ${DateFormat.yMMMd().format(c.requestedAt)}',
                                    ))
                                .toList(),
                          ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.03),
                            border: Border.all(color: AppColors.line),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Text(
                            '🔒 Every person above actively accepted a watch-list request and can revoke it anytime from their own Privacy Center.',
                            style: TextStyle(color: AppColors.ink3, fontSize: 11, height: 1.4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: AppColors.ink3, fontSize: 11, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: AppColors.ink3, fontSize: 12, height: 1.4));
}

class _PlainRow extends StatelessWidget {
  final String title;
  final String meta;
  const _PlainRow({required this.title, required this.meta});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(meta, style: const TextStyle(color: AppColors.ink3, fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _RequestRow extends StatelessWidget {
  final Consent consent;
  final Future<void> Function(String id, String decision) onRespond;
  const _RequestRow({required this.consent, required this.onRespond});

  @override
  Widget build(BuildContext context) {
    final scopeLabel = consent.scope == 'precise' ? 'Precise location' : 'City-level only';
    final until = consent.expiresAt != null ? ' · until ${DateFormat.yMMMd().format(consent.expiresAt!)}' : ' · until revoked';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentDim,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: const Color(0x593987E5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Someone wants to watch your device', style: TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text('Asking for: $scopeLabel$until', style: const TextStyle(color: AppColors.ink3, fontSize: 10.5)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7), minimumSize: Size.zero),
            onPressed: () => onRespond(consent.id, 'denied'),
            child: const Text('Deny', style: TextStyle(fontSize: 11)),
          ),
          const SizedBox(width: 6),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.good,
              foregroundColor: const Color(0xFF05230A),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              minimumSize: Size.zero,
            ),
            onPressed: () => onRespond(consent.id, 'active'),
            child: const Text('Allow', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  final Device device;
  const _DeviceRow({required this.device});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: device.lastSeenAt != null ? AppColors.good : const Color(0xFF4A4A48),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(device.nickname, style: const TextStyle(color: AppColors.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(
                  '${device.deviceType}${device.lastSeenAt != null ? ' · last seen ${DateFormat.jm().format(device.lastSeenAt!)}' : ''}',
                  style: const TextStyle(color: AppColors.ink3, fontSize: 10.5),
                ),
              ],
            ),
          ),
          if (device.batteryPct != null) ...[
            Text('${device.batteryPct}%', style: const TextStyle(color: AppColors.ink3, fontSize: 11, fontFamily: 'monospace')),
            const SizedBox(width: 8),
          ],
          InkWell(
            onTap: () => context.push('/add-geofence', extra: {'deviceId': device.id, 'nickname': device.nickname}),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(AppRadius.sm)),
              child: const Text('📍', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}
