import '../../core/api/api_client.dart';
import '../../core/models/models.dart';

class CreateDeviceInput {
  final String nickname;
  final String? deviceType;
  final String? platform;
  final bool? isSelfOwned;
  final String? pushToken;
  CreateDeviceInput({required this.nickname, this.deviceType, this.platform, this.isSelfOwned, this.pushToken});

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        if (deviceType != null) 'device_type': deviceType,
        if (platform != null) 'platform': platform,
        if (isSelfOwned != null) 'is_self_owned': isSelfOwned,
        if (pushToken != null) 'push_token': pushToken,
      };
}

class LocationOut {
  final DateTime recordedAt;
  final double lon;
  final double lat;
  final double? accuracyM;
  final num? batteryPct;
  final String precisionLevel;

  LocationOut({required this.recordedAt, required this.lon, required this.lat, required this.accuracyM, required this.batteryPct, required this.precisionLevel});

  factory LocationOut.fromJson(Map<String, dynamic> j) => LocationOut(
        recordedAt: DateTime.parse(j['recorded_at'] as String),
        lon: (j['lon'] as num).toDouble(),
        lat: (j['lat'] as num).toDouble(),
        accuracyM: (j['accuracy_m'] as num?)?.toDouble(),
        batteryPct: j['battery_pct'] as num?,
        precisionLevel: j['precision_level'] as String,
      );
}

/// Ported 1:1 from findme_app/lib/devices.ts.
class DevicesRepository {
  final _api = ApiClient.instance;

  Future<List<Device>> listDevices() async {
    final json = await _api.request<List<dynamic>>('/devices');
    return (json ?? []).map((e) => Device.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Device> createDevice(CreateDeviceInput input) async {
    final json = await _api.request<Map<String, dynamic>>('/devices', method: 'POST', body: input.toJson());
    return Device.fromJson(json!);
  }

  Future<Device> updateDevice(String deviceId, Map<String, dynamic> input) async {
    final json = await _api.request<Map<String, dynamic>>('/devices/$deviceId', method: 'PATCH', body: input);
    return Device.fromJson(json!);
  }

  Future<void> deleteDevice(String deviceId) => _api.request('/devices/$deviceId', method: 'DELETE');

  Future<LocationOut> reportLocation(String deviceId, {required double lat, required double lon, double? accuracyM, num? batteryPct}) async {
    final json = await _api.request<Map<String, dynamic>>(
      '/devices/$deviceId/pings',
      method: 'POST',
      body: {
        'lat': lat,
        'lon': lon,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (batteryPct != null) 'battery_pct': batteryPct,
      },
    );
    return LocationOut.fromJson(json!);
  }

  Future<List<LocationOut>> getDeviceLocations(String deviceId, {int limit = 50}) async {
    final json = await _api.request<List<dynamic>>('/devices/$deviceId/locations', params: {'limit': limit});
    return (json ?? []).map((e) => LocationOut.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Geofence>> fetchGeofencesGeo(String deviceId) async {
    final json = await _api.request<List<dynamic>>('/devices/$deviceId/geofences');
    return (json ?? []).map((e) => Geofence.fromJson(e as Map<String, dynamic>)).where((g) => g.active).toList();
  }

  Future<void> createGeofence(String deviceId, {required String name, required double lon, required double lat, required int radiusM}) =>
      _api.request('/devices/$deviceId/geofences', method: 'POST', body: {'name': name, 'lon': lon, 'lat': lat, 'radius_m': radiusM});
}
