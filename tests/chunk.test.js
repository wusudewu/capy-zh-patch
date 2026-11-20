const fs = require('fs')
const { JSDOM } = require('jsdom')
const script = fs.readFileSync(require('path').join(__dirname, '..', 'capy-zh-cn.js'), 'utf8')
let html = '<body><main>'
for (let i = 0; i < 900; i += 1) html += '<div><span>Thread options</span><span>Copy link</span></div>'
html += '</main></body>'
const dom = new JSDOM(html, { runScripts: 'dangerously' })
dom.window.eval(script)
setTimeout(() => {
  const n = (dom.window.document.body.textContent.match(/会话选项/g) || []).length
  console.log('elements:', 900 * 3, '| translated after 1.5s:', n, '/ 900')
}, 1500)
