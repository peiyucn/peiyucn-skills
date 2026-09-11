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
│   ├── commands/                  — 命令文件（9 个 .md，三平台通用：Claude Code / Codex / Copilot 均自动发现，命名空间 /note2md:xxx）
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
├── plugins/obscura-fetch/           — 市场下的插件（插件名 obscura-fetch，命令命名空间 /obscura-fetch:xxx）
│   ├── commands/                  — 命令薄壳（3 个 .md：fetch / install / help）
│   ├── .claude-plugin/
│   │   └── plugin.json            — 插件清单
│   ├── SKILL-CN.md                — SKILL.md 中文对照（仅供作者）
│   └── skills/obscura-fetch/
│       ├── SKILL.md               — **单一真相来源**：匿名抓取（fetch / 批量 scrape / stealth）+ 已知坑；脚本路径用 {SKILL_DIR} 相对约定
│       └── scripts/
│           └── install-obscura.ps1 — Obscura 引擎安装/升级（Windows，幂等，直连失败走代理）
```

### 关键文件

| 文件 | 作用 |
|------|------|
| `.claude-plugin/marketplace.json` | 市场货架清单。`name` 即市场名（peiyucn-skills），插件条目声明 `source: ./plugins/note2md`；多余字段被各平台静默忽略 |
| `docs/agent-compatibility.md` | 三平台兼容性分析与决策记录（市场/插件安装/命令注册机制） |
| `plugins/note2md/skills/note2md/SKILL.md` | **核心**：所有 9 个命令的完整交互流程。是唯一需要维护逻辑的地方 |
| `plugins/obscura-fetch/skills/obscura-fetch/SKILL.md` | **核心**：匿名抓取（`fetch` / 批量 `scrape` / stealth 反指纹）与已知坑；脚本路径 {SKILL_DIR} 相对约定。**刻意只做抓取**——交互式浏览一律走 Playwright 栈 |
| `plugins/obscura-fetch/SKILL-CN.md` | SKILL.md 中文同步翻译，仅供作者对照。**修改 SKILL.md 时必须同步更新** |
| `plugins/note2md/SKILL-CN.md` | SKILL.md 的中文同步翻译，仅供作者对照。**修改 SKILL.md 时必须同步更新** |
| `plugins/note2md/commands/*.md` | 薄壳——仅含 frontmatter（name + description + argument-hint）+ 一句委托指令 |
| `plugins/note2md/.claude-plugin/plugin.json` | 插件清单，声明 commands 路径；skills 目录自动发现 |

## 文档规范

> 三份文档各司其职、各有读者：AGENTS 给开发 agent、README 给用户、CHANGELOG 给用户——写错读者是文档事故。

* `AGENTS.md`：中文一份（面向开发 agent；唯一 agent 指令文件，不保留 CLAUDE.md 等其它厂商指令文件）
* `README.md` / `README.zh-CN.md`：市场介绍——安装、命令列表、导入说明；中英双份、英文默认、顶部互链；功能/命令变更时更新
* `CONTRIBUTING.md` / `CONTRIBUTING.zh-CN.md`：贡献指南——项目结构树、分支策略；结构或流程变更时更新
* 无 CHANGELOG（版本语义 = `marketplace.json`/`plugin.json` 的 `version` 字段 + git tag，见「工程管线 · 发布」）
* 插件内：`SKILL.md` 是**单一真相来源**；`SKILL-CN.md` 是其**中文同步翻译**（仅供作者对照，改 SKILL.md 必须同步）；`commands/*.md` 是薄壳委托，不重复维护逻辑

## 工程管线（本仓库自含）

* 本仓库无 CI / 无构建（纯内容仓库，无 pipeline）
* **开发**：日常改动在 `dev`；`main` 供市场安装拉取（Copilot Chat 市场装 `main`）
* **验证**：无构建验证——提交前自查「commit 前检查工程文件」清单
* **提交**：逐项提交，中文描述 + 英文类型前缀；可用类型 `feat` `fix` `refactor` `chore` `docs` `style` `perf` `build` `revert`（例：`feat: 新增命令自动补全`、`fix: 修复模板排序`、`docs: 补充命令交互流程文档`）；不确定的事直接说"不确定"，禁止编造事实性信息。**提交时机**：每轮对话结束时自行判断——独立完成一个功能/修复/重构且改动原子可回溯，或用户明确说「好了」「提交吧」→ 提交；还在讨论/探索、方向未定、中途打断、留了 TODO 未处理 → 先不交
* **推送**：push 到 `dev` 后**必须**同步 `main`（`git push origin dev:main`）——Copilot Chat 市场安装拉的是 `main`，不同步会导致用户安装到旧版本；**版本号与 push 强绑定**：凡是 push，被改插件的 `plugin.json` 与 `marketplace.json` 对应条目的 `version` 必须同步更新——市场按版本号识别更新，只改代码不改版本号会导致用户装到旧版缓存；例外：未 push 的本地测试可先不改版本号，准备发布时才 bump + push
* **发布确认（硬门禁，owner 当次点头）**：`git tag` / `npm publish` / 市场发布 / 部署上线等**不可逆的对外发布动作**，执行前必须由 owner **当次明确确认**——「之前批准了整条发布流程」「评审时说按你建议走」「继续」一律**不构成**发布许可；agent 做完审计 / 定版 / verify / 合并后**停在发布动作之前**，一句话报出「要发什么、版本号、目标通道、影响范围」等 owner 回话，未回话即视为未批准（总规范《工程管线 · ⑦发布》第 5 步）
* **发布**：**两插件各自独立版本线**（松散集合，互不牵连：note2md 与 obscura-fetch 的版本号各自独立演进，当前值见 `marketplace.json`）；每个 push 的版本**必须**打 tag（`git tag -a {plugin}-v{version} -m "{plugin}-v{version}: {简要说明}"` + `git push origin {plugin}-v{version}`；新 tag 一律插件前缀；历史无前缀 v0.1.0–v0.5.1 是 note2md 单插件时期的遗留，保留不动）；版本规则：`fix` → patch（0.5.3 → 0.5.4）、`feat` → minor（0.5.3 → 0.6.0）、破坏性变更 → major；流程：bump 被改插件的 `plugin.json` + `marketplace.json` 对应条目 → commit → push dev → push dev:main → 打 tag → push tag，**一个版本一个 commit，版本号与代码同批推送**
* **commit 前检查工程文件**：任何涉及行为/结构的改动，commit 前必须检查以下文件是否需要同步调整：
  * `AGENTS.md` — 项目结构树、关键文件表、命令数量（**结构改动必查**；曾因漏掉本文件，结构树长期写着已删除的目录）
  * `README.md` / `README.zh-CN.md` — 功能描述、命令列表、导入说明
  * `CONTRIBUTING.md` / `CONTRIBUTING.zh-CN.md` — 项目结构树、分支策略
  * `plugins/*/SKILL-CN.md` — SKILL.md 的中文同步翻译，**改 SKILL.md 必须同步**
  * `.claude-plugin/marketplace.json` + `plugins/*/.claude-plugin/plugin.json` — version 字段
  * `docs/` 下的文档（如 onenote-loss-matrix.md）

## 安全基线（本仓库自含要点）

* 已开启：secret scanning + push protection、根 `SECURITY.md`；检查命令 `gh api repos/peiyucn/peiyucn-skills --jq .security_and_analysis`
* 未开启（与统一安全基线有出入，2026-09 查证）：Dependabot alerts、CodeQL default setup、Dependabot 自动升级
* 分支保护：`dev` 与默认分支两个 ruleset 轻保护（禁删/禁强推/禁建）；无 CI

## GitHub 与网络

* 本机已安装并登录 **gh cli**（账号 `peiyucn`，https 协议，凭据存 keyring），GitHub 操作一律走 `gh`，Agent 可直接使用
* 本仓库远程：`https://github.com/peiyucn/peiyucn-skills.git`（原名 pyskills，再往前是 note2md，已两次改名）
* 常用操作：
  * 仓库改名：`gh repo rename <新名> --repo peiyucn/peiyucn-skills --yes`
  * 查看仓库信息：`gh repo view peiyucn/peiyucn-skills`
  * 创建仓库：`gh repo create <名称> --public --source . --remote origin --push`
* 改名后需同步更新本地 remote：`git remote set-url origin https://github.com/peiyucn/<新名>.git`

## 项目专属章节

### 开发约定

* **薄壳原则**：`commands/` 只做委托，不重复维护逻辑
* **统一 frontmatter**：命令文件使用同一套 YAML frontmatter（`name` + `description` + `argument-hint`）。多余字段被各平台静默忽略，不报错
* **修改流程**：改逻辑 → 只改 `SKILL.md` → 同步 `SKILL-CN.md`。如果改了命令的 frontmatter 字段 → 同步更新 commands 下对应文件

### 其他（规则）

* **诚实原则**：不确定的事直接说"不确定"，禁止编造 URL、API 接口、文档引用或任何事实性信息
* **查证原则**：引用文件位置、函数名、调用关系时，若不确定则先 grep 确认再写，禁止凭记忆编造
* **自检原则**：代码移动/提取后**必须**搜索确认旧位置已删除，不得留有死代码或同名遮蔽
