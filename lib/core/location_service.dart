import 'package:geolocator/geolocator.dart';

/// New capability -- neither findme_app nor this port ever actually called
/// POST /devices/{id}/pings before now. lib/devices.ts's reportLocation() existed only
/// as an unused client wrapper; nothing collected a device's own coordinates.
///
/// Returns null (never throws) on permission denial, disabled location services, or a
/// timeout -- callers show a clear message rather than crashing.
Future<Position?> getCurrentLocationOrNull({Duration timeLimit = const Duration(seconds: 15)}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      return null;
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: LocationAccuracy.high, timeLimit: timeLimit),
    );
  } catch (_) {
    return null;
  }
}
