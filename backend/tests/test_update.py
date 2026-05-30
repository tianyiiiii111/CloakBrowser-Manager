import sys
from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient


def _platform_asset_name(version: str) -> str:
    if sys.platform == "darwin":
        return f"CloakBrowser-Manager-{version}-x86_64.dmg"
    return f"CloakBrowser-Manager-{version}-win64.zip"


@pytest.fixture
def release_payload():
    return {
        "tag_name": "v0.2.0",
        "html_url": "https://github.com/tianyiiiii111/CloakBrowser-Manager/releases/tag/v0.2.0",
        "body": "Test release",
        "draft": False,
        "assets": [
            {
                "name": _platform_asset_name("0.2.0"),
                "browser_download_url": "https://example.com/app.bin",
            }
        ],
    }


def test_update_check_no_release(app_client: TestClient):
    with patch("backend.updater._fetch_releases", new_callable=AsyncMock, return_value=[]):
        resp = app_client.get("/api/update/check")
    assert resp.status_code == 200
    data = resp.json()
    assert data["update_available"] is False


def test_update_check_newer_available(app_client: TestClient, release_payload):
    with patch("backend.updater._fetch_releases", new_callable=AsyncMock, return_value=[release_payload]):
        with patch("backend.updater.app_version", return_value="0.1.0"):
            resp = app_client.get("/api/update/check")
    assert resp.status_code == 200
    data = resp.json()
    assert data["update_available"] is True
    assert data["latest_version"] == "0.2.0"
    assert data["download_url"] == "https://example.com/app.bin"


def test_update_check_uses_asset_version_over_mismatched_tag(app_client: TestClient):
    release = {
        "tag_name": "v9.9.9",
        "html_url": "https://example.com/r",
        "body": "",
        "draft": False,
        "assets": [
            {
                "name": _platform_asset_name("0.2.0"),
                "browser_download_url": "https://example.com/app.bin",
            }
        ],
    }
    with patch("backend.updater._fetch_releases", new_callable=AsyncMock, return_value=[release]):
        with patch("backend.updater.app_version", return_value="0.1.0"):
            resp = app_client.get("/api/update/check")
        data = resp.json()
        assert data["latest_version"] == "0.2.0"
    assert data["update_available"] is True


def test_update_apply_not_supported(app_client: TestClient):
    with patch("backend.updater.update_supported", return_value=False):
        resp = app_client.post("/api/update/apply")
    assert resp.status_code == 400
