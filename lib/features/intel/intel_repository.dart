import '../../core/api/api_client.dart';
import '../../core/models/models.dart';

class WatchTopic {
  final String id;
  final String topicType; // region | company | keyword
  final String value;
  final DateTime createdAt;
  WatchTopic({required this.id, required this.topicType, required this.value, required this.createdAt});

  factory WatchTopic.fromJson(Map<String, dynamic> j) => WatchTopic(
        id: j['id'] as String,
        topicType: j['topic_type'] as String,
        value: j['value'] as String,
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// Ported 1:1 from findme_app/lib/intel.ts.
class IntelRepository {
  final _api = ApiClient.instance;

  Future<List<NewsItem>> fetchNewsItems({String? category, int limit = 40}) async {
    final json = await _api.request<List<dynamic>>('/news', params: {'category': category, 'limit': limit});
    return (json ?? []).map((e) => NewsItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<WatchTopic>> fetchWatchTopics() async {
    final json = await _api.request<List<dynamic>>('/watch-topics');
    return (json ?? []).map((e) => WatchTopic.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addWatchTopic(String topicType, String value) =>
      _api.request('/watch-topics', method: 'POST', body: {'topic_type': topicType, 'value': value.trim()});

  Future<void> removeWatchTopic(String id) => _api.request('/watch-topics/$id', method: 'DELETE');
}
