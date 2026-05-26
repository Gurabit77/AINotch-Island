# AINotch Island — 发布前手动测试 Checklist

跟自动化测试不冲突，这是**你要亲手过一遍**的清单。每条左边打勾后再进入打包流程。

构建产物位置：Xcode 默认在 `~/Library/Developer/Xcode/DerivedData/AINotchIsland-*/Build/Products/Debug/AINotch Island.app`。

---

## 1. 启动与基础

- [ ] `pkill -f "AINotch Island"` → `open -a "AINotch Island"`，app 不闪退
- [ ] 紧凑岛在屏幕顶部 notch 区可见，黑色背景
- [ ] 看到像素螃蟹 buddy（不是 idle 就是 working 之一）
- [ ] 菜单栏只有**一个**白色像素螃蟹图标，旁边带活跃会话数字
- [ ] 点击菜单栏图标，弹出 popover 含活跃会话列表 + 底部 Settings/Updates/Restart/Quit

## 2. AI 会话监控（AgentHalo）

测前置：至少开 1 个 Claude Code / Codex / mimo 终端
- [ ] 紧凑岛显示当前在做什么（`Bash: ...` / `Read: ...` 等 workingOn 文本）
- [ ] 右侧数字反映实际跑的会话数（不夸大、不漏报）
- [ ] 一次 Bash 工具调用后，tool ticker 出现 `✓ Bash` 标记
- [ ] CLI 回复完成时**不**会弹"已完成"通知
- [ ] 关掉一个终端后，对应卡片几秒内消失（不是永久残留）

## 3. Buddy 场景触发（手动各做一次）

每个动作后看紧凑岛的像素螃蟹是否短暂切换场景：

- [ ] **音量+** → buddy 切 volumeUp/volumeMute（同时弹出音量条岛）
- [ ] **音量静音** → buddy 切 volumeMute
- [ ] **亮度+** → buddy 切 brightnessChange
- [ ] **WiFi 连接** → buddy 切 wifiConnected
- [ ] **WiFi 断开** → buddy 切 wifiLost
- [ ] **蓝牙连接** → buddy 切 bluetoothConnected
- [ ] **Focus 开启** → buddy 切 focusOn
- [ ] **充电器插上** → buddy 切 charging
- [ ] **下载开始**（浏览器下载或 curl > 文件） → buddy 切 downloading
- [ ] **AirDrop 拖拽** → buddy 切 airdropReceiving
- [ ] **截图 (Cmd+Shift+3/4)** → buddy 切 screenshot
- [ ] **屏幕录制开始** → buddy 切 screenRecording
- [ ] **外接显示器接入** → buddy 切 mirrorDisplay
- [ ] **U 盘/移动硬盘接入** → buddy 切 usbConnected
- [ ] **U 盘弹出** → buddy 切 usbEjected
- [ ] **NowPlaying 开始播放** → buddy 切 listeningMusic
- [ ] **双击 buddy** → buddy.dance() 跳舞序列
- [ ] **长按 buddy 1.5s** → buddy.cuddle() 睡觉序列
- [ ] **空闲 10min+** → buddy 进入 sleeping

## 4. 多 Agent / 去重

- [ ] 同时跑 2 个 mimo 实例，岛上显示 2 张卡（不是 1 张）
- [ ] 当前对话的 Claude 同时被 hooked + scanner 检测到，**只显示 1 张**（pid 合并）
- [ ] 后台早就跑着的孤儿 claude 进程**不**出现在岛上
- [ ] 跑 `bash scripts/cleanup-orphan-agents.sh` 列出实际孤儿；`--force` 后真的清掉

## 5. 资源占用

```bash
PID=$(pgrep -f "AINotch Island" | head -1)
ps -p $PID -o pid,%cpu,%mem,rss,etime
lsof -p $PID | wc -l
```

- [ ] 启动 30s 后 CPU < 10%（稳态）
- [ ] RAM (RSS) < 250 MB
- [ ] fd 数稳定在 < 250
- [ ] 用 15 分钟，三个指标都不显著上涨

## 6. 长期稳定（运行一晚）

- [ ] 第二天看 app 还活着、岛仍正常显示
- [ ] `~/.agent-halo/debug.log` 没有 `[OrphanCleaner]` 之外的 error 大量
- [ ] 任何 `Crash` 报告：`ls ~/Library/Logs/DiagnosticReports/ | grep AINotch`

## 7. Settings UI 抽查

打开 Settings 窗口（菜单栏 → Settings），各 tab 点一遍：
- [ ] General / Notch / Battery / Bluetooth / Network / Focus / HUD / Lock Screen / Now Playing / Downloads / DragAndDrop / Timer / Agent Halo / About / Debug
- [ ] Agent Halo → Sounds：theme 切换能听到不同音色
- [ ] Agent Halo → Silence Rules：加一条规则后，对应会话从岛上消失
- [ ] 关闭 Settings 窗口不会让 app 退出

---

## 已知遗留（**不阻塞发布**，但要记录在 release notes）

- 没有 Apple Developer ID 签名 → 用户首次启动会被 Gatekeeper 拦，需要右键打开
- `MediaRemoteAdapter.framework` 内部签名 layout 报警（不影响功能）
- 长期运行（>1 周）孤儿清理需要观察日志确认行为
- TranscriptWatcher 在 antigravity 目录 50+ jsonl 时打开 50+ fd（fd 不紧张但需注意）

---

完成所有检查后，进入 `RELEASE.md` 走打包流程。
