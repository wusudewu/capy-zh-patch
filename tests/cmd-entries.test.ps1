# 双击入口测试：验证三个 .cmd 能真正跑通（以退出码判定，避免控制台编码差异）
# 用法（在任意目录）：powershell -ExecutionPolicy Bypass -File tests\cmd-entries.test.ps1
# 需要本机已安装 Capy。脚本会依次执行 状态 / 安装 / 还原 / 安装，结束时补丁处于已安装状态。

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$env:CAPY_ZH_NO_PAUSE = '1'
$failed = 0

function Invoke-Entry {
    param([string]$Name)

    $target = Join-Path $root $Name
    if (-not (Test-Path -LiteralPath $target -PathType Leaf)) {
        Write-Host ("FAIL " + $Name + "（找不到文件：$target）")
        $script:failed += 1
        return
    }

    & cmd.exe /c $target > $null 2>&1
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        Write-Host ("PASS " + $Name + " (exit 0)")
    } else {
        Write-Host ("FAIL " + $Name + " (exit " + $code + ")")
        $script:failed += 1
    }
}

Invoke-Entry '查看状态.cmd'
Invoke-Entry '安装.cmd'
Invoke-Entry '恢复英文.cmd'
Invoke-Entry '安装.cmd'

Write-Host ""
if ($failed -eq 0) {
    Write-Host "CMD ENTRY PASS"
    exit 0
}
Write-Host ("CMD ENTRY FAIL: " + $failed + " 项")
exit 1
