# Build de produção do app Windows — rode ESTE script numa máquina Windows.
# O Flutter não faz cross-compile: um Mac/Linux não gera binário Windows.
#
#   powershell -ExecutionPolicy Bypass -File scripts\build_prod.ps1
#
# Requisitos na máquina: Flutter (stable), Visual Studio 2022 com a carga
# "Desktop development with C++" e `flutter doctor` sem erro em "Visual Studio".
# Verifique com: flutter doctor -v   e   flutter devices  (deve listar Windows).
$ErrorActionPreference = 'Stop'

Set-Location (Join-Path $PSScriptRoot '..')
$EnvFile = 'env\prod.json'

Write-Host "> alvo: windows - config: $EnvFile"
if (-not (Test-Path $EnvFile)) { throw "$EnvFile nao encontrado" }

flutter config --enable-windows-desktop
flutter pub get
dart run build_runner build
flutter analyze
flutter test

flutter build windows --release --dart-define-from-file=$EnvFile

$Out = 'build\windows\x64\runner\Release'
Write-Host "OK - binario em $Out"
Get-ChildItem $Out | Select-Object Name, Length | Format-Table

# Distribuição: a pasta Release INTEIRA é o app (o .exe sozinho não roda — ele
# depende das DLLs e da pasta data\ ao lado). Zipe a pasta, ou gere um
# instalador (ex.: Inno Setup / MSIX) a partir dela.
