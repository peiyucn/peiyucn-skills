# Obscura Web — 抓取与浏览器引擎（中文对照）

> 本文件是 `skills/obscura-web/SKILL.md` 的中文同步翻译，仅供作者对照。以英文 SKILL.md 为准。

通过本地 **Obscura** 引擎（Rust 无头浏览器，内嵌 V8，无 Chromium）做匿名网页抓取、JS 重页面渲染、并行批量抓取、截图/PDF、有状态浏览器会话。

**分工**（本插件不替代任何现有工具）：

| 工具 | 定位 | 什么时候用 |
|---|---|---|
| Agent 内置 fetch（如 `web_fetch` + `web_search` 组合） | 轻量读取 | 静态页快速读、跟随搜索链接 |
| `browser-cdp` skill（真 Chrome） | 复用登录态 | 需要已有 Chrome 登录会话的任务 |
| **`obscura-web`（本插件）** | 匿名重型抓取 + 会话 | JS 重页面、批量抓取、截图/PDF、多步流程（可自建并保持登录会话） |

> 路径约定：`{SKILL_DIR}` = 本 skill 目录（skill 运行器会解析；否则替换为 `skills/obscura-web` 的绝对路径）。

## 前置条件

> **先装引擎——这是装完本插件后必须做的一步。**
> 插件本体只含指令与辅助脚本；Obscura 引擎二进制（约 160MB）**不随市场打包**（市场格式没有安装钩子）。装完插件后运行 **`/obscura-web install`**（Windows 上也可直接跑 `scripts/install-obscura.ps1`）。

- 二进制落位 **`~/.obscura/bin/`**——特意放在插件目录之外的**共享用户级目录**：
  - 一份引擎服务你所有 agent（DSH / Claude Code / Codex / Copilot）+ 一个常驻 MCP 服务；
  - 平台的插件缓存会在更新时重拷/清理——引擎不受影响；
  - 引擎升级与插件版本解耦（`-Force` 重装即可）。
- **Windows（主要）**：`fetch`/`scrape` 不需要 Chrome 或 Node。
- **Node.js 20+** 仅会话助手 `scripts/browse/` 需要（在该目录跑一次 `npm install`）。
- **macOS / Linux**：从[官方 releases 页](https://github.com/h4ckf0r0day/obscura/releases)装二进制——见「其他平台」。
- 变体：`render`（渲染，默认）/ `stealth`（渲染 + 反指纹 + 拦截 3520 个追踪域名）/ `no-render`（最轻）/ `no-render-stealth`。

## 安装 / 升级（Windows）

```powershell
$install = "{SKILL_DIR}/scripts/install-obscura.ps1"

& $install                          # 幂等（已装则跳过）
& $install -Force                   # 重装最新 release（Obscura 发布频密）
& $install -Force -Variant stealth  # 换变体
```

## 服务（两个，各司其职）

```powershell
$svc = "{SKILL_DIR}/scripts/obscura-serve.ps1"

# MCP 服务——常驻主角，会话模式用（工具调用之间页面保持存活）
& $svc -Action mcp-start            # http://127.0.0.1:8080/mcp
& $svc -Action mcp-start -Stealth   # 反指纹 + 追踪域名拦截
& $svc -Action mcp-status
& $svc -Action mcp-stop

# CDP 服务——按需起，原生 puppeteer-core 脚本用（断开即重置页面，勿做多步）
& $svc -Action start                # 默认 ws://127.0.0.1:9223
& $svc -Action start -Local         # 允许内网目标（SSRF 防护默认开启）
& $svc -Action status
& $svc -Action stop                 # 只杀 PID 文件记录的进程
```

CDP 就绪：`ws://127.0.0.1:9223/devtools/browser`，探测 `http://127.0.0.1:9223/json/version`。

## 一次性抓取（核心）

`$bin = "~/.obscura/bin/obscura.exe"`（Windows；macOS/Linux 直接是 `obscura`）。

```powershell
# JS 渲染后 Markdown——内置 fetch 拿到空壳 SPA 时的首选
& $bin fetch https://news.ycombinator.com --dump markdown --output "$env:TEMP\page.md"

# 等动态内容 / 选择器 / 超时
& $bin fetch https://example.com --dump markdown --wait-until networkidle0 --output "$env:TEMP\p.md"
& $bin fetch https://example.com --dump markdown --selector "#app" --output "$env:TEMP\p.md"
& $bin fetch https://example.com --dump text --timeout 10 --output "$env:TEMP\p.txt"

# 原始响应字节（图片/JSON/下载，二进制安全）
& $bin fetch https://picsum.photos/200/300 --dump original --output "$env:TEMP\photo.jpg"

# 页面内执行 JS
& $bin fetch https://example.com --eval "document.title" --output "$env:TEMP\title.txt"

# 截图 / 链接提取
& $bin fetch https://example.com --screenshot "$env:TEMP\page.png"
& $bin fetch https://example.com --dump links --output "$env:TEMP\links.txt"

# 走代理
& $bin --proxy http://127.0.0.1:7897 fetch https://example.com --dump markdown --output "$env:TEMP\p.md"
```

**铁律：一律 `--output` 落文件再读，不要管道捕获 stdout**（编码/转义问题）。

dump 类型：`markdown` / `text` / `html`（渲染后 DOM）/ `links` / `assets`（子资源清单 NDJSON）/ `original`（原始响应，二进制安全）。

## 批量并发抓取

```powershell
& $bin scrape url1 url2 url3 --concurrency 10 --eval "document.title" --format json --quiet --output "$env:TEMP\out.json"
```

## 会话模式（多步 / 会话连续性）

> 姿势原则：**一次性 `fetch` 无状态；多步流程（登录→翻页→提取、跨调用保持 cookie）走 MCP 会话**。
> 实测 v0.2.2：CDP 客户端断开后 serve 页面重置为 `about:blank`；MCP 服务在工具调用之间保持页面存活——会话连续性走 MCP。

```powershell
$bmcp = "{SKILL_DIR}/scripts/browse/browse-mcp.js"

node $bmcp navigate "<URL>" [waitUntil]   # load | domcontentloaded | networkidle0
node $bmcp snapshot                       # URL / 标题 / 可读正文 + 元素引用
node $bmcp text                           # body.innerText
node $bmcp eval "<js>"                    # 页面内执行 JS
node $bmcp click "<selector>"             # 点击
node $bmcp fill "<selector>" "<value>"    # 填值（触发 input + change）
node $bmcp type "<selector>" "<text>"     # 追加输入
node $bmcp press "<key>"                  # 按键
node $bmcp select "<selector>" "<value>"  # 下拉选择
node $bmcp wait "<selector>" [秒]         # 等选择器
node $bmcp screenshot "<file.png>"        # 截图（渲染版）
node $bmcp pdf "<file.pdf>"               # PDF（渲染版）
node $bmcp requests                       # 网络请求
node $bmcp console                        # 控制台消息
node $bmcp close                          # 关页面 = 清空会话
```

- 页面与 cookie 留在 MCP 服务进程里，browse-mcp.js 每次独立执行、状态跨调用连续（实测：httpbin 种 cookie 后独立进程读回）
- MCP session id 存于 `~/.obscura/run/mcp-session.txt`，服务重启后自动重新初始化
- MCP 没起？`obscura-serve.ps1 -Action mcp-start`

## 原生 CDP（puppeteer-core / playwright-core）

一次性 Puppeteer 脚本或 Obscura 私有域（如 `LP.getMarkdown`）：

```powershell
& "{SKILL_DIR}/scripts/obscura-serve.ps1" -Action start
# 然后 ws://127.0.0.1:9223/devtools/browser（puppeteer-core 在 scripts/browse 下）
# scripts/browse/browse.js：open/md/text/eval/click/fill/cookies/screenshot/close（仅单步）
```

**CDP 断开即重置页面**——`browse.js` 只做单步；多步一律走 MCP。

## 已知坑

- **端口冲突**：作者机器上 9222 被 `msedgewebview2` 调试端口占用——勿碰勿杀。本插件默认 9223；`failed`（10048）即端口被占，换 `-Port`。
- **CDP 断开即重置页面**（实测 v0.2.2）：serve 页面在客户端断开后回到 `about:blank`——多步必须走 MCP。
- **stealth 过不了验证码/IP 级风控**（实测：qidian.com 即便 stealth 也返回 HTTP 202 / 验证码页——拦截在 IP/会话层）。这类站点用真 Chrome 登录态（browser-cdp），别用本插件硬刚。
- **SSRF 防护默认拦内网**：localhost / LAN / 内网需 `--allow-private-network`（serve 用 `-Local`）。
- **大响应体**：默认 2 MiB 以上不保留（`OBSCURA_NETWORK_BODY_BUFFER_BYTES`）；大下载流式走 CDP `Fetch.takeResponseBodyAsStream` + `IO.read`。
- **JS 重页面 OOM**：`--v8-flags "--max-old-space-size=4096"`；SPA 启动预算 `OBSCURA_SCRIPT_DEADLINE_MS`（默认 30000，重 SPA 试 60000）。
- **渲染保真度**：独立引擎——长尾 CSS / 媒体播放 / 平台字体与 Chromium 有差异。截图做参考，别做像素级对比。
- **agent-browser 兼容性**：`agent-browser connect` 的 `snapshot` 依赖 Accessibility 域，Obscura 未实现——未实测，勿承诺。优先用本插件 fetch/scrape 或 puppeteer-core。
- **版本节奏**：v0.2.x 变化快——API 可能变；升级用 `-Force`，看 [release notes](https://github.com/h4ckf0r0day/obscura/releases)。
- **服务僵死**：`status` 报 degraded → 看 `~/.obscura/logs/serve.err.log`，再 `stop` + `start`。禁止按进程名批量杀。

## 其他平台（macOS / Linux）

引擎本身跨平台，只是辅助脚本是 Windows PowerShell。

```bash
# macOS（Apple Silicon 示例；Intel = x86_64-macos）
curl -LO https://github.com/h4ckf0r0day/obscura/releases/latest/download/obscura-aarch64-macos.tar.gz
tar xzf obscura-aarch64-macos.tar.gz          # Linux: obscura-x86_64-linux.tar.gz

obscura fetch https://example.com --dump markdown   # 一次性
obscura mcp --http --port 8080 &                    # 有状态 MCP 会话服务
obscura serve --port 9223 &                         # CDP 按需
```

会话助手：用 Node 跑 `browse-mcp.js`（MCP 协议与传输无关）；服务管理手动（`pkill -f "obscura mcp"`——只做窄匹配）。

## 参考

- 引擎仓库：https://github.com/h4ckf0r0day/obscura （Apache-2.0）
- 文档：https://docs.obscura.sh
- 环境变量全集：仓库 `docs/Environment-variables.md`
- MCP 模式（Claude Desktop / Cursor）：`obscura mcp`（stdio）或 `obscura mcp --http --port 8080`
