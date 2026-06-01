import 'package:dio/dio.dart';
import 'package:expense_manager/data/datasources/local_storage.dart';

class ApiClient {
  final Dio _dio;
  final LocalStorage _storage;

  ApiClient(this._dio, this._storage) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final skipAuth = options.extra['skipAuth'] == true;
        if (!skipAuth) {
          final token = await _storage.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Chỉ refresh + retry khi 401 (token hết hạn). Không retry 403 để tránh loop vô hạn
        // (403 thường là forbidden/role, refresh cũng không giúp).
        if (error.response?.statusCode == 401) {
          final refreshed = await _refreshToken();
          if (refreshed) {
            return handler.resolve(await _retry(error.requestOptions));
          }
          // Refresh fail → clear auth để app quay về login ở lần check tiếp theo.
          await _storage.clearAuth();
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post(
        '/auth/refresh',
        options: Options(
          headers: {'Authorization': 'Bearer $refreshToken'},
          extra: {'skipAuth': true},
        ),
      );

      final data = response.data['data'];
      if (data != null) {
        await _storage.saveTokens(
          data['accessToken'],
          data['refreshToken'],
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<Response> _retry(RequestOptions options) async {
    final token = await _storage.getAccessToken();
    options.headers['Authorization'] = 'Bearer $token';
    return _dio.fetch(options);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
    final response = await _dio.get(path, queryParameters: params);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, {dynamic data}) async {
    final response = await _dio.post(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, {dynamic data}) async {
    final response = await _dio.put(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(String path, {dynamic data}) async {
    final response = await _dio.patch(path, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final response = await _dio.delete(path);
    return response.data as Map<String, dynamic>;
  }

  Future<List<int>> getBytes(String path, {Map<String, dynamic>? params}) async {
    final response = await _dio.get<List<int>>(
      path,
      queryParameters: params,
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// Upload multipart (vd: ảnh hóa đơn cho OCR). [fields] dùng cho field "file".
  /// OCR ảnh có thể mất 10-20s trên máy yếu — receiveTimeout dài hơn mặc định.
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required FormData formData,
  }) async {
    final response = await _dio.post(
      path,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    return response.data as Map<String, dynamic>;
  }
}
