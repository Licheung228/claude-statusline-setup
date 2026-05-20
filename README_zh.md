[English](./README.md)

**基于 Claude code 官方skill `/statusline`**

# claude-statusline-setup

Claude Code 状态栏，通过 `/statusline-setup` 直接安装。

## 功能

在 Claude Code 终端会话底部添加实时状态栏：

```
Claude Sonnet 4.6 · thinking:on · high          ctx:72%/28%
```

- **左侧**：模型名称、思考状态、effort 等级
- **右侧**：上下文窗口使用率，动态颜色（绿色/黄色/红色）
- 右对齐至终端宽度

## 安装

1. 将本仓库安装为 Claude Code 技能：

   ```bash
   mkdir -p ~/.claude/skills/statusline-setup
   cp statusline-setup/SKILL.md ~/.claude/skills/statusline-setup/
   ```

2. 在 Claude Code 中运行以下命令之一：

   ```
   /statusline-setup
   /statusline-setup --interactive
   /statusline-setup --preset
   ```

   - `/statusline-setup`：会先询问你要使用默认预设还是交互式配置
   - `/statusline-setup --interactive`：交互式选择段落、布局、颜色和格式
   - `/statusline-setup --preset`：直接应用默认预设

3. 如果有提示，重启 Claude Code。

技能会自动完成平台识别、脚本生成、配置写入和验证。

## 说明

- 在 macOS / Linux 上，如果缺少 `jq`，技能会提示你安装。
- `/statusline-setup` 现在会先让你选择默认预设或交互模式。
- 默认模式会直接应用可用的预设。
- 交互模式允许你自定义段落、布局、颜色和格式。

## 卸载

### macOS / Linux

1. 删除 `~/.claude/statusline-command.sh`。
2. 从 `~/.claude/settings.json` 中移除 `statusLine` 字段。

### Windows

1. 删除 `~/.claude/statusline-command.ps1`。
2. 从 `~/.claude/settings.json` 中移除 `statusLine` 字段。

## 许可证

[MIT](LICENSE)
