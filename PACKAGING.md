# 分发包构建

## 本地构建

**macOS：**

```bash
chmod +x scripts/build-macos.sh
./scripts/build-macos.sh
```

**Windows（PowerShell）：**

```powershell
.\scripts\build-windows.ps1
```

| 平台 | 产物 |
|------|------|
| macOS (Apple Silicon) | `dist/CloakBrowser-Manager-<版本>-arm64.dmg` |
| macOS (Intel) | `dist/CloakBrowser-Manager-<版本>-x86_64.dmg` |
| Windows | `dist/CloakBrowser-Manager-<版本>-win64.zip`（免安装便携版） |

Windows 用户解压 zip 后运行 `CloakBrowser Manager.exe`。应用内可通过右上角 **更新** 按钮一键下载并覆盖安装（无需手动下 zip）。

本地默认只打本机架构。两个 macOS 架构：`./scripts/build-macos.sh --all-archs`。

仅重打分发包：`-PackageOnly` / `-p`。

版本号：修改 `pyproject.toml` 的 `version`（构建时会写入 `version.txt`）。

## GitHub 发布（自动）

推送版本标签后，Actions 构建并上传到 [Releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)：

```bash
git tag v0.2.0
git push origin v0.2.0
```

产物：

- `CloakBrowser-Manager-<版本>-arm64.dmg`
- `CloakBrowser-Manager-<版本>-x86_64.dmg`
- `CloakBrowser-Manager-<版本>-win64.zip`（**应用内更新依赖此文件名**）

## 应用内更新（Windows）

- 检查：GitHub Releases API → 最新 `*-win64.zip`
- 更新：下载 zip → 退出 → `robocopy` 覆盖当前目录 → 重启 exe
- 配置：`CBM_UPDATE_REPO=owner/name`（默认 `tianyiiiii111/CloakBrowser-Manager`）

macOS 暂不支持应用内覆盖更新，界面会引导至发布页下载 DMG。

## 环境要求（本地）

| 平台 | 要求 |
|------|------|
| macOS | Python 3.12+、Node 20+ |
| Windows | Python 3.12+、Node 20+ |
