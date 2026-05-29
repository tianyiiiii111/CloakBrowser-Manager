"""Application version (from pyproject.toml in dev, version.txt when frozen)."""

from __future__ import annotations

import re
import sys
from pathlib import Path

from .paths import is_frozen

_DEFAULT = "0.0.0-dev"


def app_version() -> str:
    if is_frozen():
        for base in (
            Path(sys.executable).resolve().parent,
            Path(getattr(sys, "_MEIPASS", "")),  # type: ignore[attr-defined]
        ):
            vf = base / "version.txt"
            if vf.is_file():
                return vf.read_text(encoding="utf-8").strip()

    root = Path(__file__).resolve().parent.parent
    pyproject = root / "pyproject.toml"
    if pyproject.is_file():
        for line in pyproject.read_text(encoding="utf-8").splitlines():
            m = re.match(r'^version\s*=\s*"([^"]+)"', line.strip())
            if m:
                return m.group(1)
    return _DEFAULT


def version_tuple(version: str | None = None) -> tuple[int, ...]:
    v = (version or app_version()).lstrip("v")
    parts: list[int] = []
    for piece in v.split("."):
        if not piece.isdigit():
            break
        parts.append(int(piece))
    return tuple(parts) if parts else (0,)


def is_newer(candidate: str, current: str | None = None) -> bool:
    return version_tuple(candidate) > version_tuple(current)
