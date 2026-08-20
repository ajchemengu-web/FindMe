import 'dart:math' as math;
import 'dart:ui';

/// Orthographic sphere projection, ported from findme_situation_room_mockup.html's
/// `project()` (the globe's only real geometry) via the Expo app's lib/globeMath.ts.

/// Fixed camera tilt (mockup's `phi`), degrees. Only `lambda` (rotation) ever animates.
const double kGlobeTiltDeg = -16;

class Projected {
  final double x;
  final double y;
  final double z;
  final bool visible;
  const Projected(this.x, this.y, this.z, this.visible);
}

Projected projectPoint(double lon, double lat, double lambdaDeg, double phiDeg, double cx, double cy, double r) {
  final l0 = lambdaDeg * math.pi / 180;
  final p0 = phiDeg * math.pi / 180;
  final l = lon * math.pi / 180 - l0;
  final p = lat * math.pi / 180;
  final cosp = math.cos(p);
  final sinp = math.sin(p);
  final x = cosp * math.sin(l);
  final y = math.cos(p0) * sinp - math.sin(p0) * cosp * math.cos(l);
  final z = math.sin(p0) * sinp + math.cos(p0) * cosp * math.cos(l);
  return Projected(cx + r * x, cy - r * y, z, z > 0.02);
}

void _traceParallel(Path path, double lat, double lambdaDeg, double phiDeg, double cx, double cy, double r) {
  var started = false;
  for (var lon = -180.0; lon <= 180.0; lon += 3) {
    final p = projectPoint(lon, lat, lambdaDeg, phiDeg, cx, cy, r);
    if (p.visible) {
      if (started) {
        path.lineTo(p.x, p.y);
      } else {
        path.moveTo(p.x, p.y);
        started = true;
      }
    } else {
      started = false;
    }
  }
}

void _traceMeridian(Path path, double lon, double lambdaDeg, double phiDeg, double cx, double cy, double r) {
  var started = false;
  for (var lat = -90.0; lat <= 90.0; lat += 3) {
    final p = projectPoint(lon, lat, lambdaDeg, phiDeg, cx, cy, r);
    if (p.visible) {
      if (started) {
        path.lineTo(p.x, p.y);
      } else {
        path.moveTo(p.x, p.y);
        started = true;
      }
    } else {
      started = false;
    }
  }
}

/// Lat/lon grid every 30deg -- the equator is traced separately (buildEquatorPath) so
/// it can be stroked brighter.
Path buildGraticulePath(double lambdaDeg, double phiDeg, double cx, double cy, double r) {
  final path = Path();
  for (var lat = -60.0; lat <= 60.0; lat += 30) {
    _traceParallel(path, lat, lambdaDeg, phiDeg, cx, cy, r);
  }
  for (var lon = -150.0; lon <= 180.0; lon += 30) {
    _traceMeridian(path, lon, lambdaDeg, phiDeg, cx, cy, r);
  }
  return path;
}

Path buildEquatorPath(double lambdaDeg, double phiDeg, double cx, double cy, double r) {
  final path = Path();
  _traceParallel(path, 0, lambdaDeg, phiDeg, cx, cy, r);
  return path;
}

class LandDotPaths {
  final Path near;
  final Path far;
  const LandDotPaths(this.near, this.far);
}

const double _landDotRadius = 1.3;
const double _nearZThreshold = 0.32;

/// Batches every visible land dot into two Paths (near/far) instead of ~1,100 individual
/// draw calls -- one filled path of circles is far cheaper to draw each frame than that
/// many separate canvas.drawCircle calls.
LandDotPaths buildLandDotPaths(List<List<double>> dots, double lambdaDeg, double phiDeg, double cx, double cy, double r) {
  final near = Path();
  final far = Path();
  for (final dot in dots) {
    final p = projectPoint(dot[0], dot[1], lambdaDeg, phiDeg, cx, cy, r);
    if (!p.visible) continue;
    final rect = Rect.fromCircle(center: Offset(p.x, p.y), radius: _landDotRadius);
    if (p.z > _nearZThreshold) {
      near.addOval(rect);
    } else {
      far.addOval(rect);
    }
  }
  return LandDotPaths(near, far);
}
