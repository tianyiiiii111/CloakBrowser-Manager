# 本地开发

## 桌面模式（单窗口）

```bash
cd frontend && npm install && npm run build
cd ..
source backend/.venv/bin/activate
pip install -r backend/requirements.txt pywebview
python -m backend.desktop
```

## 打包分发（仅 DMG / Setup.exe）

macOS：`./scripts/build-macos.sh`  
Windows：`.\scripts\build-windows.ps1`（或 `./scripts/build.sh` 自动分发）

本地构建见 [PACKAGING.md](PACKAGING.md)。发布：`git tag v0.1.0 && git push origin v0.1.0`。

## 前后端分离（前端热更新）

```bash
# 终端 1
uvicorn backend.main:app --reload --port 8080

# 终端 2
cd frontend && npm run dev
```

打开 http://localhost:5173
