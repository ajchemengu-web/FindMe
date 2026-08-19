import '../../core/api/api_client.dart';
import '../../core/models/models.dart';
import '../devices/devices_repository.dart';

class ProfileLookup {
  final String id;
  final String username;
  final String? displayName;
  ProfileLookup({required this.id, required this.username, required this.displayName});

  factory ProfileLookup.fromJson(Map<String, dynamic> j) => ProfileLookup(
        id: j['id'] as String,
        username: j['username'] as String,
        displayName: j['display_name'] as String?,
      );
}

class MyConsents {
  final List<Consent> incoming;
  final List<Consent> outgoingPending;
  final List<Consent> active;
  MyConsents({required this.incoming, required this.outgoingPending, required this.active});
}

/// Ported 1:1 from findme_app/lib/consent.ts.
class ConsentRepository {
  final _api = ApiClient.instance;

  /// Narrow lookup for the "add someone" flow -- GET /auth/lookup returns
  /// id/username/display_name only, never location/device data.
  Future<ProfileLookup?> findProfileForInvite(String contact) async {
    final json = await _api.request<Map<String, dynamic>>('/auth/lookup', params: {'contact': contact});
    return json != null ? ProfileLookup.fromJson(json) : null;
  }

  Future<void> requestConsent(String grantorId, {required String scope, String? expiresAt}) => _api.request(
        '/consents',
        method: 'POST',
        body: {'grantor_id': grantorId, 'scope': scope, 'expires_at': expiresAt},
      );

  Future<void> respondToRequest(String consentId, String decision) =>
      _api.request('/consents/$consentId', method: 'PATCH', body: {'status': decision});

  Future<void> revokeConsent(String consentId) => _api.request('/consents/$consentId/revoke', method: 'POST');

  Future<List<Device>> fetchVisibleDevices() => DevicesRepository().listDevices();

  Future<MyConsents> fetchMyConsents() async {
    final json = await _api.request<Map<String, dynamic>>('/consents');
    List<Consent> parse(String key) =>
        ((json![key] as List<dynamic>?) ?? []).map((e) => Consent.fromJson(e as Map<String, dynamic>)).toList();
    return MyConsents(incoming: parse('incoming'), outgoingPending: parse('outgoing_pending'), active: parse('active'));
  }
}
