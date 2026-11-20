const fs = require('fs')
const { JSDOM } = require('jsdom')
const script = fs.readFileSync(require('path').join(__dirname, '..', 'capy-zh-cn.js'), 'utf8')

const rows = []
for (let i = 0; i < 1200; i += 1) {
  rows.push(
    '<div class="row"><span>Thread options</span><button aria-label="Copy link">Copy link</button>' +
    '<p>Capy runs your coding agents in the cloud.</p>' +
    '<span>' + i + ' messages</span><span>Updated ' + i + ' minutes ago</span></div>'
  )
}
const dom = new JSDOM('<body><main>' + rows.join('') + '</main></body>', { runScripts: 'dangerously' })
const { window } = dom
const t0 = Date.now()
window.eval(script)
const sync = Date.now() - t0
const total = 1200
const started = Date.now()
const check = () => {
  const done = (window.document.body.textContent.match(/会话选项/g) || []).length
  if (done >= total || Date.now() - started > 15000) {
    console.log('elements:', window.document.querySelectorAll('*').length)
    console.log('synchronous eval ms:', sync)
    console.log('fully translated after ms:', Date.now() - started, '| blocks:', done + '/' + total)
    const btn = window.document.querySelector('button')
    console.log('button:', btn.textContent, '| aria:', btn.getAttribute('aria-label'))
  } else {
    setTimeout(check, 20)
  }
}
setTimeout(check, 20)
