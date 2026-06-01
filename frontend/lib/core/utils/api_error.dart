import 'package:dio/dio.dart';

String extractErrorMessage(dynamic error) {
  if (error is DioException) {
    final response = error.response;
    final status = response?.statusCode;
    if (status == 401) {
      return 'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.';
    }
    if (status == 403) {
      return 'Không có quyền thực hiện thao tác này. Vui lòng đăng nhập lại.';
    }
    if (response?.data is Map) {
      final data = response!.data as Map<String, dynamic>;
      final message = data['message'];
      if (message is String) return message;
      if (message is Map) {
        final values = message.values;
        for (final v in values) {
          if (v is String) return v;
        }
      }
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Kết nối timeout. Vui lòng thử lại.';
      case DioExceptionType.connectionError:
        return 'Không thể kết nối. Kiểm tra mạng và địa chỉ API.';
      default:
        return error.message ?? 'Đã xảy ra lỗi';
    }
  }
  return error.toString().replaceAll('Exception: ', '');
}
