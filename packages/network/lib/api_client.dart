import 'package:dio/dio.dart';

import 'interceptors.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio() {
    _dio.interceptors.addAll(interceptors);
  }

  final Dio _dio;

  Dio get dio => _dio;
}
