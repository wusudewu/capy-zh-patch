const fs = require('fs')
const path = require('path')
const { JSDOM } = require('jsdom')

const script = fs.readFileSync(path.join(__dirname, '..', 'capy-zh-cn.js'), 'utf8')

const html = `<!DOCTYPE html><html><head><title>Threads | Capy</title></head><body>
<nav aria-label="Sidebar">
  <a href="/threads">Threads</a>
  <a href="/pulls">Pull requests</a>
  <a href="/automations">Automations</a>
  <a href="/drive">Capy Drive</a>
  <a href="/explore">Explore</a>
  <a href="/settings">Settings</a>
  <button aria-label="New thread">New thread</button>
</nav>
<header>
  <button title="Copy link">Copy link</button>
  <button>Share</button>
  <button>Archive thread</button>
  <span>3 threads</span>
  <span>5 minutes ago</span>
  <span>Just now</span>
  <span id="s1">3 <span>threads</span></span>
  <span id="s2">Waiting for <b>github</b></span>
  <span id="s3">12 tokens</span>
  <span id="s4">1h 23m</span>
  <span id="s5">75%</span>
  <div id="host"></div>
  <input id="inputValue" type="submit" value="Save" />
  <span id="t1">3 actions</span>
  <span id="t2">Show 12 more</span>
  <span>Updated 2 hours ago</span>
</header>
<main>
  <h2>Thread options</h2>
  <p>Capy runs your coding agents in the cloud.</p>
  <label>Only specific people</label>
  <label>Everyone</label>
  <div>
    <input id="search" placeholder="Type a command or search threads…" />
    <textarea placeholder="Ask Capy to work on this project"></textarea>
  </div>
  <button>Continue</button>
  <button>Try again</button>
  <button>Delete thread</button>
  <select><option>Default</option><option>Private</option></select>
  <code>New thread</code>
  <pre>Settings
Connected</pre>
  <div contenteditable="true">Draft message here</div>
  <span data-capy-zh-skip>Do not touch</span>
  <div class="toast">Link copied</div>
</main>
<div role="dialog" aria-label="Discard Setup changes?">
  <h3>Discard Setup changes?</h3>
  <button>Cancel</button><button>Discard</button>
</div>
</body></html>`

const dom = new JSDOM(html, { runScripts: 'dangerously', url: 'http://127.0.0.1:8791/_shell.html' })
const { window } = dom
const host = window.document.getElementById('host')
const shadow = host.attachShadow({ mode: 'open' })
shadow.innerHTML = '<span>New thread</span>'
window.eval(script)

setTimeout(() => {
  const text = (sel) => window.document.querySelector(sel)?.textContent
  const all = window.document.body.textContent.replace(/\s+/g, ' ').trim()
  const input = window.document.getElementById('search')
  const textarea = window.document.querySelector('textarea')
  const nav = window.document.querySelector('nav')

  const checks = [
    ['nav Threads', /会话/.test(nav.textContent)],
    ['nav Pull requests', /拉取请求/.test(nav.textContent)],
    ['nav Settings', /设置/.test(nav.textContent)],
    ['aria New thread', /新建会话/.test(nav.querySelector('button').getAttribute('aria-label'))],
    ['title Copy link', /复制链接/.test(window.document.querySelector('[title]').getAttribute('title'))],
    ['count rule', /3 个会话/.test(all)],
    ['minutes rule', /5 分钟前/.test(all)],
    ['just now', /刚刚/.test(all)],
    ['updated rule', /更新于 2 小时前/.test(all)],
    ['sentence', /Capy 在云端运行你的编程智能体/.test(all) || /Capy.*云端.*智能体/.test(all)],
    ['placeholder', /搜索会话/.test(input.placeholder)],
    ['textarea untouched', textarea.placeholder.startsWith('Ask Capy')],
    ['code untouched', text('code') === 'New thread'],
    ['pre untouched', text('pre').includes('Settings')],
    ['contenteditable untouched', /Draft message/.test(all)],
    ['skip attr respected', /Do not touch/.test(all)],
    ['toast', /链接已复制/.test(all)],
    ['dialog title', /放弃环境配置更改/.test(all)],
    ['title tag', /会话/.test(window.document.title)],
    ['split nodes untouched (structure preserved)', window.document.getElementById('s1').children.length === 1],
    ['count noun', window.document.getElementById('s3').textContent === '12 个 Token'],
    ['duration', window.document.getElementById('s4').textContent === '1 小时 23 分钟'],
    ['percent', window.document.getElementById('s5').textContent === '75%'],

    ['prefix rule (single node)', window.document.getElementById('s2').children.length === 1],
    ['no english leak in nav', !/Threads|Settings/.test(nav.textContent)],
  ]

  checks.push(['shadow dom translated', shadow.textContent === '新建会话'])
  checks.push(['template rule 1', window.document.getElementById('t1').textContent === '3 个操作'])
  checks.push(['template rule 2', window.document.getElementById('t2').textContent === '再显示 12 个'])
  checks.push(['input value attr', window.document.getElementById('inputValue').getAttribute('value') === '保存'])
  let failed = 0
  for (const [name, ok] of checks) {
    if (!ok) failed += 1
    console.log((ok ? 'PASS ' : 'FAIL ') + name)
  }
  console.log('\n--- rendered text ---\n' + all)
  console.log('\n--- input placeholder:', input.placeholder)
  console.log('--- title:', window.document.title)
  console.log('--- failed:', failed)
  process.exit(failed ? 1 : 0)
}, 200)
