import 'dart:async';
import 'package:dio/dio.dart';
import '../security/device_info_collector.dart';
import '../security/secure_storage.dart';
import 'endpoints.dart';
import 'exceptions.dart';

/// Interceptor with Atomic Token Refresh Mutex Queue and Kill-Switch Handling.
class HubSightAuthInterceptor extends QueuedInterceptor {
  final Dio _dio;
  final HubSightSecureStorage _storage;
  final String Function() _getApiKey;
  final HubSightDeviceMetadata? Function() _getDeviceMetadata;
  final void Function()? onSessionExpired;
  final void Function(MaintenanceException exception)? onMaintenance;

  bool _isRefreshing = false;
  final List<Completer<String?>> _refreshQueue = [];

  HubSightAuthInterceptor({
    required Dio dio,
    required HubSightSecureStorage storage,
    required String Function() getApiKey,
    required HubSightDeviceMetadata? Function() getDeviceMetadata,
    this.onSessionExpired,
    this.onMaintenance,
  })  : _dio = dio,
        _storage = storage,
        _getApiKey = getApiKey,
        _getDeviceMetadata = getDeviceMetadata;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // 1. Mandatory App API Key
    final apiKey = _getApiKey();
    if (apiKey.isNotEmpty) {
      options.headers['X-API-Key'] = apiKey;
    }

    // 2. Client Device Metadata Headers
    final device = _getDeviceMetadata();
    if (device != null) {
      options.headers.addAll(device.toHeaders());
    }

    // 3. Bearer Token Injection
    if (!options.headers.containsKey('Authorization')) {
      final token = await _storage.getAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;

    // 1. Kill-Switch Handling (HTTP 503)
    if (response?.statusCode == 503) {
      final data = response?.data;
      final isMaintenance = (data is Map &&
          (data['maintenance'] == true || data['code'] == 'APP_API_DISABLED'));

      if (isMaintenance) {
        final retryAfterHeader = response?.headers.value('Retry-After');
        final retryAfter = int.tryParse(retryAfterHeader ?? '300') ?? 300;
        final maintenanceException = MaintenanceException.fromJson(
          Map<String, dynamic>.from(data),
          retryAfter,
        );

        onMaintenance?.call(maintenanceException);
        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            response: response,
            error: maintenanceException,
            type: DioExceptionType.badResponse,
          ),
        );
      }
    }

    // 2. Atomic Token Refresh on 401 Unauthorized
    final isAuthRoute = err.requestOptions.path.contains('/auth/login') ||
        err.requestOptions.path.contains('/auth/refresh') ||
        err.requestOptions.path.contains('/auth/2fa');

    if (response?.statusCode == 401 && !isAuthRoute) {
      // Check if token was already refreshed by a prior concurrent request
      final currentToken = await _storage.getAccessToken();
      final reqAuth = err.requestOptions.headers['Authorization'];
      if (currentToken != null &&
          currentToken.isNotEmpty &&
          reqAuth != null &&
          reqAuth != 'Bearer $currentToken') {
        err.requestOptions.headers['Authorization'] = 'Bearer $currentToken';
        try {
          final cloneReq = await _dio.fetch(err.requestOptions);
          return handler.resolve(cloneReq);
        } catch (fetchErr) {
          if (fetchErr is DioException) {
            return handler.reject(fetchErr);
          }
          return handler.reject(err);
        }
      }

      if (_isRefreshing) {
        // Another concurrent request is already performing the refresh.
        // Queue this request and await the new token.
        final completer = Completer<String?>();
        _refreshQueue.add(completer);
        final newToken = await completer.future;

        if (newToken != null && newToken.isNotEmpty) {
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          try {
            final cloneReq = await _dio.fetch(err.requestOptions);
            return handler.resolve(cloneReq);
          } catch (fetchErr) {
            if (fetchErr is DioException) {
              return handler.reject(fetchErr);
            }
            return handler.reject(err);
          }
        } else {
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: const SessionExpiredException(),
              type: DioExceptionType.unknown,
            ),
          );
        }
      }

      // First request to encounter 401 acquires the lock.
      _isRefreshing = true;
      try {
        final refreshToken = await _storage.getRefreshToken();
        if (refreshToken == null || refreshToken.isEmpty) {
          _triggerLogout();
          return handler.reject(
            DioException(
              requestOptions: err.requestOptions,
              error: const SessionExpiredException(),
              type: DioExceptionType.unknown,
            ),
          );
        }

        // Call refresh API with isolated client instance to avoid infinite loop
        final refreshDio = Dio(
          BaseOptions(
            baseUrl: _dio.options.baseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 10),
          ),
        );
        refreshDio.httpClientAdapter = _dio.httpClientAdapter;

        final refreshRes = await refreshDio.post(
          Endpoints.authRefresh,
          options: Options(
            headers: {
              'X-API-Key': _getApiKey(),
              'Content-Type': 'application/json',
            },
          ),
          data: {'refresh_token': refreshToken},
        );

        if (refreshRes.statusCode == 200 && refreshRes.data != null) {
          final data = Map<String, dynamic>.from(refreshRes.data as Map);
          final newAccessToken =
              (data['access_token'] ?? data['token']) as String?;
          final newRefreshToken = (data['refresh_token']) as String?;

          if (newAccessToken != null && newAccessToken.isNotEmpty) {
            await _storage.saveTokens(
              accessToken: newAccessToken,
              refreshToken: newRefreshToken ?? refreshToken,
            );

            // Release queued requests with the new token
            for (final c in _refreshQueue) {
              c.complete(newAccessToken);
            }
            _refreshQueue.clear();
            _isRefreshing = false;

            // Replay the original failed request
            err.requestOptions.headers['Authorization'] =
                'Bearer $newAccessToken';
            final cloneReq = await _dio.fetch(err.requestOptions);
            return handler.resolve(cloneReq);
          }
        }

        throw const SessionExpiredException();
      } catch (refreshErr) {
        for (final c in _refreshQueue) {
          c.complete(null);
        }
        _refreshQueue.clear();
        _isRefreshing = false;
        _triggerLogout();

        return handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: refreshErr is HubSightException
                ? refreshErr
                : const SessionExpiredException(),
            type: DioExceptionType.unknown,
          ),
        );
      }
    }

    return handler.next(err);
  }

  void _triggerLogout() {
    _storage.clearTokens();
    onSessionExpired?.call();
  }
}
