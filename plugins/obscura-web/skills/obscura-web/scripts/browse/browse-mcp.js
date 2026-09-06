#!/usr/bin/env node
// Obscura MCP 会话客户端（有状态）：驱动常驻 `obscura mcp --http`（默认 127.0.0.1:8080）。
//
// 会话连续性走这条线：MCP 服务在工具调用之间保持页面存活，
// cookie / 登录态 / 页面位置跨多次调用连续。
// （serve 的 CDP 连接一断开页面就被重置，勿用 attach-detach 姿势做多步流程。）
//
// 用法:
//   node browse-mcp.js navigate <url> [waitUntil]   导航（load | domcontentloaded | networkidle0）
//   node browse-mcp.js snapshot                     当前页快照（URL/标题/可读正文 + 元素引用）
//   node browse-mcp.js text                         当前页 body.innerText
//   node browse-mcp.js eval <js>                    页面内执行 JS
//   node browse-mcp.js click <selector>             点击
//   node browse-mcp.js fill <selector> <value>      填值
//   node browse-mcp.js type <selector> <text>       追加输入
//   node browse-mcp.js press <key>                  按键
//   node browse-mcp.js select <selector> <value>    下拉选择
//   node browse-mcp.js wait <selector> [秒]         等待选择器出现
//   node browse-mcp.js screenshot [file.png]        截图（给路径则落盘）
//   node browse-mcp.js pdf [file.pdf]               导出 PDF（给路径则落盘）
//   node browse-mcp.js requests                     网络请求列表
//   node browse-mcp.js console                      控制台消息
//   node browse-mcp.js close                        关闭页面（清空会话）
//
// 环境变量: OBSCURA_MCP 覆盖 MCP 端点。

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { homedir } from 'node:os';

const MCP_URL = process.env.OBSCURA_MCP || 'http://127.0.0.1:8080/mcp';
const runDir = join(homedir(), '.obscura', 'run');
const sessionFile = join(runDir, 'mcp-session.txt');
const [cmd, ...rest] = process.argv.slice(2);

async function post(payload, sessionId) {
  const headers = { 'Content-Type': 'application/json', Accept: 'application/json, text/event-stream' };
  if (sessionId) headers['MCP-Session-Id'] = sessionId;
  const res = await fetch(MCP_URL, { method: 'POST', headers, body: JSON.stringify(payload) });
  const text = await res.text();
  let body;
  try { body = JSON.parse(text); } catch { body = { raw: text }; }
  return { body, sessionId: res.headers.get('mcp-session-id') || sessionId };
}

async function ensureSession() {
  let sid = existsSync(sessionFile) ? readFileSync(sessionFile, 'utf8').trim() : '';
  const initPayload = {
    jsonrpc: '2.0', id: 1, method: 'initialize',
    params: {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'obscura-web-browse', version: '1.0.0' },
    },
  };
  let r = await post(initPayload, sid);
  if (r.body && r.body.error) {
    // 旧 session 失效（如服务重启）→ 无 session 重新初始化
    r = await post(initPayload, '');
  }
  if (r.sessionId) {
    mkdirSync(runDir, { recursive: true });
    writeFileSync(sessionFile, r.sessionId);
    sid = r.sessionId;
  }
  await post({ jsonrpc: '2.0', method: 'notifications/initialized' }, sid).catch(() => {});
  return sid;
}

const toolFor = {
  navigate: ['browser_navigate', { url: rest[0], waitUntil: rest[1] || 'load' }],
  snapshot: ['browser_snapshot', {}],
  text: ['browser_evaluate', { expression: 'document.body.innerText' }],
  eval: ['browser_evaluate', { expression: rest.join(' ') }],
  click: ['browser_click', { selector: rest[0] }],
  fill: ['browser_fill', { selector: rest[0], value: rest.slice(1).join(' ') }],
  type: ['browser_type', { selector: rest[0], text: rest.slice(1).join(' ') }],
  press: ['browser_press_key', { key: rest[0] }],
  select: ['browser_select_option', { selector: rest[0], value: rest[1] }],
  wait: ['browser_wait_for', { selector: rest[0], timeout: parseInt(rest[1] || '10', 10) }],
  screenshot: ['browser_screenshot', {}],
  pdf: ['browser_pdf', {}],
  requests: ['browser_network_requests', {}],
  console: ['browser_console_messages', {}],
  close: ['browser_close', {}],
};

function saveContent(content, file) {
  for (const item of content || []) {
    if ((item.type === 'image' || item.type === 'resource') && item.data) {
      writeFileSync(file, Buffer.from(item.data, 'base64'));
      return { saved: file, mime: item.mimeType };
    }
    if (item.type === 'text' && item.text) return { text: item.text };
  }
  return { content };
}

(async () => {
  try {
    const sid = await ensureSession();
    const [tool, args] = toolFor[cmd] || [null, null];
    if (!tool) throw new Error(`未知命令: ${cmd}（可用: navigate/snapshot/text/eval/click/fill/type/press/select/wait/screenshot/pdf/requests/console/close）`);
    const r = await post({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: tool, arguments: args } }, sid);
    if (r.body && r.body.error) throw new Error(`MCP error: ${r.body.error.message || JSON.stringify(r.body.error)}`);
    const result = r.body && r.body.result;
    if (result && result.isError) throw new Error(`tool error: ${(result.content || []).map((c) => c.text).join(' ')}`);
    const content = result && result.content;
    if ((cmd === 'screenshot' || cmd === 'pdf') && rest[0]) {
      console.log(JSON.stringify(saveContent(content, rest[0])));
    } else if (content) {
      for (const item of content) {
        if (item.type === 'text') console.log(item.text);
        else console.log(JSON.stringify({ [item.type]: `(binary content, base64 length ${item.data ? item.data.length : 0})` }));
      }
    } else {
      console.log(JSON.stringify(result));
    }
  } catch (e) {
    console.error(`BROWSE_MCP_ERROR=${e.message}`);
    process.exitCode = 1;
  }
})();
