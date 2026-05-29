# 分发包构建

## 本地构建

在 **macOS** 或 **Windows（Git Bash）** 上：

```bash
chmod +x scripts/build.sh
./scripts/build.sh
```

| 平台 | 产物 |
|------|------|
| macOS | `dist/CloakBrowser-Manager-<版本>.dmg` |
| Windows | `dist/CloakBrowser-Manager-<版本>-Setup.exe` |

仅重打安装包：`./scripts/build.sh -p`

版本号：修改 `pyproject.toml` 的 `version`。

## GitHub 发布（自动）

推送版本标签后，Actions 会在 macOS / Windows 上构建并上传到 [Releases](https://github.com/tianyiiiii111/CloakBrowser-Manager/releases)：

```bash
# 先确保 pyproject.toml 中 version 与标签一致
git tag v0.1.0
git push origin v0.1.0
```

产物：

- `CloakBrowser-Manager-<版本>.dmg`（macOS）
- `CloakBrowser-Manager-<版本>-Setup.exe`（Windows）

手动触发（只构建产物、不上传 Release）：在 GitHub → Actions → Release → Run workflow，填写版本号；构建结果在 Workflow Artifacts 中下载。

## 环境要求（本地）

| 平台 | 要求 |
|------|------|
| macOS | Python 3.12+、Node 20+ |
| Windows | 同上 + [Inno Setup 6](https://jrsoftware.org/isinfo.php) |
