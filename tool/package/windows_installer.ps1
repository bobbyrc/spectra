# Builds the Spectra Windows installer and portable zip, signing both when a
# certificate is available and shipping them unsigned when it is not, so a
# fork or a secretless run still gets artifacts (spec 10).
#
#   pwsh tool/package/windows_installer.ps1 `
#     -BuildDir app\build\windows\x64\runner\Release `
#     -Version 1.0.0-rc.1 -OutDir dist
#
# Environment (optional): WINDOWS_CERT_PFX (base64 .pfx),
# WINDOWS_CERT_PASSWORD.
param(
  [Parameter(Mandatory = $true)][string]$BuildDir,
  [Parameter(Mandatory = $true)][string]$Version,
  [Parameter(Mandatory = $true)][string]$OutDir
)

$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$BuildDir = (Resolve-Path $BuildDir).Path
$OutDir = (Resolve-Path $OutDir).Path

# Locate signtool once; it may be absent on a machine with no Windows SDK.
function Get-SignTool {
  $found = Get-ChildItem `
    'C:\Program Files (x86)\Windows Kits\10\bin\*\x64\signtool.exe' `
    -ErrorAction SilentlyContinue | Sort-Object FullName | Select-Object -Last 1
  if ($found) { return $found.FullName }
  return $null
}

$pfxPath = $null
if ($env:WINDOWS_CERT_PFX -and $env:WINDOWS_CERT_PASSWORD) {
  $signtool = Get-SignTool
  if ($signtool) {
    $pfxPath = Join-Path $env:RUNNER_TEMP 'spectra.pfx'
    [IO.File]::WriteAllBytes($pfxPath,
      [Convert]::FromBase64String($env:WINDOWS_CERT_PFX))
    Write-Host 'windows_installer: code signing enabled'
  } else {
    Write-Host 'windows_installer: signtool not found, skipping code signing'
  }
} else {
  Write-Host 'windows_installer: no certificate, skipping code signing'
}

function Invoke-Sign([string]$Path) {
  if (-not $pfxPath) { return }
  & (Get-SignTool) sign /fd SHA256 /f $pfxPath `
    /p $env:WINDOWS_CERT_PASSWORD /tr http://timestamp.digicert.com `
    /td SHA256 $Path
  if ($LASTEXITCODE -ne 0) { throw "signtool failed on $Path" }
}

# Sign the executable before it is packaged, so both artifacts carry it.
Invoke-Sign (Join-Path $BuildDir 'spectra.exe')

$zip = Join-Path $OutDir "spectra-$Version-windows.zip"
if (Test-Path $zip) { Remove-Item $zip }
Compress-Archive -Path (Join-Path $BuildDir '*') -DestinationPath $zip
Write-Host "windows_installer: wrote $zip"

$iss = Join-Path $PSScriptRoot 'windows\spectra.iss'
& ISCC.exe "/DAppVersion=$Version" "/DBuildDir=$BuildDir" "/DOutDir=$OutDir" $iss
if ($LASTEXITCODE -ne 0) { throw 'ISCC failed' }

$setup = Join-Path $OutDir "spectra-$Version-windows-setup.exe"
Invoke-Sign $setup
Write-Host "windows_installer: wrote $setup"

if ($pfxPath) { Remove-Item $pfxPath -Force }
