# Capy 桌面版简体中文补丁 · 作者：wusudewu
[CmdletBinding()]
param(
    [ValidateSet('Install', 'Restore', 'Status', 'Verify')]
    [string]$Action = 'Install',

    [string]$AppDir = '',

    [string]$StateDir = '',

    [switch]$Force,


    [switch]$CloseRunningApp,

    [string]$LibraryDir = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

$PatchVersion = '1.1.0'
$SupportedAppVersions = @('0.10.0.0', '0.10.0', '0.9.2.0', '0.9.2')
$AssetName = 'capy-zh-cn.js'
$MarkerStart = '<!-- capy-zh-patch:start -->'
$MarkerEnd = '<!-- capy-zh-patch:end -->'
$Snippet = $MarkerStart + '<script src="/' + $AssetName + '" defer></script>' + $MarkerEnd
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Write-Info {
    param([string]$Text)
    Write-Host $Text
}

function Write-Step {
    param([string]$Text)
    Write-Host ('· ' + $Text)
}

function Write-Ok {
    param([string]$Text)
    Write-Host ('✓ ' + $Text) -ForegroundColor Green
}

function Write-Warn {
    param([string]$Text)
    Write-Host ('! ' + $Text) -ForegroundColor Yellow
}

function Get-Sha256 {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    $stream = [IO.File]::OpenRead($Path)
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try {
        $hash = $algorithm.ComputeHash($stream)
        return (($hash | ForEach-Object { $_.ToString('x2') }) -join '')
    } finally {
        $algorithm.Dispose()
        $stream.Dispose()
    }
}

function Get-AppVersion {
    param([Parameter(Mandatory = $true)][string]$ExePath)
    return [Diagnostics.FileVersionInfo]::GetVersionInfo($ExePath).ProductVersion
}

function Find-CapyDirectory {
    $candidates = @()
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Capy') }
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Capy') }
    if ($env:ProgramFiles) { $candidates += (Join-Path $env:ProgramFiles 'Capy') }
    if (${env:ProgramFiles(x86)}) { $candidates += (Join-Path ${env:ProgramFiles(x86)} 'Capy') }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'Capy.exe') -PathType Leaf) { return $candidate }
    }
    throw '找不到 Capy 桌面版安装目录。请确认已安装 Capy，或用 -AppDir 指定安装目录。'
}

function Get-CapyProcesses {
    return @(Get-Process -Name 'Capy' -ErrorAction SilentlyContinue)
}

function Confirm-CapyRunning {
    param([string]$ExePath)
    $processes = Get-CapyProcesses
    if ($processes.Count -eq 0) { return $true }

    if ($CloseRunningApp) {
        foreach ($process in $processes) {
            if ([string]::IsNullOrWhiteSpace($process.Path) -or
                -not $process.Path.Equals($ExePath, [StringComparison]::OrdinalIgnoreCase)) {
                throw '另一个位置的 Capy 正在运行。请先手动退出，再重新运行本工具。'
            }
        }
        Write-Step '正在关闭 Capy…'
        foreach ($process in $processes) {
            try { $null = $process.CloseMainWindow() } catch { }
        }
        $deadline = (Get-Date).AddSeconds(30)
        while ((Get-Date) -lt $deadline) {
            if ((Get-CapyProcesses).Count -eq 0) { return $true }
            Start-Sleep -Milliseconds 400
        }
    }

    Write-Warn 'Capy 正在运行。补丁只改动界面文件，不会损坏应用；请在本工具结束后重启 Capy 以生效。'
    return $false
}

function Get-ShellState {
    param([string]$ShellPath, [string]$AssetPath)
    $text = [IO.File]::ReadAllText($ShellPath)
    $state = 'pristine'
    if ($text.Contains($MarkerStart) -or $text.Contains($AssetName)) { $state = 'patched' }
    return [PSCustomObject]@{
        Text = $text
        State = $state
        Hash = Get-Sha256 -Path $ShellPath
        AssetExists = (Test-Path -LiteralPath $AssetPath -PathType Leaf)
    }
}

function New-ShellWithPatch {
    param([string]$Text)
    $index = $Text.LastIndexOf('</body>', [StringComparison]::OrdinalIgnoreCase)
    if ($index -ge 0) {
        return $Text.Substring(0, $index) + $Snippet + $Text.Substring($index)
    }
    $index = $Text.LastIndexOf('</html>', [StringComparison]::OrdinalIgnoreCase)
    if ($index -ge 0) {
        return $Text.Substring(0, $index) + $Snippet + $Text.Substring($index)
    }
    return $Text + $Snippet
}

function Remove-ShellPatch {
    param([string]$Text)
    while ($true) {
        $start = $Text.IndexOf($MarkerStart, [StringComparison]::Ordinal)
        if ($start -lt 0) { break }
        $end = $Text.IndexOf($MarkerEnd, $start, [StringComparison]::Ordinal)
        if ($end -lt 0) {
            $Text = $Text.Remove($start)
            break
        }
        $end += $MarkerEnd.Length
        $Text = $Text.Remove($start, $end - $start)
    }
    return $Text
}

function Write-JsonFile {
    param([string]$Path, $Object)
    $json = $Object | ConvertTo-Json -Depth 6
    [IO.File]::WriteAllText($Path, $json, $Utf8NoBom)
}

# ---------------------------------------------------------------- 安装

function Invoke-Install {
    param([string]$AppDirectory, [string]$StateDirectory, [string]$Assets)

    $exePath = Join-Path $AppDirectory 'Capy.exe'
    if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
        throw "在 $AppDirectory 中找不到 Capy.exe。"
    }
    $rendererDir = Join-Path $AppDirectory 'resources\renderer'
    $shellPath = Join-Path $rendererDir '_shell.html'
    $assetPath = Join-Path $rendererDir $AssetName
    $sourceAsset = Join-Path $Assets $AssetName

    foreach ($required in @($rendererDir, $shellPath)) {
        if (-not (Test-Path -LiteralPath $required)) {
            throw "Capy 的界面文件缺失：$required。该版本结构可能已变化，请报告问题。"
        }
    }
    if (-not (Test-Path -LiteralPath $sourceAsset -PathType Leaf)) {
        throw "补丁文件不完整：缺少 $sourceAsset。请重新完整解压安装包。"
    }

    $appVersion = Get-AppVersion -ExePath $exePath
    Write-Info ("检测到 Capy 版本：" + $appVersion)
    if ($SupportedAppVersions -notcontains $appVersion -and -not $Force) {
        Write-Warn "本补丁针对 Capy $($SupportedAppVersions -join ' / ')，当前版本是 $appVersion。"
        throw "版本不匹配，已停止安装以避免破坏应用。确认无误时可加 -Force 强制安装。"
    }

    $null = Confirm-CapyRunning -ExePath $exePath

    $state = Get-ShellState -ShellPath $shellPath -AssetPath $assetPath
    $backupRoot = Join-Path $StateDirectory 'backup'
    $backupDir = Join-Path $backupRoot $appVersion
    $backupShell = Join-Path $backupDir '_shell.html'
    $manifestPath = Join-Path $StateDirectory 'manifest.json'
    $assetHash = Get-Sha256 -Path $sourceAsset

    if ($state.State -eq 'patched') {
        Write-Step '检测到已安装中文补丁，正在覆盖更新…'
        if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
            $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
            $originalHash = $manifest.shell.originalHash
            if (Test-Path -LiteralPath $backupShell -PathType Leaf) {
                if ((Get-Sha256 -Path $backupShell) -ne $originalHash) {
                    throw '备份文件的哈希与安装记录不符。已停止安装以保护原始文件。'
                }
            } else {
                throw "找不到原始备份：$backupShell。已停止安装以保护原始文件。"
            }
        } else {
            $fallback = Join-Path $env:LOCALAPPDATA 'CapyZhPatch'
            if ($fallback -ne $StateDirectory -and (Test-Path -LiteralPath (Join-Path $fallback 'manifest.json') -PathType Leaf)) {
                throw ('当前状态目录没有安装记录，但默认目录里有：' + $fallback + '。请改用该目录重新运行。')
            }
            throw '界面文件已是补丁状态，但在该状态目录里找不到安装记录。请用安装时使用的 -StateDir 重试，或重新安装 Capy。'
        }
    } else {
        if ($state.Hash -ne $null -and (Test-Path -LiteralPath $backupShell -PathType Leaf)) {
            $previous = Get-Sha256 -Path $backupShell
            if ($previous -ne $state.Hash) {
                throw '当前界面文件与已有备份不一致，可能被其他工具修改过。已停止安装以保护原文件。'
            }
        }
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        Copy-Item -LiteralPath $shellPath -Destination $backupShell -Force
        if ((Get-Sha256 -Path $backupShell) -ne $state.Hash) {
            throw '备份校验失败。已停止安装以确保安全。'
        }
        Write-Step "已备份原始界面文件：$backupShell"
    }

    $patchedText = New-ShellWithPatch -Text (Remove-ShellPatch -Text $state.Text)
    $tempShell = Join-Path $rendererDir ('.capy-zh-shell-' + [guid]::NewGuid().ToString('N') + '.tmp')
    [IO.File]::WriteAllText($tempShell, $patchedText, $Utf8NoBom)
    if (-not [IO.File]::ReadAllText($tempShell).Contains($AssetName)) {
        Remove-Item -LiteralPath $tempShell -Force -ErrorAction SilentlyContinue
        throw '补丁写入校验失败，未修改原文件。'
    }

    Copy-Item -LiteralPath $sourceAsset -Destination $assetPath -Force
    if ((Get-Sha256 -Path $assetPath) -ne $assetHash) {
        Remove-Item -LiteralPath $tempShell -Force -ErrorAction SilentlyContinue
        throw '汉化脚本复制校验失败，未修改原文件。'
    }

    try {
        Move-Item -LiteralPath $tempShell -Destination $shellPath -Force -ErrorAction Stop
    } catch {
        Remove-Item -LiteralPath $tempShell -Force -ErrorAction SilentlyContinue
        throw ('写入界面文件失败：文件可能被占用或没有权限。请完全退出 Capy 后重试，或检查安装目录权限。原因：' + $_.Exception.Message)
    }
    if (-not [IO.File]::ReadAllText($shellPath).Contains($AssetName)) {
        throw '界面文件写入失败，请重新运行安装并恢复英文。'
    }

    $manifest = [ordered]@{
        schemaVersion = 1
        patchVersion = $PatchVersion
        appVersion = $appVersion
        appDir = $AppDirectory
        installedAt = (Get-Date).ToString('s')
        shell = [ordered]@{
            path = $shellPath
            originalHash = (Get-Sha256 -Path $backupShell)
            patchedHash = (Get-Sha256 -Path $shellPath)
        }
        asset = [ordered]@{
            name = $AssetName
            path = $assetPath
            hash = $assetHash
        }
    }
    New-Item -ItemType Directory -Path $StateDirectory -Force | Out-Null
    Write-JsonFile -Path $manifestPath -Object $manifest

    Write-Ok "中文补丁已安装（补丁 $PatchVersion，Capy $appVersion）。"
    Write-Info '请重新打开 Capy，界面即为简体中文。'
    Write-Info ("如需还原：双击 恢复英文.cmd（安装记录：$manifestPath）")
    return 0
}

# ---------------------------------------------------------------- 还原

function Invoke-Restore {
    param([string]$AppDirectory, [string]$StateDirectory)

    $exePath = Join-Path $AppDirectory 'Capy.exe'
    $rendererDir = Join-Path $AppDirectory 'resources\renderer'
    $shellPath = Join-Path $rendererDir '_shell.html'
    $assetPath = Join-Path $rendererDir $AssetName
    $manifestPath = Join-Path $StateDirectory 'manifest.json'

    if (-not (Test-Path -LiteralPath $shellPath -PathType Leaf)) {
        throw "找不到界面文件：$shellPath"
    }

    $null = Confirm-CapyRunning -ExePath $exePath

    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        $stateWithoutManifest = Get-ShellState -ShellPath $shellPath -AssetPath $assetPath
        if ($stateWithoutManifest.State -eq 'pristine') {
            Write-Ok '当前没有安装中文补丁，界面已是英文。'
            if ($stateWithoutManifest.AssetExists) {
                Remove-Item -LiteralPath $assetPath -Force
                Write-Step '已清理残留的汉化脚本。'
            }
            return 0
        }
        throw '界面文件似乎打过补丁，但找不到安装记录。请重新安装 Capy 以恢复原始界面。'
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $backupShell = Join-Path (Join-Path (Join-Path $StateDirectory 'backup') $manifest.appVersion) '_shell.html'
    $currentHash = Get-Sha256 -Path $shellPath

    if ($currentHash -eq $manifest.shell.originalHash) {
        Write-Ok '界面已是原始英文状态。'
    } else {
        if ($currentHash -ne $manifest.shell.patchedHash) {
            throw '界面文件和安装记录不一致（可能被其他工具修改过或 Capy 已更新）。为安全起见未做改动，请重新安装 Capy。'
        }
        if (-not (Test-Path -LiteralPath $backupShell -PathType Leaf)) {
            throw "找不到原始备份：$backupShell。请重新安装 Capy 以恢复原始界面。"
        }
        if ((Get-Sha256 -Path $backupShell) -ne $manifest.shell.originalHash) {
            throw '备份文件校验失败。为安全起见未做改动，请重新安装 Capy。'
        }
        $tempShell = Join-Path $rendererDir ('.capy-zh-restore-' + [guid]::NewGuid().ToString('N') + '.tmp')
        Copy-Item -LiteralPath $backupShell -Destination $tempShell -Force
        try {
            Move-Item -LiteralPath $tempShell -Destination $shellPath -Force -ErrorAction Stop
        } catch {
            Remove-Item -LiteralPath $tempShell -Force -ErrorAction SilentlyContinue
            throw ('还原界面文件失败：文件可能被占用或没有权限。请完全退出 Capy 后重试。原因：' + $_.Exception.Message)
        }
        if ((Get-Sha256 -Path $shellPath) -ne $manifest.shell.originalHash) {
            throw '还原校验失败，请重新运行还原或重新安装 Capy。'
        }
        Write-Ok '界面文件已还原为英文。'
    }

    if (Test-Path -LiteralPath $assetPath -PathType Leaf) {
        Remove-Item -LiteralPath $assetPath -Force
        Write-Step '已移除汉化脚本。'
    }
    Remove-Item -LiteralPath $manifestPath -Force -ErrorAction SilentlyContinue

    $versionBackup = Join-Path (Join-Path $StateDirectory 'backup') $manifest.appVersion
    if (Test-Path -LiteralPath $versionBackup) {
        Remove-Item -LiteralPath $versionBackup -Recurse -Force -ErrorAction SilentlyContinue
    }
    $backupRoot = Join-Path $StateDirectory 'backup'
    if ((Test-Path -LiteralPath $backupRoot) -and -not (Get-ChildItem -LiteralPath $backupRoot -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $backupRoot -Force -ErrorAction SilentlyContinue
    }
    if ((Test-Path -LiteralPath $StateDirectory) -and -not (Get-ChildItem -LiteralPath $StateDirectory -Force | Select-Object -First 1)) {
        Remove-Item -LiteralPath $StateDirectory -Force -ErrorAction SilentlyContinue
    }
    Write-Step '已清理备份与安装记录。'

    Write-Info '请重新打开 Capy。'
    return 0
}

# ---------------------------------------------------------------- 状态

function Invoke-Verify {
    param([string]$AppDirectory, [string]$StateDirectory, [string]$Assets)

    $rendererDir = Join-Path $AppDirectory 'resources\renderer'
    $shellPath = Join-Path $rendererDir '_shell.html'
    $assetPath = Join-Path $rendererDir $AssetName
    $manifestPath = Join-Path $StateDirectory 'manifest.json'
    $problems = @()
    $checks = @()

    Write-Info 'Capy 中文补丁 · 完整性核对'

    if (-not (Test-Path -LiteralPath $shellPath -PathType Leaf)) {
        Write-Warn '找不到界面文件。'
        return 1
    }
    $text = [IO.File]::ReadAllText($shellPath)
    $markers = ([regex]::Matches($text, [regex]::Escape($MarkerStart))).Count

    if ($markers -eq 1) { $checks += '界面文件补丁标记：1 处（正确）' } else { $problems += "界面文件补丁标记数量异常：$markers 处" }

    if (Test-Path -LiteralPath $assetPath -PathType Leaf) {
        $checks += ('汉化脚本存在：' + [math]::Round((Get-Item -LiteralPath $assetPath).Length / 1KB, 1) + ' KB')
    } else {
        $problems += '汉化脚本缺失'
    }

    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        $backupShell = Join-Path (Join-Path (Join-Path $StateDirectory 'backup') $manifest.appVersion) '_shell.html'
        if ((Get-Sha256 -Path $shellPath) -eq $manifest.shell.patchedHash) { $checks += '界面文件哈希与安装记录一致' } else { $problems += '界面文件哈希与安装记录不一致（可能被其他工具修改）' }
        if ((Test-Path -LiteralPath $backupShell -PathType Leaf) -and (Get-Sha256 -Path $backupShell) -eq $manifest.shell.originalHash) {
            $checks += '原始界面备份可用（可随时还原）'
        } else {
            $problems += '原始界面备份缺失或损坏'
        }
        if ((Test-Path -LiteralPath $assetPath -PathType Leaf) -and (Get-Sha256 -Path $assetPath) -eq $manifest.asset.hash) {
            $checks += '汉化脚本哈希与安装记录一致'
        } else {
            $problems += '汉化脚本被改动或版本不符（建议重新运行 安装.cmd）'
        }
        if ($Assets) {
            $localPatch = Join-Path $Assets $AssetName
            if (Test-Path -LiteralPath $localPatch -PathType Leaf) {
                if ((Get-Sha256 -Path $localPatch) -ne (Get-Sha256 -Path $assetPath)) {
                    $problems += '目录里的补丁文件比已安装的新，运行 安装.cmd 可更新'
                } else {
                    $checks += '已安装版本与目录中的补丁文件一致'
                }
            }
        }
        if ($currentVersionDetected = (Get-AppVersion -ExePath (Join-Path $AppDirectory 'Capy.exe'))) {
            if ($currentVersionDetected -eq $manifest.appVersion) { $checks += "适配版本一致：Capy $currentVersionDetected" }
            else { $problems += "Capy 已从 $($manifest.appVersion) 变为 $currentVersionDetected，需要重新安装补丁" }
        }
    } elseif ($markers -eq 0 -and -not (Test-Path -LiteralPath $assetPath -PathType Leaf)) {
        Write-Info '当前未安装中文补丁，界面为原始英文。'
        return 0
    } else {
        $problems += '没有安装记录，但界面文件或脚本仍处于补丁状态（建议重新安装或重新安装 Capy）'
    }

    foreach ($check in $checks) { Write-Ok $check }
    foreach ($problem in $problems) { Write-Warn $problem }

    if ($problems.Count -eq 0) {
        Write-Ok '核对通过：补丁完整、备份可用。'
        return 0
    }
    Write-Warn "发现 $($problems.Count) 个问题。"
    return 1
}

function Invoke-Status {
    param([string]$AppDirectory, [string]$StateDirectory)

    $exePath = Join-Path $AppDirectory 'Capy.exe'
    $rendererDir = Join-Path $AppDirectory 'resources\renderer'
    $shellPath = Join-Path $rendererDir '_shell.html'
    $assetPath = Join-Path $rendererDir $AssetName
    $manifestPath = Join-Path $StateDirectory 'manifest.json'

    Write-Info 'Capy 中文补丁 · 状态'
    Write-Info ('安装目录：' + $AppDirectory)
    $currentVersion = $null
    if (Test-Path -LiteralPath $exePath -PathType Leaf) {
        $currentVersion = Get-AppVersion -ExePath $exePath
        Write-Info ('Capy 版本：' + $currentVersion)
    } else {
        Write-Warn 'Capy.exe 不存在，安装目录可能不正确。'
    }

    if (-not (Test-Path -LiteralPath $shellPath -PathType Leaf)) {
        Write-Warn '找不到界面文件，无法判断补丁状态。'
        return 1
    }

    $state = Get-ShellState -ShellPath $shellPath -AssetPath $assetPath
    $running = @(Get-Process -Name 'Capy' -ErrorAction SilentlyContinue).Count -gt 0

    if ($state.State -eq 'patched') {
        Write-Ok '中文补丁：已安装'
    } else {
        Write-Info '中文补丁：未安装（界面为英文）'
    }
    Write-Info ('汉化脚本：' + $(if ($state.AssetExists) { '存在' } else { '不存在' }))
    Write-Info ('Capy 进程：' + $(if ($running) { '正在运行' } else { '未运行' }))

    if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
        $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
        Write-Info ('补丁版本：' + $manifest.patchVersion)
        Write-Info ('安装时间：' + $manifest.installedAt)
        Write-Info ('安装时 Capy 版本：' + $manifest.appVersion)
        if ($currentVersion -and $currentVersion -ne $manifest.appVersion) {
            Write-Warn 'Capy 已更新；补丁会被覆盖，请重新运行 安装.cmd 适配新版本。'
        }
        $backupShell = Join-Path (Join-Path (Join-Path $StateDirectory 'backup') $manifest.appVersion) '_shell.html'
        if (Test-Path -LiteralPath $backupShell -PathType Leaf) {
            Write-Info ('原始界面备份：' + $backupShell)
        } else {
            Write-Warn '原始界面备份缺失，无法还原，请重新安装 Capy。'
        }
    } else {
        Write-Info '尚无安装记录。'
    }
    return 0
}

# ---------------------------------------------------------------- 入口

$resolvedAppDir = $AppDir
if ([string]::IsNullOrWhiteSpace($resolvedAppDir)) {
    try { $resolvedAppDir = Find-CapyDirectory } catch { $resolvedAppDir = '' }
}
if ([string]::IsNullOrWhiteSpace($resolvedAppDir)) {
    Write-Warn '找不到 Capy 安装目录。请确认已安装 Capy 桌面版 0.9.2。'
    exit 1
}
$resolvedAppDir = [IO.Path]::GetFullPath($resolvedAppDir)

$resolvedStateDir = $StateDir
if ([string]::IsNullOrWhiteSpace($resolvedStateDir)) {
    $resolvedStateDir = Join-Path $env:LOCALAPPDATA 'CapyZhPatch'
}
$resolvedStateDir = [IO.Path]::GetFullPath($resolvedStateDir)

$resolvedLibrary = $LibraryDir
if ([string]::IsNullOrWhiteSpace($resolvedLibrary)) {
    $resolvedLibrary = $PSScriptRoot
}

try {
    switch ($Action) {
        'Install' { $code = Invoke-Install -AppDirectory $resolvedAppDir -StateDirectory $resolvedStateDir -Assets $resolvedLibrary }
        'Restore' { $code = Invoke-Restore -AppDirectory $resolvedAppDir -StateDirectory $resolvedStateDir }
        'Status' { $code = Invoke-Status -AppDirectory $resolvedAppDir -StateDirectory $resolvedStateDir }
        'Verify' { $code = Invoke-Verify -AppDirectory $resolvedAppDir -StateDirectory $resolvedStateDir -Assets $resolvedLibrary }
    }
} catch {
    Write-Warn $_.Exception.Message
    exit 1
}

exit $code

