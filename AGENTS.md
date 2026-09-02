# 项目指令 — peiyucn-skills

## 项目概况

仓库根即**市场（marketplace）**，插件放在 `plugins/` 下：

```
peiyucn-skills/                          — 仓库根 = 市场
├── .claude-plugin/
│   └── marketplace.json           — 市场货架清单（name: peiyucn-skills；三平台均识别此路径）
├── docs/
│   └── agent-compatibility.md     — 三平台兼容性分析与决策记录（为什么用 .claude-plugin 统一兼容）
├── plugins/note2md/               — 市场下的插件（插件名保持 note2md，命令命名空间 /note2md:xxx）
│   ├── commands/                  — 命令文件（8 个 .md，三平台通用：Claude Code / Codex / Copilot 均自动发现，命名空间 /note2md:xxx）
│   ├── .claude-plugin/
│   │   └── plugin.json            — 插件清单（声明 commands；skills 目录自动发现）
│   └── skills/note2md/
│       ├── SKILL.md               — **单一真相来源**：所有命令的完整执行逻辑
│       ├── templates/             — 内置模板（daily / meeting / quick-note）
│       │   ├── daily.template.md
│       │   ├── meeting.template.md
│       │   └── quick-note.template.md
│       └── tools/
│           ├── export-onenote.ps1     — OneNote 自动导出（Windows + COM API，可选）
│           ├── format-onenote-xml.ps1 — XML 排版为多行缩进（抽查用，可选）
│           └── convert-onenote-md.ps1 — XML→MD 确定性转换（核心，含 fixture 自测）
```

### 关键文件

| 文件 | 作用 |
|------|------|
| `.claude-plugin/marketplace.json` | 市场货架清单。`name` 即市场名（peiyucn-skills），插件条目声明 `source: ./plugins/note2md`；多余字段被各平台静默忽略 |
| `docs/agent-compatibility.md` | 三平台兼容性分析与决策记录（市场/插件安装/命令注册机制） |
| `plugins/note2md/skills/note2md/SKILL.md` | **核心**：所有 8 个命令的完整交互流程。是唯一需要维护逻辑的地方 |
| `plugins/note2md/SKILL-CN.md` | SKILL.md 的中文同步翻译，仅供作者对照。**修改 SKILL.md 时必须同步更新** |
| `plugins/note2md/commands/*.md` | 薄壳——仅含 frontmatter（name + description + argument-hint）+ 一句委托指令 |
| `plugins/note2md/.claude-plugin/plugin.json` | 插件清单，声明 commands 路径；skills 目录自动发现 |

## 开发

本仓库无 CI / 无构建（总规范口径）。开发约定：

* **薄壳原则**：`commands/` 只做委托，不重复维护逻辑
* **统一 frontmatter**：命令文件使用同一套 YAML frontmatter（`name` + `description` + `argument-hint`）。多余字段被各平台静默忽略，不报错
* **修改流程**：改逻辑 → 只改 `SKILL.md` → 同步 `SKILL-CN.md`。如果改了命令的 frontmatter 字段 → 同步更新 commands 下对应文件

## Git 与发布

通用流程（自含）：日常开发在 `dev`、逐项提交、中文描述 + 英文类型前缀（feat:/fix:/refactor:/chore:/docs: 等）、不确定的事直接说"不确定"；本仓库额外约定：

* **可用类型**：`feat` `fix` `refactor` `chore` `docs` `style` `perf` `build` `revert`（例：`feat: 新增命令自动补全`、`fix: 修复模板排序`、`docs: 补充命令交互流程文档`）
* **提交时机**：每轮对话结束时，Agent 自行判断是否 `git commit` + `git push`，无需等用户发指令：
  * ✅ 该提交 — 一轮对话完成了一个独立的功能/修复/重构，改动原子化、可独立回溯
  * ✅ 该提交 — 用户明确说「好了」「可以了」「提交吧」
  * ❌ 先别交 — 还在讨论/探索/收集需求，方向未定
  * ❌ 先别交 — 中途打断、单轮改动不完整、留了 TODO 没处理
* **分支同步**：`push` 到 `dev` 后**必须**同步 `master`（`git push origin dev:master`）。Copilot Chat 市场安装拉的是 `master`，不同步会导致用户安装到旧版本
* **版本号与 push 强绑定**：**凡是 `push`，`plugin.json` 与 `marketplace.json` 的 `version` 字段必须同步更新**。市场按版本号识别更新，只改代码不改版本号会导致用户装到旧版缓存。例外：**未 push 的本地测试**可先不改版本号，测试通过、准备发布时才 bump + push
* **commit 前检查工程文件**：任何涉及行为/结构的改动，commit 前必须检查以下文件是否需要同步调整：
  * `README.md` / `README.zh-CN.md` — 功能描述、命令列表、导入说明
  * `CONTRIBUTING.md` / `CONTRIBUTING.zh-CN.md` — 项目结构树、分支策略
  * `plugins/*/SKILL-CN.md` — SKILL.md 的中文同步翻译，**改 SKILL.md 必须同步**
  * `.claude-plugin/marketplace.json` + `plugins/*/.claude-plugin/plugin.json` — version 字段
  * `docs/` 下的文档（如 onenote-loss-matrix.md）
* **版本标签**：每个 push 的版本**必须**打 tag（`plugin.json` 与 `marketplace.json` 的 `version` 保持一致）：

  ```bash
  git tag -a v{version} -m "v{version}: {简要说明}"
  git push origin v{version}
  ```

  * 版本规则：`fix` → patch（0.2.0 → 0.2.1）；`feat` → minor（0.2.0 → 0.3.0）；破坏性变更 → major
  * 流程：bump 版本号 → commit → push dev → push dev:master → 打 tag → push tag，**一个版本一个 commit，版本号与代码同批推送**

### GitHub 操作（gh cli）

* 本机已安装并登录 **gh cli**（账号 `peiyucn`，https 协议，凭据存 keyring），GitHub 操作一律走 `gh`，Agent 可直接使用；`gh api` 直连、`git push/fetch` 需要代理 127.0.0.1:7897
* 本仓库远程：`https://github.com/peiyucn/peiyucn-skills.git`（原名 pyskills，再往前是 note2md，已两次改名）
* 常用操作：
  * 仓库改名：`gh repo rename <新名> --repo peiyucn/peiyucn-skills --yes`
  * 查看仓库信息：`gh repo view peiyucn/peiyucn-skills`
  * 创建仓库：`gh repo create <名称> --public --source . --remote origin --push`
* 改名后需同步更新本地 remote：`git remote set-url origin https://github.com/peiyucn/<新名>.git`

## 其他（规则）

* **诚实原则**：不确定的事直接说"不确定"，禁止编造 URL、API 接口、文档引用或任何事实性信息
* **查证原则**：引用文件位置、函数名、调用关系时，若不确定则先 grep 确认再写，禁止凭记忆编造
* **自检原则**：代码移动/提取后**必须**搜索确认旧位置已删除，不得留有死代码或同名遮蔽
