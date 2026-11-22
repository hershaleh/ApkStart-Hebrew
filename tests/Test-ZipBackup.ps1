$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
function Assert([bool]$ok,[string]$why){if(-not $ok){throw "ZIP integration test failed: $why"}}
function Safe([string]$p){
 if([string]::IsNullOrWhiteSpace($p) -or [IO.Path]::IsPathRooted($p)){throw 'rooted path'}
 $n=$p.Replace('/',[string][char]92);$parts=$n.Split([char]92)
 if(@($parts|Where-Object {$_ -in @('..','.','')}).Count){throw 'traversal'}
 if(-not ($n -match '^src\\ui\\(main\.js|index\.html|app\.js|shell\.html|shell\.js|manual\.html|splash\.html|splash\.js|style\.css|theme\.css|shell\.css|splash\.css)$' -or $n -ceq 'src\core\autodebug.js')){throw 'not allowlisted'}
 return $n
}
function Validate-Zip([string]$zip,[string]$stage){
 $a=[IO.Compression.ZipFile]::OpenRead($zip)
 try{
  Assert ($a.Entries.Count -ge 2 -and $a.Entries.Count -le 2001) 'entry count'
  $seen=@{};$sum=[long]0
  foreach($e in $a.Entries){
   $n=[string]$e.FullName
   if([string]::IsNullOrWhiteSpace($n) -or $n.Contains('\') -or $n.StartsWith('/') -or $n -match '^[A-Za-z]:' -or $n.Split('/').Contains('..') -or $n.Split('/').Contains('.')){throw 'unsafe ZIP path'}
   if($n.EndsWith('/') -or $seen.ContainsKey($n.ToLowerInvariant())){throw 'directory or duplicate'}
   $seen[$n.ToLowerInvariant()]=$true
   $kind=($e.ExternalAttributes -shr 16) -band 0xF000
   if($kind -eq 0xA000 -or ($kind -ne 0 -and $kind -ne 0x8000)){throw 'unsupported entry type'}
   if($n -ceq 'manifest.json'){if($e.Length -gt 2MB){throw 'manifest too big'}}
   elseif($n.StartsWith('files/')){[void](Safe $n.Substring(6))}
   else{throw 'unexpected entry'}
   $sum += [long]$e.Length;if($sum -gt 1GB){throw 'expanded size'}
  }
  $me=$a.GetEntry('manifest.json');Assert ($null -ne $me) 'manifest'
  $r=New-Object IO.StreamReader($me.Open(),[Text.Encoding]::UTF8)
  try{$m=$r.ReadToEnd()|ConvertFrom-Json}finally{$r.Dispose()}
  Assert ([int]$m.Schema -eq 1) 'schema'
  $expected=@{'manifest.json'=$true}
  foreach($f in $m.Files){$k=('files/'+(Safe ([string]$f.RelativePath)).Replace([string][char]92,'/')).ToLowerInvariant();if($expected.ContainsKey($k)){throw 'duplicate manifest path'};$expected[$k]=$true}
  Assert ($expected.Count -eq $a.Entries.Count) 'manifest exact count'
  foreach($e in $a.Entries){Assert ($expected.ContainsKey($e.FullName.ToLowerInvariant())) 'manifest membership'}
  New-Item -ItemType Directory -Path $stage -Force|Out-Null
  foreach($e in $a.Entries){
   if($e.FullName -ceq 'manifest.json'){$dest=Join-Path $stage 'manifest.json'}else{$dest=Join-Path (Join-Path $stage 'files') (Safe $e.FullName.Substring(6))}
   $full=[IO.Path]::GetFullPath($dest);$prefix=[IO.Path]::GetFullPath($stage).TrimEnd('\')+'\'
   Assert $full.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase) 'contained extraction'
   New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force|Out-Null
   $src=$e.Open();try{$out=[IO.File]::Open($dest,[IO.FileMode]::CreateNew);try{$src.CopyTo($out)}finally{$out.Dispose()}}finally{$src.Dispose()}
  }
  $m=Get-Content (Join-Path $stage 'manifest.json') -Raw|ConvertFrom-Json
  foreach($f in $m.Files){$p=Join-Path (Join-Path $stage 'files') (Safe $f.RelativePath);Assert ((Get-FileHash $p -Algorithm SHA256).Hash -eq $f.BackupHash) 'SHA-256'}
  return $m
 }finally{$a.Dispose()}
}
$w=Join-Path ([IO.Path]::GetTempPath()) ('ApkStartZipTest-'+[guid]::NewGuid().ToString('N'))
try{
 $files=Join-Path $w 'backup/files/src/ui';New-Item -ItemType Directory -Path $files -Force|Out-Null
 $payload=Join-Path $files 'index.html';[IO.File]::WriteAllText($payload,'original bytes')
 $hash=(Get-FileHash $payload -Algorithm SHA256).Hash
 $manifest=Join-Path $w 'backup/manifest.json';New-Item -ItemType Directory -Path (Split-Path $manifest) -Force|Out-Null
 ([ordered]@{Schema=1;TargetRoot=$w;Version='0.6.3';Files=@([pscustomobject]@{RelativePath='src\ui\index.html';BackupHash=$hash;PatchedHash=('A'*64)})})|ConvertTo-Json -Depth 8|Set-Content $manifest
 $zip=Join-Path $w 'roundtrip.zip';$a=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
 try{foreach($x in @(@{p=$manifest;n='manifest.json'},@{p=$payload;n='files/src/ui/index.html'})){$e=$a.CreateEntry($x.n);$i=[IO.File]::OpenRead($x.p);try{$o=$e.Open();try{$i.CopyTo($o)}finally{$o.Dispose()}}finally{$i.Dispose()}}}finally{$a.Dispose()}
 $m=Validate-Zip $zip (Join-Path $w 'stage');Assert ($m.Version -eq '0.6.3') 'roundtrip manifest'
 Assert ([IO.File]::ReadAllText((Join-Path $w 'stage/files/src/ui/index.html')) -ceq 'original bytes') 'roundtrip file bytes'
 $bad=Join-Path $w 'bad.zip';$a=[IO.Compression.ZipFile]::Open($bad,[IO.Compression.ZipArchiveMode]::Create);try{$e=$a.CreateEntry('../escape.txt');$o=New-Object IO.StreamWriter($e.Open());$o.Write('x');$o.Dispose()}finally{$a.Dispose()}
 $rejected=$false;try{Validate-Zip $bad (Join-Path $w 'bad-stage')|Out-Null}catch{$rejected=$true};Assert $rejected 'path traversal rejection'
 $tampered=Join-Path $w 'tampered.zip';$a=[IO.Compression.ZipFile]::Open($tampered,[IO.Compression.ZipArchiveMode]::Create)
 try{foreach($x in @(@{p=$manifest;n='manifest.json'},@{p=$payload;n='files/src/ui/index.html'})){$e=$a.CreateEntry($x.n);$i=[IO.File]::OpenRead($x.p);try{$o=$e.Open();try{$i.CopyTo($o)}finally{$o.Dispose()}}finally{$i.Dispose()}}}finally{$a.Dispose()}
 $m=Get-Content $manifest -Raw|ConvertFrom-Json;$m.Files[0].BackupHash=('0'*64);$m|ConvertTo-Json -Depth 8|Set-Content $manifest
 # Tampered ZIP must fail integrity check; create a new archive with the altered manifest and original payload.
 $tampered2=Join-Path $w 'tampered2.zip';$a=[IO.Compression.ZipFile]::Open($tampered2,[IO.Compression.ZipArchiveMode]::Create)
 try{foreach($x in @(@{p=$manifest;n='manifest.json'},@{p=$payload;n='files/src/ui/index.html'})){$e=$a.CreateEntry($x.n);$i=[IO.File]::OpenRead($x.p);try{$o=$e.Open();try{$i.CopyTo($o)}finally{$o.Dispose()}}finally{$i.Dispose()}}}finally{$a.Dispose()}
 $rejected=$false;try{Validate-Zip $tampered2 (Join-Path $w 'tampered-stage')|Out-Null}catch{$rejected=$true};Assert $rejected 'SHA-256 tampering rejection'
 Write-Host 'ZIP backup integration tests passed: roundtrip, ZIP-slip, SHA-256 tampering.'
}finally{if(Test-Path $w){Remove-Item $w -Recurse -Force -ErrorAction SilentlyContinue}}
