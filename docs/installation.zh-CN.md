# CC Sentinel 安装说明

## 安装内容

CC Sentinel 第一版包含三个本地组件：

- `CCSentinelApp`：macOS 状态栏 App。
- `cc-sentinel-hook`：Claude Code hooks 事件转发命令。
- `cc-sentinel-wrapper`：用于 VS Code Claude Code 插件的进程 wrapper。

## 本地运行

开发版可以通过项目脚本构建并启动：

```bash
script/build_and_run.sh
```

脚本会构建 `CCSentinelApp`，在 `dist/CCSentinelApp.app` 生成本地 `.app` bundle，并启动菜单栏 App。也可以用以下命令做启动校验：

```bash
script/build_and_run.sh --verify
```

## Hooks 安装

安装器会预览并合并 `~/.claude/settings.json`，为以下事件增加 CC Sentinel 管理的 hook：

- `SessionStart`
- `PermissionRequest`
- `PostToolUse`
- `PostToolUseFailure`
- `Stop`
- `SessionEnd`
- `Notification`

CC Sentinel 管理的配置会写成 Claude command hook，并在升级或卸载时通过 `cc-sentinel-hook` 命令名识别。

## 备份与卸载

写入 Claude 设置前，安装器应创建带时间戳的备份：

```text
~/.claude/settings.json.cc-sentinel-backup-YYYYMMDD-HHMMSS
```

卸载时只删除命令名为 `cc-sentinel-hook` 的 hook，不删除用户已有 hooks。

## 暂停与自动审批

状态栏菜单可以暂停监控。自动审批默认关闭；策略完整保存在本机 JSON 配置文件中。导入配置时会先备份现有配置，再整份覆盖为导入文件。默认配置只包含自动允许规则，覆盖工作区内读取和常用低风险检查命令。工作区外读取、编辑、未列入白名单或复合 Bash 命令、`sudo`、`rm -rf`、`git push` 等危险或高风险操作不会自动同意。

未自动通过的请求可以在 CC Sentinel 面板中用 `仅本次允许`、`仅本次拒绝` 或 `下次自动允许类似请求` 审核。`仅本次拒绝` 始终是用户手动决定，CC Sentinel 不会基于策略自动拒绝。

自动审批配置和统计默认保存在：

```text
~/Library/Application Support/CC Sentinel/auto-approval-config.json
~/Library/Application Support/CC Sentinel/auto-approval-stats.json
~/Library/Application Support/CC Sentinel/pending-approvals/
~/Library/Application Support/CC Sentinel/approval-decisions/
```

仓库里还有一个可直接导入的低风险模板：`docs/examples/auto-approval-config.json`
