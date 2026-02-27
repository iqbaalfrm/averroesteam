import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import 'auth_service.dart';

class ApiDio {
  const ApiDio._();

  static Dio create({bool attachAuthToken = true}) {
    final Dio dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        headers: <String, dynamic>{
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          if (attachAuthToken) {
            final String? token = AuthService.instance.token;
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          if (!kReleaseMode) {
            debugPrint(
              '[API] ${options.method} ${options.baseUrl}${options.path}',
            );
          }
          handler.next(options);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) {
          if (!kReleaseMode) {
            debugPrint(
              '[API][ERR] ${error.requestOptions.method} '
              '${error.requestOptions.uri} '
              'type=${error.type} status=${error.response?.statusCode}',
            );
          }
          handler.next(error);
        },
      ),
    );

    return dio;
  }
}
