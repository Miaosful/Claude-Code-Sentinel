# CC Sentinel

[English](README.en.md) | 简体中文

CC Sentinel 是一个本地运行的 macOS 菜单栏工具，用来观察 Claude Code 会话状态，并在有工具权限请求等待审批时给出更醒目的提醒。

它适合同时使用 Claude Code CLI、VS Code Claude Code 插件，或者经常有多个 Claude Code 会话并行运行的人。CC Sentinel 通过 Claude Code hooks 接收本地事件，展示会话是否运行中、是否等待审批，以及 hooks 是否已经安装。

> 当前项目处于开发预览阶段。它不是 Anthropic 官方项目，也不会把 Claude Code 事件发送到外部服务。

## 功能

- 菜单栏状态指示：空闲、运行中、等待审批、状态降级。
- 会话列表：展示 Claude Code 会话来源、工作目录、最近工具请求和审批摘要。
- VS Code 支持：识别 VS Code Claude Code 会话，并在 hooks 尚未上报时使用本机进程作为 fallback。
- Hooks 管理：从菜单栏安装、更新或卸载 CC Sentinel 管理的 Claude Code hooks。
- 本地自动审批：默认关闭；策略由本机 JSON 配置文件驱动，可导入/导出并分享。
- 本地隐私边界：事件、统计和配置保存在本机，工具输入会做脱敏和截断。
- 中英文界面：支持简体中文、英文和跟随系统语言。

## 工作原理

CC Sentinel 由几个本地组件组成：

- `CCSentinelApp`：macOS 菜单栏 App，负责展示状态和操作入口。
- `cc-sentinel-hook`：Claude Code hook 命令，接收 hook JSON 并转发给本机 App。
- `cc-sentinel-wrapper`：用于辅助识别 VS Code 插件启动的 Claude Code 进程。
- `CCSentinelCore`：会话状态、hook 解析、自动审批策略和持久化逻辑。

事件优先来自 Claude Code hooks；当 hooks 尚未上报但系统检测到 Claude Code 进程时，App 会显示进程 fallback 状态。审批状态仍以 hook 事件为准。

## 系统要求

- macOS 14 或更高版本
- Swift 6 / Xcode Command Line Tools
- Claude Code

## 本地运行

克隆项目后，在仓库根目录执行：

```bash
script/build_and_run.sh
```

脚本会构建 `CCSentinelApp` 和 `cc-sentinel-hook`，生成本地 App bundle：

```text
dist/CCSentinelApp.app
```

也可以运行启动校验：

```bash
script/build_and_run.sh --verify
```

## 安装 Hooks

启动 CC Sentinel 后，打开菜单栏弹窗并点击“安装 hooks”。安装器会合并 `~/.claude/settings.json`，为 Claude Code hook 事件添加 CC Sentinel 管理的 command hook。

写入设置前会创建备份：

```text
~/.claude/settings.json.cc-sentinel-backup-YYYYMMDD-HHMMSS
```

卸载时只移除 CC Sentinel 管理的 hook，不会删除用户已有 hooks。

更多细节见：

- [安装说明](docs/installation.zh-CN.md)
- [隐私说明](docs/privacy.zh-CN.md)

## 自动审批

自动审批默认关闭。策略完整保存在本机 JSON 配置文件中，App 的导入操作会先备份现有配置，再整份覆盖为导入文件。默认配置只包含自动允许规则，包括工作区内读取和常用低风险检查命令；自动同意会记录今日和累计次数。

未自动通过的请求可以直接在 CC Sentinel 面板中审核：

- `仅本次允许`：只允许当前请求。
- `仅本次拒绝`：只拒绝当前请求。
- `下次自动允许类似请求`：保存一条较窄的允许规则，并允许当前请求。

以下操作不会被默认自动同意：

- 工作区外读取
- 编辑文件
- 未列入白名单或复合 Bash 命令
- `sudo`
- `rm -rf`
- `git push`
- 其他高风险或敏感路径操作

自动审批配置和统计默认保存在：

```text
~/Library/Application Support/CC Sentinel/auto-approval-config.json
~/Library/Application Support/CC Sentinel/auto-approval-stats.json
~/Library/Application Support/CC Sentinel/pending-approvals/
~/Library/Application Support/CC Sentinel/approval-decisions/
```

仓库里提供了一个可直接导入的常用低风险模板：`docs/examples/auto-approval-config.json`

## 开发

运行核心测试：

```bash
swift run CCSentinelCoreTestRunner
```

构建所有 SwiftPM 目标：

```bash
swift build
```

运行 hook 流程模拟：

```bash
scripts/simulate-hook-flow.sh
```

查看当前状态 dump：

```bash
swift run cc-sentinel-dump-state
```

## 项目结构

```text
Sources/
  CCSentinelApp/          macOS 菜单栏 App
  CCSentinelCore/         核心模型、hook 解析、状态存储和审批策略
  CCSentinelHook/         Claude Code hook 转发命令
  CCSentinelWrapper/      VS Code Claude Code 进程 wrapper
  CCSentinelDumpState/    状态调试工具
docs/                     安装、隐私和 QA 文档
script/                   App 构建和启动脚本
scripts/                  开发和模拟脚本
```

## 隐私

CC Sentinel 只在本机运行。默认不会保存完整 raw events，也不会向外部服务发送 Claude Code 事件。UI 展示前会对 token、API key 和过长命令做脱敏或截断。

详见 [隐私说明](docs/privacy.zh-CN.md)。

## 贡献

欢迎提交 issue 和 pull request。建议在提交前运行：

```bash
swift run CCSentinelCoreTestRunner
script/build_and_run.sh --verify
```

如果改动涉及 hook 安装、会话状态或自动审批，请同时补充测试或更新 `docs/qa-checklist.md`。

## 许可证

本项目采用 [MIT License](LICENSE) 开源。
