# Build Windows distributable (Setup.exe). Run on Windows (PowerShell).
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

$Exe = Join-Path $Root 'dist\CloakBrowser Manager\CloakBrowser Manager.exe'
$Out = Join-Path $Root "dist\CloakBrowser-Manager-$Version-Setup.exe"
if (-not (Test-Path $Exe)) { throw "Missing $Exe" }

$Iscc = $null
foreach ($candidate in @(
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)) {
    if (Test-Path $candidate) { $Iscc = $candidate; break }
}
if (-not $Iscc) {
    $cmd = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if ($cmd) { $Iscc = $cmd.Source }
}
if (-not $Iscc) {
    throw 'Inno Setup 6 required: https://jrsoftware.org/isinfo.php'
}

Write-Host '==> installer'
$Iss = Join-Path $Root 'packaging\windows\installer.iss'
& $Iscc "/DMyAppVersion=$Version" $Iss
if ($LASTEXITCODE -ne 0) { throw 'Inno Setup compiler failed' }
if (-not (Test-Path $Out)) { throw "Build failed: $Out" }
Write-Host "=> $Out"
