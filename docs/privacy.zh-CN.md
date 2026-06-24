# CC Sentinel 隐私说明

CC Sentinel 只在本机运行，不向外部服务发送 Claude Code 事件。

## 本地数据

可能保存的数据包括：

- 会话 ID
- 会话来源：CLI、VS Code 或 unknown
- 当前工作目录
- hook 事件名称和时间
- 最近工具名
- 经过脱敏和截断的工具输入摘要
- 自动审批审计事件和计数

## 敏感信息处理

- 默认不保存完整 raw events。
- UI 展示前会对 token、API key 和过长命令做脱敏或截断。
- fallback JSONL 文件只在状态栏 App 不可用时写入。
- 日志和 fallback 文件应提供清理入口。

## 自动审批

自动审批必须明确 opt-in。默认策略为 ask；危险命令如 `git push`、`rm -rf`、`sudo` 和敏感路径访问默认 deny。

