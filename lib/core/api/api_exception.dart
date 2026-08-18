/// Ported 1:1 from findme_app/lib/api.ts's `ApiError`.
class ApiException implements Exception {
  final int status;
  final String message;

  ApiException(this.status, this.message);

  @override
  String toString() => message;
}
