const fs = require('fs')
const { JSDOM } = require('jsdom')
const script = fs.readFileSync(require('path').join(__dirname, '..', 'capy-zh-cn.js'), 'utf8')

const cases = [
  ['dollar signs', '<span>Cost is $& and $1 literal</span>', (t) => !/undefined/.test(t)],
  ['placeholder literal', '<span>Removes {0} from your themes</span>', (t) => typeof t === 'string'],
  ['very long text', '<span>' + 'Settings '.repeat(1500) + '</span>', () => true],
  ['nested prefix', '<span>' + 'Waiting for '.repeat(50) + 'github</span>', (t) => t.length > 0],
  ['whitespace only', '<span>   </span>', (t) => t === '   '],
  ['empty attr', '<input placeholder="" />', () => true],
  ['script tag', '<script>var x = "Settings"</script><span>Settings</span>', (t) => true],
  ['code block', '<pre><code>Settings</code></pre>', (t) => t.includes('Settings')],
]
let failed = 0
for (const [name, html, check] of cases) {
  const dom = new JSDOM('<body>' + html + '</body>', { runScripts: 'dangerously' })
  let error = null
  try { dom.window.eval(script) } catch (e) { error = e }
  const text = dom.window.document.body.textContent
  const ok = !error && check(text)
  if (!ok) failed += 1
  console.log((ok ? 'PASS ' : 'FAIL ') + name + (error ? '  error=' + error.message : ''))
}
console.log('failed:', failed)
process.exit(failed ? 1 : 0)
