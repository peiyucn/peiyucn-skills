# Contributing to peiyucn-skills

[简体中文](CONTRIBUTING.zh-CN.md) | English | [GitHub](https://github.com/peiyucn/peiyucn-skills)

## Branch Strategy

- `main` — stable, release-ready. Never commit directly.
- `dev` — active development. All work branches from and merges into `dev`.
- Feature branches — `feature/<name>` off `dev`, merged back via PR.

Workflow: `dev` → feature branch → PR → `dev` → (when ready) → `main`.

## Project Structure

```
peiyucn-skills/                              # Repo root = marketplace
├── .claude-plugin/marketplace.json    # Marketplace registry (name: peiyucn-skills)
├── plugins/note2md/                   # Plugin: Markdown note management
│   ├── .claude-plugin/plugin.json     # Plugin metadata
│   ├── commands/                      # Slash-command stubs (thin shells)
│   ├── SKILL-CN.md                    # Chinese reference for the author (not loaded by agents)
│   └── skills/note2md/
│       ├── SKILL.md                   # Agent behavior — all command logic lives here
│       ├── templates/                 # Built-in page templates
│       └── tools/
│           ├── export-onenote.ps1     # OneNote COM export (Windows; optional)
│           ├── convert-onenote-md.ps1 # XML → Markdown conversion (core)
│           └── format-onenote-xml.ps1 # XML pretty-printing (optional; before import)
├── plugins/obscura-fetch/               # Plugin: anonymous web scraping (Obscura engine)
│   ├── .claude-plugin/plugin.json     # Plugin metadata
│   ├── commands/                      # Slash-command stubs (thin shells)
│   ├── SKILL-CN.md                    # Chinese reference for the author (not loaded by agents)
│   └── skills/obscura-fetch/
│       ├── SKILL.md                   # Agent behavior — fetch / batch scrape only
│       └── scripts/
│           └── install-obscura.ps1    # Engine install/upgrade (Windows)

> `notes/` and `.note2md/` are user-space — they do not live in this repo.
> `test/` is a scratch directory for manual testing — gitignored.
```

## Guiding Principle

**Notebook → Section → Page is the foundation.** Every note lives at `{Notebook}/{Section}/{page}.md`. Do not add other directory levels or flatten the hierarchy. The agent's navigation, search, and archive logic all depend on this three-level structure. Before adding any feature, confirm it respects this constraint.

`SKILL.md` is the single source of truth. It defines every command, every interaction flow, and every convention. Agents (Copilot, Claude Code, Codex) load it and follow it.

There is no runtime, no build step, no configuration file — just a Markdown file that tells the agent what to do.

## Adding a Command

Edit `SKILL.md`:

1. Add the command to the Command Reference table.
2. Write a section with the step-by-step flow.
3. Keep `SKILL-CN.md` in sync (Chinese reference for the author, never loaded by agents).

## Adding a Template

Drop a `.md` file into `plugins/note2md/skills/note2md/templates/`.

- Templates are just Markdown with optional frontmatter and `{{VARIABLE}}` placeholders.
- If the template starts with `---` YAML frontmatter, it will be used as-is (with placeholders filled).
- If not, the agent auto-generates frontmatter with `date`, `type` (from the filename), `title`, and `tags`.
