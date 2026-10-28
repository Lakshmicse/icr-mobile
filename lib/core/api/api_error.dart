import 'package:dio/dio.dart';

/// An API refusal or a transport failure, worded for the person using the app.
///
/// The API's error body is `{ statusCode, message, path, timestamp, code? }`,
/// where `message` is a sentence already in the caller's language, or a list
/// of them for a validation failure.
class ApiError implements Exception {
  ApiError(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  bool get isOffline => statusCode == null;

  static ApiError from(Object error) {
    if (error is ApiError) return error;
    if (error is DioException) {
      final response = error.response;
      if (response == null) {
        return ApiError("Can't reach ICR right now. Check your connection and try again.");
      }
      final data = response.data;
      String? message;
      String? code;
      if (data is Map) {
        final raw = data['message'];
        if (raw is String) message = raw;
        if (raw is List && raw.isNotEmpty) message = raw.join('\n');
        if (data['code'] is String) code = data['code'] as String;
      }
      if (response.statusCode == 429) {
        message = 'Too many requests. Wait a minute and try again.';
      }
      return ApiError(
        message ?? 'Something went wrong (${response.statusCode}). Try again.',
        statusCode: response.statusCode,
        code: code,
      );
    }
    return ApiError('Something went wrong. Try again.');
  }

  @override
  String toString() => message;
}
