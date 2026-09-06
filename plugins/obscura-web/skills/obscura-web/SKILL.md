---
name: obscura-web
description: "Use this skill for web fetching, scraping and interactive browsing with the local Obscura engine (Rust headless browser, no Chromium). Covers: JS-rendered page fetching with clean Markdown output, parallel batch scraping, screenshots/PDF, and stateful multi-step sessions via its MCP server. Use it instead of the agent's built-in fetch tool when a page is JS-heavy or blocked, and for anonymous scraping; keep browser-cdp (real Chrome login reuse) for tasks that need an existing logged-in session. Trigger phrases: 抓取, 抓页面, 网页抓取, JS 渲染, 无头浏览器, obscura, headless browser, scraping, fetch page, SPA, 批量抓取, 截图, 会话浏览, 浏览器会话, markdown dump."
metadata: {"source": "https://github.com/h4ckf0r0day/obscura", "requires": {"files": ["~/.obscura/bin/obscura.exe"]}}
---

# Obscura Web — Fetching & Browser Engine

Use the local **Obscura** engine (Rust headless browser, embedded V8, no Chromium) for anonymous fetching, JS-rendered pages, parallel batch scraping, screenshots/PDF, and stateful browser sessions.

**Division of labor** (this plugin replaces nothing):

| Tool | Role | Use it when |
|---|---|---|
| Agent built-in fetch (e.g. `web_fetch` + `web_search` pair) | Lightweight reads | Quick static pages, following search links |
| `browser-cdp` skill (real Chrome) | Login-state reuse | Tasks that need an existing logged-in Chrome session |
| **`obscura-web` (this plugin)** | Anonymous heavy fetching + sessions | JS-heavy pages, batch scraping, screenshots/PDF, multi-step flows (can build and hold its own login session) |

> Path convention: `{SKILL_DIR}` = this skill's directory (the skill runner resolves it; otherwise substitute the absolute path of `skills/obscura-web`).

## Prerequisites

- **Windows (primary)**: run `scripts/install-obscura.ps1` once — installs the binary to `~/.obscura/bin/`. No Chrome or Node needed for `fetch`/`scrape`.
- **Node.js 20+** only for the session helper under `scripts/browse/` (run `npm install` there once).
- **macOS / Linux**: install the official binary from the [releases page](https://github.com/h4ckf0r0day/obscura/releases) — see "Other platforms".
- Variants: `render` (rendering, default) / `stealth` (rendering + anti-fingerprint + blocks 3,520 tracker domains) / `no-render` (lightest) / `no-render-stealth`.

## Install / Upgrade (Windows)

```powershell
$install = "{SKILL_DIR}/scripts/install-obscura.ps1"

& $install                          # idempotent (skips if already installed)
& $install -Force                   # reinstall latest release (Obscura releases often)
& $install -Force -Variant stealth  # switch variant
```

## Services (two, different jobs)

```powershell
$svc = "{SKILL_DIR}/scripts/obscura-serve.ps1"

# MCP service — the resident workhorse for stateful sessions (page survives between tool calls)
& $svc -Action mcp-start            # http://127.0.0.1:8080/mcp
& $svc -Action mcp-start -Stealth   # anti-fingerprint + tracker blocking
& $svc -Action mcp-status
& $svc -Action mcp-stop

# CDP service — on demand, for raw puppeteer-core scripts (page resets on disconnect; no multi-step)
& $svc -Action start                # default ws://127.0.0.1:9223
& $svc -Action start -Local         # allow private-network targets (SSRF guard on by default)
& $svc -Action status
& $svc -Action stop                 # kills only the PID recorded in the pid file
```

CDP ready: `ws://127.0.0.1:9223/devtools/browser`, probe `http://127.0.0.1:9223/json/version`.

## One-shot fetching (core)

`$bin = "~/.obscura/bin/obscura.exe"` (Windows; on macOS/Linux the binary is `obscura`).

```powershell
# JS-rendered Markdown — first choice when the built-in fetch gets an empty SPA shell
& $bin fetch https://news.ycombinator.com --dump markdown --output "$env:TEMP\page.md"

# Wait for dynamic content / selector / timeout
& $bin fetch https://example.com --dump markdown --wait-until networkidle0 --output "$env:TEMP\p.md"
& $bin fetch https://example.com --dump markdown --selector "#app" --output "$env:TEMP\p.md"
& $bin fetch https://example.com --dump text --timeout 10 --output "$env:TEMP\p.txt"

# Raw response bytes (images / JSON / downloads, binary-safe)
& $bin fetch https://picsum.photos/200/300 --dump original --output "$env:TEMP\photo.jpg"

# Evaluate JS on the page
& $bin fetch https://example.com --eval "document.title" --output "$env:TEMP\title.txt"

# Screenshot / link dump
& $bin fetch https://example.com --screenshot "$env:TEMP\page.png"
& $bin fetch https://example.com --dump links --output "$env:TEMP\links.txt"

# Via proxy
& $bin --proxy http://127.0.0.1:7897 fetch https://example.com --dump markdown --output "$env:TEMP\p.md"
```

**Rule: always write with `--output` and read the file — never pipe-capture stdout** (encoding/escaping issues).

Dump types: `markdown` / `text` / `html` (rendered DOM) / `links` / `assets` (subresource list, NDJSON) / `original` (raw response, binary-safe).

## Batch scraping

```powershell
& $bin scrape url1 url2 url3 --concurrency 10 --eval "document.title" --format json --quiet --output "$env:TEMP\out.json"
```

## Stateful sessions (multi-step / session continuity)

> Posture: **one-shot `fetch` is stateless; multi-step flows (login → paginate → extract, cookies across calls) go through the MCP session**.
> Verified on v0.2.2: a CDP client disconnect resets the serve page to `about:blank`; the MCP server keeps the page alive between tool calls — session continuity lives in MCP.

```powershell
$bmcp = "{SKILL_DIR}/scripts/browse/browse-mcp.js"

node $bmcp navigate "<URL>" [waitUntil]   # load | domcontentloaded | networkidle0
node $bmcp snapshot                       # URL / title / readable text + element refs
node $bmcp text                           # body.innerText
node $bmcp eval "<js>"                    # evaluate JS on the page
node $bmcp click "<selector>"             # click
node $bmcp fill "<selector>" "<value>"    # fill (fires input + change)
node $bmcp type "<selector>" "<text>"     # append text
node $bmcp press "<key>"                  # key press
node $bmcp select "<selector>" "<value>"  # select option
node $bmcp wait "<selector>" [seconds]    # wait for selector
node $bmcp screenshot "<file.png>"        # screenshot (render build)
node $bmcp pdf "<file.pdf>"               # PDF export (render build)
node $bmcp requests                       # network requests
node $bmcp console                        # console messages
node $bmcp close                          # close page = clear session
```

- Page and cookies live in the MCP server process; each `browse-mcp.js` invocation attaches, operates, detaches — state carries across invocations (verified: cookie set on httpbin, read back from a separate process).
- MCP session id stored at `~/.obscura/run/mcp-session.txt`; re-initializes automatically after a service restart.
- MCP down? `obscura-serve.ps1 -Action mcp-start`.

## Raw CDP (puppeteer-core / playwright-core)

For one-off Puppeteer scripts or Obscura-private domains like `LP.getMarkdown`:

```powershell
& "{SKILL_DIR}/scripts/obscura-serve.ps1" -Action start
# then ws://127.0.0.1:9223/devtools/browser (puppeteer-core lives under scripts/browse)
# scripts/browse/browse.js: open/md/text/eval/click/fill/cookies/screenshot/close (single-step only)
```

**CDP detach resets the page** — `browse.js` is single-step only; all multi-step work goes through MCP.

## Known pitfalls

- **Port conflict**: on the author's machine 9222 is held by `msedgewebview2` debugging — never touch/kill it. This plugin defaults to 9223; `failed` (10048) means port busy, use `-Port`.
- **CDP detach resets the page** (verified v0.2.2): serve pages drop to `about:blank` when the client disconnects — multi-step must go through MCP.
- **stealth does not defeat captcha/IP-level anti-bot** (verified: qidian.com answers HTTP 202 / a verification page even with stealth — the block is IP/session-level). For those sites use a real logged-in Chrome (browser-cdp), not this plugin.
- **SSRF guard blocks private networks by default**: localhost / LAN / intranet needs `--allow-private-network` (serve: `-Local`).
- **Large bodies**: responses over 2 MiB aren't retained by default (`OBSCURA_NETWORK_BODY_BUFFER_BYTES`); stream big downloads over CDP `Fetch.takeResponseBodyAsStream` + `IO.read`.
- **JS-heavy pages OOM**: `--v8-flags "--max-old-space-size=4096"`; SPA startup budget `OBSCURA_SCRIPT_DEADLINE_MS` (default 30000, try 60000 for heavy SPAs).
- **Rendering fidelity**: independent engine — long-tail CSS / media playback / platform fonts differ from Chromium. Screenshots as reference, not pixel-exact.
- **agent-browser compat**: `agent-browser connect`'s `snapshot` needs the Accessibility domain, which Obscura doesn't implement — unverified, don't promise. Prefer this plugin's fetch/scrape or puppeteer-core.
- **Release cadence**: v0.2.x moves fast — API may change; upgrade with `-Force`, watch the [release notes](https://github.com/h4ckf0r0day/obscura/releases).
- **Stuck service**: `status` says degraded → read `~/.obscura/logs/serve.err.log`, then `stop` + `start`. Never bulk-kill by process name.

## Other platforms (macOS / Linux)

The engine is cross-platform; only the helper scripts are Windows PowerShell.

```bash
# macOS (Apple Silicon shown; Intel = x86_64-macos)
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-aarch64-macos.tar.gz
tar xzf obscura-aarch64-macos.tar.gz          # Linux: obscura-x86_64-linux.tar.gz

obscura fetch https://example.com --dump markdown   # one-shot
obscura mcp --http --port 8080 &                    # stateful MCP session server
obscura serve --port 9223 &                         # CDP on demand
```

Session helper on these platforms: run `browse-mcp.js` with Node (the MCP protocol is transport-agnostic); service management is manual (`pkill -f "obscura mcp"` — narrow match only).

## References

- Engine repo: https://github.com/h4ckf0r0day/obscura (Apache-2.0)
- Docs: https://docs.obscura.sh
- Environment variables: repo `docs/Environment-variables.md`
- MCP mode for Claude Desktop / Cursor: `obscura mcp` (stdio) or `obscura mcp --http --port 8080`
