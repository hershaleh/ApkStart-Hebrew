#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Fail([string]$message) {
    [Windows.Forms.MessageBox]::Show($message,'הכנת בדיקת ApkStart',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}

$dialog = New-Object Windows.Forms.FolderBrowserDialog
$dialog.Description = 'בחר את תיקיית ApkStart, או את resources/app'
$dialog.ShowNewFolderButton = $false
if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }
$selected = [IO.Path]::GetFullPath($dialog.SelectedPath)

$candidate = $null
foreach ($p in @($selected,(Join-Path $selected 'resources/app'),(Join-Path $selected 'app'))) {
    $ui = Join-Path $p 'src/ui'
    $required = @('index.html','app.js','main.js','style.css','theme.css')
    if (@($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ui $_) -PathType Leaf) }).Count -eq 0) { $candidate = $p; break }
}
if (-not $candidate) { Fail 'לא נמצאו קובצי ApkStart פרוסים בתיקייה שנבחרה. נסה לבחור את תיקיית ההתקנה או resources/app.' }

$packagePath = Join-Path $candidate 'package.json'
if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { Fail 'לא נמצא package.json. לא ניתן לאמת את גרסת ApkStart.' }
try { $package = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail 'קובץ package.json אינו תקין.' }
if ([string]$package.version -ne '0.6.3') { Fail ('נמצאה גרסה '+[string]$package.version+'. הבדיקה המבודדת מיועדת כרגע לגרסה 0.6.3 בלבד.') }

$ui = Join-Path $candidate 'src/ui'
$anchors = @(
    @{Path=(Join-Path $ui 'index.html'); Values=@('id="btnManual"','id="btnSettings"','id="search"')},
    @{Path=(Join-Path $ui 'app.js'); Values=@('function visibleApps','function refreshStatus','const SETTINGS_CATS','const DEBUG_CATS')},
    @{Path=(Join-Path $candidate 'src/main.js'); Values=@("ipcMain.handle('app:info'","ipcMain.handle('apps:list'","ipcMain.handle('settings:get'")}
)
foreach ($check in $anchors) {
    $raw = [IO.File]::ReadAllText($check.Path,[Text.Encoding]::UTF8)
    foreach ($anchor in $check.Values) { if (-not $raw.Contains($anchor)) { Fail ('מבנה ApkStart שונה מהמבנה שנבדק. חסר סימן: '+$anchor+'. לא נוצר עותק בדיקה.') } }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$manager = Join-Path $projectRoot 'src/ApkStart-Hebrew.ps1'
if (-not (Test-Path -LiteralPath $manager -PathType Leaf)) { Fail 'לא נמצא סקריפט ApkStart-Hebrew.ps1. הפעל את הקובץ מתוך תיקיית הפרויקט המלאה.' }

$testBase = Join-Path $env:LOCALAPPDATA 'ApkStart-Hebrew/TestCopies'
New-Item -ItemType Directory -Path $testBase -Force | Out-Null
$testRoot = Join-Path $testBase ('ApkStart-0.6.3-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null

try {
    $relativeFiles = @('package.json','src/main.js','src/core/autodebug.js','src/ui/main.js','src/ui/index.html','src/ui/app.js','src/ui/shell.html','src/ui/shell.js','src/ui/manual.html','src/ui/splash.html','src/ui/splash.js','src/ui/style.css','src/ui/theme.css','src/ui/shell.css','src/ui/splash.css')
    foreach ($relative in $relativeFiles) {
        $source = Join-Path $candidate $relative
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { continue }
        $destination = Join-Path $testRoot $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        [IO.File]::Copy($source,$destination,$false)
    }
    $launch = [Diagnostics.ProcessStartInfo]::new()
    $launch.FileName = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
    $launch.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "'+$manager+'" -InitialTargetPath "'+$testRoot+'"'
    $launch.UseShellExecute = $true
    [Diagnostics.Process]::Start($launch) | Out-Null
    [Windows.Forms.MessageBox]::Show("נוצר עותק בדיקה מבודד:`r`n$testRoot`r`n`r`nחלון הכלי נפתח כשהעותק כבר נבחר.`r`n1. ודא שמופיעה גרסה 0.6.3 והתקנה נתמכת.`r`n2. לחץ על החלת עברית ואשר.`r`n3. בדוק ביומן שנוצר גיבוי.`r`n4. פתח את היסטוריית הגיבויים ושחזר את הגיבוי של עותק הבדיקה.`r`n`r`nאל תמחק את עותק הבדיקה לפני השחזור. ההתקנה המקורית לא שונתה.",'עותק הבדיקה מוכן',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information) | Out-Null
} catch {
    try { if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force } } catch {}
    Fail ('הכנת עותק הבדיקה נכשלה: '+$_.Exception.Message)
}
