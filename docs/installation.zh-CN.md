# CC Sentinel 安装说明

## 安装内容

CC Sentinel 第一版包含三个本地组件：

- `CCSentinelApp`：macOS 状态栏 App。
- `cc-sentinel-hook`：Claude Code hooks 事件转发命令。
- `cc-sentinel-wrapper`：用于 VS Code Claude Code 插件的进程 wrapper。

## Hooks 安装

安装器会预览并合并 `~/.claude/settings.json`，为以下事件增加 CC Sentinel 管理的 hook：

- `SessionStart`
- `PermissionRequest`
- `PostToolUse`
- `PostToolUseFailure`
- `Stop`
- `SessionEnd`
- `Notification`

每个由 CC Sentinel 管理的配置项都会带有 `cc-sentinel-managed: true` 标记。

## 备份与卸载

写入 Claude 设置前，安装器应创建带时间戳的备份：

```text
~/.claude/settings.json.cc-sentinel-backup-YYYYMMDD-HHMMSS
```

卸载时只删除带 `cc-sentinel-managed: true` 的配置项，不删除用户已有 hooks。

## 暂停与自动审批

状态栏菜单可以暂停监控。自动审批默认关闭；开启后也应只允许明确策略覆盖的低风险操作。

