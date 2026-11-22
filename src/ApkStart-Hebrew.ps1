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
    $stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
    $backup=Join-Path $stateDir ('Backups/'+$stamp)
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
            foreach($key in $fileKeys){if($updated.Contains($key)){$count+=([regex]::Matches($updated,[regex]::Escape($key))).Count;$updated=$updated.Replace($key,$translations[$key])}}
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
                    $manifest.Files+= [pscustomobject]@{RelativePath=$relative;BackupPath=$backupPath;PatchedHash=$patchedHash}
                    $manifest.Replacements+=$count;$changed++
                } catch {
                    if(Test-Path -LiteralPath $backupPath){Copy-Item -LiteralPath $backupPath -Destination $file -Force}
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
