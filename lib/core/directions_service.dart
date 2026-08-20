import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Place search + turn-by-turn driving directions, powering the Map tab's
/// Google-Maps-style "search a place, get directions from here" bar.
///
/// Deliberately NOT Google Places/Directions -- this app's map (map_screen.dart)
/// already runs on free CartoDB tiles via flutter_map instead of the Google Maps SDK,
/// specifically to avoid a Google Cloud API key dependency. Matching that choice here:
/// Nominatim (OpenStreetMap's geocoder) for search, OSRM (Open Source Routing Machine)
/// for routing -- both free, keyless, called directly from the client. Nominatim's
/// usage policy (https://operations.osmfoundation.org/policies/nominatim/) requires a
/// descriptive User-Agent and caps casual use at ~1 req/s, which the search bar's
/// debounce already respects; OSRM's public demo server is documented as "light usage,
/// not for production traffic at scale" -- exactly this app's current stage. A real
/// wide-audience rollout would self-host both rather than lean on the public instances.
class DirectionsService {
  DirectionsService._();
  static final DirectionsService instance = DirectionsService._();

  final Dio _dio = Dio(BaseOptions(
    headers: {'User-Agent': 'FindMe/1.0 (safety app; contact via app store listing)'},
    validateStatus: (_) => true,
  ));

  Future<List<PlacePrediction>> searchPlaces(String query, {LatLng? near}) async {
    if (query.trim().length < 2) return [];
    final res = await _dio.get('https://nominatim.openstreetmap.org/search', queryParameters: {
      'q': query,
      'format': 'jsonv2',
      'limit': 6,
      if (near != null) 'viewbox': '${near.longitude - 0.5},${near.latitude + 0.5},${near.longitude + 0.5},${near.latitude - 0.5}',
      if (near != null) 'bounded': 0, // bias, don't hard-restrict -- searching somewhere else entirely should still work
    });
    if (res.statusCode != 200 || res.data is! List) {
      throw Exception('Place search failed (${res.statusCode}).');
    }
    return (res.data as List)
        .map((e) => PlacePrediction(
              lat: double.parse(e['lat'] as String),
              lon: double.parse(e['lon'] as String),
              displayName: e['display_name'] as String,
            ))
        .toList();
  }

  Future<DirectionsResult> getDirections(LatLng origin, PlacePrediction destination) async {
    final res = await _dio.get(
      'https://router.project-osrm.org/route/v1/driving/'
      '${origin.longitude},${origin.latitude};${destination.lon},${destination.lat}',
      queryParameters: {'overview': 'full', 'geometries': 'geojson', 'steps': 'true'},
    );
    if (res.statusCode != 200 || res.data?['code'] != 'Ok' || (res.data?['routes'] as List?)?.isEmpty != false) {
      throw Exception('Directions failed: ${res.data?['message'] ?? res.data?['code'] ?? res.statusCode}.');
    }

    final route = res.data['routes'][0] as Map<String, dynamic>;
    final leg = (route['legs'] as List).first as Map<String, dynamic>;
    final coords = (route['geometry']['coordinates'] as List)
        .map((c) => LatLng((c as List)[1] as double, c[0] as double))
        .toList();

    return DirectionsResult(
      route: coords,
      distanceMeters: (route['distance'] as num).toDouble(),
      durationSeconds: (route['duration'] as num).toDouble(),
      destination: LatLng(destination.lat, destination.lon),
      destinationName: destination.displayName,
      steps: (leg['steps'] as List).map((s) => _stepFrom(s as Map<String, dynamic>)).toList(),
    );
  }

  RouteStep _stepFrom(Map<String, dynamic> s) {
    final maneuver = s['maneuver'] as Map<String, dynamic>;
    final type = maneuver['type'] as String;
    final modifier = maneuver['modifier'] as String?;
    final name = (s['name'] as String?)?.trim();
    final roadPart = (name != null && name.isNotEmpty) ? ' onto $name' : '';

    final instruction = switch (type) {
      'depart' => 'Head ${_directionText(modifier)}$roadPart',
      'arrive' => 'Arrive at your destination',
      'roundabout' || 'rotary' => 'At the roundabout, take the exit$roadPart',
      'turn' => 'Turn ${_directionText(modifier)}$roadPart',
      'new name' || 'continue' => 'Continue$roadPart',
      'merge' => 'Merge${_directionText(modifier, prefix: ' ')}$roadPart',
      'fork' => 'Keep ${_directionText(modifier)} at the fork$roadPart',
      'end of road' => 'Turn ${_directionText(modifier)} at the end of the road$roadPart',
      'ramp' || 'on ramp' || 'off ramp' => 'Take the ramp$roadPart',
      _ => 'Continue$roadPart',
    };

    return RouteStep(
      instruction: instruction,
      distanceMeters: (s['distance'] as num).toDouble(),
      durationSeconds: (s['duration'] as num).toDouble(),
    );
  }

  String _directionText(String? modifier, {String prefix = ''}) {
    if (modifier == null) return 'straight ahead';
    final text = switch (modifier) {
      'left' => 'left',
      'right' => 'right',
      'slight left' => 'slightly left',
      'slight right' => 'slightly right',
      'sharp left' => 'sharp left',
      'sharp right' => 'sharp right',
      'uturn' => 'around (U-turn)',
      _ => 'straight ahead',
    };
    return '$prefix$text';
  }
}

class PlacePrediction {
  final double lat;
  final double lon;
  final String displayName;
  const PlacePrediction({required this.lat, required this.lon, required this.displayName});
}

class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  const RouteStep({required this.instruction, required this.distanceMeters, required this.durationSeconds});
}

class DirectionsResult {
  final List<LatLng> route;
  final double distanceMeters;
  final double durationSeconds;
  final LatLng destination;
  final String destinationName;
  final List<RouteStep> steps;
  const DirectionsResult({
    required this.route,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.destination,
    required this.destinationName,
    required this.steps,
  });

  String get distanceText => distanceMeters >= 1000 ? '${(distanceMeters / 1000).toStringAsFixed(1)} km' : '${distanceMeters.round()} m';

  String get durationText {
    final totalMinutes = (durationSeconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}
