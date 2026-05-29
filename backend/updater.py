"""In-app updates (Windows portable). Checks GitHub Releases and applies zip in place."""

from __future__ import annotations

import logging
import os
import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from typing import Any

import httpx

from .paths import is_frozen
from .version import app_version, is_newer

logger = logging.getLogger("cloakbrowser.manager.updater")

# Override: CBM_UPDATE_REPO=owner/name
GITHUB_REPO = os.environ.get("CBM_UPDATE_REPO", "tianyiiiii111/CloakBrowser-Manager")
WIN_ZIP_RE = re.compile(
    r"^CloakBrowser-Manager-\d+\.\d+\.\d+-win64\.zip$", re.IGNORECASE
)
EXE_NAME = "CloakBrowser Manager.exe"


def update_supported() -> bool:
    return sys.platform == "win32" and is_frozen()


def install_dir() -> Path:
    return Path(sys.executable).resolve().parent


async def check_for_update() -> dict[str, Any]:
    current = app_version()
    release = await _fetch_latest_release()
    if not release:
        return {
            "current_version": current,
            "latest_version": current,
            "update_available": False,
            "download_url": None,
            "release_url": f"https://github.com/{GITHUB_REPO}/releases",
            "release_notes": None,
            "can_apply_in_app": update_supported(),
            "asset_name": None,
        }

    tag = release.get("tag_name", "")
    latest = tag.lstrip("v") if tag else current
    notes = release.get("body") or ""
    release_url = release.get("html_url") or f"https://github.com/{GITHUB_REPO}/releases"
    asset = _pick_windows_asset(release.get("assets") or [])

    available = is_newer(latest, current) and asset is not None
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


async def _fetch_latest_release() -> dict[str, Any] | None:
    url = f"https://api.github.com/repos/{GITHUB_REPO}/releases/latest"
    headers = {"Accept": "application/vnd.github+json", "User-Agent": "CloakBrowser-Manager"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.get(url, headers=headers)
            if resp.status_code == 404:
                return None
            resp.raise_for_status()
            return resp.json()
    except Exception as exc:
        logger.warning("Update check failed: %s", exc)
        return None


def _pick_windows_asset(assets: list[dict[str, Any]]) -> dict[str, Any] | None:
    for asset in assets:
        name = asset.get("name", "")
        if WIN_ZIP_RE.match(name):
            return asset
    return None


async def download_release_zip(url: str, dest: Path) -> None:
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


def _ps_path(path: Path) -> str:
    return str(path.resolve()).replace("'", "''")


async def prepare_windows_update(download_url: str, version: str) -> Path:
    """Download zip and write updater script; returns path to updater .ps1."""
    if not update_supported():
        raise RuntimeError("当前环境不支持应用内更新")

    work = Path(tempfile.gettempdir()) / "cloakbrowser-manager-update"
    work.mkdir(parents=True, exist_ok=True)
    zip_path = work / f"update-{version}.zip"
    extract_dir = work / f"extract-{version}"

    await download_release_zip(download_url, zip_path)

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


def launch_updater_and_exit(updater_script: Path) -> None:
    """Spawn detached updater and terminate this process."""
    creationflags = 0
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
    logger.info("Updater launched, exiting for in-place update")
    os._exit(0)
