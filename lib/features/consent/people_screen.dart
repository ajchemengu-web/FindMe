import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/location_service.dart';
import '../../core/models/models.dart';
import '../../theme/tokens.dart';
import '../auth/auth_controller.dart';
import '../devices/devices_repository.dart';
import '../devices/situation_room_screen.dart' show situationRoomProvider;
import '../map/map_screen.dart' show mapDataProvider;
import 'consent_repository.dart';

final consentRepositoryProvider = Provider((ref) => ConsentRepository());
final devicesRepositoryForPeopleProvider = Provider((ref) => DevicesRepository());

class PeopleData {
  final List<Device> devices;
  final List<Consent> incoming;
  final List<Consent> outgoingPending;
  final List<Consent> active;
  PeopleData({required this.devices, required this.incoming, required this.outgoingPending, required this.active});

  /// The consent that grants `currentUserId` visibility into `device` (i.e. where
  /// `currentUserId` is the grantee and `device`'s owner is the grantor) -- null if
  /// somehow not backed by an active grant. `active` mixes both directions (people
  /// watching you and people you're watching), so both ids matter, not just one.
  Consent? activeConsentFor(Device device, String currentUserId) {
    for (final c in active) {
      if (c.grantorId == device.ownerId && c.granteeId == currentUserId) return c;
    }
    return null;
  }
}

final peopleDataProvider = FutureProvider.autoDispose<PeopleData>((ref) async {
  final repo = ref.read(consentRepositoryProvider);
  final results = await Future.wait([repo.fetchVisibleDevices(), repo.fetchMyConsents()]);
  final devices = results[0] as List<Device>;
  final consents = results[1] as MyConsents;
  return PeopleData(devices: devices, incoming: consents.incoming, outgoingPending: consents.outgoingPending, active: consents.active);
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
  void _invalidateDeviceDerivedProviders() {
    ref.invalidate(peopleDataProvider);
    ref.invalidate(situationRoomProvider);
    ref.invalidate(mapDataProvider);
  }

  Future<void> _respond(String consentId, String decision) async {
    await ref.read(consentRepositoryProvider).respondToRequest(consentId, decision);
    _invalidateDeviceDerivedProviders();
  }

  Future<bool> _confirm({required String title, required String body, required String confirmLabel}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: const TextStyle(color: AppColors.ink, fontSize: 15)),
        content: Text(body, style: const TextStyle(color: AppColors.ink2, fontSize: 13, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel, style: const TextStyle(color: AppColors.critical, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// Owner removing a device they registered -- stops tracking it and (server-side)
  /// deletes its location history.
  Future<void> _removeOwnDevice(Device device) async {
    final ok = await _confirm(
      title: 'Remove "${device.nickname}"?',
      body: 'This stops tracking it and deletes its location history. This cannot be undone.',
      confirmLabel: 'Remove',
    );
    if (!ok) return;
    await ref.read(devicesRepositoryForPeopleProvider).deleteDevice(device.id);
    _invalidateDeviceDerivedProviders();
  }

  /// Watcher giving up their own access to someone else's device -- ported from
  /// lib/consent.ts's revokeConsent(), never wired to any UI in the original app.
  Future<void> _revokeAccess(Device device, String consentId) async {
    final ok = await _confirm(
      title: 'Stop watching "${device.nickname}"?',
      body: "You'll no longer see this device's location. They can always send a new request later if you change your mind.",
      confirmLabel: 'Stop watching',
    );
    if (!ok) return;
    await ref.read(consentRepositoryProvider).revokeConsent(consentId);
    _invalidateDeviceDerivedProviders();
  }

  /// New capability -- see core/location_service.dart's doc comment. Manual fallback
  /// for whenever the device wasn't pinged automatically (permission denied at
  /// add-device time, or its position is just stale).
  Future<void> _updateLocation(Device device) async {
    final position = await getCurrentLocationOrNull();
    if (!mounted) return;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't get this device's current position -- check location permission/services.")),
      );
      return;
    }
    await ref
        .read(devicesRepositoryForPeopleProvider)
        .reportLocation(device.id, lat: position.latitude, lon: position.longitude, accuracyM: position.accuracy);
    _invalidateDeviceDerivedProviders();
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
                      _invalidateDeviceDerivedProviders();
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
                              : myDevices
                                  .map((dev) => _DeviceRow(
                                        device: dev,
                                        isOwn: true,
                                        onUpdateLocation: () => _updateLocation(dev),
                                        onRemove: () => _removeOwnDevice(dev),
                                      ))
                                  .toList(),
                        ),
                        _Section(
                          title: "People you're watching",
                          children: watchedDevices.isEmpty
                              ? [const _EmptyText("Nobody yet -- tap + Add to request access to someone else's device.")]
                              : watchedDevices.map((dev) {
                                  final consent = userId != null ? d.activeConsentFor(dev, userId) : null;
                                  return _DeviceRow(
                                    device: dev,
                                    isOwn: false,
                                    onUpdateLocation: null,
                                    onRemove: consent != null ? () => _revokeAccess(dev, consent.id) : null,
                                  );
                                }).toList(),
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

enum _DeviceRowMenu { updateLocation, remove }

class _DeviceRow extends StatefulWidget {
  final Device device;
  final bool isOwn;
  final Future<void> Function()? onUpdateLocation;
  final Future<void> Function()? onRemove;
  const _DeviceRow({required this.device, required this.isOwn, this.onUpdateLocation, this.onRemove});

  @override
  State<_DeviceRow> createState() => _DeviceRowState();
}

class _DeviceRowState extends State<_DeviceRow> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = widget.device;
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
          if (widget.onUpdateLocation != null || widget.onRemove != null) ...[
            const SizedBox(width: 4),
            _busy
                ? const SizedBox(width: 26, height: 26, child: Center(child: SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))))
                : PopupMenuButton<_DeviceRowMenu>(
                    padding: EdgeInsets.zero,
                    color: AppColors.surface2,
                    icon: const Icon(Icons.more_vert, color: AppColors.ink3, size: 18),
                    onSelected: (choice) {
                      switch (choice) {
                        case _DeviceRowMenu.updateLocation:
                          if (widget.onUpdateLocation != null) _run(widget.onUpdateLocation!);
                        case _DeviceRowMenu.remove:
                          if (widget.onRemove != null) _run(widget.onRemove!);
                      }
                    },
                    itemBuilder: (context) => [
                      if (widget.onUpdateLocation != null)
                        const PopupMenuItem(
                          value: _DeviceRowMenu.updateLocation,
                          child: Text('Update location', style: TextStyle(color: AppColors.ink, fontSize: 13)),
                        ),
                      if (widget.onRemove != null)
                        PopupMenuItem(
                          value: _DeviceRowMenu.remove,
                          child: Text(widget.isOwn ? 'Remove device' : 'Stop watching', style: const TextStyle(color: AppColors.critical, fontSize: 13)),
                        ),
                    ],
                  ),
          ],
        ],
      ),
    );
  }
}
