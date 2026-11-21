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
if ($translations.PSObject.Properties.Count -lt 40) {
    throw 'Translation dictionary unexpectedly small.'
}
$hebrewCount = @($translations.PSObject.Properties | Where-Object { $_.Value -match '[\u0590-\u05FF]' }).Count
if ($hebrewCount -lt 35) {
    throw 'Hebrew translation entries are missing.'
}

$source = Get-Content -LiteralPath $script -Raw -Encoding UTF8
foreach ($required in @('Get-FileHash','APKSTART-HEBREW:RTL','app.asar','WindowsApps','Backups','PatchedHash')) {
    if ($source -notmatch [regex]::Escape($required)) {
        throw "Safety or compatibility feature missing: $required"
    }
}

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error $_.Message }
    throw 'PowerShell syntax validation failed.'
}

Write-Host ("Project validation passed. Hebrew entries: " + $hebrewCount) -ForegroundColor Green
