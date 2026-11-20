/*
 * 浏览器集成测试：用真实 Chrome 加载补丁后的界面，检查页面错误与残留英文。
 *
 * 前置条件：
 *   1. 本机已安装 Capy 桌面版（默认 %LOCALAPPDATA%\Programs\Capy\resources\renderer）
 *   2. 已执行 npm install（jsdom、puppeteer-core）
 *   3. 已安装 Chrome；非默认路径时设置环境变量 CHROME_PATH
 *
 * 运行：node integration.test.js
 */
const http = require('http')
const fs = require('fs')
const path = require('path')
const puppeteer = require('puppeteer-core')

const RENDERER = process.env.CAPY_RENDERER
  || path.join(process.env.LOCALAPPDATA || '', 'Programs', 'Capy', 'resources', 'renderer')
const CHROME = process.env.CHROME_PATH || 'C:/Program Files/Google/Chrome/Application/chrome.exe'
const PORT = 8794

const MIME = {
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.html': 'text/html; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.woff2': 'font/woff2',
  '.wasm': 'application/wasm',
}

function startServer(root) {
  const server = http.createServer((req, res) => {
    const clean = decodeURIComponent(req.url.split('?')[0])
    if (path.extname(clean) === '') {
      const shell = fs.readFileSync(path.join(root, '_shell.html'))
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' })
      res.end(shell)
      return
    }
    const file = path.join(root, clean)
    if (!file.startsWith(root) || !fs.existsSync(file)) {
      res.writeHead(404)
      res.end('not found')
      return
    }
    res.writeHead(200, { 'Content-Type': MIME[path.extname(file).toLowerCase()] || 'application/octet-stream' })
    res.end(fs.readFileSync(file))
  })
  return new Promise((resolve) => server.listen(PORT, '127.0.0.1', () => resolve(server)))
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms))

;(async () => {
  if (!fs.existsSync(path.join(RENDERER, '_shell.html'))) {
    console.log('找不到 Capy 界面文件：' + RENDERER)
    process.exit(2)
  }
  const server = await startServer(RENDERER)
  const browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    args: ['--no-first-run', '--disable-gpu'],
    defaultViewport: { width: 1440, height: 1000 },
  })

  const page = await browser.newPage()
  const errors = []
  page.on('pageerror', (e) => errors.push(String(e.message || e)))

  const routes = ['/', '/sign-in', '/sign-up', '/explore']
  const rows = []
  for (const route of routes) {
    await page.goto(`http://127.0.0.1:${PORT}${route}`, { waitUntil: 'networkidle2', timeout: 45000 })
    await sleep(2000)
    const info = await page.evaluate(() => ({
      title: document.title,
      version: (window.__capyZh && window.__capyZh.version) || null,
      english: (document.body.innerText.match(/[A-Za-z]{4,}/g) || []).length,
    }))
    rows.push({ route, ...info })
  }

  const before = errors.length
  await page.evaluate(() => {
    const link = document.querySelector('a[href*="sign-up"]')
    if (link) link.click()
  })
  await sleep(2000)
  const navErrors = errors.length - before

  await browser.close()
  server.close()

  let ok = true
  for (const r of rows) {
    const good = r.version && /[\u4e00-\u9fff]/.test(r.title)
    if (!good) ok = false
    console.log(`${good ? 'PASS' : 'FAIL'} ${r.route.padEnd(12)} 补丁=${r.version} title=${r.title} 英文词=${r.english}`)
  }
  if (errors.length || navErrors) ok = false
  console.log(`页面错误 ${errors.length} 条，站内跳转新增 ${navErrors} 条`)
  if (errors.length) console.log(errors.slice(0, 3).join('\n'))
  console.log(ok ? 'INTEGRATION PASS' : 'INTEGRATION FAIL')
  process.exit(ok ? 0 : 1)
})()
