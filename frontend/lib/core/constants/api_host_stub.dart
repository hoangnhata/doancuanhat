/// Web: không dùng dart:io — localhost trỏ tới máy dev.
const _kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

String resolveApiBaseUrl() =>
    _kApiBaseUrl.isNotEmpty ? _kApiBaseUrl : 'http://localhost:8080/api';
