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
| Windows | `dist/CloakBrowser-Manager-<版本>-Setup.exe` |

本地默认只打本机架构。两个架构都打：`./scripts/build-macos.sh --all-archs`（Apple Silicon 上需 Rosetta，且 x86_64 会使用独立 venv）。

CI 在两个 macOS job 中分别用 `arm64` / `x64` 的 Python 构建，避免交叉编译依赖不兼容。

仅重打安装包：`./scripts/build-macos.sh -p`（单架构）或 `./scripts/build-macos.sh --all-archs -p`；Windows `.\scripts\build-windows.ps1 -PackageOnly`

版本号：修改 `pyproject.toml` 的 `version`。

## GitHub 发布（自动）

推送版本标签后，Actions 会在 macOS / Windows 上构建并上传到 [Releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)：

```bash
# 先确保 pyproject.toml 中 version 与标签一致
git tag v0.1.0
git push origin v0.1.0
```

产物：

- `CloakBrowser-Manager-<版本>-arm64.dmg`（macOS Apple Silicon）
- `CloakBrowser-Manager-<版本>-x86_64.dmg`（macOS Intel）
- `CloakBrowser-Manager-<版本>-Setup.exe`（Windows）

手动触发（只构建产物、不上传 Release）：在 GitHub → Actions → Release → Run workflow，填写版本号；构建结果在 Workflow Artifacts 中下载。

## 环境要求（本地）

| 平台 | 要求 |
|------|------|
| macOS | Python 3.12+、Node 20+ |
| Windows | 同上 + [Inno Setup 6](https://jrsoftware.org/isinfo.php) |
