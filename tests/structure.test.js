const fs = require('fs')
const { JSDOM } = require('jsdom')
const script = fs.readFileSync(require('path').join(__dirname, '..', 'capy-zh-cn.js'), 'utf8')

const html = `<body>
<div id="a"><span>3</span> <span>threads</span></div>
<div id="b"><span>Show</span> <span>more</span></div>
<button id="c"><svg></svg>Save</button>
<p id="d">Capy runs your coding agents in the cloud.</p>
</body>`

const dom = new JSDOM(html, { runScripts: 'dangerously' })
const { window } = dom
const doc = window.document
const before = ['a', 'b', 'c', 'd'].map((id) => {
  const el = doc.getElementById(id)
  return { id, count: el.childNodes.length, kids: Array.from(el.childNodes) }
})
window.eval(script)

setTimeout(() => {
  let structural = 0
  for (const snap of before) {
    const el = doc.getElementById(snap.id)
    if (el.childNodes.length !== snap.count) structural += 1
    for (const kid of snap.kids) {
      if (!el.contains(kid)) structural += 1
    }
  }
  const text = doc.getElementById('d').textContent
  console.log('结构被改动的元素数:', structural)
  console.log('单节点句子已翻译:', /云端/.test(text))
  console.log('拆分节点保持英文（安全优先）:', doc.getElementById('a').textContent)
  process.exit(structural === 0 ? 0 : 1)
}, 400)
