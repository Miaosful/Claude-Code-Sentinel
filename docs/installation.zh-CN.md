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

状态栏菜单可以暂停监控。自动审批默认关闭；开启后当前只自动允许工作区内的 `Read` 请求，并记录今日/总计统计。工作区外读取、编辑、Bash、`sudo`、`rm -rf`、`git push` 等危险或高风险操作不会自动同意。

自动审批配置和统计默认保存在：

```text
~/Library/Application Support/CC Sentinel/auto-approval-settings.json
~/Library/Application Support/CC Sentinel/auto-approval-stats.json
```
