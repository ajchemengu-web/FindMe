import '../../core/api/api_client.dart';
import '../../core/models/models.dart';

/// Ported 1:1 from findme_app/lib/alerts.ts.
class AlertsRepository {
  final _api = ApiClient.instance;

  Future<List<Alert>> fetchAlerts({int limit = 50}) async {
    final json = await _api.request<List<dynamic>>('/alerts', params: {'limit': limit});
    return (json ?? []).map((e) => Alert.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Alert> markAlertRead(String id) async {
    final json = await _api.request<Map<String, dynamic>>('/alerts/$id', method: 'PATCH', body: {'read': true});
    return Alert.fromJson(json!);
  }
}
