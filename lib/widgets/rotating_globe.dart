import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors_data.dart';

/// The HTML mockup this app is based on (findme_situation_room_mockup.html) opened
/// with a canvas-drawn spinning globe / "zoom in from space" sequence. Both the
/// original React Native app and the first pass of this Flutter port deliberately
/// skipped porting it literally -- see situation_room_screen.dart's original commit
/// message: "that was a 2D canvas + Leaflet technique built to sell the look and feel
/// of a static design, not something to port literally." Real functionality (the
/// interactive Map tab with actual device pins and threat zones) earned its own
/// screen instead.
///
/// This brings the visual back as a lightweight, scoped wireframe-globe animation
/// (rotating meridian lines drawn each frame via CustomPainter) rather than a full
/// canvas/WebGL recreation of the mockup's effect -- decorative, matches the dark HUD
/// aesthetic, costs nothing functionally, and doesn't pretend to be the real map.
class RotatingGlobe extends StatefulWidget {
  final double size;
  const RotatingGlobe({super.key, this.size = 96});

  @override
  State<RotatingGlobe> createState() => _RotatingGlobeState();
}

class _RotatingGlobeState extends State<RotatingGlobe> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 14))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _GlobePainter(t: _controller.value, accent: colors.accent, line: colors.ink3),
        ),
      ),
    );
  }
}

class _GlobePainter extends CustomPainter {
  final double t; // 0..1, one full rotation
  final Color accent;
  final Color line;
  _GlobePainter({required this.t, required this.accent, required this.line});

  static const _meridianCount = 5;
  static const _latitudeCount = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Soft glow behind the globe.
    final glowPaint = Paint()
      ..shader = RadialGradient(colors: [accent.withValues(alpha: 0.16), accent.withValues(alpha: 0)]).createShader(
        Rect.fromCircle(center: center, radius: radius * 1.6),
      );
    canvas.drawCircle(center, radius * 1.6, glowPaint);

    final outline = Paint()
      ..color = line.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawCircle(center, radius, outline);

    // Meridian lines (longitude): each is an ellipse whose horizontal radius traces
    // cos(angle) as it "rotates" -- the classic 2D trick for faking a wireframe sphere.
    // The far side (cos < 0) is drawn dimmer to suggest it's behind the globe.
    for (var i = 0; i < _meridianCount; i++) {
      final angle = t * 2 * math.pi + i * math.pi / _meridianCount;
      final scaleX = math.cos(angle);
      final isFront = scaleX.abs() < 0.02 ? true : scaleX > 0;
      final paint = Paint()
        ..color = (isFront ? accent : accent.withValues(alpha: 0.35)).withValues(alpha: isFront ? 0.85 : 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawOval(
        Rect.fromCenter(center: center, width: (radius * scaleX.abs() * 2).clamp(0.5, radius * 2), height: radius * 2),
        paint,
      );
    }

    // Latitude lines (flattened static ellipses) -- gives the sphere a "ruled" look
    // without needing to animate vertically too.
    for (var i = 1; i <= _latitudeCount; i++) {
      final f = i / (_latitudeCount + 1); // 0..1 top to bottom
      final dy = (f - 0.5) * 2 * radius;
      final rowRadius = math.sqrt((radius * radius - dy * dy).clamp(0, radius * radius));
      final paint = Paint()
        ..color = line.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawOval(Rect.fromCenter(center: center + Offset(0, dy), width: rowRadius * 2, height: rowRadius * 2 * 0.28), paint);
    }

    // A couple of slowly orbiting "activity" dots, purely decorative.
    for (var i = 0; i < 2; i++) {
      final angle = t * 2 * math.pi * (i.isEven ? 1 : -1.3) + i * math.pi;
      final dotX = center.dx + math.cos(angle) * radius * 0.72;
      final dotY = center.dy + math.sin(angle * 0.6) * radius * 0.5;
      final depth = (math.cos(angle) + 1) / 2; // 0 (back) .. 1 (front)
      canvas.drawCircle(Offset(dotX, dotY), 2.2, Paint()..color = accent.withValues(alpha: 0.35 + depth * 0.5));
    }
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) => oldDelegate.t != t;
}
