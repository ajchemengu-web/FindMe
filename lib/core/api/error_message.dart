import 'package:dio/dio.dart';

import 'api_exception.dart';

/// Turns any caught error into a message that actually reflects what went wrong,
/// instead of every screen's catch-all defaulting to a generic "invalid credentials"
/// or "something went wrong" text regardless of the real cause. [fallback] is used
/// only for errors that aren't an [ApiException] or [DioException] -- callers should
/// pass something specific to what they were trying to do.
///
/// Backend down/cold-starting (Render's free tier spins down after ~15min idle, and a
/// woken instance can take 30-60s to answer its first request) surfaces as a
/// DioExceptionType.connectionTimeout/receiveTimeout here, not a generic failure --
/// worth knowing at a glance rather than looking identical to a typo'd password.
String describeError(Object error, {required String fallback}) {
  if (error is ApiException) return error.message;

  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return "The server is taking a while to respond -- it may be waking up after being idle. Please try again in a few seconds.";
      case DioExceptionType.connectionError:
        return "Couldn't reach the server. Check your internet connection and try again.";
      case DioExceptionType.badCertificate:
        return "Couldn't establish a secure connection to the server.";
      case DioExceptionType.cancel:
        return "Request cancelled.";
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return "Something went wrong talking to the server. Please try again.";
    }
  }

  return fallback;
}
