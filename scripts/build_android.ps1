param(
  [string]$Flutter = "flutter"
)

$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

Write-Host "Setting up JDK 17..."
& powershell -ExecutionPolicy Bypass -File (Join-Path $root "scripts\\setup_jdk17.ps1") | Out-Host
$jdkRoot = Join-Path $root "tools\\jdk17"
$env:JAVA_HOME = $jdkRoot
$env:Path = "$(Join-Path $jdkRoot "bin");$env:Path"

 $sdkRoot = Join-Path $root "tools\\android-sdk"
 $env:ANDROID_HOME = $sdkRoot
 $env:ANDROID_SDK_ROOT = $sdkRoot
 $env:Path = "$(Join-Path $sdkRoot "platform-tools");$env:Path"

if (-not (Test-Path $sdkRoot)) {
  Write-Host "ANDROID_HOME not set; setting up a local Android SDK..."
  & powershell -ExecutionPolicy Bypass -File (Join-Path $root "scripts\\setup_android_sdk.ps1") | Out-Host
}

$ndkRoot = Join-Path $sdkRoot "ndk"
if (Test-Path $ndkRoot) {
  $candidates = Get-ChildItem $ndkRoot -Directory | Where-Object {
    Test-Path (Join-Path $_.FullName "toolchains\\llvm\\prebuilt\\windows-x86_64\\bin\\clang.exe")
  } | Sort-Object Name -Descending

  $selected = $candidates | Select-Object -First 1
  if ($null -ne $selected) {
    $env:ANDROID_NDK_HOME = $selected.FullName
    $env:ANDROID_NDK_ROOT = $selected.FullName
    $env:NDK_HOME = $selected.FullName
    Write-Host "ANDROID_NDK_HOME=$env:ANDROID_NDK_HOME"
  } else {
    Write-Host "No usable NDK found under $ndkRoot"
  }
}

& $Flutter --version | Out-Host
& $Flutter pub get | Out-Host

$apk = Join-Path $root "build\\app\\outputs\\flutter-apk\\app-release.apk"
$previousWriteTime = $null
if (Test-Path $apk) {
  $previousWriteTime = (Get-Item $apk).LastWriteTimeUtc
}

& $Flutter build apk --release | Out-Host
if ($LASTEXITCODE -ne 0) {
  throw "flutter build apk failed with exit code $LASTEXITCODE"
}

if (!(Test-Path $apk)) {
  throw "Build finished but APK not found: $apk"
}
if ($null -ne $previousWriteTime) {
  $currentWriteTime = (Get-Item $apk).LastWriteTimeUtc
  if ($currentWriteTime -le $previousWriteTime) {
    throw "Build did not produce a new APK (output timestamp did not advance): $apk"
  }
}

$distRoot = Join-Path $root "dist\\android"
New-Item -ItemType Directory -Force -Path $distRoot | Out-Null

$out = Join-Path $distRoot "FuwariStudio-android.apk"
Copy-Item -Force $apk $out
Write-Host "OK: $out"
