import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Ported 1:1 from findme_app/lib/api.ts's `tokenStore`. Same key names, so a device
/// migrating between the RN and Flutter builds during the transition period would (in
/// principle) share stored tokens -- not required, but free to keep.
class TokenStore {
  TokenStore._();
  static final TokenStore instance = TokenStore._();

  static const _accessTokenKey = 'findme:access_token';
  static const _refreshTokenKey = 'findme:refresh_token';

  final _storage = const FlutterSecureStorage();

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> set({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
