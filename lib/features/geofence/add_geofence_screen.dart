import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../theme/tokens.dart';
import '../devices/devices_repository.dart';

/// Ported 1:1 from findme_app/app/add-geofence.tsx. No map-based point picker (same
/// known gap as the original) -- centers the new geofence on the device's own last
/// known position instead, read through GET /devices/{id}/locations so scope
/// coarsening (a city-scope grant) is respected the same way everywhere else is.
class AddGeofenceScreen extends StatefulWidget {
  final String? deviceId;
  final String? nickname;
  const AddGeofenceScreen({super.key, this.deviceId, this.nickname});

  @override
  State<AddGeofenceScreen> createState() => _AddGeofenceScreenState();
}

class _AddGeofenceScreenState extends State<AddGeofenceScreen> {
  final _repo = DevicesRepository();
  LocationOut? _location;
  bool _loadingLocation = true;
  final _name = TextEditingController();
  final _radiusM = TextEditingController(text: '200');
  String? _error;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final deviceId = widget.deviceId;
    if (deviceId == null) {
      setState(() => _loadingLocation = false);
      return;
    }
    try {
      final rows = await _repo.getDeviceLocations(deviceId, limit: 1);
      setState(() => _location = rows.isNotEmpty ? rows.first : null);
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : 'Failed to load location.');
    } finally {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _onSubmit() async {
    final deviceId = widget.deviceId;
    final loc = _location;
    if (deviceId == null || loc == null) return;

    final parsedRadius = int.tryParse(_radiusM.text.trim());
    if (_name.text.trim().isEmpty || parsedRadius == null || parsedRadius <= 0) {
      setState(() => _error = 'Give the zone a name and a radius greater than 0.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _repo.createGeofence(deviceId, name: _name.text.trim(), lon: loc.lon, lat: loc.lat, radiusM: parsedRadius);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : 'Failed to create the geofence.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This is a bare fullscreenDialog page (see app_router.dart's '/add-geofence' route),
    // not a Scaffold -- which normally supplies the Material ancestor TextField needs for
    // its input decoration/selection handles. Without this wrapper, tapping into either
    // TextField in _buildBody() below crashes with "No Material widget found."
    // `type: transparency` means it paints nothing of its own, just provides the ancestor
    // the fields need.
    return Material(
      type: MaterialType.transparency,
      child: Container(
      color: const Color(0xD9040608),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.nickname != null ? 'ADD GEOFENCE -- ${widget.nickname!.toUpperCase()}' : 'ADD GEOFENCE',
                      style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1),
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close, color: AppColors.ink3, size: 18)),
                ],
              ),
              const SizedBox(height: 4),
              _buildBody(),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loadingLocation) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (_location == null) {
      return Text(
        _error ?? 'No location history for this device yet -- it needs to report at least one position before a geofence can be centered on it.',
        style: const TextStyle(color: AppColors.critical, fontSize: 12, height: 1.4),
      );
    }

    final loc = _location!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0x0F3987E5),
            border: Border.all(color: const Color(0x403987E5)),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('CENTERED ON CURRENT POSITION', style: TextStyle(color: AppColors.ink3, fontSize: 10, letterSpacing: 0.6)),
              const SizedBox(height: 4),
              Text(
                '${loc.lat.toStringAsFixed(4)}, ${loc.lon.toStringAsFixed(4)}'
                '${loc.precisionLevel == 'city' ? " (city-level -- this grant's scope)" : ''}',
                style: const TextStyle(color: AppColors.ink2, fontSize: 13, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _FieldLabel('Zone name'),
        TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. School, Home')),
        const SizedBox(height: 12),
        const _FieldLabel('Radius (meters)'),
        TextField(controller: _radiusM, decoration: const InputDecoration(), keyboardType: TextInputType.number),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: AppColors.critical, fontSize: 12, height: 1.4)),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitting ? null : _onSubmit,
          child: _submitting
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Create Geofence'),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text.toUpperCase(), style: const TextStyle(color: AppColors.ink3, fontSize: 10.5, letterSpacing: 1)),
      );
}
