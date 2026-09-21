param(
  [string]$ApiUrl = "http://192.168.18.161:8001/api/v1"
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$mobile = Join-Path $root "mobile"
if (-not (Test-Path (Join-Path $mobile "pubspec.yaml"))) { throw "Pasta mobile nao encontrada em $root" }
Push-Location $mobile
try {
  flutter pub get
  flutter build web --release --dart-define="MENTORIA_API_URL=$ApiUrl"
  Write-Host ""
  Write-Host "Build Web concluido:" -ForegroundColor Green
  Write-Host (Join-Path $mobile "build\web")
} finally { Pop-Location }
