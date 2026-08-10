---
name: note2md
description: Agent-native Markdown note management with Notebook→Section→Page hierarchy. Slash commands: help, init, newnotebook, newsection, newpage (template-first), newtemplate, securecheck, archive. Plugin ships with daily, meeting, and quick-note templates; user templates take priority. Use when the user wants to manage notes, create a notebook/section/page, import from OneNote, or archive old notes.
---

# note2md — Agent-Native Markdown Note Management

You are the interface to the user's note system. All notes use the same **Notebook → Section → Page** hierarchy as OneNote.

```
{notes_root}/
├── {Notebook}/              # Notebook (top-level category)
│   ├── {Section}/           # Section (topic area)
│   │   ├── {page}.md        # Page (an individual note)
│   │   └── ...
│   └── ...
└── .note2md/                # Internal area — never a notebook
    ├── templates/           # User templates (plugin defaults stay in <skill_dir>/templates/)
    ├── archive/             # Archive — agent never reads this by default
    └── import/              # Import staging (created at init; cleared only with user's permission)
```

>   No lock-in.   Every notebook is a folder, every section is a subfolder, every page is a `.md` file. You can create, rename, move, or delete anything through your file manager — the agent picks up the changes automatically. Commands are optional convenience.

> `{notes_root}` is set during `init` (default: `./notes/`). All paths below use this variable.

> **Root discipline:** once `{notes_root}` is resolved, every artifact — notebooks and `.note2md/` (internal: `templates/`, `archive/`, `import/`) — lives under it. Never write import/export artifacts to the current working directory unless the user explicitly chose it as `{notes_root}`.

***

## Command Reference

| Command | What it does |
|---------|-------------|
| `help` | Show this quick-start guide |
| `init` | Setup wizard — pick language, choose root path, import or start fresh |
| `newnotebook [name]` | Create a notebook under `{notes_root}` |
| `newsection [notebook] [section]` | Create a section inside a notebook |
| `newpage` | Create a page — pick template or blank, ask destination, build it |
| `newtemplate` | Extract a template from a section of similar pages |
| `securecheck` | Scan notes for sensitive info (passwords, IDs, bank cards, tokens) |
| `archive` | Archive a notebook, section, or single page |

***

## `help` — Quick-Start Guide

When the user types `help`, reply with a concise guide in their chosen language (default English):

```
📓 note2md — Your Markdown Notebook

Commands:
  init           First-time setup (import OneNote or start fresh)
  newnotebook    Create a new notebook
  newsection     Create a section inside a notebook  
  newpage        Write a note (pick a template — diary, meeting, quick note, or blank)
  newtemplate    Extract a template from a section of similar notes
  archive        Clean up old notebooks, sections, or pages

First time?
  Type init to import your OneNote or create your first notebook.
  Then newnotebook → newsection → newpage to start writing.

Templates?
  newpage always offers templates. The plugin comes with diary, meeting, and quick-note.
  Add your own under notes/.note2md/templates/ (named {name}.template.md) — they'll appear automatically.
  newtemplate extracts a template from any section with similar pages.

OneNote?
  init imports text content (tables, lists, headings, to-dos, OCR text). Images, attachments, ink, and media are not extracted.
  Conversion is deterministic — a bundled PowerShell script does it (no Python, no Node). Windows ships PowerShell; others can use pwsh.
  Auto-export needs Windows + OneNote desktop; on other platforms, point init at any folder of OneNote XML exports.

Security?
  securecheck checks your notes for passwords, ID numbers, bank cards, and API tokens.

Questions? Just ask — you don't need to memorize commands.

No lock-in — every notebook/section/page is just a folder or .md file. You can manage everything through your file manager too.
```

***

## `init` — Setup Wizard

Multi-step guided flow. Use the platform's native question UI (`askQuestions`) at each decision point.

### Step 0 — Language

```
Question: "Select your language / 选择语言："
Options: "中文" | "English"
```

Use the chosen language for all subsequent prompts, confirmations, and generated content.

### Step 1 — Root Path

Don't scan or guess. Just ask:

```
Question: "Use the current directory '{cwd}' as your notes root?"
Options:
  - "Yes — use {cwd}/"
  - "No — let me specify a path"
```

If user specifies a path, use that. Otherwise use `{cwd}/`. Record the result as `{notes_root}`.

### Step 2 — Mode

```
Question: "How would you like to start?"
Options:
  - "Import from OneNote"
  - "Start fresh — create my first notebook"
```

#### Import Path

**Runtime: PowerShell only.** No Python, no Node — conversion is done by the bundled `convert-onenote-md.ps1` script (deterministic, fixture-tested), not by hand. Windows ships PowerShell 5.1; macOS/Linux can use `pwsh`. The only Windows-only helper is `export-onenote.ps1`, used solely for Windows users with OneNote desktop.

In the commands below, `powershell` means `powershell` on Windows and `pwsh` on macOS/Linux — the two cross-platform scripts (`format-onenote-xml.ps1`, `convert-onenote-md.ps1`) run on any platform that has PowerShell.

Proceed to the [Import Pipeline](#import-pipeline), which handles platform detection and export options.

**Start import:**

First, ensure the internal area exists — create it if missing (same three directories as Fresh Start, so the skill works identically either way):

```
{notes_root}/.note2md/
├── templates/        # user templates only (empty at init)
├── archive/
└── import/           # import staging
```

Then check whether `{notes_root}/` already contains anything (excluding `.note2md/`).

If it is **empty**, proceed straight to the [Import Pipeline](#import-pipeline) — no conflict to resolve.

If it **already has content**, do NOT silently overwrite or clear anything. Ask the user which import mode they want:

```
Question: "⚠️ {notes_root}/ already has notes. How should I handle the existing content?"
Options:
  - "Merge — keep everything, add a (2)/(3)… suffix on any same-name pages" (recommended, non-destructive)
  - "Clear then import — delete everything under {notes_root}/ first, then import fresh"
  - "Cancel"
```

- **Merge** (default): run the Import Pipeline as-is. The existing files stay untouched; the Phase 2 rule "avoid overwrites" (`(2)`, `(3)`, … suffix) applies on top of them.
- **Clear then import**: before running the pipeline, delete the contents of `{notes_root}/` **except** `.note2md/` — and confirm once more before deleting:

  ```
  Question: "This will permanently delete all current notes under {notes_root}/. Continue?"
  Options: "Yes, clear everything and import" | "No, go back"
  ```

  Only after the user confirms, delete those folders/files, then run the [Import Pipeline](#import-pipeline).

After import, tell the user: "Import complete. Use `newtemplate` on any section with similar pages to create templates."

#### Fresh Start Path

1. Ask: "First notebook name?"
2. Create:

   ```
   {notes_root}/
   ├── {Notebook}/
   ├── Quick Notes/
   └── .note2md/
       ├── templates/        # user templates only (empty at init)
       ├── archive/
       └── import/           # import staging (created at init)
   ```
3. Ask: "First section name in {Notebook}?"
4. Create `{notes_root}/{Notebook}/{Section}/`
5. Confirm: "All set! '{Notebook}' and 'Quick Notes' created. Use `newpage` to write your first note."

### Step 3 — Done

Setup complete. The resolved `{notes_root}` is used for all subsequent operations.

***

## `newnotebook` — Create Notebook

| Step | Action |
|------|--------|
| 1 | Get name — from argument (`newnotebook Work`) or ask user |
| 2 | If `{notes_root}/{Name}/` exists → warn, ask for a different name |
| 3 | Create `{notes_root}/{Name}/` |
| 4 | Confirm: "Notebook '{Name}' created. Use `newsection` to add sections." |

***

## `newsection` — Create Section

| Step | Action |
|------|--------|
| 1 | Get notebook + section — from arguments or ask (list notebooks, exclude `.note2md/`) |
| 2 | Create `{notes_root}/{Notebook}/{Section}/` |
| 3 | Confirm: "Section '{Section}' created in '{Notebook}'." |

***

## `newpage` — Create Page

Template-first; "blank page" always available as the last option.

**Fast path**: `newpage` with no argument → skip template selection, create a blank page directly. User only needs to pick destination and title.

**With argument**: `newpage daily` → use daily template; `newpage meeting` → use meeting template, etc.

### Step 1 — Discover Templates

Scan in priority order:

1. `{notes_root}/.note2md/templates/*.md` (user templates — highest priority; named `{name}.template.md`, see [Template System](#template-system))
2. `<skill_dir>/templates/*.template.md` (plugin defaults — fallback)

Plugins defaults: `daily.template.md`, `meeting.template.md`, `quick-note.template.md`. See [Template System](#template-system).

### Step 2 — Resolve Template

| Condition | Action |
|-----------|--------|
| `newpage` (no argument) | Skip to Step 3 — blank page |
| `newpage {name}` (argument provided) | Match by base name, ignoring the `.template.md` suffix (`newpage 待办` → `待办.template.md`). If found → use it. If not found or ambiguous → present choices: |

```
Question: "Which template?"
Options:
  - ...any user templates found in .note2md/templates/...  ← user templates FIRST
  - "📅 Daily Journal (daily)"
  - "🤝 Meeting Notes (meeting)"
  - "💡 Quick Note (quick-note)"
  - "📄 Blank page — no template"
```

### Step 3 — Destination

Ask: notebook → section → page title. Allow creating new notebook/section inline.

### Step 4 — Frontmatter

| Condition | Action |
|-----------|--------|
| Template has `---`...`---` YAML | Use as-is, replace `{{VARIABLE}}` placeholders |
| No frontmatter in template | Generate default |

Default frontmatter:

```yaml
---
date: YYYY-MM-DD
type: {template basename}    # e.g. "daily", "meeting"; "note" for blank — strip the .template.md/.md suffix
title: {user_input}
tags: []
---
```

### Step 5 — Body

| Choice | Action |
|--------|--------|
| Template | Read `.md`, replace `{{DATE}}`, `{{TITLE}}`, `{{TOPIC}}`. Ask for unknown `{{KEY}}`. |
| Blank | No body — frontmatter only |

### Step 5.5 — Template Creation Contract

The requirements the user gave when creating the template (via `newtemplate` step 2) are the **execution contract for creating pages from it**. When the template's frontmatter has these fields, honor them:

| Field | Execution on `newpage` |
|-------|------------------------|
| `filename` | Derive the filename from this pattern instead of the default naming rules — replace `{{KEY}}` placeholders with the answers already asked, or follow the natural-language description. |
| `base` | Ask the user whether to seed the new page from the reference page; copy its content as the starting point if they agree. |
| `confirm` | Ask each comma-separated item in turn via `askQuestions`, in addition to the `{{KEY}}` placeholders already asked. |

All fields optional — a template without them behaves exactly as before.

### Step 6 — Filename

If the template has a `filename` field, use it (see [Step 5.5](#step-55--template-creation-contract)). Otherwise match `type` against the naming rules below (see [File Naming](#file-naming)). Append `(2)` if exists.

### Step 7 — Confirm

```
Created: {notes_root}/{Notebook}/{Section}/{filename}.md
```

***

## `archive` — Archive Notebooks, Sections, or Pages

Triggered by `archive` command, or when agent notices 5+ notebooks.

### Step 1 — Scope

```
Question: "What do you want to archive?"
Options:
  - "Entire notebook"
  - "A specific section"
  - "A single page"
```

### Step 2 — Select Target

| Scope | Action |
|-------|--------|
| Notebook | List all notebooks (excluding `.note2md/`), ask which one |
| Section | List notebooks → ask which one → list its sections → ask which one |
| Page | List notebooks → section → ask which page |

Highlight items untouched for > 3 months. Allow multi-select.

### Step 3 — Confirm & Move

Preserve the original directory structure under `.note2md/archive/`:

| Scope | Moves |
|-------|-------|
| Notebook | `{notes_root}/{Notebook}/` → `{notes_root}/.note2md/archive/{Notebook}/` |
| Section | `{notes_root}/{Notebook}/{Section}/` → `{notes_root}/.note2md/archive/{Notebook}/{Section}/` |
| Page | `{notes_root}/{Notebook}/{Section}/{page}.md` → `{notes_root}/.note2md/archive/{Notebook}/{Section}/{page}.md` |

Empty parent directories left behind? Clean them up (e.g. if all sections of a notebook are archived, the notebook folder becomes empty — ask if it should be removed).

### Rules

* Never read `.note2md/import/` or `.note2md/archive/` during normal operations
* Only search `.note2md/archive/` when user says "search archive"
* Archived items can be restored by moving them back to their original path

***

## `securecheck` — Security Check

Scans `{notes_root}/` (excluding `.note2md/`) for sensitive information. Read files directly — you understand context, not just regex.

### What to Look For

Read each page and flag anything that looks like:

* Passwords or credentials (`password`, `pwd`, `密码` near `=` or `:`)
* Government IDs (Chinese 18-digit ID, US SSN, passport numbers, driver's license)
* Financial data (bank card numbers, `credit`, `银行卡`)
* API keys and tokens (`sk-...`, `ghp_...`, `Bearer ...`, `Authorization:` headers)
* Personal contact (phone numbers, email addresses in unexpected places)

Use your judgment — if it walks like a secret, flag it.

### Procedure

1. Announce: "Scanning your notes for sensitive information…"
2. Ask if user wants to add custom checks:

   ```
   Question: "I'll check for passwords, IDs, bank cards, API keys, and personal contact info. Anything else to look for?"
   Options:
     - "No — just the defaults" (default)
     - "Let me add custom patterns" (free text input — e.g. "internal project codes like PRJ-XXXX", "company confidential headers")
   ```

   If custom patterns provided, add them to the scan list.
3. Search across `{notes_root}/` (skip `.note2md/`)
4. For each match:

   * Report the file path and line number
   * Show the matching category (NOT the actual sensitive value)
   * Example: `⚠️ notes/Work/Projects/credentials.md:12 — Possible password`
5. Never output the actual sensitive value. Use `[REDACTED]` if context is needed.
6. Summary: "Found N potential issues across M files."
7. Remind: "You can move sensitive files to .note2md/archive/ or delete them. Use archive to clean up."

### Scope Options

If user wants targeted scan:

```
Question: "Scan everything, or a specific area?"
Options:
  - "All notebooks (recommended)"
  - "A specific notebook"
  - "A specific section"
```

***

## Template System

### Priority

```
{notes_root}/.note2md/templates/{name}.template.md   ← User override (highest)
<skill_dir>/templates/{name}.template.md    ← Plugin default (fallback)
```

### Naming Convention

All templates — user and plugin defaults — use the `{name}.template.md` suffix so they're recognizable as templates at a glance (e.g. `待办.template.md`, `daily.template.md`). `newpage {name}` matches by base name, ignoring the suffix — `newpage 待办` finds `待办.template.md`, `newpage daily` finds `daily.template.md`.

### Built-in Defaults

| Template | File |
|----------|------|
| Daily Journal | `daily.template.md` |
| Meeting Notes | `meeting.template.md` |
| Quick Note | `quick-note.template.md` |

### Creating User Templates

**`newtemplate` — Extract template from a section:**



1. Ask: which notebook → which section to analyze.
2. Ask about the template in one pass (before extracting) — structure needs plus the three creation questions (filename format, reference page, other confirmations):

   ```
   Question: "I'll analyze the pages in '{Section}' to build a template. Any specific requirements?"
   Options:
     - "No preference — just find the common structure" (default)
     - "Let me describe what I want" (free text input)
   Question: "When creating a page from this template, how should the filename be decided?"
   Question: "Should creating a page from this template be based on an existing page?"
   Question: "Anything else you want to confirm with the user when creating a page from this template?"
   ```

   Record the answers — structure needs guide the extraction; filename / base / confirm go into the template frontmatter.
3. Read all `.md` pages in that section. If the user provided requirements, use them to guide the extraction (e.g. "focus on the action items section", "combine the agenda and notes patterns").
4. Compare their structure to find common patterns:

   * Same frontmatter keys appearing in ≥ 60% of pages → keep as `{{VARIABLE}}`
   * Same heading hierarchy (##, ###) → keep the skeleton
   * Body text that varies → replace with representative {{PLACEHOLDER}}
5. Show the extracted template and report: "Found N pages with similar structure in '{Section}'."
6. Ask: "Save this template? Give it a name."
7. Write to `{notes_root}/.note2md/templates/{name}.template.md` (including the `filename` / `base` / `confirm` fields from step 2). From now on, `newpage` will include it.



**Manual**: Drop `{name}.template.md` files into `{notes_root}/.note2md/templates/`. Auto-discovered by `newpage`.

***

## Import Pipeline

1:1 mapping — OneNote structure preserved as-is. Only the Recycle Bin is skipped (system folder, not user content).

**Deterministic conversion.** The XML → MD conversion is done by a bundled PowerShell script (`convert-onenote-md.ps1`), not by the agent — agent judgment drifts on long imports (forgot table-cell to-dos, dropped headings, mis-detected types). The script encodes every rule in the [XML → Markdown Conversion Rules](#xml--markdown-conversion-rules) section and ships with built-in fixture regression tests. The agent's job is to **orchestrate and verify**, not to hand-convert pages.

PowerShell is the only runtime (Windows ships PS 5.1; macOS/Linux can use `pwsh`). No Python, no Node.

Bundled scripts (all in `<skill_dir>/tools/`):

| Script | Purpose |
|--------|---------|
| `export-onenote.ps1` | Windows-only: export OneNote notebooks to XML via COM |
| `format-onenote-xml.ps1` | Pretty-print single-line XML into readable multi-line |
| `convert-onenote-md.ps1` | **XML → MD conversion (all rules scripted) + `-RunSelfTest` fixture tests** |

### Phase 0 — Platform Detection

Detect the user's OS before offering any export option:

| Platform | How to detect |
|----------|---------------|
| Windows | `$env:OS` / `ver` in PowerShell, or check for a `C:\` drive |
| macOS | `uname -s` → `Darwin` |
| Linux | `uname -s` → `Linux` |

If you cannot detect reliably, just ask the user.

### Phase 1 — Obtain XML Export

**Windows + OneNote desktop (2016+):** offer auto-export.

```
Question: "How to export your OneNote data?"
Options:
  - "Auto-export (Windows + OneNote desktop)" → runs export-onenote.ps1
  - "I already have XML files — I'll copy them into {notes_root}/.note2md/import/"
```

**Manual imports always go through `{notes_root}/.note2md/import/`** (the directory already exists — it's created at init) — see the macOS/Linux branch below for details.

If auto-export:

```
Question: "Export to which directory?"
Options: "Default ({notes_root}/.note2md/import/)" | "Custom path"
```

The default is `{notes_root}/.note2md/import/` (inside `{notes_root}`, never the current working directory) so import artifacts never pollute the workspace. If the user picks custom, use their path as-is — but treat that path as user-owned (never delete it).

Run: `powershell -File "<skill_dir>/tools/export-onenote.ps1" -OutputDir "{notes_root}/.note2md/import"`
Requires Windows + Office 2016+, COM API. The script refuses to run without an explicit `-OutputDir`.

**Verify the export result (mandatory) — never proceed on an unverified export:**

1. The script completed without errors (check the exit code and error output).
2. The output directory contains **at least one** `*.xml` file. Zero XML files means the export failed — e.g. OneNote desktop not installed, COM not registered, or all notebooks empty.
3. Scan the script output for `FAIL:` lines; report every failed page to the user by name.
4. Structure sanity check: pages sit under Notebook/Section folders as `{PageName}.xml`.

If the export failed or produced no XML: tell the user what went wrong and fall back to the manual path below. Never continue to conversion with an empty or broken export.

**macOS / Linux (or no OneNote desktop):** the COM API is Windows-only, so `export-onenote.ps1` **cannot run here** — auto-export is not available. Tell the user this plainly: *they must obtain the XML exports themselves* (e.g. run the export on a Windows machine with OneNote desktop, or use any tool that produces OneNote page XML). You only handle the conversion. Then offer:

```
Question: "Auto-export isn't available on this system (needs Windows + OneNote desktop). Please export your notebooks to XML yourself, or choose another option:"
Options:
  - "I have XML exports — I'll copy them into {notes_root}/.note2md/import/"
  - "Skip import — start fresh instead"
```

**Manual imports always go through `{notes_root}/.note2md/import/`.** Ask the user to copy their XML exports there (the directory already exists — it's created at init). Then verify the directory actually contains XML files before continuing (see the checks above).

XML exports are plain files — they can come from any machine or tool. What matters: each page is a `.xml` file containing OneNote page XML (namespace `http://schemas.microsoft.com/office/onenote/2013/onenote`), typically named `{PageName}.xml` inside a Notebook/Section folder structure. Accept any path containing such files.

### Phase 1.5 — (optional) Pretty-print XML for spot-checking

The converter reads raw XML directly — no pretty-printing needed. **This step is only for you when spot-checking** a page whose XML is one very long line (Agent reading tools truncate long lines). If needed:

`powershell -File "<skill_dir>/tools/format-onenote-xml.ps1" -InputDir "<export_dir>"` (`pwsh` on macOS/Linux) → outputs to `<export_dir>_pretty/`. Keep everything under the staging area.

### Phase 2 — Convert & Verify (script-driven)

Conversion is fully scripted. Do not hand-convert pages.

1. **Run the converter** against the export:
   `powershell -File "<skill_dir>/tools/convert-onenote-md.ps1" -InputDir "<xml_dir>" -OutputDir "{notes_root}"` (`pwsh` on macOS/Linux)
   - Mirrors Notebook → Section → Page structure under `{notes_root}`.
   - Sanitizes filenames (Windows reserved chars + Unicode specials → `_`), skips Recycle Bin, reports converted count + any failures.
2. **Verify (mandatory):**
   - Count check: `*.xml` found == `.md` written.
   - Spot check 2–3 random pages against their XML (pretty-print first if needed): frontmatter, `# {title}` first line, headings, tables, to-dos, `↳` nesting, OCR text.
   - Any page the script reported as failed → read the failure list, fix script or source, re-run.
3. **Report:** "Converted N pages → {notes_root}." (If any failed: "M pages failed — see list above.")
4. **Ask about cleanup** — after conversion + verification, ask the user (applies to both auto-exported and manually placed XML alike):

   ```
   Question: "Import complete. Clear the XML files in {notes_root}/.note2md/import/?"
   Options:
     - "Yes — delete them"
     - "No — keep them"
   ```

   Respect the answer either way. `import/` is a staging area, and whether to empty it is the user's call.

> **Why not hand-convert?** On a 500-page import, agent attention decays and rules get forgotten (this has happened: table-cell to-dos dropped, `# {title}` headings missing, `type` misjudged for date-only titles). The script is deterministic; the agent's value is orchestration + verification + judgment on edge cases the script flags.
>
> **Sanity-check the script** (one-time, or when in doubt): `convert-onenote-md.ps1 -RunSelfTest` runs built-in fixture regression tests. Every assertion must pass before converting real data.

### Conversion behavior (implemented in `convert-onenote-md.ps1`)

The full element-by-element mapping lives in the script (with fixture tests). What the script guarantees — and what you verify when spot-checking:

| Behavior | Guarantee |
|----------|-----------|
| Frontmatter | `title`/`date`/`type`/`tags: []`; `type` from title **+ section dir name** (date-only titles in e.g. "公司月度例会" → `meeting`) |
| Body first line | Always `# {title}` |
| Text | CDATA plain text, embedded `<span>`/`<a>` markup stripped, entities unescaped; link visible text kept |
| Bold/italic | `**text**` / `*text*` |
| To-dos | `- [ ]` / `- [x]` |
| Lists | `-`/`1.`, nested children indent 2 spaces/level |
| Tables | MD table, `<br>` for cell line breaks, empty rows skipped; **to-dos/lists inside cells** use `[ ]`/`1.`/`-` text markers; **mixed nested trees** inside a cell use `↳` per level |
| Checklist tables | Single-column to-do tables extracted as native MD lists |
| Images | OCR text extracted (`[OCR 图片内容]`); no-OCR images → `[图片]` placeholder |
| Filenames | `\/:*?"<>|` + U+00A0/U+201C/U+201D etc. → `_` |
| Recycle Bin | Skipped |

Any structure the script can't map → it falls back conservatively (text joined by `<br>`, zero loss) and reports it.

**Loss matrix:** images, attachments, hyperlinks, ink, math, audio, and video are intentionally not converted. Full breakdown: `docs/onenote-loss-matrix.md` in the plugin repo.

***

## File Naming

Default naming rules:

| type | pattern | example |
|------|---------|---------|
| `daily` | `{date}.md` | `2026-07-29.md` |
| `meeting` | `{date}-{topic}.md` | `2026-07-29-product-review.md` |
| `quick-note` | `{date}-{title}.md` | `2026-07-29-idea.md` |
|  (default)   | `{title}.md`        | `my-note.md`                   |

> ⚠️ When editing this file, keep `SKILL-CN.md` (`../../SKILL-CN.md`) in sync. It is the Chinese reference version for the plugin author.

