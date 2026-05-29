"""Desktop entry: local API server + native app window (macOS / Windows)."""

from __future__ import annotations

import logging
import os
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
import webbrowser
from pathlib import Path

try:
    from .paths import frontend_dist_dir, is_frozen
except ImportError:  # PyInstaller script entry
    from backend.paths import frontend_dist_dir, is_frozen

logger = logging.getLogger("cloakbrowser.manager.desktop")

DEFAULT_PORT = 28765
APP_TITLE = "CloakBrowser Manager"


def _find_free_port(preferred: int) -> int:
    for port in (preferred, *range(preferred + 1, preferred + 50)):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            try:
                s.bind(("127.0.0.1", port))
                return port
            except OSError:
                continue
    raise RuntimeError("No free local port for CloakBrowser Manager")


def _wait_for_server(base_url: str, timeout: float = 90.0) -> bool:
    deadline = time.monotonic() + timeout
    status_url = f"{base_url}/api/status"
    while time.monotonic() < deadline:
        try:
            with urllib.request.urlopen(status_url, timeout=2) as resp:
                if resp.status == 200:
                    return True
        except (urllib.error.URLError, TimeoutError, OSError):
            time.sleep(0.25)
    return False


def _start_uvicorn(host: str, port: int) -> tuple[threading.Thread, object]:
    import uvicorn

    os.environ.setdefault("CLOAKMANAGER_FRONTEND_DIR", str(frontend_dist_dir()))

    config = uvicorn.Config(
        "backend.main:app",
        host=host,
        port=port,
        log_level="info",
        access_log=False,
    )
    server = uvicorn.Server(config)

    def run() -> None:
        server.run()

    thread = threading.Thread(target=run, name="uvicorn", daemon=True)
    thread.start()
    return thread, server


def _open_webview(url: str) -> None:
    import webview

    window = webview.create_window(
        APP_TITLE,
        url,
        width=1280,
        height=800,
        min_size=(900, 600),
    )
    webview.start()


def _preflight() -> None:
    dist = frontend_dist_dir()
    if not (dist / "index.html").is_file():
        raise SystemExit(
            f"前端未构建，缺少 {dist / 'index.html'}。\n"
            "请先运行: cd frontend && npm install && npm run build"
        )


def main() -> None:
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(name)s %(levelname)s %(message)s",
    )

    _preflight()

    host = "127.0.0.1"
    port = _find_free_port(DEFAULT_PORT)
    base_url = f"http://{host}:{port}"

    logger.info("Starting %s at %s", APP_TITLE, base_url)
    _thread, server = _start_uvicorn(host, port)

    if not _wait_for_server(base_url):
        logger.error("Server did not become ready in time")
        server.should_exit = True
        raise SystemExit(1)

    try:
        _open_webview(base_url)
    except ImportError:
        logger.warning("pywebview not installed; opening system browser")
        webbrowser.open(base_url)
        print(f"\n{APP_TITLE} 已在浏览器中打开: {base_url}")
        print("关闭此窗口将停止服务。按 Enter 退出…")
        try:
            input()
        except KeyboardInterrupt:
            pass
    finally:
        server.should_exit = True
        _thread.join(timeout=10)
        logger.info("Shutdown complete")


if __name__ == "__main__":
    main()
