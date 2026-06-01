import 'dart:io';

const _kApiBaseUrl = String.fromEnvironment('API_BASE_URL');

/// Android emulator: localhost là chính emulator — dùng 10.0.2.2 để tới máy host.
/// iOS simulator / desktop: localhost = máy dev.
/// Thiết bị thật: đổi thành IP LAN máy chạy backend (vd. http://192.168.1.x:8080/api).
String resolveApiBaseUrl() {
  if (_kApiBaseUrl.isNotEmpty) return _kApiBaseUrl;
  if (Platform.isAndroid) return 'http://10.0.2.2:8080/api';
  return 'http://localhost:8080/api';
}
