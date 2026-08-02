# Gera o instalador Windows (build release + Inno Setup) a partir de env/prod.json.
# Rode ESTE script numa máquina Windows (o Flutter não faz cross-compile).
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_installer.ps1
#
# Requisitos: os mesmos de build_prod.ps1 (Flutter, Visual Studio com "Desktop
# development with C++", Developer Mode ON, OpenSSL dev — ver
# `winget install ShiningLight.OpenSSL.Dev`, setar $env:OPENSSL_ROOT_DIR se o
# CMake não achar sozinho) + Inno Setup 6 (`winget install JRSoftware.InnoSetup`).
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')
$VCRedistPath = 'scripts\vcredist_x64.exe'
$VCRedistUrl = 'https://aka.ms/vs/17/release/vc_redist.x64.exe'
$IssScript = 'scripts\installer.iss'

Write-Host "> 1/3 - build windows release"
& (Join-Path $PSScriptRoot 'build_prod.ps1')

Write-Host "> 2/3 - VC++ redistributable (bundlado no instalador)"
if (-not (Test-Path $VCRedistPath)) {
  Write-Host "  baixando $VCRedistUrl"
  Invoke-WebRequest -Uri $VCRedistUrl -OutFile $VCRedistPath
}

Write-Host "> 3/3 - compilando instalador (Inno Setup)"
$iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
if ($iscc) {
  $isccPath = $iscc.Source
} else {
  $candidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
  )
  $isccPath = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
  if (-not $isccPath) {
    throw "ISCC.exe nao encontrado. Instale: winget install --id JRSoftware.InnoSetup -e"
  }
}

& $isccPath $IssScript

$Setup = Get-ChildItem 'build\installer\*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $Setup) { throw "Instalador nao foi gerado em build\installer\" }
Write-Host "OK - instalador em $($Setup.FullName)"
