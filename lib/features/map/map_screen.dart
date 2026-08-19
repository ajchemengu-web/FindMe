import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

import '../../core/models/models.dart';
import '../../theme/app_colors_data.dart';
import '../../theme/tokens.dart';
import '../devices/devices_repository.dart';
import 'map_repository.dart';

final mapRepositoryProvider = Provider((ref) => MapRepository());

class MapData {
  final List<VisibleDeviceLocation> devices;
  final List<ThreatZoneGeo> zones;
  MapData({required this.devices, required this.zones});
}

final mapDataProvider = FutureProvider.autoDispose<MapData>((ref) async {
  final repo = ref.read(mapRepositoryProvider);
  final results = await Future.wait([repo.fetchVisibleDeviceLocations(), repo.fetchThreatZonesGeo()]);
  return MapData(devices: results[0] as List<VisibleDeviceLocation>, zones: results[1] as List<ThreatZoneGeo>);
});

Color _severityColor(AppColorsData c, String severity) => switch (severity) {
      'critical' => c.critical,
      'serious' => c.serious,
      _ => c.warning,
    };

Color _precisionColor(AppColorsData c, String level) => switch (level) {
      'owner' => c.accent,
      'precise' => c.good,
      _ => c.warning,
    };

// CartoDB's raster tiles are natively sharp up to zoom 19 (confirmed against the live
// tile server); a couple of levels beyond that the server still returns valid tiles
// (over-zoomed/upscaled), which is normal map-app behavior for inspecting an exact pin
// position closely -- letting the camera go a bit past native resolution rather than
// hard-stopping at it.
const _minZoom = 2.0;
const _maxNativeZoom = 19;
const _maxZoom = 21.0;

/// Ported from findme_app/app/(app)/map.tsx, adapted from react-native-maps to
/// flutter_map: a CartoDB tile layer instead of a Google Maps JSON style (renders
/// identically on iOS/Android/Web, unlike the RN app where iOS fell back to plain Apple
/// Maps styling -- see findme_app/README.md's "known gaps"), and a bottom info card in
/// place of a marker Callout bubble (flutter_map has no built-in callout widget).
///
/// Theme-reactive -- previously forced dark regardless of the user's preference, which
/// also meant no light, high-contrast option existed for anyone who found a
/// permanently dark map hard to read.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final _mapController = MapController();
  VisibleDeviceLocation? _selected;
  List<Geofence> _geofences = [];
  bool _fitted = false;

  Future<void> _selectDevice(VisibleDeviceLocation d) async {
    setState(() => _selected = d);
    try {
      final rows = await DevicesRepository().fetchGeofencesGeo(d.deviceId);
      if (mounted) setState(() => _geofences = rows);
    } catch (_) {
      if (mounted) setState(() => _geofences = []);
    }
  }

  void _clearSelection() => setState(() {
        _selected = null;
        _geofences = [];
      });

  void _fitToData(MapData data) {
    final points = [
      for (final d in data.devices) LatLng(d.lat, d.lon),
      for (final z in data.zones) LatLng(z.lat, z.lon),
    ];
    if (points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.fitCamera(CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(60, 80, 60, 180),
        // Was 12 (city/regional scale) -- for the common case of one or a handful of
        // nearby devices, that left the initial view much further out than useful.
        // 16 is roughly street-level, a far more usable default close-up.
        maxZoom: 16,
      ));
    });
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(_minZoom, _maxZoom));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(mapDataProvider);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tileUrl = isDark ? mapTileUrlDark : mapTileUrlLight;
    final overlayBg = colors.surface.withValues(alpha: 0.92);

    return Scaffold(
      backgroundColor: colors.page,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🌐 Global Threat Map', style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
                  IconButton(
                    onPressed: data.isLoading ? null : () => ref.invalidate(mapDataProvider),
                    icon: data.isLoading
                        ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: colors.accent))
                        : Icon(Icons.refresh, color: colors.ink2, size: 18),
                    style: IconButton.styleFrom(side: BorderSide(color: colors.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm))),
                  ),
                ],
              ),
            ),
            Expanded(
              child: data.when(
                loading: () => Center(child: CircularProgressIndicator(color: colors.accent)),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$e', textAlign: TextAlign.center, style: TextStyle(color: colors.critical, fontSize: 13, height: 1.4)),
                        const SizedBox(height: 14),
                        ElevatedButton(onPressed: () => ref.invalidate(mapDataProvider), child: const Text('Retry')),
                      ],
                    ),
                  ),
                ),
                data: (d) {
                  if (!_fitted) {
                    _fitted = true;
                    _fitToData(d);
                  }
                  return Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(20, 10),
                          initialZoom: 2,
                          minZoom: _minZoom,
                          maxZoom: _maxZoom,
                          onTap: (_, _) => _clearSelection(),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: tileUrl,
                            userAgentPackageName: 'com.findme.findme_flutter',
                            // Fetches sharp @2x tiles on high-DPI screens instead of
                            // upscaled 1x ones -- the urlTemplate's {r} placeholder was
                            // already there but silently resolved to nothing without
                            // this flag, so every device was getting soft, non-retina
                            // tiles regardless of its actual screen density.
                            retinaMode: true,
                            maxNativeZoom: _maxNativeZoom,
                            maxZoom: _maxZoom,
                            minZoom: _minZoom,
                          ),
                          CircleLayer(
                            circles: [
                              for (final z in d.zones)
                                CircleMarker(
                                  point: LatLng(z.lat, z.lon),
                                  radius: (z.radiusKm ?? 25) * 1000,
                                  useRadiusInMeter: true,
                                  color: _severityColor(colors, z.severity).withValues(alpha: 0.18),
                                  borderColor: _severityColor(colors, z.severity),
                                  borderStrokeWidth: 1.5,
                                ),
                              if (_selected != null)
                                for (final g in _geofences)
                                  CircleMarker(
                                    point: LatLng(g.lat, g.lon),
                                    radius: g.radiusM,
                                    useRadiusInMeter: true,
                                    color: colors.accent.withValues(alpha: 0.16),
                                    borderColor: colors.accent,
                                    borderStrokeWidth: 1.5,
                                  ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              for (final dev in d.devices)
                                Marker(
                                  point: LatLng(dev.lat, dev.lon),
                                  width: 28,
                                  height: 28,
                                  child: GestureDetector(
                                    onTap: () => _selectDevice(dev),
                                    child: Icon(Icons.location_on, color: _precisionColor(colors, dev.precisionLevel), size: 28),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      // Right-center rather than a corner -- the bottom is already
                      // contested by the legend/selected-device card (both full-width
                      // when shown) and the top by the empty-state banner.
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(child: _ZoomControls(background: overlayBg, onZoomIn: () => _zoomBy(1), onZoomOut: () => _zoomBy(-1))),
                      ),
                      if (d.devices.isEmpty && d.zones.isEmpty)
                        Positioned(
                          top: 16,
                          left: 16,
                          right: 16,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: overlayBg,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: colors.line),
                            ),
                            child: Text(
                              'Nothing to plot yet -- devices need at least one reported position (see People & Devices), and threat zones need the conflict-events ingest run with a real API key configured.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colors.ink3, fontSize: 12, height: 1.4),
                            ),
                          ),
                        ),
                      if (_selected != null)
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 16,
                          child: _DeviceInfoCard(device: _selected!, background: overlayBg),
                        )
                      else
                        Positioned(bottom: 16, left: 16, child: _Legend(background: overlayBg)),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Explicit +/- zoom buttons -- previously the only way to zoom was pinch/scroll,
/// which isn't always discoverable (especially on desktop/web without touch or a
/// precise trackpad), and there was no visible affordance suggesting the map could be
/// zoomed in further than wherever the initial auto-fit landed.
class _ZoomControls extends StatelessWidget {
  final Color background;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  const _ZoomControls({required this.background, required this.onZoomIn, required this.onZoomOut});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: colors.line)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ZoomButton(icon: Icons.add, onTap: onZoomIn),
          Container(height: 1, color: colors.line),
          _ZoomButton(icon: Icons.remove, onTap: onZoomOut),
        ],
      ),
    );
  }
}

class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ZoomButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(width: 36, height: 36, child: Icon(icon, color: context.colors.ink2, size: 18)),
    );
  }
}

class _DeviceInfoCard extends StatelessWidget {
  final VisibleDeviceLocation device;
  final Color background;
  const _DeviceInfoCard({required this.device, required this.background});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = switch (device.precisionLevel) {
      'owner' => 'Your device',
      'precise' => 'Precise location (consented)',
      _ => 'City-level only (consented)',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: colors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(device.nickname, style: TextStyle(color: colors.ink, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 3),
          Text(label, style: TextStyle(color: colors.ink2, fontSize: 11)),
          const SizedBox(height: 3),
          Text('Updated ${DateFormat.yMMMd().add_jm().format(device.recordedAt)}', style: TextStyle(color: colors.ink3, fontSize: 10)),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color background;
  const _Legend({required this.background});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: colors.line)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendRow(color: colors.accent, label: 'Your device'),
          _LegendRow(color: colors.good, label: 'Precise consent'),
          _LegendRow(color: colors.warning, label: 'City-level consent'),
          _LegendRow(color: colors.critical, label: 'Critical zone'),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 7),
          Text(label, style: TextStyle(color: context.colors.ink2, fontSize: 10.5)),
        ],
      ),
    );
  }
}
