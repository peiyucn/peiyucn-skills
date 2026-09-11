# 项目指令 — peiyucn-skills

## 项目概况

仓库根即**市场（marketplace）**，插件放在 `plugins/` 下；仓库无 CI、无构建（纯内容仓库）。

```
peiyucn-skills/
├── .claude-plugin/marketplace.json   — 市场货架清单（name: peiyucn-skills）
├── docs/agent-compatibility.md       — 三平台兼容性分析与决策记录
├── plugins/note2md/                  — 插件（命令命名空间 /note2md:xxx）
│   ├── commands/                     — 9 个命令薄壳（三平台通用：Claude Code / Codex / Copilot 自动发现）
│   ├── .claude-plugin/plugin.json    — 插件清单（声明 commands；skills 目录自动发现）
│   └── skills/note2md/
│       ├── SKILL.md                  — **单一真相来源**：所有命令的完整执行逻辑
│       ├── templates/                — 内置模板（daily / meeting / quick-note）
│       └── tools/                    — export-onenote.ps1 / format-onenote-xml.ps1 / convert-onenote-md.ps1（XML→MD，核心，含 fixture 自测）
└── plugins/obscura-scrape/           — 插件（命令命名空间 /obscura-scrape:xxx）
    ├── commands/                     — 3 个命令薄壳（fetch / install / help）
    ├── .claude-plugin/plugin.json    — 插件清单
    ├── SKILL-CN.md                   — SKILL.md 中文对照（仅供作者）
    └── skills/obscura-scrape/
        ├── SKILL.md                  — **单一真相来源**：匿名抓取（fetch / 批量 scrape / stealth）+ 已知坑；脚本路径用 {SKILL_DIR} 相对约定
        └── scripts/install-obscura.ps1 — Obscura 引擎安装/升级（Windows，幂等）
```

* `marketplace.json` 的 `name` 即市场名；插件条目声明 `source: ./plugins/<插件名>`；多余字段被各平台静默忽略
* `SKILL.md` 是**单一真相来源**；`SKILL-CN.md` 是其**中文同步翻译**（仅供作者对照，改 SKILL.md 必须同步）；`commands/*.md` 是薄壳委托，不重复维护逻辑

## 文档规范

> AGENTS 给开发 agent、README 给用户——写错读者是文档事故。

* `AGENTS.md`：中文一份；唯一 agent 指令文件（不留 CLAUDE.md 等其它厂商指令文件）
* `README.md` / `README.zh-CN.md`：市场介绍——安装、命令列表、导入说明；中英双份、英文默认、顶部互链；**面向用户**——只写用法与行为，不写实现细节、私有 seam、开发历史（归本文件与 `docs/`）
* `CONTRIBUTING.md` / `CONTRIBUTING.zh-CN.md`：贡献指南——项目结构树、分支策略
* 无 CHANGELOG（版本语义 = `marketplace.json` / `plugin.json` 的 `version` + git tag）

## 工程管线（本仓库自含）

* **开发**：日常改动在 `dev`；`main` 供市场安装拉取（Copilot Chat 市场装 `main`）
* **验证**：无构建验证——提交前自查下方「commit 前检查工程文件」清单
* **提交**：逐项提交，中文描述 + 英文类型前缀（feat / fix / refactor / chore / docs / style / perf / build / revert）；一个 commit 一件事；还在讨论 / 方向未定 / 留了 TODO 就先不交
* **推送**：push `dev` 后**必须** `git push origin dev:main`；**版本号与 push 强绑定**——凡 push，被改插件的 `plugin.json` 与 `marketplace.json` 对应条目 `version` 必须同步更新（未 push 的本地测试可先不改）
* **发布确认（硬门禁，owner 当次点头）**：`git tag` / 市场发布等**不可逆的对外发布动作**，执行前必须由 owner **当次明确确认**——「之前批准了整条发布流程」「按你建议走」「继续」**不构成**发布许可；agent 停在发布动作之前，一句话报出「要发什么、版本号、目标通道、影响范围」，未回话即视为未批准（根规范《发布（定版）》step5）
* **发布**：两插件**各自独立版本线**（note2md 与 obscura-scrape 互不牵连，当前值见 `marketplace.json`）；版本规则 `fix` → patch、`feat` → minor、破坏性 → major；**每个 push 的版本必须打 tag**：`git tag -a {plugin}-v{version} -m "{plugin}-v{version}: {简要说明}"` + push（新 tag 一律插件前缀；旧的无前缀 tag v0.1.0–v0.5.1 保留不动）；流程：bump 被改插件的 `plugin.json` + `marketplace.json` → commit → push dev → push dev:main → 打 tag → push tag（一个版本一个 commit，版本号与代码同批推送）
* **commit 前检查工程文件**（任何涉及行为 / 结构的改动）：
  * `AGENTS.md` — 结构树、命令数量（**结构改动必查**）
  * `README.md` / `README.zh-CN.md` — 功能描述、命令列表、导入说明
  * `CONTRIBUTING.md` / `CONTRIBUTING.zh-CN.md` — 结构树、分支策略
  * `plugins/*/SKILL-CN.md` — 改 SKILL.md 必须同步
  * `.claude-plugin/marketplace.json` + `plugins/*/.claude-plugin/plugin.json` — version 字段
  * `docs/` 下的文档（如 onenote-loss-matrix.md）

## 安全基线（本仓库自含要点）

* 已开启（2026-09 逐项核验）：Dependabot alerts（仅报警）、secret scanning + push protection、根 `SECURITY.md`
* 未开启（与基线有出入，2026-09 逐项核验）：CodeQL default setup（`state=not-configured`）、Dependabot 自动升级
* 分支保护三层（2026-09 逐项核验）：经典保护 **未设**（出入：无「要求对话解决 / 不允许绕过」）；ruleset 轻保护 ✓（`dev` 与默认分支各一条）；合并设置 **非 Squash-only**（出入：三个合并方式全开）；核验按根规范《统一安全基线 · 逐项检查命令》逐项跑

## GitHub 与网络

* 一律 `gh` CLI（已登录 peiyucn）；远程 `https://github.com/peiyucn/peiyucn-skills.git`
* 常用：仓库改名 `gh repo rename <新名> --repo peiyucn/peiyucn-skills --yes`；建仓库 `gh repo create <名> --public --source . --remote origin --push`；改名后同步本地 remote `git remote set-url origin <新 URL>`

## 项目专属章节

### 开发约定

* **薄壳原则**：`commands/` 只做委托，不重复维护逻辑
* **统一 frontmatter**：命令文件用同一套 YAML frontmatter（`name` + `description` + `argument-hint`）；多余字段被各平台静默忽略
* **修改流程**：改逻辑只改 `SKILL.md` → 同步 `SKILL-CN.md`；改了命令 frontmatter 字段 → 同步 commands 下对应文件

### 规则

* **诚实原则**：不确定的事直接说"不确定"，禁止编造 URL、API 接口、文档引用或任何事实性信息
* **查证原则**：引用文件位置、函数名、调用关系前先 grep 确认，禁止凭记忆编造
* **自检原则**：代码移动 / 提取后**必须**搜索确认旧位置已删除，不留死代码或同名遮蔽
