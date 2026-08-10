***

## note: 本文是 skills/note2md/SKILL.md 的中文同步翻译，仅供作者对照检查。不被任何 Agent 加载。修改 SKILL.md 时必须同步更新本文。

# note2md — Agent 原生 Markdown 笔记管理

你是用户笔记系统的交互界面。所有笔记和 OneNote 一样，按   笔记本 → 分区 → 页面   三层组织。

```
{notes_root}/
├── {Notebook}/              # 笔记本（顶级分类）
│   ├── {Section}/           # 分区（主题区域）
│   │   ├── {page}.md        # 页面（单条笔记）
│   │   └── ...
│   └── ...
└── .note2md/                # 内部区 — 绝不是笔记本
    ├── templates/           # 用户模板（插件默认保留在 <skill_dir>/templates/）
    ├── archive/             # 归档 — Agent 默认不读取
    └── import/              # 导入暂存区（init 时默认建立；仅经用户同意才清空）
```

>   无锁定。   每个笔记本是一个文件夹，每个分区是一个子文件夹，每个页面是一个 `.md` 文件。你可以通过文件管理器直接创建、重命名、移动或删除任何内容 — Agent 会自动感知变化。命令只是可选的便利工具。

> `{notes_root}` 在 `init` 中设定（默认：`./notes/`）。下文所有路径使用此变量。

>   根目录纪律：   `{notes_root}` 一旦确定，所有产物 — 笔记本和 `.note2md/`（内部：`templates/`、`archive/`、`import/`）— 都位于其下。除非用户明确将当前工作目录选为 `{notes_root}`，否则绝不把导入/导出产物写入当前工作目录。

***

## 命令参考

| 命令 | 功能 |
|------|------|
| `help` | 显示快速入门指南 |
| `init` | 设置向导 — 选择语言、确定根路径、导入或从头开始 |
| `newnotebook [名称]` | 在 `{notes_root}` 下创建笔记本 |
| `newsection [笔记本] [分区]` | 在笔记本内创建分区 |
| `newpage` | 创建页面 — 选择模板或空白、指定位置、生成内容 |
| `newtemplate` | 从分区中的同类页面提取模板 |
| `securecheck` | 检查笔记中的敏感信息（密码、身份证、银行卡、API 令牌等） |
| `archive` | 归档笔记本、分区或单个页面 |

***

## `help` — 快速入门指南

用户输入 `help` 时，用其选择的语言回复简要指南（默认中文）：

```
📓 note2md — 你的 Markdown 笔记本

命令：
  init           首次设置（导入 OneNote 或从头开始）
  newnotebook    创建笔记本
  newsection     在笔记本中创建分区
  newpage        写笔记（选择模板 — 日记、会议、快速笔记或空白）
  newtemplate    从分区中的同类笔记提取模板
  archive        清理旧的笔记本、分区或页面

新用户？
  输入 init 导入 OneNote 或创建第一个笔记本。
  然后 newnotebook → newsection → newpage 开始写笔记。

模板？
  newpage 始终提供模板选择。插件自带日记、会议、快速笔记三种。
  在 notes/.note2md/templates/ 下添加你自己的模板（命名为 {名称}.template.md）— 会自动出现在选项中。
  newtemplate 可从分区中的同类笔记中提取模板。

OneNote？
  init 导入文本类内容（表格、列表、标题、待办、OCR 文本）。图片、附件、墨迹、媒体暂不提取。
  转换是确定性的 — 由内置 PowerShell 脚本完成（无需 Python、无需 Node）。Windows 自带 PowerShell；其他平台可用 pwsh。
  自动导出仅限 Windows + OneNote 桌面版；其他平台提供 OneNote XML 导出文件即可。

安全？
  securecheck 检查笔记中的密码、身份证号、银行卡号和 API 令牌。

有问题随时问 — 不需要记住所有命令。

无锁定 — 每个笔记本/分区/页面就是一个文件夹或 .md 文件，用文件管理器也能管理一切。
```

***

## `init` — 设置向导

多步骤引导流程。每个决策点使用平台原生提问界面（`askQuestions`）。

### Step 0 — 语言

```
问题: "Select your language / 选择语言："
选项: "中文" | "English"
```

选定语言后，本次会话所有提示、确认、生成内容均使用该语言。

### Step 1 — 根路径

不扫描，不猜测。直接问：

```
问题: "使用当前目录 '{cwd}' 作为笔记根目录？"
选项:
  - "是 — 使用 {cwd}/"
  - "否 — 让我指定其他路径"
```

如果用户指定了路径，使用该路径。否则使用 `{cwd}/`。记录结果为 `{notes_root}`。

### Step 2 — 模式

```
问题: "你想怎么开始？"
选项:
  - "从 OneNote 导入现有笔记"
  - "从头开始 — 创建第一个笔记本"
```

#### 导入路径



运行时仅需 PowerShell。

 不需要 Python、Node — 转换由内置的 `convert-onenote-md.ps1` 脚本完成（确定性、带 fixture 回归测试），而非手工转换。Windows 自带 PowerShell 5.1；macOS/Linux 可用 pwsh。唯一 Windows 专属的辅助工具是 `export-onenote.ps1`，仅用于 Windows + OneNote 桌面版用户。
下文命令中的 `powershell` 在 Windows 上指 `powershell`，在 macOS/Linux 上指 `pwsh` — 两个跨平台脚本（`format-onenote-xml.ps1`、`convert-onenote-md.ps1`）可在任何装有 PowerShell 的平台上运行。
进入[导入流程](#导入流程)，由它处理平台检测与导出选项。



开始导入：

首先确保内部区存在 — 若缺失则创建（与"从头开始"相同的三个目录，两种方式下技能行为完全一致）：

```
{notes_root}/.note2md/
├── templates/        # 仅用户模板（init 时为空）
├── archive/
└── import/           # 导入暂存区
```

然后检查 `{notes_root}/` 是否已有内容（排除 `.note2md/`）。

如果为空，直接进入[导入流程](#导入流程) — 无冲突需要处理。

如果已有内容，绝不静默覆盖或清空。询问用户希望用哪种导入模式：

```
问题: "⚠️ {notes_root}/ 中已有笔记。如何处理现有内容？"
选项:
  - "合并 — 保留所有现有内容，同名页面自动加 (2)/(3)… 后缀"（推荐，无破坏性）
  - "清空后导入 — 先删除 {notes_root}/ 下所有内容，再全新导入"
  - "取消"
```

*   合并  （默认）：直接运行导入流程。现有文件保持不变；阶段 2 的"防覆盖"规则（`(2)`、`(3)`… 后缀）在现有内容之上生效。

  **清空后导入**：运行导入流程前，删除 `{notes_root}/` 下的内容，**保留** `.note2md/`。删除前必须再确认一次：

  ```
  问题: "此操作将永久删除 {notes_root}/ 下的所有现有笔记。继续？"
  选项: "是，清空后导入" | "否，返回"
  ```

  用户确认后才删除这些文件夹/文件，然后运行[导入流程](#导入流程)。

导入完成后告知用户："导入完成。对任意包含同类笔记的分区使用 `newtemplate` 即可创建模板。"

#### 从头开始

1. 询问："第一个笔记本叫什么名字？"

2. 创建：

   ```
   {notes_root}/
   ├── {Notebook}/
   ├── Quick Notes/
   └── .note2md/
       ├── templates/        # 仅用户模板（init 时为空）
       ├── archive/
       └── import/           # 导入暂存区（init 时默认建立）
   ```
3. 询问："在 {Notebook} 中创建什么分区？"

4. 创建 `{notes_root}/{Notebook}/{Section}/`

5. 确认："就绪！「{Notebook}」和「Quick Notes」已创建。用 `newpage` 写第一篇笔记。"

### Step 3 — 完成

设置完成。`{notes_root}` 将被用于所有后续操作。

***

## `newnotebook` — 创建笔记本

| 步骤 | 操作 |
|------|------|
| 1 | 获取名称 — 从参数（`newnotebook Work`）或询问用户 |
| 2 | 若 `{notes_root}/{Name}/` 已存在 → 警告，换一个名字 |
| 3 | 创建 `{notes_root}/{Name}/` |
| 4 | 确认："笔记本「{Name}」已创建。用 `newsection` 添加分区。" |

***

## `newsection` — 创建分区

| 步骤 | 操作 |
|------|------|
| 1 | 获取笔记本 + 分区 — 从参数或询问（列出笔记本，排除 `.note2md/`） |
| 2 | 创建 `{notes_root}/{Notebook}/{Section}/` |
| 3 | 确认："分区「{Section}」已在「{Notebook}」中创建。" |

***

## `newpage` — 创建页面

模板优先；"空白页"始终作为最后一个选项。



快速路径

：`newpage` 无参数 → 跳过模板选择，直接以空白页开始。仅需选择目的地和标题。



带参数

：`newpage daily` → 使用日记模板；`newpage meeting` → 使用会议模板，以此类推。

### Step 1 — 发现模板

按优先级扫描：

1. `{notes_root}/.note2md/templates/*.md`（用户模板 — 最高优先级；按 `{名称}.template.md` 命名，详见[模板系统](#模板系统)）
2. `<skill_dir>/templates/*.md`（插件默认 — 兜底）

插件默认：`daily.template.md`、`meeting.template.md`、`quick-note.template.md`。详见[模板系统](#模板系统)。

### Step 2 — 解析模板

| 情况 | 操作 |
|------|------|
| `newpage`（无参数） | 跳到 Step 3 — 空白页 |
| `newpage {名称}`（有参数） | 按基础名匹配、自动忽略 `.template.md` 后缀（`newpage 待办` → `待办.template.md`）。找到 → 直接使用。未找到或模糊 → 显示选项： |

```
问题: "选择哪个模板？"
选项:
  - ...用户在 .note2md/templates/ 中的任何模板...  ← 用户模板优先
  - "📅 日记 (daily)"
  - "🤝 会议记录 (meeting)"
  - "💡 快速笔记 (quick-note)"
  - "📄 空白页 — 不使用模板"
```

### Step 3 — 目标位置

询问：笔记本 → 分区 → 页面标题。允许在流程中新建笔记本/分区。

### Step 4 — Frontmatter

| 条件 | 操作 |
|------|------|
| 模板有 `---`...`---` YAML | 原样使用，替换 `{{VARIABLE}}` 占位符 |
| 模板无 frontmatter | 生成默认的 |

默认 frontmatter：

```yaml
---
date: YYYY-MM-DD
type: {模板基础名}    # 如 "daily"、"meeting"；空白页用 "note" — 去掉 .template.md/.md 后缀
title: {user_input}
tags: []
---
```

### Step 5 — 正文

| 选择 | 操作 |
|------|------|
| 模板 | 读取 `.md`，替换 `{{DATE}}`、`{{TITLE}}`、`{{TOPIC}}`。遇到未知 `{{KEY}}` 则询问 |
| 空白 | 无正文 — 仅 frontmatter |

### Step 5.5 — 模板创建约定

用户创建模板时提的要求（`newtemplate` 第 2 步），就是以后用该模板创建页面时的**执行约定**。模板 frontmatter 出现这些字段时，必须遵循：

| 字段 | `newpage` 时的执行 |
|------|------|
| `filename` | 用该模式派生文件名，替代默认命名规则 — `{{KEY}}` 占位符用已询问的答案替换，或按自然语言描述执行 |
| `base` | 询问用户是否从参考页面初始化新页面；同意则复制其内容作为起点 |
| `confirm` | 逐项用 `askQuestions` 询问每个逗号分隔项，在已询问的 `{{KEY}}` 占位符之外 |

全部字段可选 — 不带这些字段的模板行为与之前完全一致。

### Step 6 — 文件名

若模板有 `filename` 字段则用它（见 [Step 5.5](#step-55--模板创建约定)）。否则按 `type` 匹配下方命名规则（见[文件命名](#文件命名)）。已存在则追加 `(2)`。

### Step 7 — 确认

```
已创建：{notes_root}/{Notebook}/{Section}/{filename}.md
```

***

## `archive` — 归档笔记本、分区或页面

触发：`archive` 命令，或 Agent 发现 5+ 个笔记本时主动提醒。

### 第一步 — 选择范围

```
问题: "你要归档什么？"
选项:
  - "整个笔记本"
  - "某个分区"
  - "单个页面"
```

### 第二步 — 选择目标

| 范围 | 操作 |
|------|------|
| 笔记本 | 列出所有笔记本（排除 `.note2md/`），询问哪个 |
| 分区 | 列笔记本 → 选一个 → 列其分区 → 选一个 |
| 页面 | 列笔记本 → 选分区 → 选页面 |

高亮 3 个月以上未触碰的项目。支持多选。

### 第三步 — 确认并移动

保持原始目录结构，移入 `.note2md/archive/`：

| 范围 | 移动 |
|------|------|
| 笔记本 | `{notes_root}/{Notebook}/` → `{notes_root}/.note2md/archive/{Notebook}/` |
| 分区 | `{notes_root}/{Notebook}/{Section}/` → `{notes_root}/.note2md/archive/{Notebook}/{Section}/` |
| 页面 | `{notes_root}/{Notebook}/{Section}/{page}.md` → `{notes_root}/.note2md/archive/{Notebook}/{Section}/{page}.md` |

移动后如果上级目录变空（如某笔记本下所有分区都被归档），清理空目录并询问是否删除该笔记本。

### 规则

* 常规操作绝不读取 `.note2md/import/` 或 `.note2md/archive/`
* 仅在用户说"搜索归档"时搜索 `.note2md/archive/`
* 归档的条目可随时移回原路径恢复

***

## `securecheck` — 安全检查

扫描 `{notes_root}/`（排除 `.note2md/`）中的敏感信息。直接读取文件 — Agent 理解上下文，不仅仅是正则匹配。

### 检查内容

逐页阅读，标记任何看起来像以下内容的信息：

* 密码或凭证（`password`、`pwd`、`密码` 等靠近 `=` 或 `:`）
* 身份信息（中国 18 位身份证、美国 SSN、护照号、驾照号）
* 财务数据（银行卡号、`credit`、`银行卡`）
* API 密钥和令牌（`sk-...`、`ghp_...`、`Bearer ...`、`Authorization:` 头）
* 个人联系方式（手机号码、出现在异常位置的邮箱地址）

发挥判断力 — 看起来像秘密的东西就该标记。

### 执行流程

1. 告知："正在扫描笔记中的敏感信息……"

2. 询问是否追加自定义检查：

   ```
   问题: "我会检查密码、身份证、银行卡、API 密钥和个人联系方式。还需要检查什么？"
   选项:
     - "不用 — 默认就行"（默认）
     - "让我添加自定义模式"（自由输入 — 如"内部项目代码如 PRJ-XXXX"、"公司机密标题"）
   ```

   如果提供了自定义模式，加入扫描列表。

3. 在 `{notes_root}/` 范围内搜索（跳过 `.note2md/`）

4. 对每个匹配项：

   * 报告文件路径和行号
   * 显示匹配类别（**绝不输出实际的敏感值**）
   * 示例：`⚠️ notes/Work/项目/密码本.md:12 — 可能包含密码`

5.   禁止输出实际的敏感值。   如需上下文，使用 `[已隐藏]` 替代。

6. 摘要："在 M 个文件中发现 N 处潜在问题。"

7. 提醒："可将敏感文件移入 .note2md/archive/ 或删除。使用 archive 进行清理。"

### 扫描范围选项

如果用户想针对性扫描：

```
问题: "扫描全部还是指定范围？"
选项:
  - "全部笔记本（推荐）"
  - "指定笔记本"
  - "指定分区"
```

***

## 模板系统

### 优先级

```
{notes_root}/.note2md/templates/{名称}.template.md   ← 用户版本（最高）
<skill_dir>/templates/{名称}.template.md    ← 插件默认（兜底）
```

### 命名约定

所有模板 — 用户模板与插件默认 — 统一使用 `{名称}.template.md` 后缀，一眼即可识别为模板（如 `待办.template.md`、`daily.template.md`）。`newpage {名称}` 按基础名匹配、自动忽略该后缀 — `newpage 待办` 可找到 `待办.template.md`，`newpage daily` 可找到 `daily.template.md`。

### 内置默认

| 模板 | 文件 |
|------|------|
| 日记 | `daily.template.md` |
| 会议记录 | `meeting.template.md` |
| 快速笔记 | `quick-note.template.md` |

### 创建用户模板



`newtemplate` — 从分区中提取模板：



1. 询问：哪个笔记本 → 哪个分区需要分析。

2.   一次性询问模板需求  （提取之前）— 结构需求 + 三个创建要求问题（文件名格式、参考页面、其他确认项）：

   ```
   问题: "我会分析「{Section}」中的笔记来构建模板。有什么特别要求吗？"
   选项:
     - "没有偏好 — 直接提取公共结构"（默认）
     - "让我描述需求"（自由输入）
   问题: "用这个模板创建页面时，文件名怎么定？"
   问题: "用这个模板创建页面时，要以某个现有页面为基础吗？"
   问题: "用这个模板创建页面时，还有什么要向用户确认的？"
   ```

   记录答案 — 结构需求引导提取方向；`filename` / `base` / `confirm` 写入模板 frontmatter。

3. 读取该分区下所有 `.md` 页面。如果用户提供了需求，据此引导提取方向（如"重点关注待办事项部分"、"把议程和讨论合并"）。

4. 比较它们的结构，找到共同模式：

   * 相同 frontmatter 键（出现率 ≥ 60%）→ 保留为 `{{VARIABLE}}` 占位符
   * 相同标题层级（##、###）→ 保留骨架
   * 变量化的正文 → 替换为代表性 {{占位符}}

5. 展示提取的模板，并告知："在「{Section}」中发现 N 篇结构相似的笔记。"

6. 询问："保存此模板？给它起个名字。"

7. 写入 `{notes_root}/.note2md/templates/{名称}.template.md`（含第 2 步记录的 `filename` / `base` / `confirm` 字段）。之后 `newpage` 会自动包含该模板。



手动添加：

 往 `{notes_root}/.note2md/templates/` 丢 `{名称}.template.md` 文件。`newpage` 自动发现。

***

## 导入流程

1:1 映射 — OneNote 结构原样保留。仅跳过回收站（系统目录，非用户内容）。



**确定性转换。** XML → MD 转换由内置 PowerShell 脚本（`convert-onenote-md.ps1`）完成，而非 Agent 手工转换 — Agent 在长导入中会出现判断漂移（曾发生：表格内待办丢失、`# {title}` 标题缺失、纯日期标题的 type 误判）。脚本将转换规则全部代码化，并内置 fixture 回归测试。Agent 的职责是**编排与校验**，而非逐页手工转换。

PowerShell 是唯一运行时（Windows 自带 PS 5.1；macOS/Linux 可用 `pwsh`）。无需 Python、无需 Node。

内置脚本（均在 `<skill_dir>/tools/`）：

| 脚本 | 用途 |
|------|------|
| `export-onenote.ps1` | Windows 专属：通过 COM 将 OneNote 笔记本导出为 XML |
| `format-onenote-xml.ps1` | 将超长单行 XML 排版为可读的多行格式 |
| `convert-onenote-md.ps1` |   XML → MD 转换（全部规则脚本化）+ `-RunSelfTest` fixture 测试   |

### 阶段 0 — 平台检测

在提供任何导出选项之前，先判断用户的操作系统：

| 平台 | 检测方法 |
|------|----------|
| Windows | PowerShell 中 `$env:OS` / `ver`，或检查是否存在 `C:\` 盘 |
| macOS | `uname -s` → `Darwin` |
| Linux | `uname -s` → `Linux` |

如果无法可靠检测，直接询问用户。

### 阶段 1 — 获取 XML 导出



**Windows + OneNote 桌面版（2016+）：** 提供自动导出。

```
问题: "OneNote 数据怎么导出？"
选项:
  - "自动导出（Windows + OneNote 桌面版）" → 运行 export-onenote.ps1
  - "我已有 XML 文件 — 我会把它们复制到 {notes_root}/.note2md/import/"
```

**手动导入统一走 `{notes_root}/.note2md/import/`**（目录已存在 — init 时已建立）— 详见下方 macOS/Linux 分支。

自动导出时：

```
问题: "导出到哪个目录？"
选项: "默认路径（{notes_root}/.note2md/import/）" | "自定义路径"
```

默认路径是 `{notes_root}/.note2md/import/`（位于 `{notes_root}` 内部，绝不是当前工作目录），这样导入产物永远不会污染工作区。用户选择自定义则原样使用其路径 — 该路径视为用户所有（绝不删除）。

运行：`powershell -File "<skill_dir>/tools/export-onenote.ps1" -OutputDir "{notes_root}/.note2md/import"`
需 Windows + Office 2016+，COM API。脚本拒绝在未显式指定 `-OutputDir` 时运行。



校验导出结果（强制）— 未经验证的导出不得继续：



1. 脚本无错误完成（检查退出码和错误输出）。
2. 输出目录中**至少有一个** `*.xml` 文件。0 个 XML 说明导出失败 — 例如未安装 OneNote 桌面版、COM 未注册、或所有笔记本为空。
3. 扫描脚本输出中的 `FAIL:` 行；逐个向用户报告失败的页面。
4. 结构合理性检查：页面以 `{页面名}.xml` 位于 笔记本/分区 目录下。

若导出失败或没有产出 XML：告知用户具体原因，并回退到下方的手动路径。绝不带着空导出或损坏的导出进入转换。



**macOS / Linux（或没有 OneNote 桌面版）：** COM API 仅限 Windows，`export-onenote.ps1` 无法在此环境运行 — 自动导出不可用。直接明确告知用户：他们必须自己获取 XML 导出（例如在装有 OneNote 桌面版的 Windows 机器上导出，或用任何能产出 OneNote 页面 XML 的工具）。你只负责转换。然后提供：

```
问题: "当前系统无法自动导出（需要 Windows + OneNote 桌面版）。请自行将笔记本导出为 XML，或选择其他方式："
选项:
  - "我有 XML 导出文件 — 我会把它们复制到 {notes_root}/.note2md/import/"
  - "跳过导入 — 改为从头开始"
```

**手动导入统一走 `{notes_root}/.note2md/import/`。** 请用户将 XML 导出复制到该目录（目录已存在 — init 时已建立）。然后验证该目录确实包含 XML 文件再继续（见上方检查）。

XML 导出是纯文本文件 — 可以来自任何机器或工具。关键要求：每个页面是一个 `.xml` 文件，内容是 OneNote 页面 XML（命名空间 `http://schemas.microsoft.com/office/onenote/2013/onenote`），通常命名为 `{页面名}.xml`，位于 笔记本/分区 目录结构中。包含此类文件的任意路径均可接受。

### 阶段 1.5 — （可选）XML 排版，便于抽查

转换器直接读取原始 XML — 无需排版。**此步骤仅用于你抽查时**遇到超长单行的页面（Agent 读取工具会截断长行）。需要时：

`powershell -File "<skill_dir>/tools/format-onenote-xml.ps1" -InputDir "<导出目录>"`（macOS/Linux 用 `pwsh`）→ 默认输出到 `<导出目录>_pretty/`。所有输出留在暂存区内。

### 阶段 2 — 转换与校验（脚本驱动）

转换完全脚本化。不要手工逐页转换。

1. **运行转换器**，指向导出目录：
   `powershell -File "<skill_dir>/tools/convert-onenote-md.ps1" -InputDir "<xml目录>" -OutputDir "{notes_root}"`（macOS/Linux 用 `pwsh`）
   - 在 `{notes_root}` 下镜像笔记本 → 分区 → 页面的文件夹结构。
   - 脚本清洗文件名（Windows 保留字符 + Unicode 特殊字符 → `_`）、自动跳过回收站、避免覆盖（同名追加 `(2)`）、报告转换数量与任何失败。
2. **校验（强制）：**
   - 数量核对：`*.xml` 数 == `.md` 数。
   - 抽查 2-3 个随机页面对照其 XML（必要时先排版）：frontmatter、正文首行 `# {title}`、标题层级、表格、待办、`↳` 嵌套、OCR 文本。
   - 脚本报告的失败页 → 读失败清单，修脚本或源文件后重跑。
3. **报告：** "已转换 N 个页面 → {notes_root}。"（若有失败："M 个页面失败 — 见上方清单。"）
4. **询问是否清理** — 转换 + 校验通过后，询问用户（自动导出和手动放置的 XML 一视同仁）：

   ```
   问题: "导入完成。清空 {notes_root}/.note2md/import/ 下的 XML 文件？"
   选项:
     - "是 — 删除"
     - "否 — 保留"
   ```

   无论用户选什么都尊重。`import/` 是暂存区，是否清空由用户决定。

> **为何不手工转换？** 500 页的导入中 Agent 注意力会衰减、规则会被遗忘（这已实际发生：表格内待办丢失、`# {title}` 标题缺失、纯日期标题的 type 误判）。脚本是确定性的；Agent 的价值在于编排 + 校验 + 对脚本标记的边界情况做判断。
>
> **脚本自检**（一次性，或存疑时）：`convert-onenote-md.ps1 -RunSelfTest` 运行内置 fixture 回归测试。所有断言必须通过后才能转换真实数据。

### 转换行为（由 `convert-onenote-md.ps1` 实现）

逐元素映射的完整实现位于脚本中（带 fixture 测试）。脚本保证以下行为 — 抽查时对照验证：

| 行为 | 保证 |
|------|------|
| Frontmatter | `title`/`date`/`type`/`tags: []`；`type` 由标题**+ 分区目录名**判断（纯日期标题在"公司月度例会"等分区中 → `meeting`） |
| 正文首行 | 永远是 `# {title}` |
| 文本 | CDATA 纯文本，剥离内嵌 `<span>`/`<a>` 标记、反转义实体；链接可见文本保留 |
| 粗体/斜体 | `**文本**` / `*文本*` |
| 待办 | `- [ ]` / `- [x]` |
| 列表 | `-`/`1.`，嵌套子项每级缩进 2 空格 |
| 表格 | MD 表格，单元格换行 `<br>`，空行跳过；**单元格内待办/列表**用 `[ ]`/`1.`/`-` 文本标记；**单元格内混合嵌套树**每级用 `↳` |
| 清单表格 | 单列待办表格提取为原生 MD 列表 |
| 图片 | 提取 OCR 文本（`[OCR 图片内容]`）；无 OCR 图片 → `[图片]` 占位 |
| 文件名 | `\/:*?"<>|` + U+00A0/U+201C/U+201D 等 → `_` |
| 回收站 | 自动跳过 |

脚本无法映射的结构 → 保守兜底（文本用 `<br>` 连接，零丢失）并报告。

**丢失矩阵：** 图片（无 OCR）、附件、超链接 URL、墨迹、公式、音频、视频有意不转换。完整清单：插件仓库的 `docs/onenote-loss-matrix.md`。

***

## 文件命名

默认命名规则：

| type | 命名规则 | 示例 |
|------|----------|------|
| `daily` | `{date}.md` | `2026-07-29.md` |
| `meeting` | `{date}-{topic}.md` | `2026-07-29-产品评审.md` |
| `quick-note` | `{date}-{title}.md` | `2026-07-29-灵感.md` |
|  (default)   | `{title}.md`        | `我的笔记.md`            |

