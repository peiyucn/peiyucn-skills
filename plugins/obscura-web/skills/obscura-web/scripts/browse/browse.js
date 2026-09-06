#!/usr/bin/env node
// Obscura CDP 会话助手：驱动常驻 obscura serve（默认 ws://127.0.0.1:9223）。
//
// 关键事实（实测 v0.2.2）：CDP 客户端断开后 serve 会重置页面（/json/list 变 about:blank），
// 所以本脚本只适合单步操作；多步流程 / 会话连续性一律用 browse-mcp.js（MCP 服务保持页面存活）。
//
// 用法:
//   node browse.js open <url>          导航并等 load，输出 {url,title}
//   node browse.js md [selector]       当前页 Markdown（LP.getMarkdown，失败回退 body.innerText）
//   node browse.js text                当前页 body.innerText
//   node browse.js eval <js>           页面内执行 JS，输出 JSON
//   node browse.js click <selector>    点击
//   node browse.js fill <selector> <v> 填值（触发 input + change）
//   node browse.js cookies             列出会话 cookie
//   node browse.js screenshot <path>   截图 PNG
//   node browse.js close               关闭页面（清空会话）
//
// 环境变量: OBSCURA_WS 覆盖 WebSocket 端点。

import puppeteer from 'puppeteer-core';

const WS = process.env.OBSCURA_WS || 'ws://127.0.0.1:9223/devtools/browser';
const [cmd, ...rest] = process.argv.slice(2);

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function attach() {
  let browser;
  try {
    browser = await puppeteer.connect({ browserWSEndpoint: WS });
  } catch (e) {
    console.error(`BROWSE_ERROR=连接 serve 失败（${e.message}）——先跑 obscura-serve.ps1 -Action start`);
    process.exit(1);
  }
  const pages = await browser.pages();
  // 复用 serve 里已存在的页面（会话连续性就靠它），没有才新建
  const page = pages[0] || (await browser.newPage());
  return { browser, page };
}

async function pageMarkdown(page, sel) {
  try {
    const cdp = await page.createCDPSession();
    const r = await cdp.send('LP.getMarkdown', sel ? { selector: sel } : {});
    if (r && (r.markdown ?? r.result)) return r.markdown ?? r.result;
  } catch {
    // LP 域参数不匹配时回退 innerText
  }
  return page.evaluate((s) => {
    const el = s ? document.querySelector(s) : document.body;
    return el ? el.innerText : '';
  }, sel);
}

function out(obj) {
  console.log(typeof obj === 'string' ? obj : JSON.stringify(obj, null, 2));
}

(async () => {
  const { browser, page } = await attach();
  try {
    switch (cmd) {
      case 'open': {
        const url = rest[0];
        if (!url) throw new Error('open 缺少 URL');
        await page.goto(url, { waitUntil: 'load', timeout: 30000 });
        await sleep(1200); // 留出 load 之后 XHR/渲染的沉降时间
        out({ url: page.url(), title: await page.title() });
        break;
      }
      case 'md':
        out(await pageMarkdown(page, rest[0]));
        break;
      case 'text':
        out(await page.evaluate(() => (document.body ? document.body.innerText : '')));
        break;
      case 'eval':
        out(await page.evaluate(rest.join(' ')));
        break;
      case 'click':
        await page.click(rest[0]);
        out({ clicked: rest[0], url: page.url() });
        break;
      case 'fill':
        await page.$eval(
          rest[0],
          (el, v) => {
            el.value = v;
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
          },
          rest.slice(1).join(' ')
        );
        out({ filled: rest[0] });
        break;
      case 'cookies':
        out(await page.cookies());
        break;
      case 'screenshot':
        await page.screenshot({ path: rest[0] });
        out({ screenshot: rest[0] });
        break;
      case 'close':
        await page.close();
        out({ closed: true });
        break;
      default:
        throw new Error(`未知命令: ${cmd}（可用: open/md/text/eval/click/fill/cookies/screenshot/close）`);
    }
  } catch (e) {
    console.error(`BROWSE_ERROR=${e.message}`);
    process.exitCode = 1;
  } finally {
    await browser.disconnect();
  }
})();
