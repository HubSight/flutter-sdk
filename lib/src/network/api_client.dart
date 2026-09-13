import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../security/device_info_collector.dart';
import '../security/secure_storage.dart';
import 'auth_interceptor.dart';
import 'error_codes.dart';
import 'exceptions.dart';

/// Central HTTP API Client for HubSight Gateway.
class HubSightApiClient {
  final Dio _dio;
  final HubSightSecureStorage _storage;
  String _baseUrl;
  String _apiKey;
  HubSightDeviceMetadata? _deviceMetadata;

  HubSightApiClient({
    required String baseUrl,
    required String apiKey,
    required HubSightSecureStorage storage,
    HubSightDeviceMetadata? deviceMetadata,
    void Function()? onSessionExpired,
    void Function(MaintenanceException exception)? onMaintenance,
    Dio? customDio,
  })  : _baseUrl = baseUrl,
        _apiKey = apiKey.isNotEmpty ? apiKey : 'hs_mob_client_default',
        _storage = storage,
        _deviceMetadata = deviceMetadata,
        _dio = customDio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
                headers: {
                  'Content-Type': 'application/json',
                  'Accept': 'application/json',
                },
              ),
            ) {
    _dio.interceptors.add(
      HubSightAuthInterceptor(
        dio: _dio,
        storage: _storage,
        getApiKey: () => _apiKey,
        getDeviceMetadata: () => _deviceMetadata,
        onSessionExpired: onSessionExpired,
        onMaintenance: onMaintenance,
      ),
    );
  }

  Dio get rawDio => _dio;
  String get baseUrl => _baseUrl;
  String get apiKey => _apiKey;
  HubSightDeviceMetadata? get deviceMetadata => _deviceMetadata;

  void updateConfig(HubSightAppConfig config) {
    _baseUrl = config.urls.apiBaseUrl;
    _apiKey =
        config.apiKey.isNotEmpty ? config.apiKey : 'hs_mob_client_default';
    _dio.options.baseUrl = _baseUrl;
  }

  void updateDeviceMetadata(HubSightDeviceMetadata metadata) {
    _deviceMetadata = metadata;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _wrapRequest(
      () => _dio.get(path, queryParameters: queryParameters, options: options),
    );
  }

  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _wrapRequest(
      () => _dio.post(path,
          data: data, queryParameters: queryParameters, options: options),
    );
  }

  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _wrapRequest(
      () => _dio.put(path,
          data: data, queryParameters: queryParameters, options: options),
    );
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _wrapRequest(
      () => _dio.patch(path,
          data: data, queryParameters: queryParameters, options: options),
    );
  }

  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    return _wrapRequest(
      () => _dio.delete(path,
          data: data, queryParameters: queryParameters, options: options),
    );
  }

  Future<T> _wrapRequest<T>(Future<Response<T>> Function() request) async {
    try {
      final res = await request();
      return res.data as T;
    } on DioException catch (e) {
      if (e.error is HubSightException) {
        throw e.error as HubSightException;
      }

      final response = e.response;
      Map<String, dynamic>? errorMap;
      if (response != null) {
        if (response.data is Map) {
          errorMap = Map<String, dynamic>.from(response.data as Map);
        } else if (response.data is String) {
          try {
            final decoded = jsonDecode(response.data as String);
            if (decoded is Map) {
              errorMap = Map<String, dynamic>.from(decoded);
            }
          } catch (_) {}
        }
      }

      if (errorMap != null) {
        final code = HubSightErrorCode.fromBackendCode(
          errorMap['code'] as String?,
          response?.statusCode,
        );
        final devMsg = errorMap['message_en'] as String? ??
            errorMap['message'] as String? ??
            'API returned error: ${code.wireCode}';

        if (response?.statusCode == 401 || response?.statusCode == 403) {
          throw HubSightAuthException(
            code: code,
            statusCode: response?.statusCode,
            developerMessage: devMsg,
            rawResponse: errorMap,
            details: errorMap['errors'] ?? errorMap['details'],
          );
        }

        throw HubSightApiException(
          code: code,
          statusCode: response?.statusCode,
          developerMessage: devMsg,
          rawResponse: errorMap,
          details: errorMap['errors'] ?? errorMap['details'],
        );
      }

      HubSightErrorCode netCode = HubSightErrorCode.networkUnknown;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        netCode = HubSightErrorCode.networkTimeout;
      } else if (e.type == DioExceptionType.connectionError) {
        netCode = HubSightErrorCode.networkUnreachable;
      } else if (e.type == DioExceptionType.cancel) {
        netCode = HubSightErrorCode.networkCanceled;
      }

      final detail = e.message ??
          (e.error != null
              ? e.error.toString()
              : 'Network transport failure (${e.type})');
      throw HubSightNetworkException(
        code: netCode,
        developerMessage: detail,
        statusCode: response?.statusCode,
      );
    }
  }
}
