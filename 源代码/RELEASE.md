# AINotch Island — 发布流程

## 一次性准备（每台开发机器只做一次）

### 1. Apple Developer 账户
- 已知 `TEAM_ID = YOUR_TEAM_ID`（写在 `scripts/build-release.sh`）
- 需要在 [developer.apple.com](https://developer.apple.com) 有付费账号
- Keychain 里要有 **"Developer ID Application: <Name> (YOUR_TEAM_ID)"** 证书
  - 验证：`security find-identity -p codesigning -v | grep "Developer ID"`

### 2. 公证凭证（notarytool keychain profile）
一次性把 App Store Connect API key 存到 keychain：

```bash
# 在 App Store Connect 后台 → Users and Access → Integrations → App Store
# Connect API → Keys，生成一个 Key，下载 .p8 文件，记下 Key ID 和 Issuer ID

xcrun notarytool store-credentials "notarytool-profile" \
  --key /path/to/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer YOUR-ISSUER-UUID
```

`notarytool-profile` 这个名字对应 `build-release.sh` 第 38 行的 `--keychain-profile`。

### 3. Sparkle EdDSA（自动更新签名密钥）

启动日志里有：
```
[Sparkle] Error: Serving updates without an EdDSA key ... is deprecated
```

要生成：
```bash
# Sparkle 提供的工具
~/Library/Developer/Xcode/DerivedData/AINotchIsland-*/SourcePackages/checkouts/Sparkle/bin/generate_keys

# 输出 public key，添加到 Info.plist 的 SUPublicEDKey
# private key 自动存到 keychain（item: "https://sparkle-project.org"）
```

发布 update 时签名 zip：
```bash
~/.../Sparkle/bin/sign_update AINotch_Island_1.4.4.zip
# 输出 sparkle:edSignature="..."，放到 appcast.xml
```

不做这步 app 仍能发布，只是更新机制将来要废弃。

---

## 每次发布走的步骤

### 1. 跑测试 checklist
```bash
open TESTING.md
# 逐条勾选，全过再继续
```

### 2. 改版本号
- `AINotchIsland/Application/Info.plist` → `CFBundleShortVersionString`、`CFBundleVersion`
- git tag 准备好：`git tag -a v1.5.0 -m "Release 1.5.0"`

### 3. 一键打包
```bash
# 从仓库根目录
./scripts/build-release.sh
```

脚本会：
1. 编译 bridge 二进制（`Bridge/agent-halo-bridge`）
2. xcodebuild archive Release 配置（Developer ID 签名）
3. xcodebuild exportArchive 出 `.app`
4. notarytool 提交到 Apple 公证（一般 5-15 分钟）
5. stapler 把公证票钉到 `.app`

输出在 `build/release/AINotch Island.app`。

### 4. 做 DMG
```bash
./scripts/build-dmg.sh
```

输出 `build/AINotch Island.dmg`，里面 `.app` 已经被公证 + stapled，用户拖到 Applications 即可正常打开。

### 5. 测公证后的 app
```bash
# 重要：删旧的、装新的
rm -rf "/Applications/AINotch Island.app"
cp -R "build/release/AINotch Island.app" /Applications/

# 用户体验测试：从 /Applications 启动，**不应该**被 Gatekeeper 拦
open "/Applications/AINotch Island.app"

# 验证签名 / 公证
codesign --verify --deep --strict --verbose=2 "/Applications/AINotch Island.app"
spctl -a -t exec -vvv "/Applications/AINotch Island.app"
# 应该看到：accepted, source=Notarized Developer ID
```

### 6. 发布
- DMG 上传到 GitHub Release / 自有 CDN
- 更新 `appcast.xml`（Sparkle 配置）
- git push tag

---

## 常见出错

| 报错 | 原因 | 修法 |
|---|---|---|
| `errSecInternalComponent` | Developer ID 证书过期 / 撤销 | Apple Developer 网站重新生成 |
| `Notarization failed: ... contains invalid signatures` | framework 内部签名乱（之前 `/Applications` 测试踩过的） | `codesign --force --deep --sign "Developer ID Application" "<app>"` 重签 |
| `Hardened Runtime is not enabled` | exportArchive 没开 hardened runtime | `scripts/ExportOptions.plist` 加 `<key>hardenedRuntime</key><true/>` |
| `The signature of the binary is invalid` | adhoc 二进制混进了发布包 | 检查 `Bridge/agent-halo-bridge` 是否被 release 用到，需要也用 Developer ID 签 |
| `Process /usr/bin/codesign failed` | Keychain 锁住 | `security unlock-keychain ~/Library/Keychains/login.keychain-db` |

---

## Bridge 二进制公证

`Bridge/agent-halo-bridge` 是 swift 编译出的 CLI 工具，被 app 安装到 `~/.agent-halo/bin/`。它**也需要 Developer ID 签**，否则用户第一次跑 Claude Code hook 时会被 Gatekeeper 静默杀掉。

```bash
codesign --force --sign "Developer ID Application: ... (YOUR_TEAM_ID)" \
  --options runtime \
  --timestamp \
  Bridge/agent-halo-bridge

# bridge 在 release app 里以 Resources/agent-halo-bridge 形式 bundle 进去，
# xcodebuild archive 会自动连带签名。但如果手工分发它做调试，记得单独签。
```

---

## 用户首次安装注意

- 拖 .app 到 Applications 后第一次启动，macOS 会要求：
  - **辅助功能**（音量/亮度键拦截）
  - **通知**（任务完成提示）
  - **完全磁盘访问**（读 `~/.claude/projects/*.jsonl` 用 — 通常 Sandbox 关闭时不需要）
- App 首次运行会装 hook 到 `~/.claude/settings.json` 和 `~/.codex/config.toml` 等
- 老的孤儿 AI 进程会被 OrphanAgentCleaner 在 24h 内自动清理

---

## 当前阻塞项（发布前必须做掉）

- [ ] **MediaRemoteAdapter.framework 签名 layout** — 之前测试 `codesign --verify` 报 sealed resource invalid。需要排查是否影响公证
- [ ] **Sparkle EdDSA 密钥** — 不阻塞首次发布，但为后续自动更新铺路
- [ ] **测一次完整公证流程** — 因为这是这次会话以来的首次发布
- [ ] **跑完 TESTING.md** — 所有 checklist 项

---

## 联系 / 故障

如果 `build-release.sh` 失败，先单独跑：
```bash
xcodebuild archive -project AINotchIsland.xcodeproj -scheme AINotchIsland \
  -configuration Release -archivePath build/test.xcarchive
```
看具体 error 输出。常见是 `Code signing identity ... not found` → keychain 里找不到证书。
