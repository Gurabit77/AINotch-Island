# AINotchIsland

**macOS Dynamic Island for Universal AI Process Monitoring & Control**

AINotchIsland transforms your MacBook's notch into a live command center for all AI coding agents. Monitor Claude Code, Codex, Cursor, Gemini CLI, Hermes, OpenClaw, and 15+ other AI tools in real-time — approve permissions, view diffs, jump to terminals, all from the notch.

Built on [DynamicNotch](https://github.com/jackson-storm/DynamicNotch), combining the best ideas from [MioIsland](https://github.com/Chen3167/MioIsland) and [SuperIsland](https://github.com/shobhit99/SuperIsland).

## Core Features

### Universal AI Monitoring
- **22+ AI tools supported** out of the box (Claude Code, Codex, Cursor, Kiro, Windsurf, Gemini CLI, Hermes, OpenClaw, Amp, DeepSeek, Copilot, Aider, and more)
- **JSON-driven registry** — add new tools without code changes (`~/.agent-halo/agents.json`)
- **Dual detection**: hooked (real-time events) + scanned (process detection)
- **Auto hook installation** for Claude Code, Codex, Cursor, Amp on first launch

### Real-time Event Feedback
- Live status updates in the notch for all monitored agents
- Color-coded session dots: green (working), orange (approval needed), red (error)
- Buddy companion animation reflecting overall agent status
- Approval badge with pulse animation when action required

### Interactive Control
- **Permission approval** directly from the notch — view diffs, approve/deny
- **Quick approve hotkey**: Cmd+Shift+Y approves the latest pending request
- **Terminal jump**: click a session to navigate to its terminal (iTerm2, Ghostty, Warp, Terminal.app, Kitty, WezTerm, VS Code, Cursor)
- **Toggle hotkey**: Cmd+Shift+A to expand/collapse the agent panel

### Extension System
- **JavaScript extensions** in sandboxed JavaScriptCore
- Rich API: `AgentHalo.sessions`, `AgentHalo.approvals`, `AgentHalo.on(event, callback)`
- System APIs: `Storage`, `Notifications`, `System.battery/time/platform`
- Auto-activation, persistent state, event subscriptions

### DynamicNotch Features (preserved)
- Now Playing with lyrics
- Battery/charging status
- Bluetooth connectivity
- Network status (WiFi, VPN, Hotspot)
- Timer/Pomodoro
- Downloads progress
- Screen recording indicator
- Focus mode
- Hardware HUD (brightness/volume)
- Drag & Drop / AirDrop

## Architecture

```
AINotchIsland/
├── Application/          # App lifecycle, DI container, window management
├── Core/
│   ├── Models/           # AgentRegistry, AgentSession, NotchModel
│   ├── Protocols/        # NotchContentProtocol, feature contracts
│   └── Services/         # AgentHaloScanner, SocketServer, HookInstaller
├── ExtensionHost/        # JS runtime, manifest, renderer
├── Features/
│   ├── AgentHalo/        # AI monitoring UI (compact + expanded views)
│   ├── Notch/            # Core notch engine, event coordination
│   ├── Buddy/            # ASCII art companion system
│   ├── Settings/         # Preferences UI
│   └── [Battery|Bluetooth|Network|...]  # System features
├── Shared/               # Extensions, localization, private APIs
└── Resources/            # Assets, sounds, agents-builtin.json
```

## Requirements

- macOS 14.6+ (Sonoma)
- MacBook with notch (or external display in floating mode)
- Xcode 15+ to build

## Build

```bash
cd ai灵动岛v2
open AINotchIsland.xcodeproj
# Build & Run the AINotchIsland scheme
```

## Hook Installation

On first launch, AINotchIsland automatically installs bridge hooks for supported tools. You can also manage hooks in Settings > Agent Halo > Hook Status.

The bridge binary at `~/.agent-halo/bin/agent-halo-bridge` normalizes events from different AI tools into a unified protocol over Unix socket (`~/.agent-halo/run/agent-halo.sock`).

## Custom Agent Registry

Add custom agent definitions to `~/.agent-halo/agents.json`:

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

## Writing Extensions

Create a directory in `~/.agent-halo/extensions/my-extension/` with:

**manifest.json:**
```json
{
  "id": "com.example.my-ext",
  "name": "My Extension",
  "version": "1.0.0",
  "description": "My custom notch extension",
  "author": "You",
  "entry": "index.js",
  "permissions": ["agents", "storage"],
  "autoActivate": true
}
```

**index.js:**
```javascript
function activate() {
  AgentHalo.on("sessionStart", function(data) {
    Notifications.show("Agent Started", data.title);
  });
}

function render() {
  var agents = AgentHalo.sessions.getActive();
  if (agents.length === 0) return UI.text("Idle", {fontSize: 10});
  return UI.hstack([
    UI.image("circle.fill", {style: {fontSize: 6, foregroundColor: "green"}}),
    UI.text(agents.length + " active", {fontSize: 11})
  ], {spacing: 4});
}
```

## License

GPL-3.0 (inherited from DynamicNotch)

## Credits

- [DynamicNotch](https://github.com/jackson-storm/DynamicNotch) — Base notch UI framework
- [MioIsland](https://github.com/Chen3167/MioIsland) — Claude Code monitoring inspiration
- [SuperIsland](https://github.com/shobhit99/SuperIsland) — Extension system inspiration
