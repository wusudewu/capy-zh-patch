# 测试

补丁自带一套可复现的测试。分两类：**引擎测试**（纯 Node + jsdom，任何机器都能跑）和**浏览器集成测试**（需要本机装了 Capy 与 Chrome）。

## 准备

```bash
cd tests
npm install jsdom puppeteer-core
```

浏览器集成测试会读取本机 Capy 的界面文件，默认路径 `%LOCALAPPDATA%\Programs\Capy\resources\renderer`；装在别处时用环境变量指定：

```bash
set CAPY_RENDERER=D:\Capy\resources\renderer
set CHROME_PATH=C:\Program Files\Google\Chrome\Application\chrome.exe
```

## 引擎测试（无需 Chrome、无需安装补丁）

| 文件 | 覆盖内容 |
| --- | --- |
| `engine.test.js` | 29 条断言：导航与按钮翻译、占位符、aria-label、标题、计数与相对时间、代码块/输入框不被改写、`data-capy-zh-skip` 生效、输入框 value 翻译 |
| `structure.test.js` | 翻译过程**不改变 DOM 结构**（子节点数量与引用完全一致），这是 1.0.1 修复崩溃的核心保证 |
| `adversarial.test.js` | 8 类异常输入：`$&`、字面占位符、超长文本、深层嵌套前缀、纯空白、空属性、`<script>` 内文本、`<pre><code>` |
| `chunk.test.js` | 大页面分片扫描最终覆盖全部节点 |
| `perf.test.js` | 首屏同步耗时与全量翻译耗时 |

运行：

```bash
node engine.test.js
node structure.test.js
node adversarial.test.js
node chunk.test.js
node perf.test.js
```

## 浏览器集成测试

用真实 Chrome 加载补丁后的界面，检查 4 个路由的标题是否已汉化、补丁版本是否注入、页面是否报错，以及站内跳转是否产生新错误（`removeChild` 那类崩溃就是在这里被抓住的）。

```bash
node integration.test.js
```

输出最后一行是 `INTEGRATION PASS` 或 `INTEGRATION FAIL`。

## 安装器测试

安装器（`CapyZhPatch.ps1`）的测试需要 Windows 与一个已安装的 Capy，属于手动验证，不在本目录：

- `-Action Verify` 的七项完整性核对
- 安装 → 还原 → 再安装的往返，哈希应回到原值
- 篡改 `_shell.html` 后 `Restore` 必须拒绝执行
- 还原后 `%LOCALAPPDATA%\CapyZhPatch` 不留任何文件
