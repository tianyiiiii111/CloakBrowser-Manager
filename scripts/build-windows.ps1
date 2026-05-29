# Build Windows portable zip (no installer). Run on Windows (PowerShell).
# Usage: .\scripts\build-windows.ps1 [-PackageOnly]
param(
    [switch]$PackageOnly
)

$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $Root

$VersionLine = Select-String -Path pyproject.toml -Pattern '^\s*version\s*=' | Select-Object -First 1
if (-not $VersionLine) { throw 'version not found in pyproject.toml' }
$Version = [regex]::Match($VersionLine.Line, '"([^"]+)"').Groups[1].Value

$Python = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' }
          elseif (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' }
          else { throw 'python not found' }

$VenvPip = Join-Path $Root '.venv-build\Scripts\pip.exe'
$VenvPyinstaller = Join-Path $Root '.venv-build\Scripts\pyinstaller.exe'

if (-not $PackageOnly) {
    Write-Host '==> frontend'
    Push-Location (Join-Path $Root 'frontend')
    npm ci
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    npm run build
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Pop-Location

    Write-Host '==> python'
    if (-not (Test-Path '.venv-build')) {
        & $Python -m venv .venv-build
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    }
    & $VenvPip install -q -r packaging/requirements-desktop.txt
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host '==> pyinstaller'
    & $VenvPyinstaller packaging/cloakbrowser-manager.spec --noconfirm --clean
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$AppDir = Join-Path $Root 'dist\CloakBrowser Manager'
$Exe = Join-Path $AppDir 'CloakBrowser Manager.exe'
$ZipOut = Join-Path $Root "dist\CloakBrowser-Manager-$Version-win64.zip"

if (-not (Test-Path $Exe)) { throw "Missing $Exe" }

Write-Host '==> portable zip'
Set-Content -Path (Join-Path $AppDir 'version.txt') -Value $Version -Encoding utf8 -NoNewline
if (Test-Path $ZipOut) { Remove-Item -Force $ZipOut }
Compress-Archive -Path $AppDir -DestinationPath $ZipOut -CompressionLevel Optimal
if (-not (Test-Path $ZipOut)) { throw "Build failed: $ZipOut" }
Write-Host "=> $ZipOut"
Write-Host '解压后运行 CloakBrowser Manager.exe（免安装，支持应用内一键更新）'
