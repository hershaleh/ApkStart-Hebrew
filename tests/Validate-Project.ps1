$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'src/ApkStart-Hebrew.ps1'
$dict = Join-Path $root 'translations/he-IL.json'
$launcher = Join-Path $root 'Run-ApkStart-Hebrew.cmd'

foreach ($path in @($script, $dict, $launcher)) {
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

$source = Get-Content -LiteralPath $script -Raw -Encoding UTF8
foreach ($required in @('Get-FileHash','APKSTART-HEBREW:RTL','app.asar','WindowsApps','Backups','PatchedHash','set-nav','modal-head','toolbar-right','toast-wrap','main.js','splash.html','splash.js','splash.css')) {
    if ($source -notmatch [regex]::Escape($required)) {
        throw "Safety or compatibility feature missing: $required"
    }
}


foreach ($key in @('Windows 上的安卓应用运行器','正在准备…','首次使用 · 自动配置中','首次启动 · 本地准备中（无需联网）','选择数据存放目录','选择要安装的 APK','确认清理运行时缓存','重建桌面/开始菜单快捷方式')) {
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

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_.Message }
    throw 'PowerShell syntax validation failed.'
}

Write-Host ("Project validation passed. Hebrew entries: " + $hebrewCount) -ForegroundColor Green
