param(
  [string]$SdkRoot = "",
  [string]$ApiLevel = "34",
  [string]$BuildTools = "34.0.0"
)

$ErrorActionPreference = "Stop"

function Get-ProjectRoot {
  Split-Path -Parent $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($SdkRoot)) {
  $SdkRoot = Join-Path (Get-ProjectRoot) "tools\\android-sdk"
}

New-Item -ItemType Directory -Force -Path $SdkRoot | Out-Null

$cmdlineDir = Join-Path $SdkRoot "cmdline-tools\\latest"
$sdkManager = Join-Path $cmdlineDir "bin\\sdkmanager.bat"

if (!(Test-Path $sdkManager)) {
  $zip = Join-Path $SdkRoot "cmdline-tools.zip"
  if (Test-Path $zip) { Remove-Item -Force $zip }
  $tmpZip = Join-Path $SdkRoot ("cmdline-tools.download.{0}.zip" -f $PID)
  $url = "https://dl.google.com/android/repository/commandlinetools-win-11076708_latest.zip"
  Invoke-WebRequest -Uri $url -OutFile $tmpZip -UseBasicParsing | Out-Null
  Move-Item -Force $tmpZip $zip

  $tmp = Join-Path $SdkRoot "_tmp"
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
  New-Item -ItemType Directory -Force -Path $tmp | Out-Null

  Expand-Archive -Path $zip -DestinationPath $tmp -Force
  Remove-Item -Force $zip

  $extracted = Join-Path $tmp "cmdline-tools"
  if (!(Test-Path $extracted)) {
    throw "Android commandline-tools archive structure unexpected."
  }

  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $cmdlineDir) | Out-Null
  Move-Item -Force -Path $extracted -Destination $cmdlineDir
  Remove-Item -Recurse -Force $tmp
}

$env:ANDROID_HOME = $SdkRoot
$env:ANDROID_SDK_ROOT = $SdkRoot
$env:Path = "$(Join-Path $SdkRoot "platform-tools");$(Join-Path $cmdlineDir "bin");$env:Path"

Write-Host "ANDROID_HOME=$env:ANDROID_HOME"

& $sdkManager --sdk_root=$SdkRoot --list | Out-Null

"y`n" * 250 | & $sdkManager --sdk_root=$SdkRoot --licenses | Out-Host

& $sdkManager --sdk_root=$SdkRoot `
  "platform-tools" `
  "platforms;android-$ApiLevel" `
  "build-tools;$BuildTools" | Out-Host

Write-Host "OK: Android SDK ready at $SdkRoot"
