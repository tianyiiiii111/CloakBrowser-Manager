# PyInstaller spec — build on target OS (macOS or Windows).
# Usage (from repo root): pyinstaller packaging/cloakbrowser-manager.spec --noconfirm

import os
import sys
from pathlib import Path

block_cipher = None

# Set by scripts/build-macos.sh: arm64 | x86_64 (PyInstaller disallows --target-arch with .spec)
_target_arch = os.environ.get("PYINSTALLER_TARGET_ARCH", "").strip() or None
if _target_arch and sys.platform == "darwin":
    if _target_arch not in ("arm64", "x86_64"):
        raise SystemExit(f"Invalid PYINSTALLER_TARGET_ARCH: {_target_arch}")
elif _target_arch and sys.platform != "darwin":
    _target_arch = None

# SPECPATH is the packaging/ directory containing this spec file
root = Path(SPECPATH).resolve().parent
frontend_dist = root / "frontend" / "dist"
if not (frontend_dist / "index.html").is_file():
    raise SystemExit(
        "Missing frontend/dist/index.html — run: cd frontend && npm install && npm run build"
    )

datas = [(str(frontend_dist), str(Path("frontend") / "dist"))]

hiddenimports = [
    "backend",
    "backend.main",
    "backend.database",
    "backend.browser_manager",
    "backend.models",
    "backend.paths",
    "uvicorn",
    "uvicorn.logging",
    "uvicorn.loops",
    "uvicorn.loops.auto",
    "uvicorn.protocols",
    "uvicorn.protocols.http",
    "uvicorn.protocols.http.auto",
    "uvicorn.protocols.websockets",
    "uvicorn.protocols.websockets.auto",
    "uvicorn.lifespan",
    "uvicorn.lifespan.on",
    "websockets",
    "websockets.legacy",
    "websockets.legacy.server",
    "cloakbrowser",
    "cloakbrowser.config",
    "cloakbrowser.download",
    "webview",
    "webview.platforms",
    "webview.platforms.cocoa",
    "webview.platforms.winforms",
    "webview.platforms.edgechromium",
]

a = Analysis(
    [str(root / "run_desktop.py")],
    pathex=[str(root)],
    binaries=[],
    datas=datas,
    hiddenimports=hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[str(Path(SPECPATH) / "pyi_rthook_pkgpath.py")],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name="CloakBrowser Manager",
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=_target_arch,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.zipfiles,
    a.datas,
    strip=False,
    upx=False,
    upx_exclude=[],
    name="CloakBrowser Manager",
)

if sys.platform == "darwin":
    app = BUNDLE(
        coll,
        name="CloakBrowser Manager.app",
        icon=None,
        bundle_identifier="com.cloakhq.cloakbrowser-manager",
    )
