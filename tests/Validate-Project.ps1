$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'src/ApkStart-Hebrew.ps1'
$dict = Join-Path $root 'translations/he-IL.json'
$launcher = Join-Path $root 'Run-ApkStart-Hebrew.cmd'
$appAllowPath = Join-Path $root 'translations/app-js-allowlist.json'
$manualAllowPath = Join-Path $root 'translations/manual-allowlist.json'

foreach ($path in @($script, $dict, $launcher, $appAllowPath, $manualAllowPath)) {
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

if ($source -notmatch "\$mainAllow=@\('还没有安装应用'.*'启动失败：'\)") {
    throw 'Main-process translations must remain restricted to the reviewed UI allowlist.'
}


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
