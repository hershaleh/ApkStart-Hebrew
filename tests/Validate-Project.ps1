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

$appAllow = Get-Content -LiteralPath $appAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($appAllow).Count -lt 150) { throw 'Reviewed app.js allowlist unexpectedly small.' }
foreach ($key in $appAllow) { if ($null -eq $translations.PSObject.Properties[[string]$key]) { throw "app.js allowlist key is missing from dictionary: $key" } }

# Main settings surface: ensure the newly discovered visible labels are translated.
foreach ($key in @('运行时与环境','运行状态','安卓系统设置（不用进安卓桌面）','桌面与应用','文件互通','系统集成','软件更新','关于','当前版本','尚未检查','adb 路径','设备地址','系统镜像（ISO）','内存 (MB，0 = 自动)','CPU 核心（0 = 自动）','空闲回收（分钟，0 = 不回收）','通用兼容镜像（自动管理）','兼容镜像','下载兼容镜像','启动运行时','停止内置虚拟机','媒体音量','字体大小','标准','特大','显示大小','紧凑（省性能）','宽松','安卓原生设置','显示设置','声音设置','语言设置','应用管理','安装后自动创建桌面快捷方式','同时添加到开始菜单','快捷方式目录','本机共享目录','浏览','保存并迁移','安卓内对应目录','关联 .apk 文件','卸载 ApkStart','一键卸载','设置修改后立即生效')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Main settings translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Main settings phrase has no Hebrew translation: $key" }
}
foreach ($key in @('仍失败请把安装包路径换成纯英文短路径（如 D:\\a.apk）。','但应用内的登录态、追剧记录等会丢失')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Installer/recovery translation missing: $key" }
    if ($null -eq @($appAllow | Where-Object { $_ -ceq $key })[0]) { throw "Installer/recovery phrase is not allowlisted: $key" }
}
foreach ($key in @('运行时未就绪','网络不可用','（自动）','（为修复网络重置过安卓数据，点开应用会自动重装）','（未动你的数据）','运行时就绪，点开即用','运行时会按需自动准备','设备 / 端口')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Home/status/context-menu translation missing: $key" }
    if ($null -eq @($appAllow | Where-Object { $_ -ceq $key })[0]) { throw "Home/status/context-menu string is not allowlisted: $key" }
}
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
foreach ($key in @('ApkStart 产品使用手册与问题解决方案','1. 30 秒看懂 ApkStart','2.1 选择适合你的版本','2.2 首次启动会发生什么','3.5 文件互通（Windows ↔ 安卓）','4. 理解三个核心概念（看懂报错的关键）','4.1 运行时 / 系统镜像','4.3 ARM 转译层','5. 遇到问题先做这一步：体检与自动检测','5.1 本机体检 · 自动配置','5.2 自动检测（自动 debug）','5.4 内置使用手册与自动教程','6. 常见问题解决方案','6.1 提示「未启用硬件加速」 / 开机很慢','6.2 安装失败（INSTALL_FAILED_*）','6.3 系统镜像没有 ARM 转译层 / ARM 应用装不上或闪退','6.4 adb 未授权（允许 USB 调试）','6.5 双击图标没反应 / 一直转圈 / 出现带旋转按钮的窗口','6.6 其它启动类问题速查表','6.7 应用没有声音 / 声音很小','6.8 商店版启动失败 / 0xC0000135（DLL 加载失败）','文件名','什么时候选','务必用最新版','三种方式任选：','双击 APK 文件','主界面里选「安装应用」','命令行：','支持 .apks / .xapk 拆分包（自动用 install-multiple ）。装完自动生成桌面 + 开始菜单快捷方式。','全屏 / 窗口模式切换','旋转当前应用横竖屏','自动全屏','强制横屏/竖屏','按键','作用','分类','主要内容')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Manual heading/table translation missing: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Manual heading/table phrase is not allowlisted: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Manual heading/table phrase has no Hebrew translation: $key" }
}
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


# RTL coverage for settings, context menus, dialogs and technical-value exceptions.
foreach ($selector in @(
    '/* Settings, menus and dialogs: preserve',
    '.modal-main{direction:rtl}',
    '.modal-body{direction:rtl;text-align:right}',
    '.set-nav-item{justify-content:flex-start;text-align:right}',
    '.switch-field{direction:rtl;justify-content:space-between}',
    '.ctxmenu .item{direction:rtl;justify-content:flex-start;text-align:right}',
    '.modal-head{direction:rtl}',
    '.modal-foot{direction:rtl}',
    '.welcome-actions{direction:rtl}',
    'input[type=url]',
    'input[type=password]',
    'input[type=number]',
    'input[dir=ltr]',
    'textarea[dir=ltr]',
    'code,pre,kbd,samp',
    '.terminal',
    'input[id*="Path" i]',
    'textarea[id*="Command" i]'
)) {
    if ($source -notmatch [regex]::Escape($selector)) {
        throw "RTL selector or LTR exception missing: $selector"
    }
}
if ($source -notmatch 'direction:ltr;text-align:left;unicode-bidi:plaintext') {
    throw 'Technical fields must explicitly preserve LTR direction.'
}
if ($source -match '(?s)/\* Settings, menus and dialogs: preserve.*?\*\/.*?\*\s*\{\s*direction:\s*rtl') {
    throw 'RTL rules must not apply direction globally to every element.'
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
