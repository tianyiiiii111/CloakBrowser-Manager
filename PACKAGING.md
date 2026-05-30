# 分发包构建

## 产物一览

| 平台 | 文件名 | 说明 |
|------|--------|------|
| macOS Intel | `CloakBrowser-Manager-<版本>-x86_64.dmg` | **免安装**：打开 DMG 后双击 `.app` 即用 |
| Windows | `CloakBrowser-Manager-<版本>-win64.zip` | **免安装便携版**，解压即用 |

Release 页仅发布以上两个文件。

macOS DMG 内包含：

- `CloakBrowser Manager.app` — 主程序
- `CloakBrowser Manager.command` — 首次若被 Gatekeeper 拦截，可改点此项启动
- `使用说明.txt`

用户数据与配置保存在 `~/.cloakbrowser-manager/`，与程序位置无关。

## 本地构建

### macOS Intel（x86_64）

```bash
chmod +x scripts/build-macos.sh
./scripts/build-macos.sh

# 仅重打 DMG（需已有 dist-x86_64/）
./scripts/build-macos.sh -p
```

在 Apple Silicon Mac 上会通过 Rosetta 构建 x86_64 包。

### Windows（PowerShell）

```powershell
.\scripts\build-windows.ps1

# 仅重打 zip（需已有 dist\CloakBrowser Manager\）
.\scripts\build-windows.ps1 -PackageOnly
```

构建流程：前端 `npm ci && build` → Python venv → PyInstaller → 写入 `version.txt` → **codesign** → 打便携 DMG / zip → 可选 **notarize**（DMG）。

## macOS 签名与公证

从 GitHub 下载的未签名应用可能被 Gatekeeper 拦截，提示「已损坏，无法打开」（并非文件损坏）。

**用户侧**（免安装）：

1. 打开 DMG，直接双击 `CloakBrowser Manager.app`；可将 `.app` 拖到任意文件夹
2. 若被拦截，改点 `CloakBrowser Manager.command`
3. 或在终端执行：`xattr -cr "/path/to/CloakBrowser Manager.app"`

**维护者侧**（可选）：见下方 Secrets 表，配置后 CI 会签名并公证 DMG。

| Secret | 说明 |
|--------|------|
| `MACOS_CERTIFICATE_P12` | Developer ID 证书（`.p12`）Base64 |
| `MACOS_CERTIFICATE_PASSWORD` | 证书密码 |
| `MACOS_CODESIGN_IDENTITY` | 如 `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | Apple ID 邮箱 |
| `APPLE_TEAM_ID` | 10 位 Team ID |
| `APPLE_APP_SPECIFIC_PASSWORD` | 应用专用密码（用于 notarytool） |

## 版本号

1. 修改 `pyproject.toml` 中的 `version`
2. 构建时写入 `version.txt`；PyInstaller 也会将版本打入包内
3. 发布标签须与版本一致，例如 `version = "0.2.0"` → `git tag v0.2.0`
4. 更新检测以资源文件名中的版本为准

## GitHub Actions 发布

```bash
git tag v0.2.0
git push origin v0.2.0
```

CI 矩阵：

- `macos-latest`（x64 Python）→ `-x86_64.dmg`
- `windows-latest` → `-win64.zip`

## 应用内更新

| 平台 | 更新包 |
|------|--------|
| Windows 便携版 | `*-win64.zip` |
| macOS Intel 便携版 | `*-x86_64.dmg` |

macOS 更新时下载 DMG、挂载后覆盖当前 `.app` 并重启。

## 环境要求

| 平台 | 依赖 |
|------|------|
| macOS | Python 3.12+（x86_64）、Node 20+ |
| Windows | Python 3.12+、Node 20+ |

桌面打包额外依赖见 `packaging/requirements-desktop.txt`。
