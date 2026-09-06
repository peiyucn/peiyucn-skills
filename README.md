# peiyucn-skills — Agent Skills Marketplace

[简体中文](README.zh-CN.md) | English | [GitHub](https://github.com/peiyucn/peiyucn-skills)

> Agent-native skills, installable across Copilot, Claude Code, and Codex. This repo is a **marketplace** — add it once, then install any plugin it ships.

## Install the Marketplace

**VS Code Copilot** — Add marketplace `https://github.com/peiyucn/peiyucn-skills`, then install the plugins you want.

**Claude Code** — `/marketplace add https://github.com/peiyucn/peiyucn-skills` then `/plugin install note2md`.

**Codex CLI** — `codex plugin install https://github.com/peiyucn/peiyucn-skills` (installs all plugins in the marketplace).

## Plugins

### note2md 📓

Markdown notes with Notebook→Section→Page hierarchy, managed through slash commands. Your notes are just folders and `.md` files — open them in any editor. But an agent can also manage them: create notebooks, organize sections, write pages from templates, import from OneNote, archive old content.

> **Model note:** this skill relies on the model executing multi-step flows (import pipeline, template workflows, verification). It was tested and validated on **deepseek-v4-flash (high effort)** — models at or above this capability level should work fine. Smaller or weaker models may struggle; there's no hard minimum we can guarantee.

#### Commands

All agents use the same commands:

| Command | What it does |
|---------|-------------|
| `/note2md help` | Quick-start guide |
| `/note2md init` | Setup — pick language, choose notes directory, import OneNote or start fresh |
| `/note2md newnotebook <name>` | Create a notebook |
| `/note2md newsection <notebook> <section>` | Create a section inside a notebook |
| `/note2md newpage [template]` | Create a page — no arg = blank page; `daily`/`meeting`/`quick-note` = use template |
| `/note2md newtemplate` | Extract a template from a section of similar pages |
| `/note2md securecheck` | Scan your notes for passwords, IDs, API keys, and other sensitive data |
| `/note2md archive` | Move old notebooks, sections, or pages to the archive |

First time? Type `/note2md help` (Copilot) or `/note2md-help` (Claude/Codex) for a quick tour.

#### Free to use

Notebook = folder. Section = subfolder. Page = `.md` file. Use it however you like: tell the agent what you need in natural language, run slash commands, or create/rename/move/delete files yourself in your file manager — the agent picks up changes automatically. Commands are optional convenience.

#### Templates

`/note2md newpage` always offers templates. Three built-in defaults ship with the plugin:

| Template | Name |
|----------|------|
| Daily Journal | `daily` |
| Meeting Notes | `meeting` |
| Quick Note | `quick-note` |

Add your own templates under `notes/.note2md/templates/` — they automatically appear in `/note2md newpage` and override the built-in ones with the same name.

Use `/note2md newtemplate` to extract a template from any section with similar pages — pick a section, optionally describe what you want, and the agent builds a template skeleton from the common patterns it finds.

#### OneNote Import

Use `/note2md init` to import your existing OneNote notebooks. Text content — tables, lists, headings, to-dos, OCR text — is converted to Markdown automatically.

- **Windows + OneNote desktop:** the agent can auto-export your notebooks.
- **macOS / Linux (or no OneNote desktop):** auto-export isn't available (Windows-only) — export your notebooks to XML yourself (e.g. on a Windows machine with OneNote desktop) and tell `init` where the files are.

Result: `notes/` mirrors your original Notebook → Section → Page structure. After the import, you'll be asked whether to clear the temporary import files.

> **Known limitations:** images, file attachments, hyperlinks, ink/drawings, math, audio, and video are **not** extracted yet (see [docs/onenote-loss-matrix.md](docs/onenote-loss-matrix.md) for the full breakdown). Only text-based content is guaranteed.

### obscura-web 🌐

Web fetching, scraping, and stateful browser sessions on the local **Obscura** engine — a Rust headless browser (embedded V8, no Chromium). JS-rendered pages come back as clean Markdown, batch scraping runs in parallel, and multi-step flows (login → paginate → extract) keep state through the built-in MCP server.

> **Platform note:** Windows-first. The PowerShell install/service helpers are Windows-only; on macOS/Linux install the official binary from the [Obscura releases](https://github.com/h4ckf0r0day/obscura/releases) and run `obscura fetch` / `obscura mcp` directly.

#### Commands

| Command | What it does |
|---------|-------------|
| `/obscura-web help` | Quick-start guide |
| `/obscura-web install` | Install/upgrade the Obscura engine binary |
| `/obscura-web fetch <url>` | Fetch a page as rendered Markdown (JS-heavy pages included) |
| `/obscura-web browse <cmd>` | Stateful session: navigate, snapshot, click, fill, extract |

## License

MIT
