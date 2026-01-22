param(
  [string]$Flutter = "flutter"
)

$ErrorActionPreference = "Stop"

function Get-ProjectRoot {
  Split-Path -Parent $PSScriptRoot
}

function Get-PubspecVersion([string]$pubspecPath) {
  $content = Get-Content $pubspecPath -Raw
  # Strip UTF-8 BOM if present.
  if ($content.Length -gt 0 -and [int]$content[0] -eq 0xFEFF) {
    $content = $content.Substring(1)
  }
  if ($content -match '(?m)^\s*version:\s*([^\s]+)\s*$') {
    return $Matches[1]
  }
  throw "Unable to read version from $pubspecPath"
}

function Ensure-Wix([string]$toolsDir) {
  $wixDir = Join-Path $toolsDir "wix311"
  $candle = Join-Path $wixDir "candle.exe"
  $light = Join-Path $wixDir "light.exe"
  $heat = Join-Path $wixDir "heat.exe"

  if ((Test-Path $candle) -and (Test-Path $light) -and (Test-Path $heat)) {
    return $wixDir
  }

  New-Item -ItemType Directory -Force -Path $wixDir | Out-Null
  $zip = Join-Path $wixDir "wix311-binaries.zip"

  $urls = @(
    "https://github.com/wixtoolset/wix3/releases/download/wix3112rtm/wix311-binaries.zip",
    "https://github.com/wixtoolset/wix3/releases/download/wix3111rtm/wix311-binaries.zip"
  )

  foreach ($url in $urls) {
    try {
      Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing | Out-Null
      break
    } catch {
      # try next
    }
  }

  if (!(Test-Path $zip)) {
    throw "Failed to download WiX Toolset 3.11 binaries."
  }

  Expand-Archive -Path $zip -DestinationPath $wixDir -Force
  Remove-Item -Force $zip

  if (!(Test-Path $candle)) {
    throw "WiX download/extract failed: $candle not found."
  }

  return $wixDir
}

function Require-Success([string]$stepName) {
  if ($LASTEXITCODE -ne 0) {
    throw "$stepName failed with exit code $LASTEXITCODE"
  }
}

function To-WixVersion([string]$semver) {
  $core = $semver.Split("+")[0]
  $parts = $core.Split(".")
  if ($parts.Count -gt 4) { $parts = $parts[0..3] }
  while ($parts.Count -lt 4) { $parts += "0" }
  $ints = @()
  foreach ($p in $parts) {
    $ints += [int]$p
  }
  return ($ints -join ".")
}

$root = Get-ProjectRoot
Set-Location $root

& $Flutter --version | Out-Host
& $Flutter pub get | Out-Host
& $Flutter build windows --release | Out-Host
Require-Success "flutter build windows"

$releaseDir = Join-Path $root "build\\windows\\x64\\runner\\Release"
$exe = Join-Path $releaseDir "FuwariStudio.exe"
if (!(Test-Path $exe)) {
  throw "Windows release exe not found: $exe"
}

$stageDir = Join-Path $root "build\\installer\\stage"
if (Test-Path $stageDir) { Remove-Item -Recurse -Force $stageDir }
New-Item -ItemType Directory -Force -Path $stageDir | Out-Null

Copy-Item -Force (Join-Path $releaseDir "FuwariStudio.exe") (Join-Path $stageDir "FuwariStudio.exe")
Copy-Item -Force (Join-Path $releaseDir "flutter_windows.dll") (Join-Path $stageDir "flutter_windows.dll")
Get-ChildItem $releaseDir -Filter "*_plugin.dll" -File | Where-Object {
  $_.Name -ne "flutter_inappwebview_windows_plugin.dll"
} | ForEach-Object {
  Copy-Item -Force $_.FullName (Join-Path $stageDir $_.Name)
}
Copy-Item -Recurse -Force (Join-Path $releaseDir "data") (Join-Path $stageDir "data")

$toolsDir = Join-Path $root "tools"
New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
$wixDir = Ensure-Wix $toolsDir

$wixObjDir = Join-Path $root "build\\installer\\wix"
New-Item -ItemType Directory -Force -Path $wixObjDir | Out-Null

$heat = Join-Path $wixDir "heat.exe"
$candle = Join-Path $wixDir "candle.exe"
$light = Join-Path $wixDir "light.exe"

$appFilesWxs = Join-Path $wixObjDir "AppFiles.wxs"
& $heat dir $stageDir `
  -nologo `
  -dr INSTALLFOLDER `
  -cg AppFiles `
  -ag `
  -var var.SourceDir `
  -sreg -sfrag -srd `
  -out $appFilesWxs | Out-Host
Require-Success "heat"

$pubspecVersion = Get-PubspecVersion (Join-Path $root "pubspec.yaml")
$productVersion = To-WixVersion $pubspecVersion

$productWxs = Join-Path $root "installer\\wix\\Product.wxs"
$wixObjs = @(
  (Join-Path $wixObjDir "Product.wixobj")
  (Join-Path $wixObjDir "AppFiles.wixobj")
)

& $candle -nologo `
  -arch x64 `
  "-dProjectDir=$root\\" `
  "-dProductVersion=$productVersion" `
  -out (Join-Path $wixObjDir "Product.wixobj") `
  $productWxs | Out-Host
Require-Success "candle product"

& $candle -nologo `
  -arch x64 `
  -out (Join-Path $wixObjDir "AppFiles.wixobj") `
  "-dSourceDir=$stageDir\\" `
  $appFilesWxs | Out-Host
Require-Success "candle appfiles"

$dist = Join-Path $root "dist\\windows"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$msi = Join-Path $dist "FuwariStudio-$productVersion-win-x64.msi"
if (Test-Path $msi) { Remove-Item -Force $msi }

& $light -nologo `
  -ext WixUIExtension `
  -out $msi `
  $wixObjs | Out-Host
Require-Success "light"

if (!(Test-Path $msi)) {
  throw "MSI build finished but output not found: $msi"
}

Write-Host "OK: $msi"
