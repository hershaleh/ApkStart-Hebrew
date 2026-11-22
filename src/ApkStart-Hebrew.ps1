#requires -Version 5.1
param([string]$InitialTargetPath)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[Windows.Forms.Application]::EnableVisualStyles()
$root = Split-Path -Parent $PSScriptRoot
$dictPath = Join-Path $root 'translations/he-IL.json'
$stateDir = Join-Path $env:LOCALAPPDATA 'ApkStart-Hebrew'
$stateFile = Join-Path $stateDir 'last-backup.json'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$map = Get-Content -LiteralPath $dictPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Log([string]$message,[string]$kind='info') {
    $colors = @{info=[Drawing.Color]::FromArgb(55,65,81);success=[Drawing.Color]::DarkGreen;warning=[Drawing.Color]::DarkGoldenrod;error=[Drawing.Color]::Firebrick}
    $logBox.SelectionStart=$logBox.TextLength; $logBox.SelectionLength=0
    $logBox.SelectionColor=$colors[$kind]
    $logBox.AppendText(('['+(Get-Date -Format 'HH:mm:ss')+'] '+$message+[Environment]::NewLine))
    $logBox.SelectionColor=$logBox.ForeColor; $logBox.ScrollToCaret()
}
function Test-ReviewedStructure([string]$candidate,[string]$ui,[ref]$reason) {
    # Reviewed 0.6.3 structural anchors survive Hebrew text replacement.
    # They detect common same-version upstream layout/API changes.
    $checks=@(
        @{Path=(Join-Path $ui 'index.html');Anchors=@('id="btnManual"','id="btnSettings"','id="search"')},
        @{Path=(Join-Path $ui 'app.js');Anchors=@('function visibleApps','function refreshStatus','const SETTINGS_CATS','const DEBUG_CATS')},
        @{Path=(Join-Path $candidate 'src/main.js');Anchors=@("ipcMain.handle('app:info'","ipcMain.handle('apps:list'","ipcMain.handle('settings:get'")}
    )
    foreach($check in $checks){
        if(-not (Test-Path -LiteralPath $check.Path -PathType Leaf)){
            $reason.Value='חסר קובץ מבנה מרכזי: '+(Split-Path -Leaf $check.Path)
            return $false
        }
        $content=[IO.File]::ReadAllText($check.Path,[Text.Encoding]::UTF8)
        foreach($anchor in $check.Anchors){
            if(-not $content.Contains($anchor)){
                $reason.Value='מבנה הקובץ השתנה: '+(Split-Path -Leaf $check.Path)+'; חסר סימן מבני '+$anchor
                return $false
            }
        }
    }
    $reason.Value=''
    return $true
}
function Resolve-Target([string]$path) {
    if ([string]::IsNullOrWhiteSpace($path)) { return $null }
    try {
        $path=[IO.Path]::GetFullPath($path.Trim().Trim('"'))
    } catch {
        return [pscustomobject]@{Status='InvalidPath';Root=$path;Ui=$null;Version='—';Message='הנתיב שהוזן אינו תקין. בחר תיקייה קיימת.'}
    }
    if(-not (Test-Path -LiteralPath $path -PathType Container)){
        return [pscustomobject]@{Status='InvalidPath';Root=$path;Ui=$null;Version='—';Message='התיקייה שנבחרה אינה קיימת או שאינה תיקייה. בחר את תיקיית ApkStart, את resources/app או את תיקיית app.'}
    }
    if ($path -match '(?i)\\WindowsApps(?:\\|$)') { return [pscustomobject]@{Status='MSIX';Root=$path;Ui=$null;Version='—';Message='זוהתה התקנת Microsoft Store / MSIX. חבילה חתומה לא תשונה.'} }
    $candidates=@($path,(Join-Path $path 'resources/app'),(Join-Path $path 'app'))
    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        $ui=Join-Path $candidate 'src/ui'
        $requiredFiles=@('index.html','app.js','main.js','style.css','theme.css')
        $missing=@($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ui $_) -PathType Leaf) })
        if($missing.Count -eq 0){
            $version='לא ידועה'; $pkg=Join-Path $candidate 'package.json'
            if(Test-Path -LiteralPath $pkg -PathType Leaf){
                try {
                    $parsed=Get-Content -LiteralPath $pkg -Raw -Encoding UTF8 | ConvertFrom-Json
                    if($parsed.version){$version=([string]$parsed.version).Trim()}
                } catch {}
            }
            $verifiedVersion='0.6.3'
            if($version -ne $verifiedVersion){
                return [pscustomobject]@{Status='UnsupportedVersion';Root=$candidate;Ui=$ui;Version=$version;Message=('נמצאה גרסה '+$version+', אך התרגום נבדק כרגע רק מול ApkStart '+$verifiedVersion+'. לא יבוצעו שינויים כדי למנוע פגיעה בגרסה אחרת.')}
            }
            $structureReason=''
            if(-not (Test-ReviewedStructure $candidate $ui ([ref]$structureReason))){
                return [pscustomobject]@{Status='UnsupportedStructure';Root=$candidate;Ui=$ui;Version=$version;Message=('מספר הגרסה עדיין '+$verifiedVersion+', אך מבנה הקבצים שונה מהמבנה שנבדק. ייתכן שהותקן עדכון או build אחר. ההחלה חסומה. '+$structureReason)}
            }
            return [pscustomobject]@{Status='Supported';Root=$candidate;Ui=$ui;Version=$version;Message='נמצאה גרסה 0.6.3 עם מבנה ממשק תואם לסימנים שנבדקו.'}
        }
    }
    $asarCandidates=@((Join-Path $path 'resources/app.asar'),(Join-Path $path 'app.asar'),(Join-Path $path 'resources/app/app.asar'))
    if(@($asarCandidates | Where-Object {Test-Path -LiteralPath $_ -PathType Leaf}).Count -gt 0){
        return [pscustomobject]@{Status='ASAR';Root=$path;Ui=$null;Version='—';Message='נמצא app.asar. הכלי אינו משנה ארכיוני ASAR בשלב זה.'}
    }
    return [pscustomobject]@{Status='Unknown';Root=$path;Ui=$null;Version='—';Message='התיקייה קיימת, אך לא נמצאו בה קובצי ApkStart נתמכים. נסה לבחור את תיקיית ההתקנה, resources/app או app.'}
}
function Detect-Targets {
    $list=New-Object System.Collections.Generic.List[string]
    $keys=@('HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall')
    foreach($key in $keys){ if(Test-Path $key){ Get-ChildItem $key -ErrorAction SilentlyContinue | ForEach-Object { try { $v=Get-ItemProperty $_.PSPath; if($v.DisplayName -match '(?i)ApkStart' -and $v.InstallLocation){$list.Add($v.InstallLocation)} }catch{} } } }
    $pf86=[Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    foreach($p in @((Join-Path $env:LOCALAPPDATA 'Programs/ApkStart'),(Join-Path $env:ProgramFiles 'ApkStart'),(Join-Path $pf86 'ApkStart'),(Join-Path $env:USERPROFILE 'Apps/ApkStart'))) { if($p -and (Test-Path $p)){$list.Add($p)} }
    return @($list | Select-Object -Unique)
}
function HashFile([string]$path){ return (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash }
function Restore-FileAtomic([string]$source,[string]$destination) {
    if(-not (Test-Path -LiteralPath $source -PathType Leaf)){throw 'קובץ המקור לשחזור חסר.'}
    if(-not (Test-Path -LiteralPath $destination -PathType Leaf)){throw 'קובץ היעד לשחזור חסר.'}
    $temp=$destination+'.apkstart-hebrew-restore.tmp'
    try {
        [IO.File]::Copy($source,$temp,$true)
        [IO.File]::Replace($temp,$destination,$null,$true)
    } finally {
        if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}
    }
}

function Get-FullPath([string]$path) {
    return [IO.Path]::GetFullPath($path).TrimEnd([IO.Path]::DirectorySeparatorChar,[IO.Path]::AltDirectorySeparatorChar)
}
function Test-PathWithin([string]$candidate,[string]$base) {
    try {
        $candidateFull=Get-FullPath $candidate
        $baseFull=Get-FullPath $base
        $prefix=$baseFull+[IO.Path]::DirectorySeparatorChar
        return $candidateFull.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)
    } catch { return $false }
}
function Get-SafeRelativePath([string]$relative) {
    if([string]::IsNullOrWhiteSpace($relative) -or [IO.Path]::IsPathRooted($relative)){throw 'נתיב יחסי בגיבוי אינו תקין.'}
    $normalized=$relative.Replace('/',[string][char]92)
    $parts=$normalized.Split([char]92)
    if(@($parts | Where-Object { $_ -eq '..' -or $_ -eq '.' -or $_ -eq '' }).Count -gt 0){throw 'נתיב הגיבוי מכיל רכיב אסור.'}
    $allowedUi='^src\\ui\\(main\.js|index\.html|app\.js|shell\.html|shell\.js|manual\.html|splash\.html|splash\.js|style\.css|theme\.css|shell\.css|splash\.css)$'
    if(-not ($normalized -match $allowedUi -or $normalized -ceq 'src\core\autodebug.js')){throw 'הגיבוי מפנה לקובץ שאינו חלק מרשימת קובצי הממשק המותרים.'}
    return $normalized
}
function Select-DetectedInstall([string[]]$targets) {
    if($targets.Count -eq 0){return $null}
    if($targets.Count -eq 1){return $targets[0]}
    $dialog=New-Object Windows.Forms.Form
    $dialog.Text='בחירת התקנת ApkStart';$dialog.Size=New-Object Drawing.Size(650,190);$dialog.StartPosition='CenterParent';$dialog.RightToLeft='Yes';$dialog.RightToLeftLayout=$true
    $label=New-Object Windows.Forms.Label;$label.Text='נמצאו כמה התקנות. בחר באיזו מהן להשתמש:';$label.AutoSize=$true;$label.Location=New-Object Drawing.Point(18,15);$dialog.Controls.Add($label)
    $combo=New-Object Windows.Forms.ComboBox;$combo.DropDownStyle='DropDownList';$combo.Location=New-Object Drawing.Point(18,45);$combo.Size=New-Object Drawing.Size(595,28);$combo.RightToLeft='No'
    foreach($targetPath in $targets){
        $resolved=Resolve-Target $targetPath
        $combo.Items.Add(($resolved.Version+' | '+$resolved.Status+' | '+$targetPath)) | Out-Null
    }
    $combo.SelectedIndex=0;$dialog.Controls.Add($combo)
    $ok=New-Object Windows.Forms.Button;$ok.Text='בחר';$ok.DialogResult=[Windows.Forms.DialogResult]::OK;$ok.Location=New-Object Drawing.Point(435,90);$dialog.Controls.Add($ok)
    $cancel=New-Object Windows.Forms.Button;$cancel.Text='ביטול';$cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel;$cancel.Location=New-Object Drawing.Point(525,90);$dialog.Controls.Add($cancel)
    $dialog.AcceptButton=$ok;$dialog.CancelButton=$cancel
    if($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK){return $targets[$combo.SelectedIndex]}
    return $null
}

function Get-BackupHistory {
    $backupsRoot=Join-Path $stateDir 'Backups'
    $items=New-Object System.Collections.Generic.List[object]
    if(-not (Test-Path -LiteralPath $backupsRoot -PathType Container)){return @()}
    foreach($folder in (Get-ChildItem -LiteralPath $backupsRoot -Directory -ErrorAction SilentlyContinue)){
        $manifestPath=Join-Path $folder.FullName 'manifest.json'
        try {
            if(-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)){continue}
            $manifestFull=Get-FullPath $manifestPath
            if(-not (Test-PathWithin $manifestFull $backupsRoot) -or (Split-Path -Leaf $manifestFull) -cne 'manifest.json'){continue}
            $m=Get-Content -LiteralPath $manifestFull -Raw -Encoding UTF8 | ConvertFrom-Json
            if([int]$m.Schema -ne 1 -or [string]::IsNullOrWhiteSpace([string]$m.TargetRoot) -or @($m.Files).Count -eq 0){continue}
            $targetRoot=Get-FullPath ([string]$m.TargetRoot)
            if(-not (Test-Path -LiteralPath $targetRoot -PathType Container)){continue}
            $backupRoot=Get-FullPath $folder.FullName
            if(-not (Test-PathWithin $backupRoot $backupsRoot)){continue}
            $backupFiles=Join-Path $backupRoot 'files'
            $seen=@{};$valid=$true
            foreach($entry in $m.Files){
                $relative=Get-SafeRelativePath ([string]$entry.RelativePath)
                $key=$relative.ToLowerInvariant()
                if($seen.ContainsKey($key)){$valid=$false;break}
                $seen[$key]=$true
                $backupPath=Join-Path $backupFiles $relative
                if(-not (Test-PathWithin $backupPath $backupFiles) -or -not (Test-Path -LiteralPath $backupPath -PathType Leaf)){$valid=$false;break}
                if(-not [string]::IsNullOrWhiteSpace([string]$entry.BackupHash) -and (HashFile $backupPath) -ne [string]$entry.BackupHash){$valid=$false;break}
                if([string]::IsNullOrWhiteSpace([string]$entry.PatchedHash)){$valid=$false;break}
            }
            if($valid){
                $items.Add([pscustomobject]@{
                    ManifestPath=$manifestFull
                    TargetRoot=$targetRoot
                    Version=[string]$m.Version
                    FileCount=@($m.Files).Count
                    Created=$folder.LastWriteTime
                    Display=($folder.LastWriteTime.ToString('dd/MM/yyyy HH:mm:ss')+' | גרסה '+[string]$m.Version+' | '+@($m.Files).Count+' קבצים | '+$targetRoot)
                })
            }
        } catch {
            # A damaged or incomplete backup is intentionally omitted from the selectable history.
            continue
        }
    }
    return @($items | Sort-Object Created -Descending)
}
function Select-BackupManifest {
    $history=@(Get-BackupHistory)
    if($history.Count -eq 0){
        [Windows.Forms.MessageBox]::Show('לא נמצאו גיבויים תקינים לבחירה.','היסטוריית גיבויים') | Out-Null
        return $null
    }
    $dialog=New-Object Windows.Forms.Form
    $dialog.Text='היסטוריית גיבויים';$dialog.Size=New-Object Drawing.Size(820,360);$dialog.MinimumSize=New-Object Drawing.Size(700,300)
    $dialog.StartPosition='CenterParent';$dialog.RightToLeft='Yes';$dialog.RightToLeftLayout=$true
    $label=New-Object Windows.Forms.Label;$label.Text='בחר גיבוי לשחזור. גיבויים פגומים או חלקיים אינם מוצגים:';$label.AutoSize=$true;$label.Location=New-Object Drawing.Point(16,14);$dialog.Controls.Add($label)
    $list=New-Object Windows.Forms.ListBox;$list.Location=New-Object Drawing.Point(16,42);$list.Size=New-Object Drawing.Size(770,220);$list.Anchor='Top,Bottom,Left,Right';$list.HorizontalScrollbar=$true
    foreach($item in $history){[void]$list.Items.Add($item.Display)}
    $list.SelectedIndex=0;$dialog.Controls.Add($list)
    $hint=New-Object Windows.Forms.Label;$hint.Text='בשחזור מגיבוי ישן, קבצים ששונו מאז לא יידרסו ועלולים להידלג.';$hint.AutoSize=$true;$hint.Location=New-Object Drawing.Point(16,270);$hint.Anchor='Bottom,Left';$hint.ForeColor=[Drawing.Color]::DarkGoldenrod;$dialog.Controls.Add($hint)
    $ok=New-Object Windows.Forms.Button;$ok.Text='שחזר גיבוי נבחר';$ok.DialogResult=[Windows.Forms.DialogResult]::OK;$ok.Location=New-Object Drawing.Point(540,295);$ok.Size=New-Object Drawing.Size(140,30);$ok.Anchor='Bottom,Right';$dialog.Controls.Add($ok)
    $cancel=New-Object Windows.Forms.Button;$cancel.Text='ביטול';$cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel;$cancel.Location=New-Object Drawing.Point(690,295);$cancel.Size=New-Object Drawing.Size(95,30);$cancel.Anchor='Bottom,Right';$dialog.Controls.Add($cancel)
    $dialog.AcceptButton=$ok;$dialog.CancelButton=$cancel
    if($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK -and $list.SelectedIndex -ge 0){return [string]$history[$list.SelectedIndex].ManifestPath}
    return $null
}


function Select-BackupForExport {
    $history=@(Get-BackupHistory)
    if($history.Count -eq 0){[Windows.Forms.MessageBox]::Show('לא נמצאו גיבויים תקינים לייצוא.','ייצוא גיבוי') | Out-Null;return $null}
    $dialog=New-Object Windows.Forms.Form
    $dialog.Text='בחירת גיבוי לייצוא';$dialog.Size=New-Object Drawing.Size(820,350);$dialog.MinimumSize=New-Object Drawing.Size(700,290)
    $dialog.StartPosition='CenterParent';$dialog.RightToLeft='Yes';$dialog.RightToLeftLayout=$true
    $label=New-Object Windows.Forms.Label;$label.Text='בחר גיבוי תקין ליצירת קובץ ZIP:';$label.AutoSize=$true;$label.Location=New-Object Drawing.Point(16,14);$dialog.Controls.Add($label)
    $list=New-Object Windows.Forms.ListBox;$list.Location=New-Object Drawing.Point(16,42);$list.Size=New-Object Drawing.Size(770,205);$list.Anchor='Top,Bottom,Left,Right';$list.HorizontalScrollbar=$true
    foreach($item in $history){[void]$list.Items.Add($item.Display)}
    $list.SelectedIndex=0;$dialog.Controls.Add($list)
    $ok=New-Object Windows.Forms.Button;$ok.Text='ייצא גיבוי נבחר';$ok.DialogResult=[Windows.Forms.DialogResult]::OK;$ok.Location=New-Object Drawing.Point(545,265);$ok.Size=New-Object Drawing.Size(130,30);$ok.Anchor='Bottom,Right';$dialog.Controls.Add($ok)
    $cancel=New-Object Windows.Forms.Button;$cancel.Text='ביטול';$cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel;$cancel.Location=New-Object Drawing.Point(690,265);$cancel.Size=New-Object Drawing.Size(95,30);$cancel.Anchor='Bottom,Right';$dialog.Controls.Add($cancel)
    $dialog.AcceptButton=$ok;$dialog.CancelButton=$cancel
    if($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK -and $list.SelectedIndex -ge 0){return [string]$history[$list.SelectedIndex].ManifestPath}
    return $null
}
function Export-BackupZip {
    $manifestPath=Select-BackupForExport
    if([string]::IsNullOrWhiteSpace($manifestPath)){return}
    $history=@(Get-BackupHistory | Where-Object {$_.ManifestPath -eq $manifestPath})
    if($history.Count -ne 1){throw 'הגיבוי אינו מופיע עוד בהיסטוריה התקינה. בצע רענון ונסה שוב.'}
    $backupRoot=Split-Path -Parent $manifestPath
    $dialog=New-Object Windows.Forms.SaveFileDialog
    $dialog.Title='שמירת גיבוי ApkStart';$dialog.Filter='קובץ גיבוי ZIP (*.zip)|*.zip';$dialog.DefaultExt='zip';$dialog.AddExtension=$true
    $dialog.FileName=('ApkStart-Hebrew-backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'.zip')
    if($dialog.ShowDialog($form) -ne [Windows.Forms.DialogResult]::OK){return}
    $destination=$dialog.FileName
    $temp=$destination+'.tmp-'+[guid]::NewGuid().ToString('N')
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    try{
        $archive=[IO.Compression.ZipFile]::Open($temp,[IO.Compression.ZipArchiveMode]::Create)
        try{
            $manifestEntry=$archive.CreateEntry('manifest.json',[IO.Compression.CompressionLevel]::Optimal)
            $sourceManifest=[IO.File]::OpenRead($manifestPath)
            try{$out=$manifestEntry.Open();try{$sourceManifest.CopyTo($out)}finally{$out.Dispose()}}finally{$sourceManifest.Dispose()}
            $backupFiles=Join-Path $backupRoot 'files'
            foreach($entry in (Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json).Files){
                $relative=Get-SafeRelativePath ([string]$entry.RelativePath)
                $source=Join-Path $backupFiles $relative
                if(-not (Test-PathWithin $source $backupFiles) -or -not (Test-Path -LiteralPath $source -PathType Leaf)){throw ('קובץ גיבוי חסר: '+$relative)}
                if(-not [string]::IsNullOrWhiteSpace([string]$entry.BackupHash) -and (HashFile $source) -ne [string]$entry.BackupHash){throw ('טביעת קובץ הגיבוי אינה תואמת: '+$relative)}
                $zipName='files/'+$relative.Replace('\','/')
                $zipEntry=$archive.CreateEntry($zipName,[IO.Compression.CompressionLevel]::Optimal)
                $input=[IO.File]::OpenRead($source)
                try{$output=$zipEntry.Open();try{$input.CopyTo($output)}finally{$output.Dispose()}}finally{$input.Dispose()}
            }
        }finally{$archive.Dispose()}
        if((Get-Item -LiteralPath $temp).Length -gt 500MB){throw 'קובץ ה-ZIP שנוצר חורג ממגבלת הגודל של 500MB.'}
        if(Test-Path -LiteralPath $destination){throw 'קובץ היעד כבר קיים. בחר שם אחר כדי לא לדרוס קובץ קיים.'}
        [IO.File]::Move($temp,$destination)
        Log ('הגיבוי יוצא לקובץ ZIP: '+$destination) 'success'
        [Windows.Forms.MessageBox]::Show('ייצוא הגיבוי הסתיים בהצלחה. קובצי ApkStart ונתוני המשתמש לא נכללו.','ייצוא הסתיים') | Out-Null
    }catch{if(Test-Path -LiteralPath $temp){Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue};throw}
}
function Import-BackupZip {
    $dialog=New-Object Windows.Forms.OpenFileDialog
    $dialog.Title='בחירת קובץ גיבוי לייבוא';$dialog.Filter='קובצי גיבוי ZIP (*.zip)|*.zip';$dialog.CheckFileExists=$true; $dialog.Multiselect=$false
    if($dialog.ShowDialog($form) -ne [Windows.Forms.DialogResult]::OK){return}
    $archivePath=$dialog.FileName
    $backupsRoot=Join-Path $stateDir 'Backups'
    New-Item -ItemType Directory -Path $backupsRoot -Force | Out-Null
    $stage=Join-Path $backupsRoot ('.import-'+[guid]::NewGuid().ToString('N'))
    Add-Type -AssemblyName System.IO.Compression
    try{
        $info=Get-Item -LiteralPath $archivePath
        if($info.Length -le 0 -or $info.Length -gt 500MB){throw 'גודל קובץ ZIP אינו תקין או חורג ממגבלת 500MB.'}
        $archive=[IO.Compression.ZipFile]::OpenRead($archivePath)
        try{
            if($archive.Entries.Count -lt 2 -or $archive.Entries.Count -gt 2001){throw 'מספר הפריטים בארכיון אינו תקין (מותר manifest ועד 2,000 קבצים).'}
            $seen=@{};$total=[long]0;$manifestSeen=$false
            foreach($entry in $archive.Entries){
                $name=[string]$entry.FullName
                if([string]::IsNullOrWhiteSpace($name) -or $name.Contains('\') -or $name.StartsWith('/') -or $name -match '^[A-Za-z]:' -or $name.Split('/').Contains('..') -or $name.Split('/').Contains('.')){throw ('נתיב לא בטוח בתוך ZIP: '+$name)}
                if($name.EndsWith('/')){throw 'הארכיון מכיל תיקיות מפורשות שאינן נחוצות.'}
                if($seen.ContainsKey($name.ToLowerInvariant())){throw ('הארכיון מכיל נתיב כפול: '+$name)}
                $seen[$name.ToLowerInvariant()]=$true
                $unixType=($entry.ExternalAttributes -shr 16) -band 0xF000
                if($unixType -eq 0xA000 -or ($unixType -ne 0 -and $unixType -ne 0x8000)){throw ('קובץ מסוג קישור או סוג קובץ לא נתמך: '+$name)}
                if($name -ceq 'manifest.json'){$manifestSeen=$true;if($entry.Length -gt 2MB){throw 'קובץ manifest גדול באופן חריג.'}}
                elseif($name.StartsWith('files/')){[void](Get-SafeRelativePath ($name.Substring(6)))}
                else{throw ('הארכיון מכיל פריט שאינו חלק מגיבוי: '+$name)}
                $total += [long]$entry.Length
                if($total -gt 1GB){throw 'הגיבוי המכווץ גדול מדי לאחר פתיחה (מגבלה 1GB).'}
            }
            if(-not $manifestSeen){throw 'קובץ manifest.json חסר בארכיון.'}
            $manifestEntry=$archive.GetEntry('manifest.json')
            $reader=New-Object IO.StreamReader($manifestEntry.Open(),[Text.Encoding]::UTF8)
            try{$archiveManifest=$reader.ReadToEnd() | ConvertFrom-Json}finally{$reader.Dispose()}
            if([int]$archiveManifest.Schema -ne 1 -or @($archiveManifest.Files).Count -lt 1 -or @($archiveManifest.Files).Count -gt 2000){throw 'מבנה manifest.json אינו נתמך או שמספר הקבצים אינו תקין.'}
            $expected=@{'manifest.json'=$true}
            foreach($fileRecord in $archiveManifest.Files){
                $safeRelative=Get-SafeRelativePath ([string]$fileRecord.RelativePath)
                $expectedName=('files/'+$safeRelative.Replace([string][char]92,'/')).ToLowerInvariant()
                if($expected.ContainsKey($expectedName)){throw ('המניפסט מכיל נתיב כפול: '+$safeRelative)}
                $expected[$expectedName]=$true
            }
            if($expected.Count -ne $archive.Entries.Count){throw 'תוכן ה-ZIP אינו תואם לרשימת הקבצים שבמניפסט.'}
            foreach($zipEntry in $archive.Entries){if(-not $expected.ContainsKey(([string]$zipEntry.FullName).ToLowerInvariant())){throw ('נמצא קובץ שאינו רשום במניפסט: '+$zipEntry.FullName)}}
            New-Item -ItemType Directory -Path $stage -Force | Out-Null
            foreach($entry in $archive.Entries){
                $relative=$entry.FullName
                if($relative -ceq 'manifest.json'){$destination=Join-Path $stage 'manifest.json'}
                else{$safe=Get-SafeRelativePath ($relative.Substring(6));$destination=Join-Path (Join-Path $stage 'files') $safe}
                if(-not (Test-PathWithin $destination $stage)){throw 'נתיב חילוץ חורג מתיקיית הייבוא.'}
                New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
                $input=$entry.Open()
                try{$output=[IO.File]::Open($destination,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$input.CopyTo($output)}finally{$output.Dispose()}}finally{$input.Dispose()}
            }
        }finally{$archive.Dispose()}
        $valid=@(Get-BackupHistory | Where-Object {$_.ManifestPath -eq (Join-Path $stage 'manifest.json')})
        if($valid.Count -ne 1){throw 'הגיבוי שיובא אינו תקין, חסרים בו קבצים, טביעות SHA-256 אינן תואמות, או שההתקנה המקורית אינה זמינה במחשב זה.'}
        $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
        $final=Join-Path $backupsRoot ('Imported-'+$stamp)
        while(Test-Path -LiteralPath $final){$final=Join-Path $backupsRoot ('Imported-'+[guid]::NewGuid().ToString('N'))}
        [IO.Directory]::Move($stage,$final)
        Log ('הגיבוי יובא ונוסף להיסטוריה: '+$final) 'success'
        [Windows.Forms.MessageBox]::Show('הייבוא הסתיים. הגיבוי נוסף להיסטוריה ולא החליף גיבויים קיימים. לשחזור יש לבחור את אותה התקנת ApkStart שעבורה נוצר הגיבוי.','ייבוא הסתיים') | Out-Null
        Update-ActionState
    }catch{
        if(Test-Path -LiteralPath $stage){Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue}
        throw
    }
}

function Update-ActionState {
    $isSupported=($null -ne $script:Target -and $script:Target.Status -eq 'Supported')
    if($apply){$apply.Enabled=$isSupported}
    if($restore){$restore.Enabled=(@(Get-BackupHistory).Count -gt 0)
    if($exportBackup){$exportBackup.Enabled=(@(Get-BackupHistory).Count -gt 0)}}
}
function Scan {
    $target=Resolve-Target $pathBox.Text
    $script:Target=$target
    if(!$target){
        $statusLabel.Text='נדרשת בחירת תיקייה וסריקה';$statusLabel.ForeColor=[Drawing.Color]::DimGray
        $versionLabel.Text='גרסה: —'
        Update-ActionState
        Log 'בחר תיקיית ApkStart ולחץ על סריקה.' 'warning'
        return $null
    }
    $versionLabel.Text='גרסה: '+$target.Version
    if($target.Status -eq 'Supported'){$statusLabel.Text='נמצאה התקנה נתמכת';$statusLabel.ForeColor=[Drawing.Color]::DarkGreen;Log ($target.Message+' '+$target.Root) 'success'}
    elseif($target.Status -eq 'UnsupportedVersion'){$statusLabel.Text='גרסה לא מאומתת — ההחלה חסומה';$statusLabel.ForeColor=[Drawing.Color]::DarkGoldenrod;Log ($target.Message+' '+$target.Root) 'warning'}
    elseif($target.Status -eq 'UnsupportedStructure'){$statusLabel.Text='מבנה השתנה — נדרשת בדיקה מחדש';$statusLabel.ForeColor=[Drawing.Color]::DarkGoldenrod;Log ($target.Message+' '+$target.Root) 'warning'}
    elseif($target.Status -eq 'InvalidPath'){$statusLabel.Text='נתיב לא תקין';$statusLabel.ForeColor=[Drawing.Color]::Firebrick;Log $target.Message 'error'}
    elseif($target.Status -eq 'MSIX'){$statusLabel.Text='חבילת Microsoft Store אינה ניתנת לשינוי';$statusLabel.ForeColor=[Drawing.Color]::DarkGoldenrod;Log $target.Message 'warning'}
    elseif($target.Status -eq 'ASAR'){$statusLabel.Text='נדרש טיפול ייעודי ב-ASAR';$statusLabel.ForeColor=[Drawing.Color]::DarkGoldenrod;Log $target.Message 'warning'}
    else{$statusLabel.Text='לא זוהתה התקנת ApkStart בתיקייה';$statusLabel.ForeColor=[Drawing.Color]::Firebrick;Log $target.Message 'error'}
    Update-ActionState
    return $target
}
function Rtl([string]$text) {
    if($text.Contains('APKSTART-HEBREW:RTL')){return $text}
    $css=@'

/* APKSTART-HEBREW:RTL */
/* Settings, menus and dialogs: preserve the visual hierarchy while mirroring
   only layout containers. Do not reverse every flex row globally. */
.modal-main{direction:rtl}
.set-nav{order:0;text-align:right}
.modal-body{direction:rtl;text-align:right}
.set-nav-item{justify-content:flex-start;text-align:right}
.set-nav-item .icon,.set-nav-item svg{flex:0 0 auto}
.group,.advanced-group,.field,.about-box,.lab-notice{direction:rtl;text-align:right}
.field.two{direction:rtl}
.field.two>*,.field .row>*{min-width:0}
.field .row,.runtime-actions,.about-links,.about-qrs{direction:rtl}
.field .row,.runtime-actions{flex-wrap:wrap}
.field label,.field .sub,.field .note,.field .inline-note,
.group-title,.advanced-group>summary,.modal-head,.modal-foot,
.welcome-body,.welcome-actions,.welcome-tip,.welcome-opt{text-align:right}
.field input:not([type=url]):not([type=password]):not([type=number]):not([type=range]):not([type=checkbox]):not([type=radio]),
.field select,.field textarea{direction:rtl;text-align:right}
.field input[type=checkbox],.field input[type=radio],.switch{flex:0 0 auto}
.switch-field{direction:rtl;justify-content:space-between}
.switch-field>div{min-width:0;text-align:right}
.modal-head{direction:rtl}
.modal-head .icon-btn{margin-right:auto;margin-left:0}
.modal-foot{direction:rtl;justify-content:flex-start}
.modal-foot .btn{margin-right:0;margin-left:0}
.ctxmenu{direction:rtl;text-align:right}
.ctxmenu .item{direction:rtl;justify-content:flex-start;text-align:right}
.ctxmenu .item .k{margin-right:auto;margin-left:0;direction:ltr}
.toast-wrap{direction:rtl;align-items:flex-start}
.toast,.toast .t-title,.toast .t-body{text-align:right;direction:rtl}
.toast .t-title{flex-direction:row}
.welcome,.welcome-hero,.welcome-body,.welcome-actions{direction:rtl}
.welcome-tip{flex-direction:row}
.welcome-tip i{flex:0 0 auto}
.welcome-opt{flex-direction:row}
.about-info,.about-name,.about-links{direction:rtl;text-align:right}
.about-links{align-items:flex-start}
.group-title{unicode-bidi:plaintext}
.statusbar{direction:rtl}
.status-left,.status-right{direction:rtl}
.titlebar{direction:rtl}
.titlebar-actions{direction:ltr}
.toolbar{direction:rtl}
.toolbar-right{margin-right:auto;margin-left:0}
.search{direction:rtl}
.search input,.set-search{text-align:right;direction:rtl}

/* Technical values must remain readable and copyable in their natural order. */
input[type=url],input[type=password],input[type=number],input[type=range],
input[type=search][data-ltr],input[dir=ltr],textarea[dir=ltr],
code,pre,kbd,samp,.mono,.monospace,.ltr,[dir=ltr],
.path,.path-value,.file-path,.command,.terminal,.code,.url,.ip-address,
input[id*="Path" i],input[id*="Dir" i],input[id*="Url" i],
input[id*="Address" i],input[id*="Command" i],textarea[id*="Path" i],
textarea[id*="Command" i]{
  direction:ltr;text-align:left;unicode-bidi:plaintext
}
pre,code,.mono,.monospace,.terminal,.command{overflow-wrap:anywhere}
input[type=number],input[type=range]{text-align:left}

html[lang],body{direction:rtl}
body{text-align:right}
.titlebar,.toolbar,.modal-main,.statusbar,.modal-head,.modal-foot{direction:rtl}
.titlebar{padding-left:148px;padding-right:12px}
.titlebar-actions{direction:ltr}
.brand,.toolbar,.toolbar-right,.status-left,.status-right{direction:rtl}
.toolbar-right{margin-right:auto;margin-left:0}
.search,.set-search-wrap{direction:rtl}
.search input,.set-search{text-align:right;direction:rtl}
.set-nav{border-right:0;border-left:1px solid var(--line)}
.modal-head .icon-btn{margin-left:0;margin-right:auto}
.modal-foot .btn{margin-left:0;margin-right:auto}
.status-right{margin-left:0;margin-right:auto}
.ctxmenu,.toast-wrap{direction:rtl;text-align:right}
.toast-wrap{right:auto;left:16px}
.ctxmenu .item{direction:rtl}
.field label,.field .sub,.group-title,.note,.inline-note{text-align:right}
.field input[type=text],.field input[type=number],.field select,.field textarea{text-align:right;direction:rtl}
.field input[type=url],.field input[type=password],.field input[dir=ltr],
input[type=url],input[type=number],input[type=password],code,pre,.mono,.ltr,[dir=ltr]{
  direction:ltr;text-align:left;unicode-bidi:plaintext
}
.statusbar .status-left,.statusbar .status-right{flex-direction:row}
.set-nav-item,.ctxmenu .item,.checkbox-inline,.switch-field{direction:rtl}
.set-nav-item{ text-align:right }
.modal-head{padding-left:18px;padding-right:14px}
.modal-foot{justify-content:flex-start}
.bar{direction:rtl}
.name{direction:rtl;text-align:right}
'@
    return $text+$css
}
function RtlManual([string]$html) {
    if($html.Contains('APKSTART-HEBREW:MANUAL-RTL')){return $html}
    $css=@'
/* APKSTART-HEBREW:MANUAL-RTL */
html[lang],body{direction:rtl;text-align:right}
.wrap{flex-direction:row-reverse}
aside{border-right:0;border-left:1px solid var(--line);text-align:right}
aside h2,.toc-l2,.toc-l3,#tocList a{text-align:right}
#tocSearch{direction:rtl;text-align:right}
main{text-align:right}
h1,h2,h3,h4,p,li,blockquote,td,th{text-align:right}
ul,ol{padding-left:0;padding-right:26px}
blockquote{border-left:0;border-right:4px solid var(--warn);border-radius:8px 0 0 8px}
th,td{text-align:right}
.btnbar{right:auto;left:22px;direction:rtl}
code,pre,.ltr,[dir=ltr],a[href^="http"],a[href^="file:"]{
  direction:ltr;text-align:left;unicode-bidi:plaintext
}
pre{overflow-x:auto}
'@
    if($html -notmatch '(?i)</style>'){return $html}
    return [regex]::Replace($html,'(?i)</style>',($css+[Environment]::NewLine+'</style>'),1)
}
function RtlShell([string]$css) {
    if($css.Contains('APKSTART-HEBREW:SHELL-RTL')){return $css}
    $rules=@'

/* APKSTART-HEBREW:SHELL-RTL */
/* Keep the application identity on the right and window controls on the left. */
.bar{direction:rtl;padding-left:0;padding-right:10px}
.name{direction:rtl;text-align:right;unicode-bidi:plaintext}
.ctl{direction:ltr}
'@
    return $css+$rules
}
function Apply {
    if (Get-Process -Name 'ApkStart' -ErrorAction SilentlyContinue) { Log 'ApkStart עדיין פועל. סגור אותו לפני החלת התרגום.' 'warning'; return }
    $target=Scan
    if(!$target -or $target.Status -ne 'Supported'){return}
    $nl=[Environment]::NewLine
    $msg='הכלי יגבה וישנה קובצי ממשק בלבד בתיקייה:'+$nl+$target.Root+$nl+$nl+'יש לסגור את ApkStart לפני ההמשך. להחיל את התרגום?'
    if([Windows.Forms.MessageBox]::Show($msg,'אישור החלת עברית',[Windows.Forms.MessageBoxButtons]::YesNo) -ne [Windows.Forms.DialogResult]::Yes){return}
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    $backup=Join-Path $stateDir ('Backups/'+$stamp)
    if(Test-Path -LiteralPath $backup){$backup=Join-Path (Join-Path $stateDir 'Backups') ([guid]::NewGuid().ToString('N'))}
    $backupFiles=Join-Path $backup 'files'
    New-Item -ItemType Directory -Path $backupFiles -Force | Out-Null
    $manifest=[ordered]@{Schema=1;TargetRoot=$target.Root;Version=$target.Version;BackupRoot=$backup;Files=@();Replacements=0}
    $translations=@{};foreach($p in $map.PSObject.Properties){$translations[$p.Name]=[string]$p.Value}
    $keys=@($translations.Keys | Sort-Object { $_.Length } -Descending)
    $appAllowPath=Join-Path $root 'translations/app-js-allowlist.json'
    $shellAllowPath=Join-Path $root 'translations/shell-ui-allowlist.json'
    $mainAllowPath=Join-Path $root 'translations/main-process-allowlist.json'
    $autoDebugAllowPath=Join-Path $root 'translations/autodebug-allowlist.json'
    $appAllow=@(Get-Content -LiteralPath $appAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $shellAllow=@(Get-Content -LiteralPath $shellAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $mainAllow=@(Get-Content -LiteralPath $mainAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $autoDebugAllow=@(Get-Content -LiteralPath $autoDebugAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json)
    $names=@('main.js','index.html','app.js','shell.html','shell.js','manual.html','splash.html','splash.js','style.css','theme.css','shell.css','splash.css')
    $files=New-Object System.Collections.Generic.List[string]
    foreach($name in $names){$files.Add((Join-Path $target.Ui $name))}
    # The diagnostic evaluator contains executable logic; translate only reviewed UI literals.
    $files.Add((Join-Path $target.Root 'src/core/autodebug.js'))
    # src/core/manual.js contains executable matching rules and regexes; never patch it as text.
    $changed=0
    try {
        foreach($file in $files){
            $name=Split-Path -Leaf $file
            if(!(Test-Path $file)){continue}
            $original=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)
            if($original.Contains('APKSTART-HEBREW')){throw ('נמצא תרגום קודם בקובץ '+$name+'. יש לשחזר לפני החלה חוזרת.')}
            $updated=$original;$count=0
            $fileKeys=$keys
            if($name -in @('shell.html','shell.js')){
                # The standalone app window has a tiny, reviewed UI surface. Do not
                # run the broad dictionary over shell.js because it contains API names,
                # event tokens and internal fallbacks.
                $fileKeys=@($shellAllow | Where-Object { $translations.ContainsKey([string]$_) })
            }
            if($name -eq 'app.js'){
                # app.js contains UI text as well as internal command/event tokens.
                # Only source-reviewed literal UI strings are eligible for replacement.
                $fileKeys=@($appAllow | Where-Object { $translations.ContainsKey([string]$_) })
            }
            if($name -eq 'manual.html'){
                # The manual contains technical examples and executable-looking strings.
                # Translate only reviewed, user-facing manual phrases.
                $manualAllowPath=Join-Path $root 'translations/manual-allowlist.json'
                $manualAllow=@(Get-Content -LiteralPath $manualAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json)
                $fileKeys=@($manualAllow | Where-Object { $translations.ContainsKey([string]$_) })
            }
            if($name -eq 'manual.html'){$updated=RtlManual $updated}
            if($name -eq 'main.js'){
                # Main process contains internal protocol/configuration strings too.
                # Only replace reviewed, user-visible menu/dialog phrases here.
                $fileKeys=@($mainAllow | Where-Object { $translations.ContainsKey([string]$_) })
            }
            if($name -eq 'autodebug.js'){
                # The diagnostic evaluator is executable core code. Never apply the broad dictionary.
                # Only the separately reviewed category labels, issue titles, hints and detail templates are eligible.
                $fileKeys=@($autoDebugAllow | Where-Object { $translations.ContainsKey([string]$_) })
            }
            # Update document language metadata for screen readers and browser text direction.
            # Keep technical values readable through the dedicated LTR rules below.
            if($name -in @('index.html','shell.html','manual.html','splash.html')){
                $updated=[regex]::Replace($updated,'<html\s+lang=["'']zh-CN["'']\s*>','<html lang="he" dir="rtl">',1)
            }
            foreach($key in $fileKeys){
                if($name -eq 'autodebug.js'){
                    # Match complete JavaScript string/template literals only; never replace substrings in comments or other messages.
                    $tick=[string][char]96
                    $forms=@("'"+$key+"'",'"'+$key+'"',$tick+$key+$tick)
                    foreach($form in $forms){
                        if($updated.Contains($form)){
                            $count+=([regex]::Matches($updated,[regex]::Escape($form))).Count
                            $replacement=$form.Substring(0,1)+$translations[$key]+$form.Substring($form.Length-1,1)
                            $updated=$updated.Replace($form,$replacement)
                        }
                    }
                } else {
                    if($updated.Contains($key)){$count+=([regex]::Matches($updated,[regex]::Escape($key))).Count;$updated=$updated.Replace($key,$translations[$key])}
                }
            }
            if($name -in @('style.css','theme.css','shell.css','splash.css')){$updated=Rtl $updated}
            if($name -eq 'shell.css'){$updated=RtlShell $updated}
            if($updated -ne $original){
                $relative=$file.Substring($target.Root.TrimEnd('\').Length).TrimStart('\','/')
                $backupPath=Join-Path $backupFiles $relative
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
                [IO.File]::WriteAllText($backupPath,$original,$utf8)
                # Write beside the target and move into place so a failed write cannot leave a
                # partially translated source file. Keep the original backup until commit.
                $tempPath=$file+'.apkstart-hebrew.tmp'
                try {
                    [IO.File]::WriteAllText($tempPath,$updated,$utf8)
                    if(Test-Path -LiteralPath $file){
                        [IO.File]::Replace($tempPath,$file,$null,$true)
                    } else {
                        [IO.File]::Move($tempPath,$file)
                    }
                    $patchedHash=HashFile $file
                    $manifest.Files+= [pscustomobject]@{RelativePath=$relative;BackupPath=$backupPath;BackupHash=(HashFile $backupPath);PatchedHash=$patchedHash}
                    $manifest.Replacements+=$count;$changed++
                } catch {
                    if(Test-Path -LiteralPath $backupPath){Restore-FileAtomic $backupPath $file}
                    throw
                } finally {
                    if(Test-Path -LiteralPath $tempPath){Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue}
                }
            }
        }
        if($changed -eq 0){throw 'לא נמצאו מחרוזות מתאימות. לא בוצע שינוי.'}
        $manifestPath=Join-Path $backup 'manifest.json'
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
        New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
        @{ManifestPath=$manifestPath} | ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
        Log ("התרגום הוחל ב-"+$changed+" קבצים; "+$manifest.Replacements+" מופעים הוחלפו.") 'success'
        Log ('גיבוי: '+$backup) 'success'
        Log 'התרגום חלקי בשלב זה. מחרוזות שאינן במילון נשארו בשפת המקור.' 'warning'
        [Windows.Forms.MessageBox]::Show('החלת התרגום הסתיימה. פתח את ApkStart ובדוק את הממשק.','הסתיים') | Out-Null
    } catch {
        Log ('החלה נכשלה: '+$_.Exception.Message) 'error'
        foreach($entry in $manifest.Files){try{$rollbackDest=Join-Path $target.Root (Get-SafeRelativePath ([string]$entry.RelativePath));if((Test-Path -LiteralPath $rollbackDest -PathType Leaf) -and (HashFile $rollbackDest) -eq [string]$entry.PatchedHash -and (Test-Path -LiteralPath $entry.BackupPath -PathType Leaf) -and (HashFile $entry.BackupPath) -eq [string]$entry.BackupHash){Restore-FileAtomic $entry.BackupPath $rollbackDest}}catch{Log ('לא ניתן היה להשלים שחזור אוטומטי של קובץ: '+$entry.RelativePath) 'error'}}
    }
}
function Show-RestorePreview {
    param([object[]]$Items,[string]$TargetRoot,[string]$Version)
    $ready=@($Items | Where-Object {$_.CanRestore}).Count
    $skipped=$Items.Count-$ready
    $dialog=New-Object Windows.Forms.Form
    $dialog.Text='בדיקת שחזור לפני אישור'
    $dialog.Size=New-Object Drawing.Size(850,540)
    $dialog.MinimumSize=New-Object Drawing.Size(720,420)
    $dialog.StartPosition='CenterParent'
    $dialog.RightToLeft='Yes';$dialog.RightToLeftLayout=$true
    $summary=New-Object Windows.Forms.Label
    $summary.Text=('סה״כ בגיבוי: '+$Items.Count+' קבצים    |    ניתן לשחזר: '+$ready+'    |    צפויים להידלג: '+$skipped+[Environment]::NewLine+'התקנה: '+$TargetRoot+'    |    גרסה בגיבוי: '+$Version)
    $summary.Location=New-Object Drawing.Point(14,12);$summary.Size=New-Object Drawing.Size(805,48);$summary.Anchor='Top,Left,Right'
    $dialog.Controls.Add($summary)
    $list=New-Object Windows.Forms.ListView
    $list.Location=New-Object Drawing.Point(14,68);$list.Size=New-Object Drawing.Size(805,350)
    $list.Anchor='Top,Bottom,Left,Right';$list.View='Details';$list.FullRowSelect=$true
    $list.GridLines=$true;$list.RightToLeft='Yes';$list.RightToLeftLayout=$true
    [void]$list.Columns.Add('קובץ',570)
    [void]$list.Columns.Add('תוצאה צפויה',205)
    foreach($item in $Items){
        $row=New-Object Windows.Forms.ListViewItem([string]$item.RelativePath)
        [void]$row.SubItems.Add([string]$item.Status)
        if($item.CanRestore){$row.ForeColor=[Drawing.Color]::DarkGreen}else{$row.ForeColor=[Drawing.Color]::Firebrick}
        [void]$list.Items.Add($row)
    }
    $dialog.Controls.Add($list)
    $note=New-Object Windows.Forms.Label
    $note.Text='הבדיקה אינה מבטיחה שקובץ לא ישתנה ברגע האחרון; לפני כל כתיבה תיבדק שוב טביעת SHA-256.'
    $note.Location=New-Object Drawing.Point(14,426);$note.Size=New-Object Drawing.Size(805,28);$note.Anchor='Bottom,Left,Right'
    $dialog.Controls.Add($note)
    $ok=New-Object Windows.Forms.Button
    $ok.Text='אשר שחזור';$ok.Enabled=($ready -gt 0);$ok.DialogResult=[Windows.Forms.DialogResult]::OK
    $ok.Location=New-Object Drawing.Point(585,458);$ok.Size=New-Object Drawing.Size(110,30);$ok.Anchor='Bottom,Right'
    $dialog.Controls.Add($ok)
    $cancel=New-Object Windows.Forms.Button
    $cancel.Text='ביטול';$cancel.DialogResult=[Windows.Forms.DialogResult]::Cancel
    $cancel.Location=New-Object Drawing.Point(705,458);$cancel.Size=New-Object Drawing.Size(110,30);$cancel.Anchor='Bottom,Right'
    $dialog.Controls.Add($cancel)
    $dialog.AcceptButton=$ok;$dialog.CancelButton=$cancel
    return ($dialog.ShowDialog($form) -eq [Windows.Forms.DialogResult]::OK)
}

function Restore {
    if (Get-Process -Name 'ApkStart' -ErrorAction SilentlyContinue) { Log 'ApkStart עדיין פועל. סגור אותו לפני שחזור קבצים.' 'warning'; return }
    try{
        $chosenManifest=Select-BackupManifest
        if([string]::IsNullOrWhiteSpace($chosenManifest)){Log 'בחירת הגיבוי בוטלה.' 'warning';return}
        $backupsRoot=Join-Path $stateDir 'Backups'
        $manifestPath=Get-FullPath $chosenManifest
        if(-not (Test-PathWithin $manifestPath $backupsRoot) -or (Split-Path -Leaf $manifestPath) -cne 'manifest.json'){throw 'נתיב המניפסט חורג מתיקיית הגיבויים.'}
        if(!(Test-Path -LiteralPath $manifestPath -PathType Leaf)){throw 'קובץ המניפסט חסר.'}
        $m=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if([int]$m.Schema -ne 1 -or [string]::IsNullOrWhiteSpace([string]$m.TargetRoot) -or @($m.Files).Count -eq 0){throw 'מבנה המניפסט אינו נתמך או אינו שלם.'}
        $targetRoot=Get-FullPath ([string]$m.TargetRoot)
        if(!(Test-Path -LiteralPath $targetRoot -PathType Container) -or !(Test-Path -LiteralPath (Join-Path $targetRoot 'src/ui/index.html') -PathType Leaf) -or !(Test-Path -LiteralPath (Join-Path $targetRoot 'src/ui/app.js') -PathType Leaf)){throw 'תיקיית ההתקנה המקורית אינה קיימת או שמבנה ApkStart אינו מזוהה.'}
        # A single global "last backup" must never silently restore another installation.
        $selected=Resolve-Target $pathBox.Text
        if(!$selected -or $selected.Status -in @('InvalidPath','Unknown','MSIX','ASAR')){throw 'בחר תחילה את תיקיית ApkStart שעבורה נוצר הגיבוי, ולחץ על סריקה.'}
        if(-not [string]::Equals((Get-FullPath $selected.Root).TrimEnd('\\'),$targetRoot.TrimEnd('\\'),[StringComparison]::OrdinalIgnoreCase)){
            throw ('הגיבוי שנבחר שייך להתקנה אחרת: '+$targetRoot+'. בחר את ההתקנה הנכונה ולחץ על שחזור מחדש.')
        }
        $backupRoot=Get-FullPath (Split-Path -Parent $manifestPath)
        if(-not (Test-PathWithin $backupRoot $backupsRoot) -or (Join-Path $backupRoot 'manifest.json') -cne $manifestPath){throw 'תיקיית הגיבוי אינה תקינה.'}
        $backupFiles=Join-Path $backupRoot 'files'
        $seenPaths=@{}
        foreach($entry in $m.Files){
            $relative=Get-SafeRelativePath ([string]$entry.RelativePath)
            $duplicateKey=$relative.ToLowerInvariant()
            if($seenPaths.ContainsKey($duplicateKey)){throw ('המניפסט מכיל קובץ כפול: '+$relative)}
            $seenPaths[$duplicateKey]=$true
        }
        $preview=New-Object System.Collections.Generic.List[object]
        foreach($entry in $m.Files){
            $relative=Get-SafeRelativePath ([string]$entry.RelativePath)
            $dest=Join-Path $targetRoot $relative
            $backupPath=Join-Path $backupFiles $relative
            if(-not (Test-PathWithin $dest $targetRoot) -or -not (Test-PathWithin $backupPath $backupFiles)){throw 'נתיב קובץ חורג מתיקיית היעד או הגיבוי.'}
            $canRestore=$false;$status=''
            if(!(Test-Path -LiteralPath $dest -PathType Leaf)){$status='קובץ היעד חסר'}
            elseif(!(Test-Path -LiteralPath $backupPath -PathType Leaf)){$status='קובץ הגיבוי חסר'}
            elseif(-not [string]::IsNullOrWhiteSpace([string]$entry.BackupHash) -and (HashFile $backupPath) -ne [string]$entry.BackupHash){$status='עותק הגיבוי השתנה'}
            elseif((HashFile $dest) -ne [string]$entry.PatchedHash){$status='קובץ היעד השתנה מאז ההחלה'}
            else{$canRestore=$true;$status='מוכן לשחזור'}
            if([string]::IsNullOrWhiteSpace([string]$entry.BackupHash) -and $canRestore){$status='מוכן לשחזור (גיבוי ישן)'}
            $preview.Add([pscustomobject]@{RelativePath=$relative;CanRestore=$canRestore;Status=$status;Destination=$dest;BackupPath=$backupPath;Entry=$entry})
        }
        if(-not (Show-RestorePreview -Items @($preview) -TargetRoot $targetRoot -Version ([string]$m.Version))){Log 'השחזור בוטל לאחר בדיקת הקבצים.' 'warning';return}
        $ok=0;$skip=0
        foreach($item in $preview){
            if(-not $item.CanRestore){Log ('דילוג: '+$item.RelativePath+' — '+$item.Status) 'warning';$skip++;continue}
            if(-not (Test-Path -LiteralPath $item.Destination -PathType Leaf) -or -not (Test-Path -LiteralPath $item.BackupPath -PathType Leaf)){$skip++;Log ('דילוג: הקובץ נעלם לאחר בדיקת הקדם: '+$item.RelativePath) 'warning';continue}
            if(-not [string]::IsNullOrWhiteSpace([string]$item.Entry.BackupHash) -and (HashFile $item.BackupPath) -ne [string]$item.Entry.BackupHash){$skip++;Log ('דילוג: עותק הגיבוי השתנה לאחר בדיקת הקדם: '+$item.RelativePath) 'warning';continue}
            if((HashFile $item.Destination) -ne [string]$item.Entry.PatchedHash){$skip++;Log ('דילוג: קובץ היעד השתנה לאחר בדיקת הקדם: '+$item.RelativePath) 'warning';continue}
            Restore-FileAtomic $item.BackupPath $item.Destination
            $ok++
        }
        Log ("שוחזרו "+$ok+" קבצים; דולגו "+$skip+".") 'success'
        if($skip -eq 0 -and (Test-Path -LiteralPath $stateFile -PathType Leaf)){$active=Get-Content -LiteralPath $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json;if([string]::Equals([string]$active.ManifestPath,$manifestPath,[StringComparison]::OrdinalIgnoreCase)){Remove-Item -LiteralPath $stateFile -Force}}
        Update-ActionState
    }catch{Log ('השחזור נכשל: '+$_.Exception.Message) 'error';Update-ActionState}
}

$form=New-Object Windows.Forms.Form
$form.Text='ApkStart Hebrew | תרגום לעברית';$form.Size=New-Object Drawing.Size(830,640);$form.MinimumSize=New-Object Drawing.Size(780,570)
$form.StartPosition='CenterScreen';$form.RightToLeft='Yes';$form.RightToLeftLayout=$true;$form.Font=New-Object Drawing.Font('Segoe UI',9);$form.BackColor=[Drawing.Color]::FromArgb(246,248,251)
$header=New-Object Windows.Forms.Panel;$header.Dock='Top';$header.Height=88;$header.BackColor=[Drawing.Color]::FromArgb(24,34,48);$form.Controls.Add($header)
$heading=New-Object Windows.Forms.Label;$heading.Text='ApkStart בעברית';$heading.ForeColor=[Drawing.Color]::White;$heading.Font=New-Object Drawing.Font('Segoe UI',20,[Drawing.FontStyle]::Bold);$heading.AutoSize=$true;$heading.Location=New-Object Drawing.Point(26,12);$header.Controls.Add($heading)
$sub=New-Object Windows.Forms.Label;$sub.Text='תרגום ממשק ויישור RTL — בלי לשנות את מנוע Android';$sub.ForeColor=[Drawing.Color]::FromArgb(205,215,228);$sub.AutoSize=$true;$sub.Location=New-Object Drawing.Point(29,54);$header.Controls.Add($sub)
$main=New-Object Windows.Forms.Panel;$main.Dock='Fill';$main.Padding=New-Object Windows.Forms.Padding(20);$form.Controls.Add($main)
$lbl=New-Object Windows.Forms.Label;$lbl.Text='תיקיית ApkStart:';$lbl.AutoSize=$true;$lbl.Location=New-Object Drawing.Point(22,18);$main.Controls.Add($lbl)
$pathBox=New-Object Windows.Forms.TextBox;$pathBox.Location=New-Object Drawing.Point(22,43);$pathBox.Size=New-Object Drawing.Size(540,27);$pathBox.RightToLeft='No';$main.Controls.Add($pathBox)
$browse=New-Object Windows.Forms.Button;$browse.Text='עיון…';$browse.Location=New-Object Drawing.Point(572,41);$browse.Size=New-Object Drawing.Size(78,30);$main.Controls.Add($browse)
$detect=New-Object Windows.Forms.Button;$detect.Text='זיהוי אוטומטי';$detect.Location=New-Object Drawing.Point(658,41);$detect.Size=New-Object Drawing.Size(120,30);$main.Controls.Add($detect)
$statusLabel=New-Object Windows.Forms.Label;$statusLabel.Text='טרם בוצעה סריקה';$statusLabel.AutoSize=$true;$statusLabel.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold);$statusLabel.Location=New-Object Drawing.Point(22,82);$main.Controls.Add($statusLabel)
$versionLabel=New-Object Windows.Forms.Label;$versionLabel.Text='גרסה: —';$versionLabel.AutoSize=$true;$versionLabel.Location=New-Object Drawing.Point(22,108);$main.Controls.Add($versionLabel)
$scan=New-Object Windows.Forms.Button;$scan.Text='סריקה';$scan.Location=New-Object Drawing.Point(22,140);$scan.Size=New-Object Drawing.Size(100,36);$main.Controls.Add($scan)
$apply=New-Object Windows.Forms.Button;$apply.Text='החלת עברית';$apply.Enabled=$false;$apply.Location=New-Object Drawing.Point(132,140);$apply.Size=New-Object Drawing.Size(130,36);$apply.BackColor=[Drawing.Color]::FromArgb(16,130,91);$apply.ForeColor=[Drawing.Color]::White;$apply.FlatStyle='Flat';$main.Controls.Add($apply)
$restore=New-Object Windows.Forms.Button;$restore.Text='היסטוריית גיבויים…';$restore.Enabled=(@(Get-BackupHistory).Count -gt 0);$restore.Location=New-Object Drawing.Point(272,140);$restore.Size=New-Object Drawing.Size(150,36);$main.Controls.Add($restore)
$exportBackup=New-Object Windows.Forms.Button;$exportBackup.Text='ייצוא ZIP…';$exportBackup.Enabled=(@(Get-BackupHistory).Count -gt 0);$exportBackup.Location=New-Object Drawing.Point(432,140);$exportBackup.Size=New-Object Drawing.Size(105,36);$main.Controls.Add($exportBackup)
$importBackup=New-Object Windows.Forms.Button;$importBackup.Text='ייבוא ZIP…';$importBackup.Location=New-Object Drawing.Point(547,140);$importBackup.Size=New-Object Drawing.Size(105,36);$main.Controls.Add($importBackup)
$note=New-Object Windows.Forms.Label;$note.Text='התרגום עדיין חלקי. MSIX ו-app.asar מזוהים אך אינם משתנים בשלב זה.';$note.AutoSize=$false;$note.Size=New-Object Drawing.Size(750,32);$note.Location=New-Object Drawing.Point(22,190);$note.ForeColor=[Drawing.Color]::DarkGoldenrod;$main.Controls.Add($note)
$logTitle=New-Object Windows.Forms.Label;$logTitle.Text='יומן פעולות';$logTitle.AutoSize=$true;$logTitle.Location=New-Object Drawing.Point(22,226);$main.Controls.Add($logTitle)
$logBox=New-Object Windows.Forms.RichTextBox;$logBox.Location=New-Object Drawing.Point(22,251);$logBox.Size=New-Object Drawing.Size(756,290);$logBox.Anchor='Top,Bottom,Left,Right';$logBox.ReadOnly=$true;$logBox.BackColor=[Drawing.Color]::White;$logBox.Font=New-Object Drawing.Font('Consolas',9);$logBox.RightToLeft='Yes';$main.Controls.Add($logBox)
$browse.Add_Click({$d=New-Object Windows.Forms.FolderBrowserDialog;$d.Description='בחר תיקיית ApkStart או resources/app';if($d.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){$pathBox.Text=$d.SelectedPath;Scan | Out-Null}})
$detect.Add_Click({$found=@(Detect-Targets | Where-Object { (Resolve-Target $_).Status -in @('Supported','UnsupportedVersion','UnsupportedStructure','ASAR') });if($found.Count -eq 0){Log 'לא נמצאה התקנה מזוהה. בחר תיקייה ידנית.' 'warning';return};$chosen=Select-DetectedInstall $found;if($chosen){$pathBox.Text=$chosen;Scan | Out-Null}})
$pathBox.Add_TextChanged({$script:Target=$null;$statusLabel.Text='הנתיב השתנה — יש לבצע סריקה מחדש';$statusLabel.ForeColor=[Drawing.Color]::DarkGoldenrod;Update-ActionState})
$scan.Add_Click({Scan | Out-Null});$apply.Add_Click({Apply});$restore.Add_Click({Restore})
$exportBackup.Add_Click({try{Export-BackupZip}catch{Log ('ייצוא נכשל: '+$_.Exception.Message) 'error';[Windows.Forms.MessageBox]::Show($_.Exception.Message,'ייצוא נכשל') | Out-Null};Update-ActionState})
$importBackup.Add_Click({try{Import-BackupZip}catch{Log ('ייבוא נכשל: '+$_.Exception.Message) 'error';[Windows.Forms.MessageBox]::Show($_.Exception.Message,'ייבוא נכשל') | Out-Null};Update-ActionState})
$form.Add_Shown({Update-ActionState;Log 'ברוך הבא. בחר התקנה ובצע סריקה. כפתור ההחלה יופעל רק להתקנה תואמת.';if(-not [string]::IsNullOrWhiteSpace($InitialTargetPath)){$pathBox.Text=$InitialTargetPath;Scan | Out-Null}else{$found=@(Detect-Targets | Where-Object { (Resolve-Target $_).Status -in @('Supported','UnsupportedVersion','UnsupportedStructure','ASAR') });if($found.Count -gt 0){$chosen=Select-DetectedInstall $found;if($chosen){$pathBox.Text=$chosen;Scan | Out-Null}}}})
[void]$form.ShowDialog()
