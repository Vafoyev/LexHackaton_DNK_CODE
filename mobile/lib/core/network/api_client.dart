import 'package:dio/dio.dart';

import '../config/app_env.dart';
import '../security/screen_security.dart';

class ApiClient {
  ApiClient({required this.tokenStore, String? baseUrl})
      : dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppEnv.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 25),
            sendTimeout: const Duration(seconds: 25),
            headers: const {
              'Accept': 'application/json',
              'X-Client-Type': 'mobile',
            },
          ),
        ) {
    dio.interceptors.add(_AuthQueuedInterceptor(tokenStore, dio));
  }

  final Dio dio;
  final SecureTokenStore tokenStore;
}

class _AuthQueuedInterceptor extends QueuedInterceptor {
  _AuthQueuedInterceptor(this._tokenStore, this._dio);

  final SecureTokenStore _tokenStore;
  final Dio _dio;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokenStore.accessToken;
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode != 401 ||
        err.requestOptions.extra['retried'] == true) {
      return handler.next(err);
    }

    final refresh = await _tokenStore.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      return handler.next(err);
    }

    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/refresh',
        data: {'refresh_token': refresh},
        options: Options(extra: const {'retried': true}),
      );
      final newAccess = res.data?['access_token'] as String?;
      final newRefresh = res.data?['refresh_token'] as String?;
      if (newAccess == null || newAccess.isEmpty) {
        await _tokenStore.clearAll();
        return handler.next(err);
      }
      _tokenStore.setAccessToken(newAccess);
      if (newRefresh != null && newRefresh.isNotEmpty) {
        await _tokenStore.saveRefreshToken(newRefresh);
      }

      final retryOptions = err.requestOptions;
      retryOptions.headers['Authorization'] = 'Bearer $newAccess';
      retryOptions.extra['retried'] = true;
      final retryResp = await _dio.fetch<dynamic>(retryOptions);
      return handler.resolve(retryResp);
    } catch (_) {
      await _tokenStore.clearAll();
      return handler.next(err);
    }
  }
}
