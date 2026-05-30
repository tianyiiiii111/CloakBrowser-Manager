<p align="center">
<img src="https://i.imgur.com/cqkp6fG.png" width="500" alt="CloakBrowser">
</p>

<h3 align="center">CloakBrowser 浏览器配置文件管理器</h3>

<p align="center">
创建、管理并启动具有独立指纹的隔离浏览器配置文件。<br>
免费、可自托管，可作为 Multilogin、GoLogin、AdsPower 的替代方案。
</p>

<p align="center">
<a href="https://github.com/CloakHQ/CloakBrowser"><img src="https://img.shields.io/github/stars/cloakhq/cloakbrowser?label=CloakBrowser" alt="Stars"></a>
<a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue" alt="License"></a>
</p>

---

<p align="center">
<img src="https://i.imgur.com/twdX81Q.png" width="800" alt="CloakBrowser Manager — 浏览器视图">
<br>
<img src="https://i.imgur.com/XFYn1qY.png" width="800" alt="CloakBrowser Manager — 配置文件设置">
</p>

每个配置文件都是独立的 CloakBrowser 实例，拥有各自的指纹、代理、Cookie 和会话数据，重启后仍会保留。

## 快速开始

**macOS Intel** — 下载 `CloakBrowser-Manager-<version>-x86_64.dmg`，打开后**直接双击** `CloakBrowser Manager.app` 即可运行（免安装，无需复制到「应用程序」）。若首次被系统拦截，可改点 DMG 内的 `CloakBrowser Manager.command`。

**Windows** — 下载并解压 `CloakBrowser-Manager-<version>-win64.zip`（免安装便携版），运行其中的 `CloakBrowser Manager.exe`。

```bash
git clone https://github.com/tianyiiiii111/CloakBrowser-Manager.git
cd CloakBrowser-Manager
./scripts/build-macos.sh          # macOS Intel（x86_64）
# .\scripts\build-windows.ps1     # Windows（PowerShell）
```

预编译安装包见 [Releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)（macOS Intel `.dmg`、Windows 便携 `.zip`）。

不打包、仅本地开发请参阅 [DEVELOPMENT.md](DEVELOPMENT.md)。

> **早期测试版** — 项目仍在积极开发中，可能存在缺陷。发现问题请 [提交 Issue](https://github.com/tianyiiiii111/CloakBrowser-Manager/issues)。

## 为什么光用 VPN 不够？

VPN 只能改 IP；无痕模式只清 Cookie；Chrome 多配置文件底层仍共享同一硬件指纹。平台会用 50 多种信号关联账号——Canvas、WebGL、音频、GPU、字体、屏幕尺寸、时区等。

每个 CloakBrowser 配置文件都会生成完全不同的设备身份，对网站而言就像不同的电脑。

| 方案 | 改变的内容 | 账号会被关联？ |
|------|------------|----------------|
| VPN | 仅 IP 地址 | 会 — 指纹相同 |
| 无痕模式 | 清除 Cookie | 会 — 指纹相同 |
| Chrome 配置文件 | 独立书签/Cookie | 会 — 硬件指纹相同 |
| **CloakBrowser** | **全部 — 每个配置文件独立设备身份** | **不会** |

## 功能

- **配置文件管理** — 创建、编辑、删除具有独立指纹的浏览器配置
- **按配置定制** — 指纹种子、代理、时区、语言、User-Agent、屏幕尺寸、平台等
- **一键启动/停止** — 每个配置以独立 CloakBrowser 实例运行
- **会话持久化** — Cookie、localStorage、缓存随浏览器重启保留
- **原生浏览器窗口** — 每个配置在独立 CloakBrowser 窗口中打开（macOS / Windows）
- **Playwright/Puppeteer API** — 通过 CDP 以编程方式连接任意运行中的配置
- **可选鉴权** — 使用单一 Token 保护 UI 与 API
- **应用内更新** — Windows 便携版与 macOS Intel 版支持右上角一键检查并安装，无需手动下载
- **基于 CloakBrowser** — 32 处 C++ 源码级补丁，可通过 Cloudflare Turnstile，reCAPTCHA v3 约 0.9 分

## 技术栈

- **后端**：FastAPI（Python）
- **前端**：React + Tailwind CSS
- **桌面端**：PyInstaller + pywebview（macOS Intel 免安装 `.dmg`，Windows 便携 `.zip`）
- **数据库**：SQLite（`~/.cloakbrowser-manager/`）
- **浏览器引擎**：[CloakBrowser](https://github.com/CloakHQ/CloakBrowser)（隐身 Chromium 二进制）

## 系统要求

- **macOS** 12+（Intel Mac，或在 Apple Silicon 上通过 Rosetta 运行 x86_64 版）或 **Windows** 10/11
- 约 2 GB 磁盘（应用 + CloakBrowser 二进制，首次启动时下载）
- 每个运行中的配置约 512 MB 内存
- Windows：[WebView2](https://developer.microsoft.com/microsoft-edge/webview2/)（通常已预装）

## 更新

| 平台 | 方式 |
|------|------|
| **Windows** | 解压便携 zip 后使用。点击界面右上角 **刷新图标** →「一键更新并重启」。更新前会关闭所有运行中的配置。 |
| **macOS Intel** | 打开 DMG 后直接使用 `.app`。右上角 **刷新图标** →「一键更新并重启」。 |

> 请勿将程序放在需要管理员权限的目录（如 `C:\Program Files`），否则 Windows 一键更新可能因无写入权限而失败。建议解压到用户目录，如 `D:\Apps\CloakBrowser-Manager\`。

## 开发

请参阅 [DEVELOPMENT.md](DEVELOPMENT.md) 与 [PACKAGING.md](PACKAGING.md)。

## 自动化 API

每个运行中的配置都会暴露 CDP（Chrome DevTools Protocol）端点。可在使用原生浏览器窗口的同时，用 Playwright 或 Puppeteer 连接并自动化操作。

```python
from playwright.async_api import async_playwright

async with async_playwright() as pw:
    browser = await pw.chromium.connect_over_cdp(
        "http://127.0.0.1:28765/api/profiles/<profile-id>/cdp"
    )
    page = browser.contexts[0].pages[0]
    await page.goto("https://example.com")
```

配置运行后，管理界面会显示 CDP 地址（端口可能不同）。

## 鉴权

默认无需鉴权（适合本地使用）。若要保护 UI 与 API，启动前设置 `AUTH_TOKEN`：

```bash
export AUTH_TOKEN=your-secret-token
python -m backend.desktop
```

设置 `AUTH_TOKEN` 后：

- Web UI 显示登录页，输入 Token 后解锁。
- API 调用方通过 `Authorization: Bearer <token>` 请求头传递 Token。
- WebSocket（CDP 代理）通过登录 Cookie 鉴权。
- `/api/status` 端点仍无需鉴权。

> **注意**：Token 经 HTTP 明文传输。若在网络上暴露管理器，请通过反向代理使用 HTTPS。

## 许可证

- **本应用**（GUI 源代码）— MIT，见 [LICENSE](LICENSE)。
- **CloakBrowser 二进制**（编译后的 Chromium）— 可免费使用，不可再分发，见 [BINARY-LICENSE.md](BINARY-LICENSE.md)。

GUI 依赖 CloakBrowser Chromium 二进制才能运行；首次启动会自动下载，并受其独立许可条款约束。若 Fork 或再分发本应用，用户须遵守 [CloakBrowser 二进制许可](BINARY-LICENSE.md)。

## 贡献

欢迎贡献。请先 [提交 Issue](https://github.com/tianyiiiii111/CloakBrowser-Manager/issues) 讨论拟修改内容。

## 链接

- **CloakBrowser** — [github.com/CloakHQ/CloakBrowser](https://github.com/CloakHQ/CloakBrowser)
- **官网** — [cloakbrowser.dev](https://cloakbrowser.dev)
- **发布页** — [github.com/tianyiiiii111/CloakBrowser-Manager/releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)
- **问题反馈** — [GitHub Issues](https://github.com/tianyiiiii111/CloakBrowser-Manager/issues)
- **联系** — cloakhq@pm.me
