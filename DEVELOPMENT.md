# 本地开发

## 环境要求

- Python 3.12+
- Node.js 20+
- macOS 或 Windows（原生窗口与打包需在对应系统上执行）

## 桌面模式（推荐）

单窗口桌面应用（pywebview + 内嵌前端）：

```bash
cd frontend && npm install && npm run build
cd ..
python3 -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r backend/requirements.txt pywebview
python -m backend.desktop
```

首次启动会从网络下载 CloakBrowser Chromium 到 `~/.cloakbrowser`（或 `%USERPROFILE%\.cloakbrowser`）。

## 前后端分离（前端热更新）

```bash
# 终端 1 — API
source .venv/bin/activate
pip install -r backend/requirements.txt
uvicorn backend.main:app --reload --port 8080

# 终端 2 — 前端
cd frontend && npm install && npm run dev
```

浏览器打开 http://localhost:5173（Vite 代理到 8080）。

## 打包分发

| 平台 | 命令 | 产物 |
|------|------|------|
| macOS Intel | `./scripts/build-macos.sh` | `dist/CloakBrowser-Manager-<版本>-x86_64.dmg` + `.zip` |
| Windows | `.\scripts\build-windows.ps1` | `dist/CloakBrowser-Manager-<版本>-win64.zip` |

仅重打安装包（跳过 frontend / PyInstaller，需已有 `dist/` 构建结果）：

```bash
./scripts/build-macos.sh -p
.\scripts\build-windows.ps1 -PackageOnly
```

详细说明见 [PACKAGING.md](PACKAGING.md)。

### 发布到 GitHub Releases

```bash
# 1. 修改 pyproject.toml 中的 version
# 2. 打标签并推送（CI 自动构建 macOS Intel DMG/zip + Windows zip）
git tag v0.2.0
git push origin v0.2.0
```

Windows 发布包须为 `CloakBrowser-Manager-<版本>-win64.zip`，应用内更新才会识别。

## 应用内更新（开发说明）

- **API**：`GET /api/update/check`、`POST /api/update/apply`
- **逻辑**：`backend/updater.py`（Windows 便携版、macOS Intel 打包版、`sys.frozen` 为真时可一键更新）
- **版本号**：开发时读 `pyproject.toml`；打包后读 `version.txt`（exe 同目录或 `.app/Contents/MacOS/`）
- **自定义仓库**：`CBM_UPDATE_REPO=owner/name`

macOS Intel 与 Windows 均支持一键覆盖安装；开发模式或未打包时仅检查版本。

## 数据目录

默认：`~/.cloakbrowser-manager/`（Windows：`%USERPROFILE%\.cloakbrowser-manager\`）

- `profiles.db` — 配置数据库
- `profiles/<id>/` — 各配置的 Chromium 用户数据

可通过环境变量 `DATA_DIR` 覆盖。

## 可选鉴权

```bash
export AUTH_TOKEN=your-secret-token
python -m backend.desktop
```

## 测试

```bash
source .venv/bin/activate
pip install -r backend/requirements.txt pytest
pytest backend/tests -q
```
