# 三平台 Agent 插件兼容性说明

> 本文档基于源码级验证（2026-07-31）：openai/codex 与 microsoft/vscode 仓库源码、Anthropic Claude Code 官方文档。记录了 peiyucn-skills 市场在 **Claude Code / Codex / VS Code Copilot** 三平台的兼容机制与设计决策。

## 结论先行

1. **三个平台对"市场"与"插件"的识别路径有交集**：`.claude-plugin/plugin.json`（插件清单）和 `.claude-plugin/marketplace.json`（市场清单）被三个平台同时识别——Claude Code 原生支持，Codex 与 VS Code 做了跨格式兼容。
2. **因此本仓库用一套结构兼容三者**：根目录放市场清单，`plugins/` 下放插件，插件内部用 `.claude-plugin/` 清单 + `commands/` + `skills/`。无需维护三份清单。
3. **命令注册三平台都能工作，但形式不同**：Claude Code 与 VS Code 支持 `/note2md:xxx` 斜杠补全；Codex 无斜杠命令机制（产品设计），插件 `commands/` 在安装时自动迁移为 skills，靠 `@` mention / 描述触发。
4. **统一标准（agent-plugins.org）尚未完全落地**：VS Code 与 Codex 已能识别 agent-plugins.org 格式的根 `plugin.json`，但 Claude Code 仍要求 manifest 必须在 `.claude-plugin/plugin.json`。这是当前仍使用 `.claude-plugin/` 的原因；待 Claude Code 跟进后，可平滑迁移到统一标准。

---

## 一、统一标准：agent-plugins.org v1

跨平台插件统一标准（Agent Plugins，`https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`）：

- 字段：`$schema`、`name`、`version`、`description`、`author`、`homepage`、`repository`、`license`、`keywords`、`extensions`——**没有** commands/skills 字段，组件靠固定路径约定。
- 固定路径：`skills/*/SKILL.md`、`mcp.json`、`commands/`、`hooks.json`。
- `name` 约束：小写字母/数字/点/连字符，≤ 64 字符，不允许 `--` 和 `..`。

### 各平台跟进状态

| 平台 | 识别 agent-plugins.org 根 `plugin.json` | 说明 |
|------|:---:|------|
| VS Code / Copilot | ✅ | `detectPluginFormat()` 优先检测根 `plugin.json` 是否带 agent-plugins.org `$schema`（AGENT_PLUGIN_FORMAT） |
| Codex | ✅ | 根 `plugin.json` 需带 agent-plugins.org `$schema` 才会被当作 agent manifest；`.codex-plugin/plugin.json` 是自家格式 |
| Claude Code | ❌ | 官方明确要求 manifest **必须**位于 `.claude-plugin/plugin.json`，否则插件不被识别 |

> **决策依据**：统一标准是未来方向，但当前迁移会让 Claude Code 用户装不上插件，故本仓库保持 `.claude-plugin/` 结构（见第三节）。

---

## 二、三平台机制对比

### 1. 市场（Marketplace）识别

| 平台 | 市场清单路径 | 本仓库对应 |
|------|-------------|-----------|
| Claude Code | 根 `.claude-plugin/marketplace.json` | ✅ 根 `.claude-plugin/marketplace.json` |
| Codex | `MARKETPLACE_MANIFEST_RELATIVE_PATHS` 含 `.claude-plugin/marketplace.json` | ✅ 同一文件 |
| VS Code / Copilot | 支持 marketplace 列表（settings.json `chat.pluginMarketplaces` 或插件市场配置） | ✅ 同一文件 |

- `marketplace.json` 的 `name` 即**市场名**（本仓库：`peiyucn-skills`）；插件条目用 `source` 指向仓库内相对路径（本仓库：`./plugins/note2md`，Codex 有测试覆盖此"字符串本地 source"场景）。
- 多余字段（`category`、`tags` 等）被各平台静默忽略，不会报错。

### 2. 插件清单识别

| 平台 | 插件清单路径 | 说明 |
|------|-------------|------|
| Claude Code | `.claude-plugin/plugin.json`（插件根下） | 唯一入口，缺了就不识别 |
| Codex | `DISCOVERABLE_PLUGIN_MANIFEST_PATHS = [".codex-plugin/plugin.json", ".claude-plugin/plugin.json", ".cursor-plugin/plugin.json"]` | 三个目录都认 |
| VS Code / Copilot | `detectPluginFormat()`：根 plugin.json（agent-plugins.org）→ `.plugin/plugin.json` → `.claude-plugin/plugin.json` | 按顺序自动检测，命中即用 |

本仓库：`plugins/note2md/.claude-plugin/plugin.json`，三平台共用。

### 3. 命令注册与触发形式

| 平台 | 命令形式 | `/` 补全 | 注册来源 |
|------|---------|:---:|---------|
| Claude Code | `/note2md:xxx`（插件名自动前缀） | ✅ 原生 | `plugin.json` 声明的 `commands/` 目录 |
| VS Code / Copilot | `/note2md:xxx`（`getCanonicalPluginCommandId()` → `/插件名:命令名`） | ✅ | `commands/` 与 `skills/` 都注册为斜杠命令 |
| Codex | 无斜杠命令（产品设计："Plugins are not invoked directly. Use their underlying skills"） | ❌ | 安装时 `migrate_plugin_commands()` 把 `commands/*.md` 迁移为 skills（`.codex-plugin/migrated-command-skills/`，前缀 `source-command`，要求 frontmatter 有 `description`），靠 `@` mention / 描述自动触发 |

> **结论**：`commands/*.md` 薄壳（frontmatter `name` + `description` + `argument-hint` + 一句委托指令）是三平台命令的唯一来源。Codex 无 `/` 补全是平台限制，无法绕过——这是三平台行为差异的**唯一实质差异**，命令本身在 Codex 中仍可用（形式不同）。

### 4. 安装方式

| 平台 | 市场方式 | 直接方式 |
|------|---------|---------|
| Claude Code | `/marketplace add <仓库>` + `/plugin install <插件>` | — |
| VS Code / Copilot | 市场列表添加仓库 URL 后安装 | `chat.pluginLocations` 指向本地插件目录 |
| Codex | `codex plugin marketplace add <仓库>` + `codex plugin install <插件>` | `codex plugin install <仓库 URL>`（装市场内全部插件） |

---

## 三、本仓库的结构与决策

### 为什么根目录只有 `.claude-plugin/`，没有 `.codex-plugin/`、`.plugin/`？

- **Claude Code 只认 `.claude-plugin/plugin.json`**（硬性要求）；
- Codex 与 VS Code 都**主动兼容** `.claude-plugin/`（见上表），无需额外清单；
- 结论：一份 `.claude-plugin/` 结构三平台全通，重复维护多份清单反而容易漂移。

### 当前结构

```
peiyucn-skills/                          — 仓库根 = 市场
├── .claude-plugin/
│   └── marketplace.json           — 市场货架清单（name: peiyucn-skills；三平台均识别此路径）
├── plugins/note2md/               — 市场下的插件
│   ├── commands/                  — 9 个命令薄壳（三平台唯一命令来源）
│   ├── .claude-plugin/
│   │   └── plugin.json            — 插件清单（声明 commands；skills 目录自动发现）
│   └── skills/note2md/
│       ├── SKILL.md               — 单一真相来源：所有命令的完整执行逻辑
│       ├── templates/             — 内置模板
│       └── tools/                 — OneNote 导出/转换脚本
```

- **市场名 ≠ 插件名**：市场叫 `peiyucn-skills`，插件叫 `note2md`（命令命名空间 `/note2md:xxx`）。这与 Anthropic 官方市场的结构一致。
- **`skills/*/SKILL.md` 目录名即技能名**（三平台约定）：本仓库为 `skills/note2md/SKILL.md`。
- **薄壳原则**：`commands/*.md` 只含 frontmatter + 一句委托，逻辑全部在 `SKILL.md`。

### 各平台实际生效链路

| 平台 | 市场 → 插件 → 命令 |
|------|--------------------|
| Claude Code | 根 `marketplace.json` → `/marketplace add` → 插件 `plugin.json` → `commands/` 注册为 `/note2md:xxx` |
| Codex | 根 `marketplace.json`（MARKETPLACE_MANIFEST_RELATIVE_PATHS）→ `codex plugin install` → 发现 `.claude-plugin/plugin.json` → `commands/` 迁移为 skills（mention 触发） |
| VS Code / Copilot | 市场列表/`chat.pluginLocations` → 检测 `.claude-plugin/plugin.json`（CLAUDE_FORMAT）→ `commands/` + `skills/` 注册为 `/note2md:xxx` 补全 |

---

## 四、未来迁移路径

当 Claude Code 支持 agent-plugins.org 标准（根 `plugin.json`）后：

1. 在插件根放一份 agent-plugins.org 格式的 `plugin.json`（带 `$schema` 指向 `https://agent-plugins.org/schemas/1.0.0/plugin.schema.json`）；
2. 保留 `.claude-plugin/plugin.json` 一段时间（VS Code 检测顺序会优先命中根 plugin.json，Codex 亦如此；Claude Code 在跟进前仍需 `.claude-plugin/`）；
3. 待三平台全部支持后，删除 `.claude-plugin/plugin.json`，只留统一清单。

> 迁移前无需任何改动：VS Code 与 Codex 已能识别统一格式，唯一的等待项是 Claude Code。
