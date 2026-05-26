# AINotch Island — 项目描述

## 一句话定义

**AINotch Island** 是一款 macOS 原生应用，将 MacBook 的刘海区域转化为一个实时 AI 进程监控与控制中心。它能统一监控 22+ 种 AI 编程工具（Claude Code、Codex、Cursor、Gemini CLI、MiMo Code 等），在刘海区域展示会话状态、提供权限审批入口、支持一键跳转终端，并附带一个像素螃蟹宠物陪伴系统。

---

## 项目背景

随着 AI 编程助手的爆发式增长，开发者同时使用多个 AI Agent 已成常态。但这些工具各自独立运行，缺乏统一的状态感知入口。AINotch Island 的核心理念是：**利用 MacBook 刘海这块"无用"屏幕空间，打造一个零干扰的 AI 指挥中心**。

项目基于 [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) 框架 fork 而来，融合了 [MioIsland](https://github.com/Chen3167/MioIsland) 的 Claude Code 监控思路和 [SuperIsland](https://github.com/shobhit99/SuperIsland) 的扩展系统设计理念。

---

## 核心功能

### 1. 统一 AI 进程监控（AgentHalo）

这是项目的最核心功能模块。

- **22+ AI 工具内置支持**：Claude Code、Codex、Cursor、Kiro、Windsurf、Gemini CLI、Hermes、OpenClaw、Amp、DeepSeek、Copilot、Aider、MiMo Code、TRAE、ChatGPT、Claude Desktop 等
- **JSON 驱动的注册表**：Agent 定义存储在 `~/.agent-halo/agents.json`，新增工具无需改代码
- **双重检测机制**：
  - **Hook 模式**（实时事件流）：通过 Unix Socket 接收 AI 工具推送的实时事件
  - **扫描模式**（进程检测）：定期扫描系统进程，匹配已注册的 Agent 模式
- **自动 Hook 安装**：首次启动时自动为 Claude Code、Codex、Cursor、Amp 安装事件钩子
- **Adapter 架构**：每种 Agent 有独立的适配器（`ClaudeCodeAdapter`、`CodexAdapter`、`HermesAdapter` 等），负责解析各自的事件协议

### 2. 实时状态展示

- 紧凑岛（刘海区域）显示当前 AI 工作状态和活跃会话数
- 颜色编码的会话指示器：绿色（工作中）、橙色（等待审批）、红色（错误）
- 工具调用 ticker：实时展示当前执行的工具（`Bash`、`Read`、`Write` 等）
- Token 用量追踪和成本估算

### 3. 交互控制

- **权限审批**：直接在刘海区域查看 diff、批准或拒绝 AI 的操作请求
- **快速审批热键**：`Cmd+Shift+Y` 一键批准最新的待处理请求
- **终端跳转**：点击会话卡片即可跳转到对应的终端窗口（支持 iTerm2、Ghostty、Warp、Terminal.app、Kitty、WezTerm、VS Code、Cursor）
- **面板切换热键**：`Cmd+Shift+A` 展开/收起 Agent 面板
- **菜单栏集成**：白色像素螃蟹图标 + 活跃会话数 badge，点击弹出 popover 管理面板

### 4. 像素螃蟹宠物（Buddy System）

一个完整的虚拟宠物系统，以像素风格螃蟹为载体：

- **50+ 种场景动画**：涵盖 AI 工作状态、系统事件、环境变化、空闲陪伴行为
  - AI 相关：coding、reading、thinking、confused、celebrating
  - 系统事件：volumeUp、brightnessChange、wifiConnected、bluetoothConnected、charging
  - 设备事件：usbConnected、usbEjected、airdropReceiving、screenshot、screenRecording
  - 空闲行为：idleYawn、idleDance、idleChaseButterfly、idleDoze、sleeping
  - 环境感知：weatherRainy、weatherCold、nightOwl、morningStretch
- **情感系统**：affection（好感度）和 energy（能量值）双维度，影响心情计算（happy/content/neutral/tired/lonely）
- **交互反馈**：双击触发跳舞动画，长按 1.5s 触发睡觉动画，空闲 10min+ 自动进入睡眠
- **持久化**：情感数据通过 UserDefaults 持久化，重启后保持

### 5. 扩展系统（Extension Host）

基于 JavaScriptCore 的沙盒化扩展运行时：

- **声明式 manifest**：每个扩展包含 `manifest.json` 描述元数据和权限
- **丰富的 API**：
  - `AgentHalo.sessions` — 访问活跃会话
  - `AgentHalo.approvals` — 访问待审批请求
  - `AgentHalo.on(event, callback)` — 事件订阅
  - `Storage` — 持久化存储
  - `Notifications` — 系统通知
  - `System.battery/time/platform` — 系统信息
  - `UI.text/hstack/image` — 声明式 UI 组件
- **自动激活**：扩展安装后自动加载运行
- **扩展目录**：`~/.agent-halo/extensions/<extension-name>/`

### 6. 系统功能集成（继承自 DynamicNotch）

项目保留并增强了 DynamicNotch 的全部系统监控功能：

| 功能 | 说明 |
|------|------|
| Now Playing | 歌曲信息 + 歌词同步（LRCLIB） |
| Battery | 电量、充电状态、低电量提醒 |
| Bluetooth | 蓝牙设备连接/断开 |
| Network | WiFi、VPN、热点状态 |
| Timer | 计时器 / 番茄钟 |
| Downloads | 文件下载进度监控 |
| Screen Recording | 屏幕录制指示器 |
| Focus | 专注模式状态 |
| Hardware HUD | 音量/亮度调节覆盖层 |
| Drag & Drop / AirDrop | 文件拖放和 AirDrop 接收 |
| Lock Screen | 锁屏状态监控和音效 |
| External Drive | U 盘/移动硬盘接入弹出 |
| External Display | 外接显示器检测 |
| Screenshot | 截图事件检测 |

---

## 技术架构

### 技术栈

| 层级 | 技术 |
|------|------|
| 语言 | Swift 5 |
| UI 框架 | SwiftUI + AppKit |
| 响应式 | Combine |
| 扩展运行时 | JavaScriptCore |
| 自动更新 | Sparkle |
| 最低系统 | macOS 14.6 (Sonoma) |
| 构建工具 | Xcode 15+ |

### 项目结构

```
AINotchIsland/
├── Application/              # 应用生命周期、DI 容器、窗口管理
│   ├── AINotchIslandApp.swift    # App 入口
│   ├── AppContainer.swift        # 依赖注入容器
│   ├── AppDelegate/              # 应用委托
│   ├── OverlayPanelWindow.swift  # 刘海覆盖窗口
│   └── SettingsWindowCoordinator.swift
│
├── Core/
│   ├── Models/               # 数据模型
│   │   ├── AgentRegistry.swift       # Agent 注册表（JSON 驱动）
│   │   ├── AgentHalo/                # Agent 会话、事件、审批模型
│   │   └── NotchModel.swift          # 刘海状态模型
│   ├── Protocols/            # 协议定义
│   │   ├── AgentAdapter.swift        # Agent 适配器协议
│   │   ├── NotchContentProtocol.swift # 刘海内容协议
│   │   └── ...                       # 各功能模块的监控协议
│   └── Services/             # 核心服务
│       ├── AgentHalo/                # AI 监控服务集群
│       │   ├── AgentHaloScanner.swift    # 进程扫描器
│       │   ├── AgentHaloSocketServer.swift # Unix Socket 服务
│       │   ├── Adapters/                 # 各 Agent 的适配器实现
│       │   ├── TranscriptWatcher/        # 对话记录监控
│       │   └── ...
│       ├── Lyrics/           # 歌词服务
│       └── Power/            # 电源服务
│
├── ExtensionHost/            # JS 扩展系统
│   ├── ExtensionJSRuntime.swift      # JavaScriptCore 运行时
│   ├── ExtensionManager.swift        # 扩展生命周期管理
│   ├── ExtensionManifest.swift       # manifest 解析
│   ├── ExtensionRendererView.swift   # 扩展 UI 渲染
│   └── ViewNode*.swift               # 声明式 UI 节点系统
│
├── Features/                 # 功能模块（每个遵循 ViewModel + Event + Content + Views 模式）
│   ├── AgentHalo/            # AI 监控 UI（紧凑视图 + 展开视图）
│   ├── Notch/                # 刘海核心引擎
│   │   ├── NotchEngine.swift         # 刘海状态机
│   │   ├── NotchEventCoordinator.swift # 事件协调器（28KB，核心调度）
│   │   ├── NotchViewModel.swift      # 刘海视图模型
│   │   └── EventHandlers/            # 各类事件处理器
│   ├── Buddy/                # 像素螃蟹宠物系统
│   │   ├── PixelCatSprites.swift     # 像素精灵帧数据（34KB）
│   │   ├── BuddyAnimationEngine.swift # 动画引擎
│   │   ├── BuddyEmotionState.swift   # 情感状态机
│   │   └── ...
│   ├── Battery/ Bluetooth/ Network/  # 系统监控功能
│   ├── NowPlaying/ Download/ Timer/  # 媒体与文件功能
│   ├── Settings/             # 偏好设置 UI
│   └── ...
│
├── Shared/                   # 共享模块
│   ├── Extensions/           # Swift 扩展
│   ├── Localization/         # 国际化（支持中/英/俄/西）
│   ├── PrivateAPI/           # macOS 私有 API 调用
│   └── UI/                   # 通用 UI 组件
│
└── Resources/                # 资源文件
    ├── Assets.xcassets/      # 图片资源
    ├── LottieImage/          # Lottie 动画
    ├── Sounds/               # 音效文件
    ├── MediaRemoteAdapter/   # 媒体控制框架
    └── agents-builtin.json   # 内置 Agent 定义
```

### Bridge 组件

```
Bridge/
├── agent-halo-bridge.swift   # Swift CLI 工具源码
├── agent-halo-bridge         # 编译后的二进制
├── build-bridge.sh           # 编译脚本
└── test-event.sh             # 测试脚本
```

Bridge 是一个独立的 Swift CLI 二进制，安装到 `~/.agent-halo/bin/agent-halo-bridge`，负责：
- 标准化不同 AI 工具的事件协议
- 通过 Unix Socket (`~/.agent-halo/run/agent-halo.sock`) 与主应用通信
- 作为 Hook 被注入到各 AI 工具的配置中

### 关键设计模式

- **依赖注入**：`AppContainer` 作为全局 DI 容器，所有服务通过它获取依赖
- **协议驱动**：功能模块通过协议（`NotchContentProtocol`、`AgentAdapter` 等）解耦
- **事件协调**：`NotchEventCoordinator` 作为中央事件总线，协调所有模块的事件流转
- **@MainActor 一致性**：所有 UI 相关的 ViewModel 和状态管理都标注 `@MainActor`
- **fileSystemSynchronizedGroups**：Xcode 项目使用文件系统同步组，新增文件自动纳入编译

---

## 构建与运行

### 环境要求

- macOS 14.6+ (Sonoma)
- Xcode 15+
- MacBook with notch（或外接显示器的浮动模式）

### 构建命令

```bash
# 开发构建
cd ai灵动岛v2
open AINotchIsland.xcodeproj
# 在 Xcode 中 Build & Run

# 命令行构建（无签名）
xcodebuild -project AINotchIsland.xcodeproj -scheme AINotchIsland \
  -configuration Debug build \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### 发布流程

```bash
# 1. 运行测试 checklist
open TESTING.md

# 2. 一键打包（编译 + 签名 + 公证）
./scripts/build-release.sh

# 3. 制作 DMG
./scripts/build-dmg.sh

# 4. 输出位于 build/AINotch Island.dmg
```

---

## 配置与扩展

### 自定义 Agent 注册

在 `~/.agent-halo/agents.json` 中添加自定义 Agent：

```json
[
  {
    "name": "My Custom Agent",
    "source": "custom",
    "agentType": "unknown",
    "processPatterns": ["my-agent-process"],
    "hookSupport": "none",
    "icon": "cpu"
  }
]
```

### 编写扩展

在 `~/.agent-halo/extensions/my-extension/` 目录下创建：

**manifest.json** — 声明扩展元数据和权限

**index.js** — 实现 `activate()` 和 `render()` 函数，通过 `AgentHalo` API 访问会话数据和事件系统

---

## 测试

项目包含完整的测试体系：

- **单元测试**：`AINotchIslandTests/` 目录
  - Features 目录下各模块的集成测试（Notch、NowPlaying、Network、Download、Clipboard、ScreenRecording、Settings）
  - TestSupport 目录提供测试替身和异步测试工具
- **UI 测试**：`AINotchIslandUITests/DynamicNotchUITests.swift`
- **手动测试 Checklist**：`TESTING.md` 包含详细的发布前手动测试清单

### 资源占用目标

| 指标 | 目标 |
|------|------|
| CPU（稳态） | < 10% |
| 内存 (RSS) | < 250 MB |
| 文件描述符 | < 250 |
| 长期运行 | 无内存泄漏 |

---

## 项目状态

- **版本**：1.5.0（开发中）
- **许可证**：GPL-3.0（继承自 DynamicNotch）
- **提交数**：13 commits
- **更新机制**：Sparkle（appcast.xml at ainotchisland.app）
- **支持语言**：中文、English、Русский、Español

### 待完成项

- MediaRemoteAdapter.framework 签名布局修复
- Sparkle EdDSA 密钥配置（自动更新签名）
- 首次完整公证流程测试
- TESTING.md 全项通过

---

## 致谢

- [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) — 基础刘海 UI 框架
- [MioIsland](https://github.com/Chen3167/MioIsland) — Claude Code 监控灵感
- [SuperIsland](https://github.com/shobhit99/SuperIsland) — 扩展系统灵感
