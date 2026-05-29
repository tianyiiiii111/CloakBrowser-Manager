from unittest.mock import AsyncMock, patch

import pytest
from fastapi.testclient import TestClient

from backend import main


@pytest.fixture
def release_payload():
    return {
        "tag_name": "v0.2.0",
        "html_url": "https://github.com/tianyiiiii111/CloakBrowser-Manager/releases/tag/v0.2.0",
        "body": "Test release",
        "assets": [
            {
                "name": "CloakBrowser-Manager-0.2.0-win64.zip",
                "browser_download_url": "https://example.com/app.zip",
            }
        ],
    }


def test_update_check_no_release(app_client: TestClient):
    with patch("backend.updater._fetch_latest_release", new_callable=AsyncMock, return_value=None):
        resp = app_client.get("/api/update/check")
    assert resp.status_code == 200
    data = resp.json()
    assert data["update_available"] is False


def test_update_check_newer_available(app_client: TestClient, release_payload):
    with patch("backend.updater._fetch_latest_release", new_callable=AsyncMock, return_value=release_payload):
        with patch("backend.version.app_version", return_value="0.1.0"):
            resp = app_client.get("/api/update/check")
    assert resp.status_code == 200
    data = resp.json()
    assert data["update_available"] is True
    assert data["latest_version"] == "0.2.0"
    assert data["download_url"] == "https://example.com/app.zip"


def test_update_apply_not_supported(app_client: TestClient):
    with patch("backend.updater.update_supported", return_value=False):
        resp = app_client.post("/api/update/apply")
    assert resp.status_code == 400
