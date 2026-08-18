import '../../core/api/api_client.dart';
import '../../core/api/api_exception.dart';
import '../../core/api/token_store.dart';
import '../../core/models/user.dart';
import '../../core/phone.dart';

class SignUpInput {
  final String email;
  final String username;
  final String phone;
  final String password;
  SignUpInput({required this.email, required this.username, required this.phone, required this.password});
}

/// Ported 1:1 from findme_app/lib/auth.tsx's non-React logic (the request-building and
/// token-storage side; state/lifecycle lives in AuthController instead of a Context).
class AuthRepository {
  final _api = ApiClient.instance;

  Future<AppUser?> loadProfile() async {
    try {
      final json = await _api.request<Map<String, dynamic>>('/auth/me');
      return json != null ? AppUser.fromJson(json) : null;
    } catch (_) {
      return null;
    }
  }

  /// Throws [ApiException]-derived message via the caller; returns the loaded profile.
  Future<AppUser?> signUp(SignUpInput input) async {
    final tokens = await _api.request<Map<String, dynamic>>(
      '/auth/signup',
      method: 'POST',
      auth: false,
      body: {
        'email': input.email,
        'username': input.username,
        'phone': normalizePhone(input.phone),
        'display_name': input.username,
        'password': input.password,
      },
    );
    await TokenStore.instance.set(
      accessToken: tokens!['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );
    return loadProfile();
  }

  Future<AppUser?> signIn(String identifier, String password) async {
    final trimmed = normalizePhone(identifier.trim());
    final tokens = await _api.request<Map<String, dynamic>>(
      '/auth/login',
      method: 'POST',
      auth: false,
      body: {'identifier': trimmed, 'password': password},
    );
    await TokenStore.instance.set(
      accessToken: tokens!['access_token'] as String,
      refreshToken: tokens['refresh_token'] as String,
    );
    return loadProfile();
  }

  Future<void> signOut() async {
    final refreshToken = await TokenStore.instance.getRefreshToken();
    if (refreshToken != null) {
      try {
        await _api.request('/auth/logout', method: 'POST', body: {'refresh_token': refreshToken});
      } catch (_) {}
    }
    await TokenStore.instance.clear();
  }

  /// Step 1 of phone verification. Returns an error message on failure, null on success.
  Future<String?> sendPhoneVerification(String phone) async {
    try {
      await _api.request('/auth/phone/send-otp', method: 'POST', body: {'phone': normalizePhone(phone)});
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to send verification code.';
    }
  }

  /// Step 2. On success the backend sets phone/phone_verified directly -- call
  /// AuthController.refreshProfile() after this to pick up the change locally.
  Future<String?> confirmPhoneVerification(String phone, String code) async {
    try {
      await _api.request<Map<String, dynamic>>(
        '/auth/phone/confirm-otp',
        method: 'POST',
        body: {'phone': normalizePhone(phone), 'code': code.trim()},
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to verify code.';
    }
  }

  Future<AppUser> updateProfile({String? displayName, String? avatarUrl}) async {
    final json = await _api.request<Map<String, dynamic>>(
      '/auth/me',
      method: 'PATCH',
      body: {
        if (displayName != null) 'display_name': displayName,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      },
    );
    return AppUser.fromJson(json!);
  }
}
