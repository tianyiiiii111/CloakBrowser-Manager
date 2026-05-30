"""In-app updates (Windows portable, macOS Intel). Checks GitHub Releases and applies in place."""

from __future__ import annotations

import logging
import os
import platform
import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any

import httpx

from .paths import is_frozen
from .version import app_version, is_newer, version_tuple

logger = logging.getLogger("cloakbrowser.manager.updater")

# Override: CBM_UPDATE_REPO=owner/name
GITHUB_REPO = os.environ.get("CBM_UPDATE_REPO", "tianyiiiii111/CloakBrowser-Manager")
ASSET_VERSION_RE = re.compile(
    r"^CloakBrowser-Manager-(\d+\.\d+\.\d+)-(?:win64|x86_64)\.(?:zip|dmg)$",
    re.IGNORECASE,
)
WIN_ZIP_RE = re.compile(
    r"^CloakBrowser-Manager-\d+\.\d+\.\d+-win64\.zip$", re.IGNORECASE
)
MAC_ZIP_RE = re.compile(
    r"^CloakBrowser-Manager-\d+\.\d+\.\d+-x86_64\.zip$", re.IGNORECASE
)
EXE_NAME = "CloakBrowser Manager.exe"
APP_BUNDLE_NAME = "CloakBrowser Manager.app"


def _is_mac_intel() -> bool:
    machine = platform.machine().lower()
    return machine in ("x86_64", "amd64")


def update_supported() -> bool:
    if not is_frozen():
        return False
    if sys.platform == "win32":
        return True
    if sys.platform == "darwin":
        return _is_mac_intel()
    return False


def install_dir() -> Path:
    return Path(sys.executable).resolve().parent


def mac_app_bundle() -> Path:
    exe = Path(sys.executable).resolve()
    if exe.parent.name != "MacOS" or exe.parent.parent.name != "Contents":
        raise RuntimeError("当前进程不在 macOS 应用包内")
    return exe.parent.parent.parent


def _version_from_asset_name(name: str) -> str | None:
    m = ASSET_VERSION_RE.match(name)
    return m.group(1) if m else None


def _release_version(release: dict[str, Any], asset: dict[str, Any] | None) -> str:
    if asset:
        from_asset = _version_from_asset_name(asset.get("name", ""))
        if from_asset:
            return from_asset
    tag = release.get("tag_name", "")
    return tag.lstrip("v") if tag else app_version()


def _asset_patterns() -> list[re.Pattern[str]]:
    """Patterns for update assets published for this OS (not host CPU)."""
    if sys.platform == "win32":
        return [WIN_ZIP_RE]
    if sys.platform == "darwin":
        return [MAC_ZIP_RE]
    return []


def _pick_platform_asset(assets: list[dict[str, Any]]) -> dict[str, Any] | None:
    patterns = _asset_patterns()
    for pattern in patterns:
        for asset in assets:
            if pattern.match(asset.get("name", "")):
                return asset
    return None


async def check_for_update() -> dict[str, Any]:
    current = app_version()
    release, asset = await _fetch_latest_release_with_asset()
    release_url = f"https://github.com/{GITHUB_REPO}/releases"

    if not release:
        return {
            "current_version": current,
            "latest_version": current,
            "update_available": False,
            "download_url": None,
            "release_url": release_url,
            "release_notes": None,
            "can_apply_in_app": update_supported(),
            "asset_name": None,
        }

    latest = _release_version(release, asset)
    notes = release.get("body") or ""
    release_url = release.get("html_url") or release_url

    available = asset is not None and is_newer(latest, current)
    return {
        "current_version": current,
        "latest_version": latest,
        "update_available": available,
        "download_url": asset["browser_download_url"] if asset else None,
        "release_url": release_url,
        "release_notes": notes,
        "can_apply_in_app": update_supported() and available,
        "asset_name": asset["name"] if asset else None,
    }


async def _fetch_latest_release_with_asset() -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    """Pick the newest semver release that has an asset for this platform."""
    releases = await _fetch_releases()
    if not releases:
        return None, None

    best_release: dict[str, Any] | None = None
    best_asset: dict[str, Any] | None = None
    best_tuple: tuple[int, ...] = ()

    for release in releases:
        if release.get("draft"):
            continue
        asset = _pick_platform_asset(release.get("assets") or [])
        if not asset:
            continue
        ver = _release_version(release, asset)
        vt = version_tuple(ver)
        if vt > best_tuple:
            best_tuple = vt
            best_release = release
            best_asset = asset

    return best_release, best_asset


async def _fetch_releases() -> list[dict[str, Any]]:
    url = f"https://api.github.com/repos/{GITHUB_REPO}/releases"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "CloakBrowser-Manager"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(url, headers=headers, params={"per_page": 30})
            if resp.status_code == 404:
                return []
            resp.raise_for_status()
            data = resp.json()
            return data if isinstance(data, list) else []
    except Exception as exc:
        logger.warning("Update check failed: %s", exc)
        return []


async def download_release_archive(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    async with httpx.AsyncClient(timeout=httpx.Timeout(60.0, read=600.0)) as client:
        async with client.stream("GET", url, follow_redirects=True) as resp:
            resp.raise_for_status()
            with dest.open("wb") as f:
                async for chunk in resp.aiter_bytes(chunk_size=1024 * 256):
                    f.write(chunk)


def _find_payload_root(extract_dir: Path) -> Path:
    """Zip contains 'CloakBrowser Manager/' or files at top level."""
    nested = extract_dir / "CloakBrowser Manager"
    if nested.is_dir() and (nested / EXE_NAME).is_file():
        return nested
    if (extract_dir / EXE_NAME).is_file():
        return extract_dir
    children = [p for p in extract_dir.iterdir() if p.is_dir()]
    if len(children) == 1 and (children[0] / EXE_NAME).is_file():
        return children[0]
    raise RuntimeError("更新包格式无效：找不到程序目录")


def _find_mac_app_bundle(extract_dir: Path) -> Path:
    direct = extract_dir / APP_BUNDLE_NAME
    if direct.is_dir():
        return direct
    for path in extract_dir.rglob(APP_BUNDLE_NAME):
        if path.is_dir():
            return path
    raise RuntimeError("更新包格式无效：找不到 .app")


def _ps_path(path: Path) -> str:
    return str(path.resolve()).replace("'", "''")


def _sh_path(path: Path) -> str:
    return str(path.resolve()).replace("'", "'\\''")


async def prepare_windows_update(download_url: str, version: str) -> Path:
    """Download zip and write updater script; returns path to updater .ps1."""
    if not update_supported() or sys.platform != "win32":
        raise RuntimeError("当前环境不支持 Windows 应用内更新")

    work = Path(tempfile.gettempdir()) / "cloakbrowser-manager-update"
    work.mkdir(parents=True, exist_ok=True)
    zip_path = work / f"update-{version}.zip"
    extract_dir = work / f"extract-{version}"

    await download_release_archive(download_url, zip_path)

    if extract_dir.exists():
        import shutil

        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True)

    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(extract_dir)

    payload = _find_payload_root(extract_dir)
    target = install_dir()
    pid = os.getpid()
    updater = work / "apply-update.ps1"

    src = _ps_path(payload)
    dst = _ps_path(target)
    work_ps = _ps_path(work)

    script = f"""$ErrorActionPreference = 'Stop'
$pidToWait = {pid}
$src = '{src}'
$dst = '{dst}'
$exe = Join-Path $dst '{EXE_NAME}'

Write-Host 'Waiting for CloakBrowser Manager to exit...'
try {{ Wait-Process -Id $pidToWait -Timeout 120 }} catch {{ }}

Start-Sleep -Seconds 2

Write-Host "Updating in $dst ..."
if (-not (Test-Path $dst)) {{ New-Item -ItemType Directory -Path $dst -Force | Out-Null }}

$robolog = Join-Path '{work_ps}' 'robocopy.log'
& robocopy $src $dst /MIR /R:2 /W:2 /NFL /NDL /NJH /NJS | Out-File -FilePath $robolog -Encoding utf8
$code = $LASTEXITCODE
if ($code -ge 8) {{
  Write-Host "Robocopy failed with exit code $code"
  exit $code
}}

Write-Host 'Starting updated application...'
Start-Process -FilePath $exe -WorkingDirectory $dst
"""
    updater.write_text(script, encoding="utf-8")
    return updater


async def prepare_macos_update(download_url: str, version: str) -> Path:
    """Download zip and write updater shell script; returns path to apply-update.sh."""
    if not update_supported() or sys.platform != "darwin":
        raise RuntimeError("当前环境不支持 macOS 应用内更新")

    work = Path(tempfile.gettempdir()) / "cloakbrowser-manager-update"
    work.mkdir(parents=True, exist_ok=True)
    zip_path = work / f"update-{version}.zip"
    extract_dir = work / f"extract-{version}"

    await download_release_archive(download_url, zip_path)

    if extract_dir.exists():
        import shutil

        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True)

    with zipfile.ZipFile(zip_path, "r") as zf:
        zf.extractall(extract_dir)

    payload = _find_mac_app_bundle(extract_dir)
    target = mac_app_bundle()
    pid = os.getpid()
    updater = work / "apply-update.sh"

    src = _sh_path(payload)
    dst = _sh_path(target)

    script = f"""#!/bin/bash
set -euo pipefail
pid={pid}
src='{src}'
dst='{dst}'

echo "Waiting for CloakBrowser Manager to exit..."
for _ in $(seq 1 120); do
  if ! kill -0 "$pid" 2>/dev/null; then
    break
  fi
  sleep 1
done
sleep 2

echo "Updating $dst ..."
ditto "$src" "$dst"

echo "Starting updated application..."
open "$dst"
"""
    updater.write_text(script, encoding="utf-8", newline="\n")
    updater.chmod(0o755)
    return updater


async def prepare_platform_update(download_url: str, version: str) -> Path:
    if sys.platform == "win32":
        return await prepare_windows_update(download_url, version)
    if sys.platform == "darwin":
        return await prepare_macos_update(download_url, version)
    raise RuntimeError("当前平台不支持应用内更新")


def launch_updater_and_exit(updater_script: Path) -> None:
    """Spawn detached updater and terminate this process."""
    if sys.platform == "win32":
        creationflags = getattr(subprocess, "CREATE_NEW_CONSOLE", 0)
        subprocess.Popen(
            [
                "powershell.exe",
                "-NoProfile",
                "-ExecutionPolicy",
                "Bypass",
                "-File",
                str(updater_script),
            ],
            creationflags=creationflags,
            close_fds=True,
        )
    elif sys.platform == "darwin":
        subprocess.Popen(
            ["/bin/bash", str(updater_script)],
            start_new_session=True,
            close_fds=True,
        )
    else:
        raise RuntimeError("当前平台不支持应用内更新")
    logger.info("Updater launched, exiting for in-place update")
    os._exit(0)
