#requires -Version 5.1
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function Fail([string]$message) {
    [Windows.Forms.MessageBox]::Show($message,'Prepare ApkStart Test',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Error) | Out-Null
    exit 1
}

$dialog = New-Object Windows.Forms.FolderBrowserDialog
$dialog.Description = 'Select the ApkStart installation folder, or its resources/app folder.'
$dialog.ShowNewFolderButton = $false
if ($dialog.ShowDialog() -ne [Windows.Forms.DialogResult]::OK) { exit 0 }
$selected = [IO.Path]::GetFullPath($dialog.SelectedPath)

$candidate = $null
foreach ($p in @($selected,(Join-Path $selected 'resources/app'),(Join-Path $selected 'app'))) {
    $ui = Join-Path $p 'src/ui'
    $required = @('index.html','app.js','main.js','style.css','theme.css')
    if (@($required | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ui $_) -PathType Leaf) }).Count -eq 0) { $candidate = $p; break }
}
if (-not $candidate) { Fail 'No unpacked ApkStart files were found in the selected folder. Select the installation folder or resources/app.' }

$packagePath = Join-Path $candidate 'package.json'
if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) { Fail 'package.json was not found. The ApkStart version cannot be verified.' }
try { $package = Get-Content -LiteralPath $packagePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Fail 'package.json is invalid.' }
if ([string]$package.version -ne '0.6.3') { Fail ('Detected version '+[string]$package.version+'. The isolated test currently supports version 0.6.3 only.') }

$ui = Join-Path $candidate 'src/ui'
$anchors = @(
    @{Path=(Join-Path $ui 'index.html'); Values=@('id="btnManual"','id="btnSettings"','id="search"')},
    @{Path=(Join-Path $ui 'app.js'); Values=@('function visibleApps','function refreshStatus','const SETTINGS_CATS','const DEBUG_CATS')},
    @{Path=(Join-Path $candidate 'src/main.js'); Values=@("ipcMain.handle('app:info'","ipcMain.handle('apps:list'","ipcMain.handle('settings:get'")}
)
foreach ($check in $anchors) {
    $raw = [IO.File]::ReadAllText($check.Path,[Text.Encoding]::UTF8)
    foreach ($anchor in $check.Values) { if (-not $raw.Contains($anchor)) { Fail ('ApkStart structure differs from the tested version. Missing marker: '+$anchor+'. No test copy was created.') } }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$manager = Join-Path $projectRoot 'src/ApkStart-Hebrew.ps1'
if (-not (Test-Path -LiteralPath $manager -PathType Leaf)) { Fail 'ApkStart-Hebrew.ps1 was not found. Run this file from the complete project folder.' }

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
    $nl = [Environment]::NewLine
    $message = 'An isolated test copy was created:'+$nl+$testRoot+$nl+$nl+'The manager opened with this copy selected.'+$nl+'1. Confirm that version 0.6.3 and a supported installation are detected.'+$nl+'2. Click Apply Hebrew and confirm.'+$nl+'3. Check the log for a created backup.'+$nl+'4. Open Backup History and restore the backup belonging to this test copy.'+$nl+$nl+'Do not delete the test copy before restoring it. Your original installation was not modified.'
    [Windows.Forms.MessageBox]::Show($message,'Test copy is ready',[Windows.Forms.MessageBoxButtons]::OK,[Windows.Forms.MessageBoxIcon]::Information) | Out-Null
} catch {
    try { if (Test-Path -LiteralPath $testRoot) { Remove-Item -LiteralPath $testRoot -Recurse -Force } } catch {}
    Fail ('Could not prepare the test copy: '+$_.Exception.Message)
}
