# Obscura Web — 匿名抓取引擎（中文对照）

> 本文件是 `skills/obscura-web/SKILL.md` 的中文同步翻译，仅供作者对照。以英文 SKILL.md 为准。

通过本地 **Obscura** 引擎（Rust 无头浏览器，内嵌 V8，无 Chromium）做**匿名抓取**：一次性页面抓取、并行批量爬取、原始响应下载。

**本 skill 刻意只做抓取。** 它不涉及交互式浏览——点击、填表、多步会话、复用登录态、截图，或验收你自己的 UI。那些归 Playwright 栈（真 Chromium 内核浏览器）。把两者分开，工具选择才没有歧义。

| 需求 | 工具 |
| :--- | :--- |
| 静态页轻量读取、跟随搜索链接 | 内置 `web_fetch` / `web_search` |
| **匿名抓取 / 批量爬取 / 反指纹** | **本 skill —— `obscura fetch` / `obscura scrape`** |
| 一切交互（点击、填表、会话、登录态、截图、验收 UI） | Playwright 栈（`playwright-cli` + 真浏览器） |

> 路径约定：`{SKILL_DIR}` = 本 skill 目录（skill 运行器会解析；否则替换为 `skills/obscura-web` 的绝对路径）。

## 前置条件

> **先装引擎——装完本插件后必须做的一步。** 插件本体只含指令与一个安装脚本；引擎二进制（约 160MB）**不随市场打包**（市场格式没有安装钩子）。运行 **`/obscura-web install`**，Windows 上也可直接跑 `scripts/install-obscura.ps1`。

- 二进制落位 **`~/.obscura/bin/`**——特意放在插件目录之外的**共享用户级目录**：
  - 一份引擎服务你所有 agent（DSH / Claude Code / Codex / Copilot）；
  - 平台的插件缓存会在更新时重拷/清理——引擎不受影响；
  - 引擎升级与插件版本解耦（`-Force` 重装即可）。
- **不需要 Node.js、不需要 Chrome、没有其他依赖**——`fetch` 与 `scrape` 自带完备。
- **Windows（主要）**：安装脚本是 Windows PowerShell。**macOS / Linux**：从[官方 releases 页](https://github.com/h4ckf0r0day/obscura/releases)装二进制后直接驱动——见「其他平台」。
- 变体：`render`（渲染，默认）/ `stealth`（渲染 + 反指纹 + 拦截 3520 个追踪域名）/ `no-render`（最轻）/ `no-render-stealth`。

## 安装 / 升级（Windows）

```powershell
$install = "{SKILL_DIR}/scripts/install-obscura.ps1"

& $install                          # 幂等（已装则跳过）
& $install -Force                   # 重装最新 release（Obscura 发布频密）
& $install -Force -Variant stealth  # 换变体
```

## 一次性抓取（核心）

`$bin = "~/.obscura/bin/obscura.exe"`（Windows；macOS/Linux 直接是 `obscura`）。

```powershell
# JS 渲染后 Markdown——内置 fetch 拿到空壳 SPA 时的首选
& $bin fetch https://news.ycombinator.com --dump markdown --output "$env:TEMP\page.md"

# 等动态内容 / 选择器 / 超时
& $bin fetch https://example.com --dump markdown --wait-until networkidle0 --output "$env:TEMP\p.md"
& $bin fetch https://example.com --dump markdown --selector "#app" --output "$env:TEMP\p.md"
& $bin fetch https://example.com --dump text --timeout 10 --output "$env:TEMP\p.txt"

# 链接提取 / 原始响应字节（图片、JSON、下载，二进制安全）
& $bin fetch https://example.com --dump links --output "$env:TEMP\links.txt"
& $bin fetch https://picsum.photos/200/300 --dump original --output "$env:TEMP\photo.jpg"

# 页面内执行 JS
& $bin fetch https://example.com --eval "document.title" --output "$env:TEMP\title.txt"

# 走代理（flag 放在子命令之前）
& $bin --proxy http://127.0.0.1:7897 fetch https://example.com --dump markdown --output "$env:TEMP\p.md"
```

**铁律：一律 `--output` 落文件再读，不要管道捕获 stdout**（编码/转义问题）。

dump 类型：`markdown` / `text` / `html`（渲染后 DOM）/ `links` / `assets`（子资源清单 NDJSON）/ `original`（原始响应，二进制安全）。

> **截图与 PDF 不在本 skill 用途内。** 引擎能渲染，但布局保真不是它这儿的活——要截图、PDF，或任何你打算**看**或**验收**的东西，走 Playwright 栈。

## 批量并发抓取

```powershell
& $bin scrape url1 url2 url3 --concurrency 10 --eval "document.title" --format json --quiet --output "$env:TEMP\out.json"
```

`scrape` 会扇出到 worker 进程，所以 **`obscura-worker.exe` 必须与 `obscura.exe` 同目录**（安装脚本会把两个都放好）。从 `--concurrency 5`–`10` 起步：worker 是独立进程，实际瓶颈是内存而非 CPU。`--quiet` 让进度不落 stderr，便于脚本消费输出。

## Stealth（反指纹）

Stealth 是**构建变体**加**运行时 flag**。目标站点会指纹识别或封普通无头客户端时用它：

```powershell
& $bin fetch https://example.com --dump markdown --stealth --output "$env:TEMP\p.md"
& $bin scrape url1 url2 --stealth --concurrency 5 --format json --output "$env:TEMP\out.json"
```

它加的是：每会话指纹随机化（GPU / 屏幕 / canvas / 音频 / 电池）、真实的 `navigator.userAgentData`、`navigator.webdriver = undefined`、原生函数掩码、`event.isTrusted = true`，并拦截 3520 个追踪域名。需要 `stealth` 变体的二进制（`install-obscura.ps1 -Force -Variant stealth`）；只加运行时 flag 不够。

该 flag 是全局的，可放在子命令前后。

## 已知坑

- **stealth 过不了验证码 / IP 级风控**（实测：qidian.com 即便 stealth 也返回 HTTP 202 / 验证码页——拦截在 IP/会话层，不在客户端）。没有任何 flag 能解决。这类目标要么用真浏览器登录态（Playwright 栈），要么换 IP。
- **SSRF 防护默认拦内网**：抓 `localhost` / LAN / 内网需 `--allow-private-network`（也可用 `OBSCURA_ALLOW_PRIVATE_NETWORK=1`）。公网目标不受影响。
- **大响应体**：默认 2 MiB 以上不保留（`OBSCURA_NETWORK_BODY_BUFFER_BYTES`）——调大它，或用 `--dump original`（逐字节流原始响应）。
- **JS 重页面 OOM**：`--v8-flags "--max-old-space-size=4096"`；SPA 启动预算 `OBSCURA_SCRIPT_DEADLINE_MS`（默认 30000，重 SPA 试 60000）。
- **版本节奏**：v0.2.x 变化快——API 可能变；升级用 `-Force`，看 [release notes](https://github.com/h4ckf0r0day/obscura/releases)。
- **渲染保真度**（只在你越界去截图时才相关）：独立引擎——长尾 CSS / 媒体 / 平台字体与 Chromium 有差异。文本与 Markdown 提取不受影响，但**别把它的截图当布局基线**。

## 其他平台（macOS / Linux）

引擎本身跨平台，只是安装脚本是 Windows PowerShell。

```bash
# macOS（Apple Silicon 示例；Intel = x86_64-macos）
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-aarch64-macos.tar.gz
tar xzf obscura-aarch64-macos.tar.gz          # Linux: obscura-x86_64-linux.tar.gz

obscura fetch https://example.com --dump markdown                # 一次性
obscura scrape url1 url2 --concurrency 10 --format json --quiet  # 批量
```

## 参考

- 引擎仓库：https://github.com/h4ckf0r0day/obscura （Apache-2.0）
- 文档：https://docs.obscura.sh
- 环境变量全集：仓库 `docs/Environment-variables.md`
