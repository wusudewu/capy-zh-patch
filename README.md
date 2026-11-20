# Capy 中文补丁 · Windows 简体中文

> 汉化：**wusudewu**　·　非官方补丁，与 Scrapybara, Inc. 无关

给 Capy 桌面版（Electron）加上简体中文界面。不改动 `app.asar`，不注入网络请求，随时可一键还原。

参考 [freebuff-zh-patch](https://github.com/Kfowever/freebuff-zh-patch) 的做法：只替换应用的启动界面文件（`resources\renderer\_shell.html`），再挂一个运行时 DOM 汉化脚本。

## 安装要求

- Windows x64
- Capy 桌面版 **0.9.2**（其他版本会被拒绝安装，避免改错文件）

## 三步安装

1. 退出 Capy，确认托盘图标里也没有残留实例。
2. 双击 **安装.cmd**。
3. 重新打开 Capy，界面就是简体中文。

不需要管理员权限，也不会开机自启或常驻后台。

## 三个入口

| 文件 | 作用 |
| --- | --- |
| **安装.cmd** | 安装或覆盖更新补丁 |
| **恢复英文.cmd** | 还原英文界面，并删除汉化脚本 |
| **查看状态.cmd** | 查看是否已安装、补丁版本、备份位置 |

完整性核对（可选，命令行）：

```
powershell -ExecutionPolicy Bypass -File .\CapyZhPatch.ps1 -Action Verify
```

## 工作原理

Capy 桌面版的界面是打包在 `resources\renderer` 里的前端资源，由内置的 `capy://app` 协议按需读取。补丁只做两件事：

1. 把 `capy-zh-cn.js` 复制进 `resources\renderer`；
2. 在 `_shell.html` 的 `</body>` 前插入一行 `<script src="/capy-zh-cn.js" defer></script>`（带 `capy-zh-patch` 标记，便于精确还原）。

汉化脚本在页面加载后遍历 DOM，用约 11000 条词条把界面文案替换成中文，并用 MutationObserver 处理后续渲染出来的内容。它只匹配词表中已有的界面字符串，因此：

- 用户输入、消息正文、代码块、终端输出、文件内容都保持原文；
- 品牌名、模型名、编程语言名、快捷键、命令、路径保持英文。

备份和安装记录在 `%LOCALAPPDATA%\CapyZhPatch`，安装前会校验哈希，还原时按记录回滚。

## 两个开关

- **临时停用**：在 Capy 窗口的开发者工具里执行 `__capyZh.setEnabled(false)`，刷新后恢复英文；`setEnabled(true)` 再打开。设置存在 localStorage 的 `capy-zh:disabled`。
- **局部排除**：给任意元素加 `data-capy-zh-skip` 属性，该元素及其子树的文字不会被汉化。

## 已知限制

- Capy 每次更新会覆盖界面文件，补丁随之失效；更新后重跑一次 **安装.cmd** 即可（版本号变了会被拦下，说明需要适配）。
- 覆盖的是主界面窗口（Scout 预览、内置浏览器里的网页不受影响）。
- 词表从应用自带的前端资源里全量提取（按 JSX 属性位置精确定位界面文案），并补充了插件目录等运行时文案。已验证：登录、注册、首页、404 四个页面用无头浏览器渲染后，界面上除品牌与插件名外没有残留英文。用户输入、用户名、项目名、第三方返回的内容保持原文。
- 冲突检查：如果 `_shell.html` 被其他工具改过，安装会中止，不会覆盖别人的改动。

## 更新记录

见 [CHANGELOG.md](CHANGELOG.md)。当前版本 **1.0.1**。

## 文件清单

```
安装.cmd              安装 / 更新
恢复英文.cmd          还原英文
查看状态.cmd          查看状态
CapyZhPatch.ps1       安装器本体（PowerShell）
capy-zh-cn.js         运行时汉化脚本（词表 + DOM 引擎）
CHANGELOG.md          更新记录
tests/                可复现的测试（用法见 tests/README.md）
```

## 免责声明

非官方补丁。Capy 及其商标、软件版权归 Scrapybara, Inc. 所有。汉化脚本不联网、不读取账号或会话数据。
