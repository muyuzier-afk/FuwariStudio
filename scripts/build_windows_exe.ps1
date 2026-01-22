param(
  [string]$Flutter = "flutter",
  [string]$VersionTag = "v0.3"
)

$ErrorActionPreference = "Stop"

function Require-Success([string]$stepName) {
  if ($LASTEXITCODE -ne 0) {
    throw "$stepName failed with exit code $LASTEXITCODE"
  }
}

function Get-ProjectRoot {
  Split-Path -Parent $PSScriptRoot
}

function Ensure-7ZipTools([string]$toolsDir) {
  $sevenZipDir = Join-Path $toolsDir "7zip"
  $sevenZr = Join-Path $sevenZipDir "7zr.exe"
  $sevenZa = Join-Path $sevenZipDir "7za.exe"
  $sevenZSfx = Join-Path $sevenZipDir "7z.sfx"

  if ((Test-Path $sevenZr) -and (Test-Path $sevenZa) -and (Test-Path $sevenZSfx)) {
    return @{
      sevenZr = $sevenZr
      sevenZa = $sevenZa
      sevenZSfx = $sevenZSfx
    }
  }

  New-Item -ItemType Directory -Force -Path $sevenZipDir | Out-Null

  $downloadPage = "https://www.7-zip.org/download.html"
  $html = (Invoke-WebRequest -Uri $downloadPage -UseBasicParsing).Content
  $match = [regex]::Match($html, 'href="?a/(7z\d+-extra\.7z)"?', 'IgnoreCase')
  if (!$match.Success) {
    throw "Unable to locate 7-Zip extra package link on $downloadPage"
  }
  $extraName = $match.Groups[1].Value

  $zrUrl = "https://www.7-zip.org/a/7zr.exe"
  $extraUrl = "https://www.7-zip.org/a/$extraName"
  $zrPath = Join-Path $sevenZipDir "7zr.exe"
  $extraPath = Join-Path $sevenZipDir $extraName

  Invoke-WebRequest -Uri $zrUrl -OutFile $zrPath -UseBasicParsing | Out-Null
  Invoke-WebRequest -Uri $extraUrl -OutFile $extraPath -UseBasicParsing | Out-Null

  & $zrPath x "-o$sevenZipDir" -y $extraPath | Out-Host
  Require-Success "7zr extract"

  $extracted7za = Join-Path $sevenZipDir "7za.exe"
  if (!(Test-Path $extracted7za)) { throw "7-Zip extract missing: $extracted7za" }

  if (!(Test-Path $sevenZSfx)) {
    $installerMatch =
        [regex]::Match($html, 'href="?a/(7z\d+-x64\.exe)"?', 'IgnoreCase')
    if (!$installerMatch.Success) {
      throw "Unable to locate 7-Zip x64 installer link on $downloadPage"
    }
    $installerName = $installerMatch.Groups[1].Value
    $installerPath = Join-Path $sevenZipDir $installerName
    if (!(Test-Path $installerPath)) {
      Invoke-WebRequest -Uri "https://www.7-zip.org/a/$installerName" -OutFile $installerPath -UseBasicParsing | Out-Null
    }
    & $extracted7za e "-o$sevenZipDir" -y $installerPath "7z.sfx" | Out-Host
    Require-Success "7za extract sfx"
    if (!(Test-Path $sevenZSfx)) { throw "7-Zip extract missing: $sevenZSfx" }
  }

  Remove-Item -Force $extraPath -ErrorAction SilentlyContinue

  return @{
    sevenZr = $zrPath
    sevenZa = $extracted7za
    sevenZSfx = $sevenZSfx
  }
}

function Write-SfxConfig([string]$path, [string]$extractPath, [string]$runProgram) {
  $content = @(
    ';!@Install@!UTF-8!'
    "Title=`"FuwariStudio`""
    "ExtractPath=`"$extractPath`""
    'GUIMode="2"'
    "RunProgram=`"$runProgram`""
    ';!@InstallEnd@!'
  ) -join "`r`n"

  [System.IO.File]::WriteAllText(
    $path,
    $content,
    [System.Text.UTF8Encoding]::new($false)
  )
}

function Concat-Files([string[]]$parts, [string]$outFile) {
  if (Test-Path $outFile) { Remove-Item -Force $outFile }
  $outStream = [System.IO.File]::Open($outFile, [System.IO.FileMode]::CreateNew)
  try {
    foreach ($p in $parts) {
      $inStream = [System.IO.File]::OpenRead($p)
      try {
        $inStream.CopyTo($outStream)
      } finally {
        $inStream.Dispose()
      }
    }
  } finally {
    $outStream.Dispose()
  }
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

$stageDir = Join-Path $root "build\\dist\\windows-stage"
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
$sevenZip = Ensure-7ZipTools $toolsDir

$distDir = Join-Path $root "dist\\windows"
New-Item -ItemType Directory -Force -Path $distDir | Out-Null

$archive = Join-Path $root "build\\dist\\FuwariStudio-windows.7z"
if (Test-Path $archive) { Remove-Item -Force $archive }

Push-Location $stageDir
try {
  & $sevenZip.sevenZa a -t7z -mx=9 $archive "*" | Out-Host
  Require-Success "7za archive"
} finally {
  Pop-Location
}

$config = Join-Path $root "build\\dist\\7z_sfx_config.txt"
Write-SfxConfig -path $config -extractPath "%LOCALAPPDATA%\\FuwariStudio" -runProgram "FuwariStudio.exe"

$outExe = Join-Path $distDir "FuwariStudio-$VersionTag-win-x64.exe"
Concat-Files -parts @($sevenZip.sevenZSfx, $config, $archive) -outFile $outExe

if (!(Test-Path $outExe)) {
  throw "EXE packaging finished but output not found: $outExe"
}

Write-Host "OK: $outExe"
