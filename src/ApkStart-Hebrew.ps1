#requires -Version 5.1
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
function Resolve-Target([string]$path) {
    if (!$path) { return $null }
    $path=[IO.Path]::GetFullPath($path.Trim().Trim('"'))
    if ($path -match '(?i)\\WindowsApps\\') { return [pscustomobject]@{Status='MSIX';Root=$path;Ui=$null;Version='—';Message='זוהתה התקנת Microsoft Store / MSIX. חבילה חתומה לא תשונה.'} }
    foreach ($candidate in @($path,(Join-Path $path 'resources/app'),(Join-Path $path 'app'))) {
        $ui=Join-Path $candidate 'src/ui'
        if ((Test-Path (Join-Path $ui 'index.html')) -and (Test-Path (Join-Path $ui 'app.js'))) {
            $version='לא ידועה'; $pkg=Join-Path $candidate 'package.json'
            if (Test-Path $pkg) { try { $version=(Get-Content $pkg -Raw -Encoding UTF8 | ConvertFrom-Json).version } catch {} }
            return [pscustomobject]@{Status='Supported';Root=$candidate;Ui=$ui;Version=$version;Message='נמצאו קובצי ממשק פרוסים.'}
        }
    }
    if ((Test-Path (Join-Path $path 'resources/app.asar')) -or (Test-Path (Join-Path $path 'app.asar'))) {
        return [pscustomobject]@{Status='ASAR';Root=$path;Ui=$null;Version='—';Message='נמצא app.asar. הכלי אינו משנה ארכיוני ASAR בשלב זה.'}
    }
    return [pscustomobject]@{Status='Unknown';Root=$path;Ui=$null;Version='—';Message='לא נמצאו קובצי ממשק נתמכים. בחר את תיקיית ההתקנה או resources/app.'}
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
function Scan {
    $target=Resolve-Target $pathBox.Text
    $script:Target=$target
    if(!$target){Log 'בחר תיקיית ApkStart.' 'warning';return $null}
    $versionLabel.Text='גרסה: '+$target.Version
    if($target.Status -eq 'Supported'){$statusLabel.Text='נמצאה התקנה נתמכת';$statusLabel.ForeColor=[Drawing.Color]::DarkGreen;Log ($target.Message+' '+$target.Root) 'success'}
    elseif($target.Status -eq 'ASAR'){$statusLabel.Text='נדרש טיפול ייעודי ב-ASAR';$statusLabel.ForeColor=[Drawing.Color]::DarkGoldenrod;Log $target.Message 'warning'}
    else{$statusLabel.Text='התקנה אינה נתמכת';$statusLabel.ForeColor=[Drawing.Color]::Firebrick;Log $target.Message 'error'}
    return $target
}
function Rtl([string]$text) {
    if($text.Contains('APKSTART-HEBREW:RTL')){return $text}
    $css=@'

/* APKSTART-HEBREW:RTL */
html[lang],body{direction:rtl}
body{text-align:right}
.titlebar,.toolbar,.modal-main,.statusbar{direction:rtl}
.titlebar-actions{direction:ltr}
.toolbar-right{margin-inline-start:auto}
.search,.set-search-wrap{direction:rtl}
.search input,.set-search{text-align:right;direction:rtl}
.set-nav{border-right:0;border-left:1px solid var(--line,#e5e7eb)}
.status-left,.status-right,.ctxmenu,.toast-wrap{direction:rtl}
.ctxmenu{text-align:right}
input[type="text"],input[type="search"],textarea{text-align:right}
input[type="url"],input[type="number"],input[type="password"],code,pre,.mono,.ltr,[dir="ltr"]{direction:ltr;text-align:left;unicode-bidi:plaintext}
'@
    return $text+$css
}
function Apply {
    if (Get-Process -Name 'ApkStart' -ErrorAction SilentlyContinue) { Log 'ApkStart עדיין פועל. סגור אותו לפני החלת התרגום.' 'warning'; return }
    $target=Scan
    if(!$target -or $target.Status -ne 'Supported'){return}
    $nl=[Environment]::NewLine
    $msg='הכלי יגבה וישנה קובצי ממשק בלבד בתיקייה:'+$nl+$target.Root+$nl+$nl+'יש לסגור את ApkStart לפני ההמשך. להחיל את התרגום?'
    if([Windows.Forms.MessageBox]::Show($msg,'אישור החלת עברית',[Windows.Forms.MessageBoxButtons]::YesNo) -ne [Windows.Forms.DialogResult]::Yes){return}
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup=Join-Path $stateDir ('Backups/'+$stamp)
    $backupFiles=Join-Path $backup 'files'
    New-Item -ItemType Directory -Path $backupFiles -Force | Out-Null
    $manifest=[ordered]@{Schema=1;TargetRoot=$target.Root;Version=$target.Version;BackupRoot=$backup;Files=@();Replacements=0}
    $translations=@{};foreach($p in $map.PSObject.Properties){$translations[$p.Name]=[string]$p.Value}
    $keys=@($translations.Keys | Sort-Object { $_.Length } -Descending)
    $names=@('index.html','app.js','shell.html','shell.js','manual.html','style.css','theme.css','shell.css')
    $changed=0
    try {
        foreach($name in $names){
            $file=Join-Path $target.Ui $name
            if(!(Test-Path $file)){continue}
            $original=[IO.File]::ReadAllText($file,[Text.Encoding]::UTF8)
            if($original.Contains('APKSTART-HEBREW')){throw ('נמצא תרגום קודם בקובץ '+$name+'. יש לשחזר לפני החלה חוזרת.')}
            $updated=$original;$count=0
            foreach($key in $keys){if($updated.Contains($key)){$count+=([regex]::Matches($updated,[regex]::Escape($key))).Count;$updated=$updated.Replace($key,$translations[$key])}}
            if($name -in @('style.css','theme.css','shell.css')){$updated=Rtl $updated}
            if($updated -ne $original){
                $relative=$file.Substring($target.Root.TrimEnd('\').Length).TrimStart('\','/')
                $backupPath=Join-Path $backupFiles $relative
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupPath) -Force | Out-Null
                [IO.File]::WriteAllText($backupPath,$original,$utf8)
                [IO.File]::WriteAllText($file,$updated,$utf8)
                $manifest.Files+= [pscustomobject]@{RelativePath=$relative;BackupPath=$backupPath;PatchedHash=(HashFile $file)}
                $manifest.Replacements+=$count;$changed++
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
        foreach($entry in $manifest.Files){try{Copy-Item -LiteralPath $entry.BackupPath -Destination (Join-Path $target.Root $entry.RelativePath) -Force}catch{}}
    }
}
function Restore {
    if (Get-Process -Name 'ApkStart' -ErrorAction SilentlyContinue) { Log 'ApkStart עדיין פועל. סגור אותו לפני שחזור קבצים.' 'warning'; return }
    if(!(Test-Path $stateFile)){Log 'לא נמצא גיבוי אחרון.' 'warning';return}
    try{
        $state=Get-Content $stateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $m=Get-Content $state.ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $ok=0;$skip=0
        foreach($entry in $m.Files){
            $dest=Join-Path $m.TargetRoot $entry.RelativePath
            if(!(Test-Path $dest) -or !(Test-Path $entry.BackupPath)){$skip++;continue}
            if((HashFile $dest) -ne $entry.PatchedHash){Log ('דילוג: הקובץ השתנה מאז ההחלה: '+$entry.RelativePath) 'warning';$skip++;continue}
            Copy-Item -LiteralPath $entry.BackupPath -Destination $dest -Force;$ok++
        }
        Log ("שוחזרו "+$ok+" קבצים; דולגו "+$skip+".") 'success'
        if($skip -eq 0){Remove-Item $stateFile -Force}
    }catch{Log ('השחזור נכשל: '+$_.Exception.Message) 'error'}
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
$apply=New-Object Windows.Forms.Button;$apply.Text='החלת עברית';$apply.Location=New-Object Drawing.Point(132,140);$apply.Size=New-Object Drawing.Size(130,36);$apply.BackColor=[Drawing.Color]::FromArgb(16,130,91);$apply.ForeColor=[Drawing.Color]::White;$apply.FlatStyle='Flat';$main.Controls.Add($apply)
$restore=New-Object Windows.Forms.Button;$restore.Text='שחזור המקור';$restore.Location=New-Object Drawing.Point(272,140);$restore.Size=New-Object Drawing.Size(120,36);$main.Controls.Add($restore)
$note=New-Object Windows.Forms.Label;$note.Text='התרגום עדיין חלקי. MSIX ו-app.asar מזוהים אך אינם משתנים בשלב זה.';$note.AutoSize=$false;$note.Size=New-Object Drawing.Size(750,32);$note.Location=New-Object Drawing.Point(22,190);$note.ForeColor=[Drawing.Color]::DarkGoldenrod;$main.Controls.Add($note)
$logTitle=New-Object Windows.Forms.Label;$logTitle.Text='יומן פעולות';$logTitle.AutoSize=$true;$logTitle.Location=New-Object Drawing.Point(22,226);$main.Controls.Add($logTitle)
$logBox=New-Object Windows.Forms.RichTextBox;$logBox.Location=New-Object Drawing.Point(22,251);$logBox.Size=New-Object Drawing.Size(756,290);$logBox.Anchor='Top,Bottom,Left,Right';$logBox.ReadOnly=$true;$logBox.BackColor=[Drawing.Color]::White;$logBox.Font=New-Object Drawing.Font('Consolas',9);$logBox.RightToLeft='Yes';$main.Controls.Add($logBox)
$browse.Add_Click({$d=New-Object Windows.Forms.FolderBrowserDialog;$d.Description='בחר תיקיית ApkStart או resources/app';if($d.ShowDialog() -eq [Windows.Forms.DialogResult]::OK){$pathBox.Text=$d.SelectedPath;Scan | Out-Null}})
$detect.Add_Click({foreach($p in (Detect-Targets)){$t=Resolve-Target $p;if($t.Status -eq 'Supported'){$pathBox.Text=$p;Scan | Out-Null;return}};Log 'לא נמצאה התקנה רגילה. בחר תיקייה ידנית.' 'warning'})
$scan.Add_Click({Scan | Out-Null});$apply.Add_Click({Apply});$restore.Add_Click({Restore})
$form.Add_Shown({Log 'ברוך הבא. סגור את ApkStart לפני החלה או שחזור.';foreach($p in (Detect-Targets)){$t=Resolve-Target $p;if($t.Status -eq 'Supported'){$pathBox.Text=$p;Scan | Out-Null;break}}})
[void]$form.ShowDialog()
