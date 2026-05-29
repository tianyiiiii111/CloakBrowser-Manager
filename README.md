<p align="center">
<img src="https://i.imgur.com/cqkp6fG.png" width="500" alt="CloakBrowser">
</p>

<h3 align="center">Browser Profile Manager for CloakBrowser</h3>

<p align="center">
Create, manage, and launch isolated browser profiles with unique fingerprints.<br>
Free, self-hosted alternative to Multilogin, GoLogin, and AdsPower.
</p>

<p align="center">
<a href="https://github.com/CloakHQ/CloakBrowser"><img src="https://img.shields.io/github/stars/cloakhq/cloakbrowser?label=CloakBrowser" alt="Stars"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License"></a>
</p>

---

<p align="center">
<img src="https://i.imgur.com/twdX81Q.png" width="800" alt="CloakBrowser Manager — Browser View">
<br>
<img src="https://i.imgur.com/XFYn1qY.png" width="800" alt="CloakBrowser Manager — Profile Settings">
</p>

Each profile is an isolated CloakBrowser instance with its own fingerprint, proxy, cookies, and session data. Profiles persist across restarts.

## Quick start

**macOS** — download the DMG for your Mac from [Releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases):

| Mac | Installer |
|-----|-----------|
| Apple Silicon (M1/M2/M3/M4) | `CloakBrowser-Manager-<version>-arm64.dmg` |
| Intel (x86_64) | `CloakBrowser-Manager-<version>-x86_64.dmg` |

**Windows** — install from `CloakBrowser-Manager-<version>-Setup.exe`, or build from source.

```bash
git clone https://github.com/tianyiiiii111/CloakBrowser-Manager.git
cd CloakBrowser-Manager
./scripts/build-macos.sh          # macOS (native arch)
# ./scripts/build-macos.sh --all-archs   # both arm64 + Intel DMGs
# .\scripts\build-windows.ps1     # Windows (PowerShell)
```

预编译安装包见 [Releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)（macOS 两个 `.dmg`、Windows `Setup.exe`）。

For local development without packaging, see [DEVELOPMENT.md](DEVELOPMENT.md).

> **Early alpha** — this project is under active development. Expect bugs. If you find one, please [open an issue](https://github.com/tianyiiiii111/CloakBrowser-Manager/issues).

## Why Not Just Use a VPN?

A VPN only changes your IP. Incognito only clears cookies. Chrome profiles share the same hardware fingerprint underneath. Platforms use 50+ signals to link your accounts — canvas, WebGL, audio, GPU, fonts, screen size, timezone.

Each CloakBrowser profile generates a completely different device identity. To the website, each profile looks like a different computer.

| Solution | What it changes | Accounts linked? |
|----------|----------------|-----------------|
| VPN | IP address only | Yes — same fingerprint |
| Incognito | Clears cookies | Yes — same fingerprint |
| Chrome profiles | Separate bookmarks/cookies | Yes — same hardware fingerprint |
| **CloakBrowser** | **Everything — full device identity per profile** | **No** |

## Features

- **Profile management** — create, edit, delete browser profiles with unique fingerprints
- **Per-profile settings** — fingerprint seed, proxy, timezone, locale, user agent, screen size, platform
- **One-click launch/stop** — each profile runs as an isolated CloakBrowser instance
- **Session persistence** — cookies, localStorage, and cache survive browser restarts
- **Native browser windows** — each profile opens in a separate CloakBrowser window (macOS / Windows)
- **Playwright/Puppeteer API** — connect to any running profile programmatically via CDP
- **Optional authentication** — protect the UI and API with a single token
- **Powered by CloakBrowser** — 32 source-level C++ patches, passes Cloudflare Turnstile, 0.9 reCAPTCHA v3 score

## Stack

- **Backend**: FastAPI (Python)
- **Frontend**: React + Tailwind CSS
- **Desktop**: PyInstaller + pywebview (macOS `arm64` / `x86_64` `.dmg`, Windows Setup `.exe`)
- **Database**: SQLite (`~/.cloakbrowser-manager/`)
- **Browser engine**: [CloakBrowser](https://github.com/CloakHQ/CloakBrowser) (stealth Chromium binary)

## Requirements

- **macOS** 12+ (Apple Silicon or Intel) or **Windows** 10/11
- ~2 GB disk (app + CloakBrowser binary, downloaded on first launch)
- ~512 MB RAM per running profile
- Windows: [WebView2](https://developer.microsoft.com/microsoft-edge/webview2/) (usually preinstalled)

## Development

See [DEVELOPMENT.md](DEVELOPMENT.md) and [PACKAGING.md](PACKAGING.md).

## Automation API

Every running profile exposes a CDP (Chrome DevTools Protocol) endpoint. Connect Playwright or Puppeteer to automate a profile while using the native browser window.

```python
from playwright.async_api import async_playwright

async with async_playwright() as pw:
    browser = await pw.chromium.connect_over_cdp(
        "http://127.0.0.1:28765/api/profiles/<profile-id>/cdp"
    )
    page = browser.contexts[0].pages[0]
    await page.goto("https://example.com")
```

The CDP URL is shown in the manager UI when a profile is running (port may vary).

## Authentication

By default, there is no authentication (ideal for local use). To protect the UI and API, set `AUTH_TOKEN` before starting the app:

```bash
export AUTH_TOKEN=your-secret-token
python -m backend.desktop
```

When `AUTH_TOKEN` is set:

- The web UI shows a login page. Enter the token to unlock.
- API consumers pass the token via `Authorization: Bearer <token>` header.
- WebSocket connections (CDP proxy) are authenticated via the login cookie.
- The `/api/status` endpoint remains unauthenticated.

> **Note**: The auth token is transmitted in cleartext over HTTP. If you expose the Manager on a network, use HTTPS via a reverse proxy.

## License

- **This application** (GUI source code) — MIT. See [LICENSE](LICENSE).
- **CloakBrowser binary** (compiled Chromium) — free to use, no redistribution. See [BINARY-LICENSE.md](BINARY-LICENSE.md).

The GUI application requires the CloakBrowser Chromium binary to function. The binary is automatically downloaded on first launch and is governed by its own license terms. If you fork or redistribute this application, your users must comply with the [CloakBrowser Binary License](BINARY-LICENSE.md).

## Contributing

Contributions are welcome. Please [open an issue](https://github.com/CloakHQ/CloakBrowser-Manager/issues) first to discuss what you'd like to change.

## Links

- **CloakBrowser** — [github.com/CloakHQ/CloakBrowser](https://github.com/CloakHQ/CloakBrowser)
- **Website** — [cloakbrowser.dev](https://cloakbrowser.dev)
- **Releases** — [github.com/tianyiiiii111/CloakBrowser-Manager/releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)
- **Bug reports** — [GitHub Issues](https://github.com/tianyiiiii111/CloakBrowser-Manager/issues)
- **Contact** — cloakhq@pm.me
