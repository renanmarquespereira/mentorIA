param([int]$Porta = 8080)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$web = Join-Path $root "mobile\build\web"
if (-not (Test-Path (Join-Path $web "index.html"))) { throw "Build Web nao encontrado. Rode .\BUILD_WEB.ps1 primeiro." }
Push-Location $web
try {
  Write-Host "Abra no MacBook: http://IP_DESTE_PC:$Porta" -ForegroundColor Cyan
  Write-Host "Pressione Ctrl+C para encerrar."
  python -m http.server $Porta --bind 0.0.0.0
} finally { Pop-Location }
