---
name: obscura-fetch
description: "Use this skill for anonymous web scraping and batch crawling with the local Obscura engine (Rust headless browser, no Chromium). Covers: one-shot page fetch as Markdown / text / HTML / links, parallel batch scraping, stealth anti-fingerprinting, proxy use, and raw binary-safe response download. Use it when a page is JS-heavy, when a site blocks ordinary fetches, or when you need many URLs at once. This skill is scrape-only: for anything interactive — clicking, form filling, multi-step sessions, login state, screenshots, or verifying your own UI — use the Playwright stack instead. Trigger phrases: 抓取, 爬取, 批量抓取, 网页抓取, JS 渲染, 匿名, 反指纹, obscura, scraping, crawl, batch scrape, headless browser, markdown dump."
metadata: {"source": "https://github.com/h4ckf0r0day/obscura", "requires": {"files": ["~/.obscura/bin/obscura.exe"]}}
---

# Obscura Fetch — Anonymous Scraping Engine

Use the local **Obscura** engine (Rust headless browser, embedded V8, no Chromium) for **anonymous scraping**: one-shot page fetch, parallel batch crawling, raw response download.

**This skill is scrape-only by design.** It deliberately does not cover interactive browsing — clicking, form filling, multi-step sessions, login state, screenshots, or verifying your own UI. Those belong to the Playwright stack (a real Chromium-based browser). Keeping the two apart is what makes the tool choice unambiguous.

| Need | Tool |
| :--- | :--- |
| Lightweight read of a static page; following search links | built-in `web_fetch` / `web_search` |
| **Anonymous scrape / batch crawl / anti-fingerprint** | **this skill — `obscura fetch` / `obscura scrape`** |
| Anything interactive (click, fill, session, login state, screenshot, verify UI) | Playwright stack (`playwright-cli` + a real browser) |

> Path convention: `{SKILL_DIR}` = this skill's directory (the skill runner resolves it; otherwise substitute the absolute path of `skills/obscura-fetch`).

## Prerequisites

> **Install the engine once.** This plugin ships instructions and one installer script; the engine binary (~160 MB) is **not** bundled (marketplace formats have no install hooks). Run **`/obscura-fetch install`**, or `scripts/install-obscura.ps1` directly on Windows.

- The binary lands in **`~/.obscura/bin/`** — a shared, per-user location *outside* the plugin directory, on purpose:
  - one engine copy serves every agent you use (DSH, Claude Code, Codex, Copilot);
  - platform plugin caches get re-copied and cleaned on plugin updates — the engine survives them;
  - engine upgrades are decoupled from plugin versions (reinstall with `-Force`).
- **No Node.js, no Chrome, no other dependency** — `fetch` and `scrape` are self-contained.
- **Windows (primary)**: the installer is Windows PowerShell. **macOS / Linux**: install the official binary from the [releases page](https://github.com/h4ckf0r0day/obscura/releases) and drive it directly — see "Other platforms".
- Variants: `render` (rendering, default) / `stealth` (rendering + anti-fingerprint + blocks 3,520 tracker domains) / `no-render` (lightest) / `no-render-stealth`.

## Install / Upgrade (Windows)

```powershell
$install = "{SKILL_DIR}/scripts/install-obscura.ps1"

& $install                          # idempotent (skips if already installed)
& $install -Force                   # reinstall latest release (Obscura releases often)
& $install -Force -Variant stealth  # switch variant
```

## One-shot fetch (core)

`$bin = "~/.obscura/bin/obscura.exe"` (Windows; on macOS / Linux the binary is `obscura`).

```powershell
# JS-rendered content as Markdown — first choice when the built-in fetch gets an empty SPA shell
& $bin fetch https://news.ycombinator.com --dump markdown --output "$env:TEMP\page.md"

# Wait for dynamic content / selector / timeout
& $bin fetch https://example.com --dump markdown --wait-until networkidle0 --output "$env:TEMP\p.md"
& $bin fetch https://example.com --dump markdown --selector "#app" --output "$env:TEMP\p.md"
& $bin fetch https://example.com --dump text --timeout 10 --output "$env:TEMP\p.txt"

# Link dump / raw response bytes (images, JSON, downloads — binary-safe)
& $bin fetch https://example.com --dump links --output "$env:TEMP\links.txt"
& $bin fetch https://picsum.photos/200/300 --dump original --output "$env:TEMP\photo.jpg"

# Evaluate JS on the page
& $bin fetch https://example.com --eval "document.title" --output "$env:TEMP\title.txt"

# Through a proxy (the flag goes before the subcommand)
& $bin --proxy http://127.0.0.1:7897 fetch https://example.com --dump markdown --output "$env:TEMP\p.md"
```

**Rule: `fetch` always writes with `--output` (`-o`) and you read the file back — never pipe-capture its stdout** (encoding / escaping issues).

Dump types: `markdown` / `text` / `html` (rendered DOM) / `links` / `assets` (subresource list, NDJSON) / `original` (raw response, binary-safe).

> **Not for screenshots or PDF.** The engine can render, but layout fidelity is not this skill's job — for screenshots, PDF, or anything you intend to *look at* or *verify*, use the Playwright stack.

## Batch scraping

`scrape` has **no `--output` flag** — it prints to stdout, so redirect it (plain `Out-File -Encoding utf8`; UTF-8 without BOM on PowerShell 7):

```powershell
& $bin scrape url1 url2 url3 --concurrency 10 --eval "document.title" --format json --quiet |
  Out-File -Encoding utf8 "$env:TEMP\out.json"
```

It emits **one JSON object, not an array** — the rows live under `.results`:

```json
{ "total_urls": 3, "concurrency": 10, "total_time_ms": 1234, "avg_time_ms": 411.0,
  "results": [ { "url": "…", "title": "…", "eval": "…", "time_ms": 411, "worker": 0 } ] }
```

`--format text` prints a plain-text variant instead. Flags: `-e/--eval`, `--concurrency` (default 10), `--format` (default `json`), `--timeout` (default 60), `-q/--quiet`, plus the global `--proxy` / `--stealth`.

`scrape` fans out to worker processes, so **`obscura-worker.exe` must sit next to `obscura.exe`** — the installer places both. Start at `--concurrency 5`–`10`: workers are separate processes, so memory rather than CPU is the practical ceiling.

## Stealth

Stealth is a **build variant** plus a **runtime flag**. Reach for it when the target fingerprints or blocks ordinary headless clients:

```powershell
& $bin fetch https://example.com --dump markdown --stealth --output "$env:TEMP\p.md"
& $bin scrape url1 url2 --stealth --concurrency 5 --format json --quiet |
  Out-File -Encoding utf8 "$env:TEMP\out.json"
```

It adds per-session fingerprint randomization (GPU / screen / canvas / audio / battery), a realistic `navigator.userAgentData`, `navigator.webdriver = undefined`, native-function masking, `event.isTrusted = true`, and blocks 3,520 tracker domains. It requires the `stealth` build (`install-obscura.ps1 -Force -Variant stealth`); the runtime flag alone is not enough.

The flag is global — it may appear before or after the subcommand.

## Known pitfalls

- **stealth does not defeat captcha / IP-level anti-bot** (verified: qidian.com answers HTTP 202 / a verification page even with stealth — the block is IP/session-level, not client-side). No flag fixes that. For those targets use a real logged-in browser session (the Playwright stack) or a different IP.
- **SSRF guard blocks private networks by default**: scraping `localhost` / LAN / intranet needs `--allow-private-network` (`OBSCURA_ALLOW_PRIVATE_NETWORK=1` works too). Public targets are unaffected.
- **Large bodies**: responses over 2 MiB aren't retained by default (`OBSCURA_NETWORK_BODY_BUFFER_BYTES`) — raise it, or use `--dump original`, which streams the raw body verbatim.
- **JS-heavy pages OOM**: `--v8-flags "--max-old-space-size=4096"`; SPA startup budget `OBSCURA_SCRIPT_DEADLINE_MS` (default 30000, try 60000 for heavy SPAs).
- **Release cadence**: v0.2.x moves fast — the API may change; upgrade with `-Force` and watch the [release notes](https://github.com/h4ckf0r0day/obscura/releases).
- **Rendering fidelity** (only if you stray into screenshots): an independent engine — long-tail CSS / media / platform fonts differ from Chromium. Text and Markdown extraction are unaffected, but **do not treat its screenshots as a layout baseline**.

## Other platforms (macOS / Linux)

The engine is cross-platform; only the installer script is Windows PowerShell.

```bash
# macOS (Apple Silicon shown; Intel = x86_64-macos)
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-aarch64-macos.tar.gz
tar xzf obscura-aarch64-macos.tar.gz          # Linux: obscura-x86_64-linux.tar.gz

obscura fetch https://example.com --dump markdown              # one-shot
obscura scrape url1 url2 --concurrency 10 --format json --quiet  # batch
```

## References

- Engine repo: https://github.com/h4ckf0r0day/obscura (Apache-2.0)
- Docs: https://docs.obscura.sh
- Environment variables: repo `docs/Environment-variables.md`
