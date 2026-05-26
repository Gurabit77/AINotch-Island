# AINotch Island

**把 MacBook 顶部刘海做成监控所有本地 AI 编程助手的"灵动岛"。**

实时监控 Claude Code、Codex、Cursor、Gemini CLI、Hermes、OpenClaw 等 22+ 种 AI 工具——在刘海岛上直接审批权限、查看 diff、跳转终端。

基于 [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) 构建，参考了 [MioIsland](https://github.com/Chen3167/MioIsland) 和 [SuperIsland](https://github.com/shobhit99/SuperIsland) 的最佳实践。

> **系统要求**：macOS 14.6+，Apple Silicon / Intel 均支持

---

## 仓库结构

```
.
├── AINotch Island v1.0.0.dmg   ← 9.1MB，直接下载安装
├── 使用说明.md                  ← 终端用户中文使用手册
├── README.md                    ← 本文（README）
└── 源代码/                      ← 完整源码（41MB）
    ├── README.md                ← 项目详细介绍（英文）
    ├── BUILDING.md              ← 二次开发者构建指南
    ├── LICENSE                  ← MIT
    ├── SECURITY.md
    ├── TESTING.md
    └── ...
```

---

## 快速开始

### 我只想用 → 下载 DMG

1. 下载根目录的 [`AINotch Island v1.0.0.dmg`](./AINotch%20Island%20v1.0.0.dmg)
2. 双击挂载 → 把 app 拖到 `Applications`
3. **首次启动** 在「应用程序」里**右键 → 打开**（因为是 ad-hoc 签名，macOS 默认会拦一下）
4. 详细使用方法见 [`使用说明.md`](./使用说明.md)

### 我想读源码 / 二次开发

进 [`源代码/`](./源代码/) 目录，从 [`源代码/BUILDING.md`](./源代码/BUILDING.md) 开始。

```bash
git clone git@github.com:Gurabit77/AINotch-Island.git
cd AINotch-Island/源代码
# 然后按 BUILDING.md 改 TeamID + 构建
```

---

## 核心功能

- **22+ AI 工具开箱支持**：Claude Code, Codex, Cursor, Kiro, Windsurf, Gemini CLI, Hermes, OpenClaw, Amp, DeepSeek, Copilot, Aider……
- **JSON 注册表**：在 `~/.agent-halo/agents.json` 加新工具，**无需改代码**
- **双重检测**：hook（实时事件）+ scanner（进程扫描）
- **刘海岛直接审批**：查看 diff / 同意 / 拒绝
- **全局快捷键**：`⌘⇧Y` 一键批准 / `⌘⇧A` 展开 / `⌘⇧J` 跳到对应终端
- **JavaScript 扩展系统**：JavaScriptCore 沙盒里跑用户扩展
- **保留所有 DynamicNotch 原生功能**：音乐 / 电池 / 蓝牙 / WiFi / Timer / 下载 / 截图 / 屏幕录制 / Focus / AirDrop / HUD

---

## License

MIT，详见 [`源代码/LICENSE`](./源代码/LICENSE)。

欢迎 PR / Issue 🦀
