# CC Sentinel 需求说明

日期：2026-06-24
状态：待评审草稿

## 1. 目标

CC Sentinel 是一个 macOS 状态栏小工具，用来监控本机 Claude Code 的运行状态。它需要覆盖 Claude Code CLI 会话，以及由 VS Code Claude Code 插件启动的会话，让用户可以通过一个常驻状态栏信号快速判断 Claude Code 当前是空闲、运行中、等待审批，还是处于自动审批策略启用状态。

产品应避免依赖脆弱的 UI 抓取。主数据源应使用 Claude Code 生命周期 hooks；VS Code 进程 wrapper 和进程检测只作为辅助信号。

## 2. 问题背景

Claude Code 可能同时运行在多个地方：独立终端、VS Code 集成终端，或 VS Code Claude Code 插件面板。用户现在需要频繁切换窗口，才能知道 Claude Code 是否还在工作、是否已完成，或是否卡在权限审批提示上。

当 Claude Code 在后台、隐藏 tab、多个仓库或多个 VS Code 窗口中运行时，这个问题尤其明显。用户希望通过 macOS 状态栏快速回答：

- Claude Code 是否正在运行？
- 是否有任意会话正在等待审批？
- 哪个项目或哪个会话需要注意？
- 是否可以在用户控制的策略下，自动处理低风险审批？

## 3. 产品目标

- 在 macOS 状态栏显示 Claude Code 活动状态。
- 在 hooks 可用的前提下，同时支持 Claude Code CLI 和 VS Code 插件会话。
- 使用 `session_id` 独立追踪多个会话。
- 通过 Claude Code hooks 检测权限审批请求。
- 在菜单中显示会话来源、当前工作目录、最近工具和审批状态。
- 提供安全的安装器，用于添加、更新和移除 CC Sentinel 的 Claude Code hook 配置。
- 不读取或控制 VS Code UI 内部状态，也能保持可靠监控。
- 将自动审批放到第二阶段，并设置明确的安全边界。

## 4. 非目标

- 不把 VS Code UI、终端屏幕文本或 Accessibility tree 抓取作为主要监控方式。
- 不承诺在 hooks 被禁用或不可用的 Claude Code 环境中实现完美监控。
- 不在没有预览、备份和卸载能力的情况下静默修改用户 Claude Code 设置。
- 不默认启用无限制自动审批。
- 不替代 Claude Code 自身的权限系统。
- MVP 不支持远程机器、SSH 会话或云 IDE。

## 5. 目标用户

- 会让 Claude Code 长时间执行编码任务的开发者。
- 同时在多个仓库和多个 VS Code 窗口中工作的用户。
- 希望在 Claude Code 需要审批时得到明确视觉信号的用户。
- 后续可能希望为低风险操作启用策略化自动审批的高级用户。

## 6. 产品界面

### 6.1 状态栏指示器

状态栏图标需要表达全局聚合状态：

- 空闲：没有已知的活跃 Claude Code 会话。
- 运行中：至少有一个活跃会话正在运行。
- 等待审批：至少有一个会话卡在权限请求上。
- 自动审批已启用：至少一个会话或全局配置启用了自动审批策略。
- 降级状态：hook 事件过期、本地事件服务不可用，或当前状态可能不完整。

视觉表现可以使用不同图标、颜色或轻量动画。具体品牌、logo 和动效设计不属于本文档范围。

### 6.2 菜单内容

点击状态栏图标后，应展示：

- 全局状态。
- 活跃会话数量。
- 按来源分组的会话列表：CLI、VS Code、未知。
- 每个会话展示：
  - 来源
  - `session_id`
  - `cwd`
  - 当前状态
  - 权限模式，如果可得
  - 最近工具名，如果可得
  - 最近审批请求摘要，如果存在
  - 最近事件时间
- 操作入口：
  - 打开项目文件夹
  - 复制会话详情
  - 打开 Claude 设置文件
  - 安装或更新 hooks
  - 卸载 hooks
  - 暂停监控
  - 清理过期会话

## 7. 数据来源

### 7.1 Claude Code Hooks

Claude Code hooks 是主要数据源。CC Sentinel 应提供 hook 命令，从 stdin 接收 Claude Code hook JSON，并把归一化事件转发给本地事件服务。

MVP 需要支持的 hook 事件：

- `SessionStart`：创建或刷新会话。
- `PermissionRequest`：将会话标记为等待审批。
- `PostToolUse`：清除匹配的等待审批状态，并记录工具完成。
- `PostToolUseFailure`：清除匹配的等待审批状态，并记录失败。
- `Stop`：在适用时将当前 turn 标记为完成或空闲。
- `SessionEnd`：移除或关闭会话。
- `Notification` 中的 `permission_prompt`：可作为辅助提醒信号，但不是主要审批状态来源。

hook 处理器应尽量保留以下字段：

- `session_id`
- `cwd`
- `transcript_path`
- `permission_mode`
- `tool_name`
- `tool_input`
- `tool_response`
- hook 事件名
- 事件时间

### 7.2 VS Code Claude Process Wrapper

VS Code 插件可以配置 Claude process wrapper。CC Sentinel 应提供一个 wrapper 可执行文件，用于增强来源识别和进程生命周期记录。

wrapper 应该：

- 上报进程启动和进程结束
- 将事件或进程标记为可能来自 `vscode`
- 将所有参数透传给真实 Claude binary
- 不改变 Claude Code 行为
- 不负责解释审批状态

wrapper 不是权限审批提示的事实来源。

### 7.3 进程检测

进程检测只作为兜底。它可以帮助判断是否存在 Claude 相关进程，但不能可靠识别会话状态或权限状态。

进程检测可用于：

- 显示“检测到 Claude 进程，但没有 hook 事件”的降级状态
- 当相关进程消失时清理过期会话
- 结合 wrapper 数据辅助区分 CLI 和 VS Code 来源

## 8. 事件服务

CC Sentinel 应运行本地事件服务，接收来自 hook 脚本和 wrapper 的归一化事件。

可选传输方式：

- localhost HTTP endpoint
- Unix domain socket
- append-only JSONL 文件兜底

MVP 推荐：

- 使用 localhost HTTP，便于实现；如果状态栏 App 未运行，则 fallback 到文件写入。

要求：

- 快速接收 hook 命令事件
- 避免阻塞 Claude Code 执行
- 校验事件结构
- 归一化并持久化会话状态
- 容忍重复、缺失和乱序事件
- 在 UI 中对敏感 tool input 做脱敏或截断

## 9. 会话状态模型

状态必须按会话维护，而不是只有一个全局布尔值。

每个会话应包含：

- `session_id`
- `source`：`cli`、`vscode` 或 `unknown`
- `cwd`
- `status`：`running`、`waiting_approval`、`idle`、`ended`、`stale` 或 `error`
- `permission_mode`
- `last_tool_name`
- `last_tool_summary`
- `last_event_at`
- `waiting_since`
- `approval_request`

状态栏全局聚合优先级：

1. 任意会话处于 `waiting_approval`：显示需要审批。
2. 任意会话处于 `running`：显示运行中。
3. 任意会话过期或信号降级：显示降级状态。
4. 其他情况：显示空闲。

## 10. 审批检测

`PermissionRequest` 是 `waiting_approval` 的主要触发信号。

当 CC Sentinel 收到 `PermissionRequest` 事件时：

- 将对应会话标记为 `waiting_approval`
- 记录工具名和安全摘要版 tool input
- 立即更新状态栏图标
- 如果用户开启，可发送 macOS 通知

等待审批状态应在以下情况清除：

- 收到匹配的 `PostToolUse`
- 收到匹配的 `PostToolUseFailure`
- `Stop` 事件表明当前 turn 已结束
- 收到 `SessionEnd`
- 会话超过可配置的 stale timeout
- 用户手动清理过期状态

当 `PermissionRequest` 不可用时，`Notification(permission_prompt)` 可以作为辅助信号，但不应覆盖信息更完整的 `PermissionRequest` 状态。

## 11. 自动审批

自动审批不属于 MVP 默认行为。只有在被动监控足够可靠之后，才应实现自动审批。

实现时，自动审批必须是策略化的：

- 默认关闭
- 启用时在状态栏中明确可见
- 可按 workspace、来源、工具和风险等级限定范围
- 通过事件日志可审计
- 提供一个简单的全局关闭开关

建议策略：

- 只有用户明确选择时，才允许低风险读取和工作目录内编辑。
- 包安装、网络命令、`git push`、破坏性文件操作、workspace 外 shell 命令、访问敏感路径等操作应继续询问。
- 默认拒绝已知危险模式。

工具应避免无限制自动审批。如果暴露等价于跳过权限的模式，必须给出强警告，并建议只在容器或 VM 等隔离环境中使用。

## 12. 设置安装

CC Sentinel 应提供 Claude Code 集成安装流程。

安装器要求：

- 检查现有 `~/.claude/settings.json`
- 应用前预览变更
- 写入前创建带时间戳的备份
- 合并 hooks，且不删除用户无关设置
- 支持卸载，只移除 CC Sentinel 管理的配置项
- 记录安装标记，方便后续安全更新
- 说明会收集哪些数据以及数据存储位置

MVP 可以先提供手动安装命令，再做完整 UI 安装器。

## 13. 隐私与安全

CC Sentinel 只在本地运行，不应向外部服务发送事件数据。

敏感数据处理：

- 只有用户开启诊断日志时，才保存完整 raw events。
- 菜单 UI 中对命令参数和文件内容做脱敏或截断。
- 避免展示 tool input 中的 secret。
- 本地状态存放在用户的 Library/Application Support 目录下。
- 日志应易于清除。

安全要求：

- hooks 和 wrappers 应保持短小、可审计。
- 事件接收服务只监听 localhost 或 Unix domain socket。
- 事件接收服务应拒绝格式错误的事件。
- 自动审批必须明确 opt-in。

## 14. MVP 范围

第一个可用版本应包含：

- macOS 状态栏 App。
- 本地事件接收服务。
- Claude Code 事件转发 hook 脚本。
- 安全的 hook 配置安装器。
- 会话状态存储。
- 多会话菜单展示。
- 基于 `PermissionRequest` 的需要审批状态。
- 对 `permission_prompt` 的辅助通知处理。
- 过期会话清理。
- 用于来源和生命周期标记的 VS Code wrapper。
- 手动暂停、清理和卸载操作。

MVP 不包含无限制自动审批。

## 15. 后续阶段

第二阶段：

- 策略化自动审批。
- 按 workspace 配置审批 profile。
- 更详细的审计日志。
- allow、ask、deny 规则配置 UI。
- 在合适情况下提供带操作按钮的 macOS 通知。

第三阶段：

- 如有需要，增加可选 VS Code companion extension，提供更丰富的 VS Code 集成。
- 更准确的 session 到窗口映射。
- 更精致的状态栏动效和图标主题。
- 团队或共享策略模板。
- 如果 Claude Code 为远程环境暴露可靠本地事件，再支持远程环境。

## 16. 待确认问题

- MVP 应使用 Swift/SwiftUI 原生实现，还是使用 Tauri 或 Electron？
- 第一版事件传输使用 localhost HTTP，还是 Unix domain socket？
- 为了审计应保留多少 raw `tool_input`，又应脱敏到什么程度？
- 来源识别应依赖 `claudeProcessWrapper`、环境变量、进程父子关系，还是三者结合？
- 当 hooks 未安装或失效时，最低可接受行为是什么？
- 自动审批应作为付费/专业/高级功能，还是只隐藏在明确的高级设置开关之后？

## 17. 验收标准

- 安装 hooks 后，当 Claude Code CLI 会话启动时，CC Sentinel 能显示活跃会话。
- 安装 hooks 且通过 wrapper 启动 VS Code extension 会话后，CC Sentinel 能显示来源为 VS Code 的会话。
- 当 Claude Code 发出 `PermissionRequest` 时，在正常本地环境下，状态栏应在 1 秒内切换为等待审批状态。
- 当相关工具执行完成或失败时，等待审批状态会清除。
- 多个并发会话能独立展示。
- 如果 hook 事件停止到达，过期会话最终会被标记为 stale，而不是永久保持 active。
- 安装 hooks 会备份现有 Claude 设置，并且不删除无关设置。
- 卸载时只移除 CC Sentinel 管理的 hook 配置。
- 自动审批默认不启用。

## 18. 参考资料

- Claude Code hooks: https://code.claude.com/docs/en/hooks
- Claude Code permissions: https://code.claude.com/docs/en/permissions
- Claude Code VS Code integration: https://code.claude.com/docs/en/vs-code
