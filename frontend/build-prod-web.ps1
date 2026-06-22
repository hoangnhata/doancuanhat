# Build Flutter Web production — API qua proxy Vercel (/api → EC2)
$api = "/api"
Write-Host "API: $api (Vercel proxy)"
flutter pub get
flutter build web --release --dart-define=API_BASE_URL=$api
Write-Host "Output: build\web"
Write-Host "Deploy: tao project Vercel moi, Root Directory = frontend, Output = build/web"
