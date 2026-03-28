import 'package:dio/dio.dart';
import 'package:get/get.dart';

class ApiErrorMapper {
  const ApiErrorMapper._();

  static String humanize(DioException error, {String? fallback}) {
    final type = error.type;
    if (type == DioExceptionType.connectionError ||
        type == DioExceptionType.connectionTimeout ||
        type == DioExceptionType.receiveTimeout ||
        type == DioExceptionType.sendTimeout) {
      return 'network_error'.tr;
    }

    final data = error.response?.data;
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }
    return fallback ?? 'general_error'.tr;
  }
}
