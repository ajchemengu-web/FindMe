import '../../core/api/api_client.dart';
import '../../core/models/models.dart';

/// Ported 1:1 from findme_app/lib/map.ts.
class MapRepository {
  final _api = ApiClient.instance;

  Future<List<VisibleDeviceLocation>> fetchVisibleDeviceLocations() async {
    final json = await _api.request<List<dynamic>>('/map/devices');
    return (json ?? []).map((e) => VisibleDeviceLocation.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ThreatZoneGeo>> fetchThreatZonesGeo() async {
    final json = await _api.request<List<dynamic>>('/map/threat-zones');
    return (json ?? []).map((e) => ThreatZoneGeo.fromJson(e as Map<String, dynamic>)).toList();
  }
}
