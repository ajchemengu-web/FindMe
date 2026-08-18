import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'token_store.dart';

/// Ported 1:1 from findme_app/lib/api.ts. Same base-URL env-var convention (now a
/// --dart-define instead of an Expo env file), same single-flight refresh-on-401
/// behavior, same error-message extraction from FastAPI's {"detail": ...} shape.
///
/// Base URL: pass --dart-define=API_BASE_URL=https://your-backend at build/run time.
/// Defaults to http://localhost:8000, which only works from a web build running on the
/// same machine as the backend, or an iOS simulator -- an Android emulator needs
/// 10.0.2.2 instead of localhost, and a physical device needs your machine's LAN IP or
/// a publicly reachable URL.
const _apiBaseUrlEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
final String apiBaseUrl = _apiBaseUrlEnv.isNotEmpty
    ? _apiBaseUrlEnv.replaceAll(RegExp(r'/$'), '')
    : 'http://localhost:8000';

class ApiClient {
  ApiClient._() {
    if (_apiBaseUrlEnv.isEmpty) {
      // ignore: avoid_print
      print(
        'API_BASE_URL is not set -- pass --dart-define=API_BASE_URL=... pointed at '
        'your findme_backend_fastapi instance. Falling back to $apiBaseUrl.',
      );
    }
  }

  static final ApiClient instance = ApiClient._();

  final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl, validateStatus: (_) => true));

  Future<bool>? _refreshInFlight;

  /// Rotates the refresh token exactly once, shared across any requests that hit a 401
  /// at the same time. Mirrors lib/api.ts's `refreshAccessToken` single-flight pattern.
  Future<bool> _refreshAccessToken() {
    return _refreshInFlight ??= () async {
      try {
        final refreshToken = await TokenStore.instance.getRefreshToken();
        if (refreshToken == null) return false;
        final res = await _dio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
          options: Options(headers: {'Content-Type': 'application/json'}),
        );
        if (res.statusCode == null || res.statusCode! < 200 || res.statusCode! >= 300) {
          await TokenStore.instance.clear();
          return false;
        }
        final data = res.data as Map<String, dynamic>;
        await TokenStore.instance.set(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );
        return true;
      } catch (_) {
        return false;
      }
    }()
        .whenComplete(() => _refreshInFlight = null);
  }

  String _extractErrorMessage(dynamic body, String fallback) {
    if (body is Map && body.containsKey('detail')) {
      final detail = body['detail'];
      if (detail is String) return detail;
      if (detail is List) {
        return detail
            .map((d) => (d is Map && d.containsKey('msg')) ? d['msg'].toString() : jsonEncode(d))
            .join('; ');
      }
      if (detail is Map) return jsonEncode(detail);
    }
    return fallback;
  }

  /// Low-level request helper. Returns decoded JSON (or null for 204s), throws
  /// [ApiException] on any non-2xx response after a refresh attempt (for 401s).
  Future<T?> request<T>(
    String path, {
    String method = 'GET',
    Object? body,
    Map<String, dynamic>? params,
    bool auth = true,
    bool isRetry = false,
  }) async {
    final headers = <String, String>{};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (auth) {
      final token = await TokenStore.instance.getAccessToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final res = await _dio.request<dynamic>(
      path,
      queryParameters: params,
      data: body,
      options: Options(method: method, headers: headers, responseType: ResponseType.plain),
    );

    if (res.statusCode == 401 && auth && !isRetry) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        return request<T>(path, method: method, body: body, params: params, auth: auth, isRetry: true);
      }
    }

    if (res.statusCode == 204) return null;

    final text = res.data as String?;
    final json = (text != null && text.isNotEmpty) ? jsonDecode(text) : null;

    final ok = res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
    if (!ok) {
      throw ApiException(res.statusCode ?? 0, _extractErrorMessage(json, 'Request failed (${res.statusCode})'));
    }

    return json as T?;
  }

  /// Multipart upload helper (avatar / intel-photo). Takes raw bytes rather than a
  /// file:// URI (unlike lib/api.ts's apiUpload) so it works identically on web, where
  /// there is no local filesystem path -- pass `XFile.readAsBytes()` from image_picker.
  Future<T?> upload<T>(String path, {required List<int> bytes, required String filename, required String mimeType}) async {
    final token = await TokenStore.instance.getAccessToken();
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse(mimeType)),
    });

    final res = await _dio.post<dynamic>(
      path,
      data: form,
      options: Options(
        headers: token != null ? {'Authorization': 'Bearer $token'} : null,
        responseType: ResponseType.plain,
      ),
    );

    final text = res.data as String?;
    final json = (text != null && text.isNotEmpty) ? jsonDecode(text) : null;

    final ok = res.statusCode != null && res.statusCode! >= 200 && res.statusCode! < 300;
    if (!ok) {
      throw ApiException(res.statusCode ?? 0, _extractErrorMessage(json, 'Upload failed (${res.statusCode})'));
    }
    return json as T?;
  }
}
