$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'src/ApkStart-Hebrew.ps1'
$dict = Join-Path $root 'translations/he-IL.json'
$launcher = Join-Path $root 'Run-ApkStart-Hebrew.cmd'
$appAllowPath = Join-Path $root 'translations/app-js-allowlist.json'
$manualAllowPath = Join-Path $root 'translations/manual-allowlist.json'
$shellAllowPath = Join-Path $root 'translations/shell-ui-allowlist.json'
$mainAllowPath = Join-Path $root 'translations/main-process-allowlist.json'

foreach ($path in @($script, $dict, $launcher, $appAllowPath, $manualAllowPath, $shellAllowPath, $mainAllowPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Missing required project file: $path"
    }
}

$translations = Get-Content -LiteralPath $dict -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($translations.PSObject.Properties | Where-Object { $_.MemberType -eq 'NoteProperty' }).Count -lt 250) {
    throw 'Translation dictionary unexpectedly small.'
}
$hebrewCount = @($translations.PSObject.Properties | Where-Object { $_.Value -match '[\u0590-\u05FF]' }).Count
if ($hebrewCount -lt 200) {
    throw 'Hebrew translation entries are missing.'
}

foreach ($key in @('运行时未就绪','网络不可用','（自动）','（为修复网络重置过安卓数据，点开应用会自动重装）','（未动你的数据）','运行时就绪，点开即用','运行时会按需自动准备','设备 / 端口')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Home/status/context-menu translation missing: $key" }
    if ($null -eq @($appAllow | Where-Object { $_ -ceq $key })[0]) { throw "Home/status/context-menu string is not allowlisted: $key" }
}

$appAllow = Get-Content -LiteralPath $appAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($appAllow).Count -lt 150) { throw 'Reviewed app.js allowlist unexpectedly small.' }
foreach ($key in $appAllow) { if ($null -eq $translations.PSObject.Properties[[string]$key]) { throw "app.js allowlist key is missing from dictionary: $key" } }
$source = Get-Content -LiteralPath $script -Raw -Encoding UTF8
foreach ($required in @('Get-FileHash','APKSTART-HEBREW:RTL','app.asar','WindowsApps','Backups','PatchedHash','set-nav','modal-head','toolbar-right','toast-wrap','main.js','splash.html','splash.js','splash.css','src/core/manual.js','app-js-allowlist.json')) {
    if ($source -notmatch [regex]::Escape($required)) {
        throw "Safety or compatibility feature missing: $required"
    }
}


foreach ($key in @('横屏 / 竖屏（Ctrl+R）','最小化','最大化','关闭','apkstart-产品使用手册与问题解决方案','1-30-秒看懂-apkstart','2-安装与首次启动','6-常见问题解决方案','ADB 未授权','Windows 上的安卓应用运行器','正在准备…','首次使用 · 自动配置中','首次启动 · 本地准备中（无需联网）','选择数据存放目录','选择要安装的 APK','确认清理运行时缓存','重建桌面/开始菜单快捷方式')) {
    if ($null -eq $translations.PSObject.Properties[$key]) {
        throw "Startup translation missing: $key"
    }
}
if ($source -notmatch "'main\.js'.*'splash\.html'.*'splash\.js'.*'splash\.css'") {
    throw 'Electron main-process file is not included in the patch target list.'
}
if ($source -notmatch "splash\.html.*splash\.js.*splash\.css") {
    throw 'Startup splash files are not included in the patch target list.'
}

$mainAllow = Get-Content -LiteralPath $mainAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($mainAllow).Count -lt 20) { throw 'Reviewed main-process allowlist unexpectedly small.' }
foreach ($key in $mainAllow) {
    if ($null -eq $translations.PSObject.Properties[[string]$key]) {
        throw "Main-process allowlist key is missing from dictionary: $key"
    }
}
if ($source -notmatch 'main-process-allowlist\.json' -or $source -notmatch "\$name -eq 'main\.js'") {
    throw 'Main-process translations must remain restricted to the dedicated reviewed allowlist.'
}


$shellAllow = Get-Content -LiteralPath $shellAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($shellAllow).Count -lt 5) { throw 'Reviewed shell UI allowlist unexpectedly small.' }
foreach ($key in $shellAllow) {
    if ($null -eq $translations.PSObject.Properties[[string]$key]) {
        throw "Shell UI allowlist key is missing from dictionary: $key"
    }
}
if ($source -notmatch "shell-ui-allowlist\.json" -or $source -notmatch "\$name -in @\('shell\.html','shell\.js'\)") {
    throw 'Standalone shell translations must use their dedicated reviewed allowlist.'
}
if ($translations.'应用' -ne 'יישום') { throw 'Standalone shell application fallback must use the Hebrew noun for application.' }

$manualAllow = Get-Content -LiteralPath $manualAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($manualAllow).Count -lt 80) { throw 'Reviewed manual allowlist unexpectedly small.' }
foreach ($key in $manualAllow) {
    if ($null -eq $translations.PSObject.Properties[[string]$key]) {
        throw "Manual allowlist key is missing from dictionary: $key"
    }
}
if ($source -notmatch "manual\.html" -or $source -notmatch "manual-allowlist\.json" -or $source.Contains('$files.Add($coreManual)')) {
    throw 'Manual translation must use its dedicated reviewed allowlist.'
}


# Manual body coverage: verify real paragraph-level phrases, not only navigation labels.
foreach ($key in @('本项目为早期版本，作者业余时间维护，开源免费、无广告。遇到问题是正常的，本手册就是为此准备的。','首次启动慢是正常的，属"一次性成本"。之后再用就是秒进。','模拟器要跑得快，需要 CPU 虚拟化加速。Windows 上只有两条路：','如果系统本身也没声音，先去解决 Windows 音频；只有 ApkStart 里的应用没声才按下面查。','按顺序排查')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Manual body translation missing: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Manual body phrase is not allowlisted: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Manual body phrase has no Hebrew translation: $key" }
}
if (@($manualAllow).Count -lt 100) { throw 'Manual allowlist body coverage unexpectedly small.' }

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_.Message }
    throw 'PowerShell syntax validation failed.'
}

Write-Host ("Project validation passed. Hebrew entries: " + $hebrewCount) -ForegroundColor Green

# Translation writes must be staged beside the target and atomically committed.
if ($source -notmatch '\$tempPath=\$file\+''\.apkstart-hebrew\.tmp''') {
    throw 'Translation must stage edits in a temporary file before replacing the original.'
}
if ($source -notmatch '\[IO\.File\]::Replace\(\$tempPath,\$file,\$null,\$true\)') {
    throw 'Translation must atomically replace existing files.'
}
if ($source -notmatch "'style\.css','theme\.css','shell\.css','splash\.css'") {
    throw 'RTL processing must include the startup splash stylesheet.'
}

if ($source -notmatch "src/core/manual\.js.*never patch it as text") {
    throw 'Executable manual routing code must remain excluded from text translation.'
}

if ($source -notmatch "function RtlManual" -or $source -notmatch "APKSTART-HEBREW:MANUAL-RTL" -or $source -notmatch "flex-direction:row-reverse" -or $source -notmatch "blockquote\{border-left:0;border-right") {
    throw 'The built-in manual must receive its dedicated RTL layout.'
}

if ($source -notmatch 'function RtlShell' -or $source -notmatch 'APKSTART-HEBREW:SHELL-RTL' -or $source -notmatch "\$name -eq 'shell\.css'") {
    throw 'Standalone shell stylesheet must receive dedicated RTL alignment.'
}
