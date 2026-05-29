# 分发包构建

## 产物一览

| 平台 | 文件名 | 说明 |
|------|--------|------|
| macOS Apple Silicon | `CloakBrowser-Manager-<版本>-arm64.dmg` | 拖入「应用程序」安装 |
| macOS Intel | `CloakBrowser-Manager-<版本>-x86_64.dmg` | 同上 |
| Windows | `CloakBrowser-Manager-<版本>-win64.zip` | **免安装便携版**，解压即用 |

用户数据与配置保存在 `~/.cloakbrowser-manager/`，与程序安装位置无关。

## 本地构建

### macOS

```bash
chmod +x scripts/build-macos.sh

# 本机架构（M 系列 → arm64，Intel Mac → x86_64）
./scripts/build-macos.sh

# 同时打 arm64 + Intel 两个 DMG（在 Apple Silicon 上会为 x86_64 使用 Rosetta venv）
./scripts/build-macos.sh --all-archs

# 指定架构
./scripts/build-macos.sh --arch x86_64

# 仅重打 DMG（需已有 dist-<arch>/）
./scripts/build-macos.sh -p
```

### Windows（PowerShell）

```powershell
.\scripts\build-windows.ps1

# 仅重打 zip（需已有 dist\CloakBrowser Manager\）
.\scripts\build-windows.ps1 -PackageOnly
```

构建流程：前端 `npm ci && build` → Python venv → PyInstaller → 写入 `version.txt` → 压缩 zip。

输出目录示例：

```
dist/
  CloakBrowser-Manager-0.2.0-arm64.dmg
  CloakBrowser-Manager-0.2.0-win64.zip
  CloakBrowser Manager/          # PyInstaller 目录（Windows / 未打 dmg 前）
    CloakBrowser Manager.exe
    version.txt
    ...
```

## 版本号

1. 修改 `pyproject.toml` 中的 `version`
2. 构建时会在 Windows 程序目录生成 `version.txt`（应用内更新用于比对）
3. 发布标签须与版本一致，例如 `version = "0.2.0"` → `git tag v0.2.0`

## GitHub Actions 发布

推送 `v*` 标签后自动构建并上传到 [Releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)：

```bash
git tag v0.2.0
git push origin v0.2.0
```

CI 矩阵：

- `macos-latest` × arm64 → `-arm64.dmg`
- `macos-latest` × x64 Python → `-x86_64.dmg`
- `windows-latest` → `-win64.zip`

手动触发（不上传 Release）：Actions → Release → Run workflow，产物在 Artifacts 中下载。

## 应用内更新（Windows 便携版）

仅对 **PyInstaller 打包后的便携版** 生效（`CloakBrowser Manager.exe` 同目录存在 `version.txt`）。

1. 应用请求 `GET /api/update/check`，查询 GitHub Releases 最新版及 `CloakBrowser-Manager-*-win64.zip` 资源
2. 用户点击「一键更新并重启」→ `POST /api/update/apply`
3. 下载 zip → 启动 PowerShell 脚本 → 本进程退出 → `robocopy` 覆盖当前 exe 目录 → 重启

环境变量：

| 变量 | 说明 |
|------|------|
| `CBM_UPDATE_REPO` | GitHub 仓库，默认 `tianyiiiii111/CloakBrowser-Manager` |
| `GITHUB_TOKEN` | 可选，提高 API 限额 |

macOS 客户端仅显示新版本提示，跳转发布页下载 DMG。

## 环境要求

| 平台 | 依赖 |
|------|------|
| macOS | Python 3.12+、Node 20+ |
| Windows | Python 3.12+、Node 20+ |

桌面打包额外依赖见 `packaging/requirements-desktop.txt`（PyInstaller、pywebview 等）。
