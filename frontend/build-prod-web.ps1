# Build Flutter Web production — API qua proxy Vercel (/api → EC2)
$api = "/api"
Write-Host "API: $api (Vercel proxy)"
Push-Location web
npm install
Pop-Location
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=$api
Write-Host "Output: build\web"
