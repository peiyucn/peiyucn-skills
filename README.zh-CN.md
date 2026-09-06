# peiyucn-skills — Agent 技能市场

简体中文 | [English](README.md) | [GitHub](https://github.com/peiyucn/peiyucn-skills)

> Agent 原生技能，可在 Copilot、Claude Code、Codex 上通用安装。本仓库是一个个个市场个个 — 添加一次，即可安装它提供的任意插件。

## 安装市场



VS Code Copilot

 — 添加市场 `https://github.com/peiyucn/peiyucn-skills`，然后安装你需要的插件。



Claude Code

 — 先 `/marketplace add https://github.com/peiyucn/peiyucn-skills`，再 `/plugin install note2md`。



Codex CLI

 — `codex plugin install https://github.com/peiyucn/peiyucn-skills`（安装市场内的全部插件）。

## 插件

### note2md 📓

Markdown 笔记，按笔记本→分区→页面三层结构组织，通过斜杠命令管理。你的笔记就是文件夹和 `.md` 文件 — 用任何编辑器都能打开。但 Agent 也能帮你管理：创建笔记本、组织分区、从模板写页面、从 OneNote 导入、归档旧内容。

>   模型要求：   本技能依赖模型执行多步流程（导入管线、模板工作流、校验环节）。已在   deepseek-v4-flash（high）   上测试验证 — 能力不低于此模型的应可正常使用。过小或较弱的模型可能执行不稳定，我们无法给出硬性保证。

#### 命令

所有 Agent 使用统一命令：

| 命令 | 功能 |
|------|------|
| `/note2md help` | 快速入门指南 |
| `/note2md init` | 初始化 — 选择语言、确定笔记目录、导入 OneNote 或从头开始 |
| `/note2md newnotebook <名称>` | 创建笔记本 |
| `/note2md newsection <笔记本> <分区>` | 在笔记本中创建分区 |
| `/note2md newpage [模板]` | 创建页面 — 无参数=空白页；`daily`/`meeting`/`quick-note`=使用模板 |
| `/note2md newtemplate` | 从分区中的同类页面提取模板 |
| `/note2md securecheck` | 检查笔记中的密码、身份证、API 密钥等敏感信息 |
| `/note2md archive` | 将旧的笔记本、分区或页面移入归档 |

第一次用？输入 `/note2md help`（Copilot）或 `/note2md-help`（Claude/Codex）快速了解。

#### 自由使用

笔记本 = 文件夹。分区 = 子文件夹。页面 = `.md` 文件。想怎么用都行：用自然语言告诉 Agent 你的需求，用斜杠命令执行操作，或直接用文件管理器创建、重命名、移动、删除 — Agent 会自动感知变化。命令只是可选的便利工具。

#### 模板

`/note2md newpage` 始终提供模板选择。插件自带三个默认模板：

| 模板 | 名称 |
|------|------|
| 日记 | `daily` |
| 会议记录 | `meeting` |
| 快速笔记 | `quick-note` |

将你自己的模板放到 `notes/.note2md/templates/` 下 — 它们会自动出现在 `/note2md newpage` 中，并按名称覆盖同名默认模板。

使用 `/note2md newtemplate` 从任意分区中提取模板 — 选择分区、可选描述需求，Agent 会从同类笔记中提炼出模板骨架。

#### OneNote 导入

使用 `/note2md init` 导入你现有的 OneNote 笔记本。文本类内容 — 表格、列表、标题、待办、OCR 文本 — 会自动转换为 Markdown。

*   Windows + OneNote 桌面版：   Agent 可以自动导出你的笔记本。
*   macOS / Linux（或无 OneNote 桌面版）：   没有自动导出（仅限 Windows）— 你需要自己导出 XML（例如在装有 OneNote 桌面版的 Windows 机器上导出），再把文件位置告诉 `init`。

>   已知限制：   图片、文件附件、超链接、墨迹/绘图、公式、音频、视频频频暂不提取频频（完整清单见 [docs/onenote-loss-matrix.md](docs/onenote-loss-matrix.md)）。仅保证文本类内容。

### obscura-web 🌐

基于本地 **Obscura** 引擎（Rust 无头浏览器，内嵌 V8，无 Chromium）的网页抓取与浏览器会话。JS 渲染页面直接输出干净 Markdown，批量抓取并行执行，多步流程（登录→翻页→提取）通过内置 MCP 服务保持会话状态。

> 平台说明：Windows 优先。安装/服务管理脚本为 Windows PowerShell；macOS/Linux 从 [Obscura releases](https://github.com/h4ckf0r0day/obscura/releases) 安装官方二进制后直接运行 `obscura fetch` / `obscura mcp`。

#### 命令

| 命令 | 功能 |
|------|------|
| `/obscura-web help` | 快速入门指南 |
| `/obscura-web install` | 安装/升级 Obscura 引擎二进制 |
| `/obscura-web fetch <url>` | 抓取页面并输出渲染后 Markdown（含 JS 重页面） |
| `/obscura-web browse <命令>` | 会话模式：导航、快照、点击、填表、提取 |

## License

MIT
