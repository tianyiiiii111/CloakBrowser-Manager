# 分发包构建

## 产物一览

| 平台 | 文件名 | 说明 |
|------|--------|------|
| macOS Intel | `CloakBrowser-Manager-<版本>-x86_64.dmg` | 拖入「应用程序」安装 |
| macOS Intel | `CloakBrowser-Manager-<版本>-x86_64.zip` | 应用内一键更新用（与 DMG 同版本） |
| Windows | `CloakBrowser-Manager-<版本>-win64.zip` | **免安装便携版**，解压即用 |

用户数据与配置保存在 `~/.cloakbrowser-manager/`，与程序安装位置无关。

## 本地构建

### macOS Intel（x86_64）

```bash
chmod +x scripts/build-macos.sh
./scripts/build-macos.sh

# 仅重打 dmg/zip（需已有 dist-x86_64/）
./scripts/build-macos.sh -p
```

在 Apple Silicon Mac 上会通过 Rosetta 构建 x86_64 包。

### Windows（PowerShell）

```powershell
.\scripts\build-windows.ps1

# 仅重打 zip（需已有 dist\CloakBrowser Manager\）
.\scripts\build-windows.ps1 -PackageOnly
```

构建流程：前端 `npm ci && build` → Python venv → PyInstaller → 写入 `version.txt` → 生成 zip（Windows / macOS）→ macOS 再打 DMG。

输出目录示例：

```
dist/
  CloakBrowser-Manager-0.2.0-x86_64.dmg
  CloakBrowser-Manager-0.2.0-x86_64.zip
  CloakBrowser-Manager-0.2.0-win64.zip
  CloakBrowser Manager/          # PyInstaller 目录（Windows / 未打 dmg 前）
    CloakBrowser Manager.exe
    version.txt
    ...
```

## 版本号

1. 修改 `pyproject.toml` 中的 `version`
2. 构建时会在程序目录生成 `version.txt`（应用内更新用于比对）；PyInstaller 也会将版本打入包内
3. 发布标签须与版本一致，例如 `version = "0.2.0"` → `git tag v0.2.0`
4. 更新检测以发布资源文件名中的版本为准（如 `CloakBrowser-Manager-0.2.0-win64.zip`），避免 tag 与资源不一致

## GitHub Actions 发布

推送 `v*` 标签后自动构建并上传到 [Releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)：

```bash
git tag v0.2.0
git push origin v0.2.0
```

CI 矩阵：

- `macos-latest`（x64 Python）→ `-x86_64.dmg` + `-x86_64.zip`
- `windows-latest` → `-win64.zip`

手动触发（不上传 Release）：Actions → Release → Run workflow，产物在 Artifacts 中下载。

## 应用内更新

对 **PyInstaller 打包后的正式版** 生效：

| 平台 | 条件 | 更新包 |
|------|------|--------|
| Windows 便携版 | `version.txt` 在 exe 同目录 | `*-win64.zip` |
| macOS Intel | `.app` 内 `Contents/MacOS/version.txt` | `*-x86_64.zip` |

1. 应用请求 `GET /api/update/check`，从 GitHub Releases 选取带对应平台资源且版本号最高的发布
2. 用户点击「一键更新并重启」→ `POST /api/update/apply`
3. 下载 zip → 启动更新脚本 → 本进程退出 → 覆盖当前安装目录 → 重启

环境变量：

| 变量 | 说明 |
|------|------|
| `CBM_UPDATE_REPO` | GitHub 仓库，默认 `tianyiiiii111/CloakBrowser-Manager` |
| `GITHUB_TOKEN` | 可选，提高 API 限额 |

开发模式（未打包）仅显示版本与发布说明，不能一键安装。

## 环境要求

| 平台 | 依赖 |
|------|------|
| macOS | Python 3.12+（x86_64）、Node 20+ |
| Windows | Python 3.12+、Node 20+ |

桌面打包额外依赖见 `packaging/requirements-desktop.txt`（PyInstaller、pywebview 等）。
