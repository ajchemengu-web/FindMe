import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/globe_dots.dart';
import '../core/globe_math.dart';
import '../core/models/models.dart';
import '../theme/app_colors_data.dart';

/// The Situation Room's spinning globe -- a real world map (the same land-dot coastline
/// sampling as the Expo app's components/Globe.tsx, itself ported from
/// findme_situation_room_mockup.html), not the small decorative wireframe sphere this
/// widget used to be. Fills whatever space its parent gives it (via LayoutBuilder) --
/// situation_room_screen.dart is what decides how large/central it is on screen, this
/// widget just draws whatever square it's handed.
///
/// Threat zones and visible devices are plotted as colored markers, same category
/// coloring as the Expo app's theme/tokens.dart threatCategoryColor(): conflict=critical
/// (red), unrest=catYellow, disaster=catMagenta (pink), devices=accent (light blue).
class RotatingGlobe extends StatefulWidget {
  final List<ThreatZoneGeo> zones;
  final List<VisibleDeviceLocation> devices;
  final VoidCallback? onTap;

  const RotatingGlobe({super.key, this.zones = const [], this.devices = const [], this.onTap});

  @override
  State<RotatingGlobe> createState() => _RotatingGlobeState();
}

/// Mockup's `lambda += 0.045` was a flat per-frame increment, implicitly tuned for
/// ~60fps (16.67ms/frame). Scaling by actual elapsed time keeps rotation speed
/// consistent regardless of the device's refresh rate. Tripled from the mockup's
/// original pace, matching the Expo app's spin speed (a later product request).
const double _rotationDegPerMs = (0.045 * 3) / 16.67;

class _RotatingGlobeState extends State<RotatingGlobe> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _lambda = 96;
  Duration _lastElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    final dtMs = (elapsed - _lastElapsed).inMicroseconds / 1000.0;
    _lastElapsed = elapsed;
    if (dtMs > 0) {
      setState(() => _lambda += _rotationDegPerMs * dtMs);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  Color _categoryColor(AppColorsData c, String category) => switch (category) {
        'conflict' => c.critical,
        'unrest' => c.catYellow,
        'disaster' => c.catMagenta,
        _ => c.accent,
      };

  double _severityRadius(String severity) => switch (severity) {
        'critical' => 4.2,
        'serious' => 3.4,
        _ => 2.8,
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final markerCount = widget.zones.length + widget.devices.length;

    return GestureDetector(
      onTap: widget.onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Container(
            width: w,
            height: h,
            decoration: BoxDecoration(color: const Color(0xFF060809), borderRadius: BorderRadius.circular(10)),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(w, h),
                  painter: _GlobePainter(
                    lambda: _lambda,
                    zones: widget.zones,
                    devices: widget.devices,
                    categoryColor: (category) => _categoryColor(colors, category),
                    severityRadius: _severityRadius,
                    trackedColor: colors.accent,
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: _Hud(markerCount: markerCount, accent: colors.accent),
                ),
                const Positioned(right: 12, bottom: 10, child: _Caption()),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Hud extends StatelessWidget {
  final int markerCount;
  final Color accent;
  const _Hud({required this.markerCount, required this.accent});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(color: Color(0x80FFFFFF), fontSize: 9.5, fontFamily: 'monospace', height: 1.55);
    return IgnorePointer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(style: base, children: [
              const TextSpan(text: 'MODE: '),
              TextSpan(text: 'ORBITAL', style: TextStyle(color: accent)),
            ]),
          ),
          const Text('SRC: ACLED · GDELT · UCDP', style: base),
          Text('TRACKING $markerCount SITES', style: base),
        ],
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Text('Tap to open the live map', style: TextStyle(color: Color(0x4DFFFFFF), fontSize: 9, fontFamily: 'monospace')),
    );
  }
}

class _GlobePainter extends CustomPainter {
  final double lambda;
  final List<ThreatZoneGeo> zones;
  final List<VisibleDeviceLocation> devices;
  final Color Function(String category) categoryColor;
  final double Function(String severity) severityRadius;
  final Color trackedColor;

  _GlobePainter({
    required this.lambda,
    required this.zones,
    required this.devices,
    required this.categoryColor,
    required this.severityRadius,
    required this.trackedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = (size.width < size.height ? size.width : size.height) * 0.36;
    if (r <= 0) return;
    final center = Offset(cx, cy);

    // Sphere body.
    final spherePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.32, -0.32),
        radius: 1.05,
        colors: const [Color(0xFF16283B), Color(0xFF0C1822), Color(0xFF050A0F)],
        stops: const [0, 0.65, 1],
      ).createShader(Rect.fromCircle(center: center, radius: r * 1.05));
    canvas.drawCircle(center, r, spherePaint);

    // Atmosphere glow.
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [
        trackedColor.withValues(alpha: 0.30),
        trackedColor.withValues(alpha: 0),
      ]).createShader(Rect.fromCircle(center: center, radius: r * 1.28));
    canvas.drawCircle(center, r * 1.28, glowPaint);

    // Rim.
    canvas.drawCircle(
      center,
      r * 1.005,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x8C6EAFF0),
    );

    final graticule = buildGraticulePath(lambda, kGlobeTiltDeg, cx, cy, r);
    canvas.drawPath(
      graticule,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x13FFFFFF),
    );

    final equator = buildEquatorPath(lambda, kGlobeTiltDeg, cx, cy, r);
    canvas.drawPath(
      equator,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x29FFFFFF),
    );

    final dots = buildLandDotPaths(kGlobeDots, lambda, kGlobeTiltDeg, cx, cy, r);
    canvas.drawPath(dots.far, Paint()..color = const Color(0x595FD6A0));
    canvas.drawPath(dots.near, Paint()..color = const Color(0xE55FD6A0));

    for (final z in zones) {
      _drawMarker(canvas, z.lon, z.lat, cx, cy, r, categoryColor(z.category), severityRadius(z.severity));
    }
    for (final d in devices) {
      _drawMarker(canvas, d.lon, d.lat, cx, cy, r, trackedColor, 3.4);
    }

    // Depth shade -- a soft one-sided darkening so the sphere doesn't look flat-lit.
    final shadePaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.42, -0.42),
        radius: 1.02,
        colors: const [Color(0x00000000), Color(0x80000000)],
      ).createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawCircle(center, r, shadePaint);
  }

  void _drawMarker(Canvas canvas, double lon, double lat, double cx, double cy, double r, Color color, double radius) {
    final p = projectPoint(lon, lat, lambda, kGlobeTiltDeg, cx, cy, r);
    if (!p.visible) return;
    final point = Offset(p.x, p.y);
    canvas.drawCircle(
      point,
      radius + 6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.45),
    );
    canvas.drawCircle(point, radius, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) =>
      oldDelegate.lambda != lambda || oldDelegate.zones != zones || oldDelegate.devices != devices;
}
