#!/usr/bin/env python3
"""PyInstaller entry point — must use absolute imports (no package context)."""

from __future__ import annotations

import sys
from pathlib import Path


def _ensure_stdio() -> None:
    """Windowed PyInstaller builds (console=False) set stdout/stderr to None on Windows."""
    import os

    if sys.stdout is None:
        sys.stdout = open(os.devnull, "w", encoding="utf-8")  # type: ignore[assignment]
    if sys.stderr is None:
        sys.stderr = open(os.devnull, "w", encoding="utf-8")  # type: ignore[assignment]


def _bootstrap() -> None:
    if getattr(sys, "frozen", False):
        meipass = Path(getattr(sys, "_MEIPASS"))
        candidates = [meipass, meipass.parent, Path(sys.executable).resolve().parent]
        for base in candidates:
            if (base / "backend").is_dir():
                root = str(base)
                if root not in sys.path:
                    sys.path.insert(0, root)
                return
        if str(meipass) not in sys.path:
            sys.path.insert(0, str(meipass))


_bootstrap()
_ensure_stdio()

from backend.desktop import main  # noqa: E402

if __name__ == "__main__":
    main()
