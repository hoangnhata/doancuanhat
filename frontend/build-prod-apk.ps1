# Build Flutter APK trỏ API production (AWS EC2)
$api = "http://3.115.238.104/api"
Write-Host "API: $api"
flutter build apk --release --dart-define=API_BASE_URL=$api
Write-Host "APK: build\app\outputs\flutter-apk\app-release.apk"
