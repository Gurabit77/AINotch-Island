# 从源码构建 AINotch Island

如果你只想用，**直接下 `../AINotch Island v1.0.0.dmg` 即可**——本文是给想自己改/编/二次开发的人看的。

适用系统：macOS 14.6+，需要 **Xcode 15+** 和 Command Line Tools。

---

## 1. 拿到源码

```bash
git clone https://github.com/<your-fork>/AINotchIsland.git
cd AINotchIsland
```

或者直接解压你拿到的 `source/` 目录使用。

---

## 2. 替换 TeamID（必做）

源码里的 Apple Developer Team ID 被替换为占位符 `YOUR_TEAM_ID`，你需要换成自己的。

```bash
# 找自己的 TeamID
# Xcode → Preferences → Accounts → 选你的 Apple ID → 看 "Team ID"
# 或者在已有的 Apple Developer 账号里也能找
# 没有 Apple Developer 账号也行——adhoc 签名构建可以不要 TeamID

# 全文替换（macOS / Linux 通用）
find . -type f \( -name "*.pbxproj" -o -name "*.plist" -o -name "*.sh" -o -name "*.md" \) \
  -exec sed -i.bak 's/YOUR_TEAM_ID/你的TeamID/g' {} \;
find . -name "*.bak" -delete
```

或者用 Xcode：打开 `AINotchIsland.xcodeproj` → 选 Target `AINotchIsland` → Signing & Capabilities → 把 Team 改成自己的。

---

## 3. Debug 构建（最快上手）

```bash
xcodebuild -project AINotchIsland.xcodeproj \
  -scheme AINotchIsland \
  -configuration Debug build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

产物在 `~/Library/Developer/Xcode/DerivedData/AINotchIsland-*/Build/Products/Debug/AINotch Island.app`。

或者直接在 Xcode 里 ⌘R 跑。

---

## 4. 开源版 Release 构建（生成 DMG）

```bash
bash scripts/build-release-opensource.sh
```

这会：
1. 编译 Bridge 二进制（`Bridge/agent-halo-bridge.swift`）
2. Xcode archive Release 配置（ad-hoc 签名，不需要 Apple Developer 账号）
3. 修复 framework symlink layout（Xcode archive 已知问题）
4. Re-sign 所有嵌套 framework / helper
5. 生成 `build/AINotch Island.dmg`

约 2 分钟。**不需要 Apple Developer 账号**。

---

## 5. 公证版 Release 构建（可选，需要付费 Apple Developer 账号）

如果你想让用户下载后**无须右键打开**就能用，需要 Apple 公证：

```bash
# 一次性准备：把 App Store Connect API Key 存到 keychain
# 在 https://appstoreconnect.apple.com → Users and Access → Integrations
# → App Store Connect API → Keys，生成一个 Key，下载 .p8 文件
xcrun notarytool store-credentials "notarytool-profile" \
  --key /path/to/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer YOUR-ISSUER-UUID

# 然后用公证版打包脚本
bash scripts/build-release.sh   # 含 Developer ID 签名
AINOTCH_NOTARIZE=1 bash scripts/build-dmg.sh  # 含公证
```

详见 `RELEASE.md`。

---

## 6. 目录结构

```
AINotchIsland/
  Application/         # 入口 + AppContainer DI
  Core/
    Models/            # NotchModel, NotchContentRegistry, AgentRegistry 等
    Services/          # 各功能后台服务
      AgentHalo/       # AI 进程监控核心
      Bluetooth/       # 蓝牙
      Power/           # 电池/充电
      NowPlaying/      # 音乐
      ...
    Protocols/         # 接口协议
  Features/            # 各 UI 模块（ViewModel + Content + Views）
    Notch/             # 灵动岛引擎
    AgentHalo/         # AI 监控 UI
    Buddy/             # 像素螃蟹动画
    Settings/          # 设置页
    HUD/Bluetooth/Battery/... 等十几个 feature
  Resources/           # 图标、本地化、JS 扩展默认 agents.json
  ExtensionHost/       # JavaScriptCore 扩展沙盒
Bridge/                # CLI hook 桥接二进制源码（Swift）
  agent-halo-bridge.swift
  build-bridge.sh
scripts/               # 构建/打包/清理脚本
  build-release-opensource.sh   # 开源 ad-hoc 打包
  build-release.sh              # 带 Developer ID
  build-dmg.sh                  # DMG 封装
  cleanup-orphan-agents.sh      # 清理孤儿 AI 进程
```

---

## 7. 关键路径速查

| 想改什么 | 改哪里 |
|---|---|
| 启动入口 | `AINotchIsland/Application/AINotchIslandApp.swift` |
| 全局依赖注入 | `AINotchIsland/Application/AppContainer.swift` |
| AI 监控核心 | `AINotchIsland/Core/Services/AgentHalo/` |
| Agent 注册（增加新 AI 工具） | `AINotchIsland/Resources/agents-builtin.json` 或运行时 `~/.agent-halo/agents.json` |
| 灵动岛动画引擎 | `AINotchIsland/Features/Notch/NotchEngine.swift` |
| Bridge（hook 协议） | `Bridge/agent-halo-bridge.swift` |
| Buddy（像素螃蟹）动画 | `AINotchIsland/Features/Buddy/PixelCatSprites.swift` |
| Settings 各 tab | `AINotchIsland/Features/Settings/` |

---

## 8. 项目约定

- 使用 `fileSystemSynchronizedGroups`：新增 .swift 文件放进 `AINotchIsland/<目录>` 自动加入编译，不需要在 Xcode 里手动添加
- Feature 模块模式：`ViewModel + Event + Content + Views`
- 强制 `@MainActor` 标注一致性
- 不要硬编码 agent 定义——优先用 `~/.agent-halo/agents.json`

---

## 9. 调试小贴士

- App 数据目录 `~/.agent-halo/`（日志、会话、hook bin）
- Debug 日志 `~/.agent-halo/debug.log`
- 想看引导页：`defaults delete com.ayanami.ai-notch-island hasSeenOnboarding` 后重启 app
- 想看所有岛场景的演示：打开 Settings → Showcase → Run Full Showcase

---

## 10. 反馈 / PR

- 这是 MIT 开源项目，欢迎贡献
- 提 Issue / PR 前先看 `SECURITY.md`
- 测试清单见 `TESTING.md`

Happy hacking 🦀
