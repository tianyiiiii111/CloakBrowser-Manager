"""Resolve application paths for dev, desktop bundle, and PyInstaller."""

from __future__ import annotations

import os
import sys
from pathlib import Path


def is_frozen() -> bool:
    return bool(getattr(sys, "frozen", False))


def app_root() -> Path:
    """Project root (dev) or PyInstaller extract dir (bundle)."""
    if is_frozen():
        return Path(getattr(sys, "_MEIPASS"))  # type: ignore[attr-defined]
    return Path(__file__).resolve().parent.parent


def frontend_dist_dir() -> Path:
    if env := os.environ.get("CLOAKMANAGER_FRONTEND_DIR"):
        return Path(env)
    return app_root() / "frontend" / "dist"
