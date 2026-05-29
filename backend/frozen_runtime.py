"""Runtime setup for PyInstaller frozen desktop builds (Windows / macOS)."""

from __future__ import annotations

import asyncio
import os
import sys
from pathlib import Path


def is_frozen() -> bool:
    return bool(getattr(sys, "frozen", False))


def configure() -> None:
    if not is_frozen():
        return

    _ensure_stdio()

    if sys.platform == "win32":
        import multiprocessing

        multiprocessing.freeze_support()
        # Playwright async subprocess requires ProactorEventLoop on Windows.
        asyncio.set_event_loop_policy(asyncio.WindowsProactorEventLoopPolicy())

    _configure_playwright_driver()
    os.environ.setdefault("CLOAKBROWSER_CACHE_DIR", str(Path.home() / ".cloakbrowser"))


def _ensure_stdio() -> None:
    """Windowed PyInstaller builds set stdout/stderr to None."""
    if sys.stdout is None:
        sys.stdout = open(os.devnull, "w", encoding="utf-8")  # type: ignore[assignment]
    if sys.stderr is None:
        sys.stderr = open(os.devnull, "w", encoding="utf-8")  # type: ignore[assignment]


def _configure_playwright_driver() -> None:
    """Point Playwright at the driver bundled under _MEIPASS (node + cli.js)."""
    meipass = Path(getattr(sys, "_MEIPASS"))  # type: ignore[attr-defined]
    driver = meipass / "playwright" / "driver"
    node = driver / ("node.exe" if sys.platform == "win32" else "node")
    if node.is_file():
        os.environ.setdefault("PLAYWRIGHT_NODEJS_PATH", str(node))
    # CloakBrowser provides Chromium; only the Playwright driver is needed.
    os.environ.setdefault("PLAYWRIGHT_BROWSERS_PATH", "0")
