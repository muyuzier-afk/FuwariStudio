param(
  [string]$JdkRoot = ""
)

$ErrorActionPreference = "Stop"

function Get-ProjectRoot {
  Split-Path -Parent $PSScriptRoot
}

if ([string]::IsNullOrWhiteSpace($JdkRoot)) {
  $JdkRoot = Join-Path (Get-ProjectRoot) "tools\\jdk17"
}

$javaExe = Join-Path $JdkRoot "bin\\java.exe"
if (Test-Path $javaExe) {
  $env:JAVA_HOME = $JdkRoot
  $env:Path = "$(Join-Path $JdkRoot "bin");$env:Path"
  & $javaExe -version | Out-Host
  Write-Host "OK: Using JDK at $JdkRoot"
  return
}

New-Item -ItemType Directory -Force -Path $JdkRoot | Out-Null

$zip = Join-Path $JdkRoot "jdk17.zip"
$url = "https://api.adoptium.net/v3/binary/latest/17/ga/windows/x64/jdk/hotspot/normal/eclipse"
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing | Out-Null

$tmp = Join-Path $JdkRoot "_tmp"
if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
Expand-Archive -Path $zip -DestinationPath $tmp -Force
Remove-Item -Force $zip

$child = Get-ChildItem $tmp -Directory | Select-Object -First 1
if ($null -eq $child) {
  throw "Unexpected JDK archive structure."
}

Get-ChildItem $child.FullName -Force | ForEach-Object {
  Move-Item -Force $_.FullName $JdkRoot
}

Remove-Item -Recurse -Force $tmp

$javaExe = Join-Path $JdkRoot "bin\\java.exe"
if (!(Test-Path $javaExe)) {
  throw "JDK install failed: $javaExe not found."
}

$env:JAVA_HOME = $JdkRoot
$env:Path = "$(Join-Path $JdkRoot "bin");$env:Path"
& $javaExe -version | Out-Host
Write-Host "OK: Installed JDK 17 at $JdkRoot"

