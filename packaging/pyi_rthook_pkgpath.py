"""PyInstaller runtime hook: ensure backend package is importable."""
import sys
from pathlib import Path

if getattr(sys, "frozen", False):
    meipass = Path(getattr(sys, "_MEIPASS"))
    for base in (meipass, meipass.parent, Path(sys.executable).resolve().parent):
        if (base / "backend").is_dir():
            root = str(base)
            if root not in sys.path:
                sys.path.insert(0, root)
            break
