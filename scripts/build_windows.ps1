param(
  [string]$Flutter = "flutter",
  [string]$Configuration = "Release"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

& $Flutter --version | Out-Host
& $Flutter pub get | Out-Host
& $Flutter build windows --release | Out-Host

$outDir = Join-Path $root "build\\windows\\x64\\runner\\Release"
$exe = Join-Path $outDir "FuwariStudio.exe"

if (!(Test-Path $exe)) {
  throw "Build finished but exe not found: $exe"
}

$distRoot = Join-Path $root "dist\\windows"
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

$zip = Join-Path $distRoot "FuwariStudio-win-x64.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }

$stage = Join-Path $root "build\\dist\\windows-stage"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force -Path $stage | Out-Null

Copy-Item -Force (Join-Path $outDir "FuwariStudio.exe") (Join-Path $stage "FuwariStudio.exe")
Copy-Item -Force (Join-Path $outDir "flutter_windows.dll") (Join-Path $stage "flutter_windows.dll")
Get-ChildItem $outDir -Filter "*_plugin.dll" -File | Where-Object {
  $_.Name -ne "flutter_inappwebview_windows_plugin.dll"
} | ForEach-Object {
  Copy-Item -Force $_.FullName (Join-Path $stage $_.Name)
}
Copy-Item -Recurse -Force (Join-Path $outDir "data") (Join-Path $stage "data")

Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip
Write-Host "OK: $zip"
