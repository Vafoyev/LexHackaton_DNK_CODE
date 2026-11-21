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

  /// Authenticate with email/password and persist tokens
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
    String clientType = 'mobile',
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/auth/login',
      data: {
        'email': email,
        'password': password,
        'client_type': clientType,
      },
    );
    final data = res.data;
    if (data != null) {
      _extractAndSaveTokens(data);
    }
    return data;
  }

  /// Instant demo session (VM-679 / OneID sandbox)
  Future<Map<String, dynamic>?> demoSession({
    String role = 'lawyer',
    String clientType = 'mobile',
  }) async {
    final res = await dio.post<Map<String, dynamic>>(
      '/api/v1/auth/demo-session',
      data: {
        'role': role,
        'client_type': clientType,
      },
    );
    final data = res.data;
    if (data != null) {
      _extractAndSaveTokens(data);
    }
    return data;
  }

  /// Revoke tokens on logout
  Future<void> logout() async {
    try {
      final refresh = await tokenStore.readRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        await dio.post<void>(
          '/api/v1/auth/logout',
          data: {'refresh_token': refresh},
        );
      }
    } finally {
      await tokenStore.clearAll();
    }
  }

  /// Get current user profile
  Future<Map<String, dynamic>?> getMe() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/auth/me');
    return res.data;
  }

  /// Get billing quota
  Future<Map<String, dynamic>?> getQuota() async {
    final res = await dio.get<Map<String, dynamic>>('/api/v1/billing/quota');
    return res.data;
  }

  /// AI Live Voice Briefing (30s audio debrief)
  Future<Map<String, dynamic>?> getVoiceBrief(String analysisId) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/analyses/$analysisId/voice-brief',
    );
    return res.data;
  }

  /// 3D Glanceable Matrix
  Future<Map<String, dynamic>?> getGlanceableMatrix(String analysisId) async {
    final res = await dio.get<Map<String, dynamic>>(
      '/api/v1/analyses/$analysisId/glanceable-matrix',
    );
    return res.data;
  }

  void _extractAndSaveTokens(Map<String, dynamic> data) {
    final tokens = data['tokens'] as Map<String, dynamic>?;
    final access = (tokens?['access_token'] ?? data['access_token']) as String?;
    final refresh = (tokens?['refresh_token'] ?? data['refresh_token']) as String?;

    if (access != null && access.isNotEmpty) {
      tokenStore.setAccessToken(access);
    }
    if (refresh != null && refresh.isNotEmpty) {
      tokenStore.saveRefreshToken(refresh);
    }
  }
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

      final tokensMap = res.data?['tokens'] as Map<String, dynamic>?;
      final newAccess = (tokensMap?['access_token'] ?? res.data?['access_token']) as String?;
      final newRefresh = (tokensMap?['refresh_token'] ?? res.data?['refresh_token']) as String?;

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
