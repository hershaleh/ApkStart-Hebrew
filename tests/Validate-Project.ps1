$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$script = Join-Path $root 'src/ApkStart-Hebrew.ps1'
$dict = Join-Path $root 'translations/he-IL.json'
$launcher = Join-Path $root 'Run-ApkStart-Hebrew.cmd'
$appAllowPath = Join-Path $root 'translations/app-js-allowlist.json'
$manualAllowPath = Join-Path $root 'translations/manual-allowlist.json'
$shellAllowPath = Join-Path $root 'translations/shell-ui-allowlist.json'
$mainAllowPath = Join-Path $root 'translations/main-process-allowlist.json'
$autoDebugAllowPath = Join-Path $root 'translations/autodebug-allowlist.json'

foreach ($path in @($script, $dict, $launcher, $appAllowPath, $manualAllowPath, $shellAllowPath, $mainAllowPath, $autoDebugAllowPath)) {
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
foreach ($key in @('没有发现影响使用的问题。运行时、adb 授权、磁盘、数据分区、快照与设置冲突都检查过了。','上次检测',' · 一切正常',' 项待处理',' 项命中','处理','教程','一键修复全部',' 个严重',' 项待修复',' 项提示','建议改到纯英文目录','在 设置 → 系统集成 里修改「运行时数据目录」，再重启软件。')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Diagnostic UI translation missing: $key" }
    if ($null -eq @($appAllow | Where-Object { $_ -ceq $key })[0]) { throw "Diagnostic UI phrase is not allowlisted: $key" }
}
# Additional environment, connectivity and APK-drop labels found in the renderer audit.
foreach ($key in @('拖入 APK 文件，或点击选择',' · 独立窗口已启用','虚拟机未联网','（无硬件加速，将回退软件模拟）','Wi-Fi 已开','Wi-Fi 已关',' · 飞行模式','重启电脑后硬件加速才会生效，回来点「开始体检」确认','可以点「开始体检」确认结果','桌面与开始菜单入口正常','已联网')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Renderer environment translation missing: $key" }
    if ($null -eq @($appAllow | Where-Object { $_ -ceq $key })[0]) { throw "Renderer environment phrase is not allowlisted: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Renderer environment phrase has no Hebrew translation: $key" }
}

# Reviewed main-window settings/status labels and help text.
foreach ($key in @('正在检查…','专用 adb 服务端口 5044','看不到这台安卓设备 —— 这是刻意的隔离。想连的话用','重置安卓数据','小 · 720 × 1280','中 · 900 × 1600','大 · 1080 × 1920','超大 · 1440 × 2560','窗口模式下可拖动边框任意缩放；这里调的是 Android 内部渲染尺寸，越小越省性能。','流畅 · 540 × 960','均衡 · 720 × 1280','高清 · 1080 × 1920','正在读取数据分区…','English（镜像原生）','容器细节（高级）','轻量容器','正在读取驱动…','刷新','一键流畅优化','安卓虚拟机内部的无线网，关掉可省一点 CPU。','飞行模式','扫码关注公众号','Windows 原生多窗口 · 多开（实验性）','1 · 平衡（推荐）','2 · 多开更稳','3 · 最多并存')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Main-window translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Main-window translation has no Hebrew text: $key" }
}

foreach ($key in @('正在运行','停止运行时',' · 已是精简状态')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Dynamic card/runtime translation missing: $key" }
    if ($null -eq @($appAllow | Where-Object { $_ -ceq $key })[0]) { throw "Dynamic card/runtime string is not allowlisted: $key" }
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



# Automatic diagnostic engine: only explicitly reviewed UI literals may be translated.
$autoDebugAllow = Get-Content -LiteralPath $autoDebugAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($autoDebugAllow).Count -lt 55) { throw 'Reviewed automatic-diagnostics allowlist unexpectedly small.' }
foreach ($key in $autoDebugAllow) {
    if ($null -eq $translations.PSObject.Properties[[string]$key]) { throw "Automatic-diagnostics allowlist key is missing from dictionary: $key" }
    if ($translations[[string]$key] -notmatch '[\u0590-\u05FF]') { throw "Automatic-diagnostics phrase has no Hebrew translation: $key" }
}
if (-not $source.Contains('Join-Path $target.Root ''src/core/autodebug.js''') -or -not $source.Contains('autodebug-allowlist.json') -or -not $source.Contains("'autodebug.js'") -or -not $source.Contains('complete JavaScript string/template literals only')) {
    throw 'Diagnostic engine translations must use their dedicated reviewed allowlist.'
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



# Additional reviewed manual paragraphs and troubleshooting instructions.
foreach ($key in @('让安卓应用像 Windows 原生软件一样安装、出现在桌面、双击即用。','本手册先教你怎么用，再按「症状」给出可照做的解决方案。所有步骤都对应软件里真实存在的按钮和菜单。','注：本项目为早期版本，作者业余时间维护，开源免费、无广告。遇到问题是正常的，本手册就是为此准备的。','务必用最新版（当前 0.6.3）','只想先试试，首次启动再联网下载运行时','能被 Windows 搜到','Windows 原生多窗口多开（实验性）','本机体检、驱动/兼容补丁、自动检测','桌面与应用、文件互通、系统集成','更新与下载源、加速镜像、下载线程数','资源策略、画质、数据分区、系统语言、快照、开机预热','显示模式、自动全屏、屏幕方向、平板排版、窗口承载方式','运行时与环境、一键完成、开机自启、磁盘占用与清理','后台每 10 分钟把机器查一遍，按六类列问题，每条可','报告是纯文本，含本机配置、自动选中的启动参数、日志和诊断结论。反馈问题时附上它，能大幅加快定位。','自动修复失败后，会自动弹出相应教程','同一个教程在一次运行里只自动弹一次，不会反复打断你。','两个坑：① 别只开 VirtualMachinePlatform，那不是模拟器要的加速；② 若 BIOS 里 VT-x/SVM 没开，先按 5.1 进 BIOS 打开，否则系统功能开了也没用。','绝大多数国产安卓应用只提供','一个通用 Android 14 镜像','ApkStart 会自动做什么：','切换镜像会重启运行时，一次约 40 秒到 1 分钟，期间可能看到提示窗口。','重置安卓数据 / 清空安卓数据','必须勾选。0.6.3 的自动检测会检查这一项；若发现被关掉，会在「设置 → 诊断与修复」里报出来，点「处理」即可一键打开。','改完必须重启一次安卓运行时','本手册对应 v0.6.3，随版本更新。若界面文案与此处略有出入，以软件内实际显示为准。')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Manual paragraph translation missing: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Manual paragraph is not allowlisted: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Manual paragraph has no Hebrew text: $key" }
}


# Additional user-facing manual instructions and troubleshooting rows.
foreach ($key in @('支持   /   拆分包（自动用  ）。装完自动生成桌面 + 开始菜单快捷方式。','只有"面板方向和应用方向不一致"的那一次才会重启运行时（约 40 秒，标题栏会给提示），同方向的应用之后都秒进。','本机   与安卓内   秒级双向同步。 入口：设置 → 集成与文件 → 文件互通（可"立即同步"或"打开目录"）。','Windows 原生多窗口多开（实验性）、后台保留数','设置 → 更新与关于 → 检查更新，或托盘右键 → 检查更新。更新链路现测现选最快的源（GitHub / Gitee / 镜像），分块并行下载，失败自动换源。更新不会丢运行时、已装应用和快照。','说明：只有用「检查更新」从 GitHub / Gitee 装便携版的用户走增量；从微软商店装的走 Store 通道。增量对已装应用、安卓数据、运行时和快照都没有影响。','镜像缺失 / 损坏 / 与旧用户数据不兼容 → 开机失败、卡在引导、反复重启。','在翻本手册之前，先让软件自己查一遍——大多数问题它能自动修。','位置：设置 → 诊断与修复 →「自动检测 · 智能诊断」','两条原则：探测失败不会被当成问题（拿不到状态就报"不知道"，绝不瞎报）；同一个老问题不重复打扰。','自动检测/修复也会把教程送到你面前：','自动检测发现问题时，问题条目右侧有「教程」按钮，点开直达对应章节；','：这通常是"慢"，不是"打不开"。ApkStart 已自动回退软件模拟。想要流畅才需要开加速。','ApkStart 会把英文原始错误翻译成中文。对照下表处理：','应用要求更高 Android 版本','APK 损坏或非正规包，重新获取安装包','不能降级覆盖，装更高版本或先卸载','应用依赖特定厂商环境，模拟器无法提供','系统内部错误（多为空间不足或没开机完成）','看屏幕上有没有一个模拟器窗口弹着','「一律允许使用这台计算机进行调试」','退出其它模拟器（夜神/MuMu/蓝叠）或重启','更新显卡驱动；或写兼容补丁；仍不行导出诊断报告')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Manual translation missing: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Manual text not allowlisted: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Manual translation is not Hebrew: $key" }
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

# Audio and Store-build troubleshooting text: reviewed literal manual nodes must stay translated and allowlisted.
foreach ($key in @('：安卓应用里视频、提示音完全没声；或 Windows 其它软件有声、只有 ApkStart 里的应用没声。','：如果系统本身也没声音，先去解决 Windows 音频；只有 ApkStart 里的应用没声才按下面查。','Windows 音量与输出设备','：点任务栏音量图标，确认没有静音、音量不为 0，输出设备选的是你正在用的耳机/音箱。打开「音量合成器」，看 ApkStart / 安卓运行时那一行是不是被单独静音或拉到 0。','：有些应用第一次进入会把媒体音量设成 0，在应用自己的设置或安卓侧音量键里调大。B 站/抖音等还可能在应用内单独关了自动播放声音。','ApkStart 的声音开关','Windows 音频服务','蓝牙耳机 / 多输出设备','：切到蓝牙耳机后 Windows 有时不会把已运行的程序迁过去。断开重连耳机，或重启一次安卓运行时。','：在「设置 → 诊断与修复 → 导出诊断报告」后反馈；报告会带上声音开关与音频服务状态，能直接定位到底是配置、系统服务还是应用本身的问题。','自动修复失败时，软件会自动打开这一节。如果你关掉了自动检测通知，也可以从自动检测问题条目的「教程」按钮或标题栏','确实缺少 VC++ 运行库','杀毒软件隔离了运行时文件','：运行时目录里的 dll 被隔离 / 删除，也会报这个码。把 ApkStart 的安装目录和运行时数据目录加入杀毒白名单，再重新安装一次。','看诊断是不是真的缺 VC++','确认没报 VC++、却仍失败 → 多半是商店版路径问题','：这是当前最可能的原因。依次试：','完全退出 ApkStart（托盘图标 → 退出），重新打开；','检查杀毒软件的「受控文件夹访问 / 勒索软件防护」，把 ApkStart 加入白名单后重启；','想拿到确切的失败 DLL 名','（进阶）：反馈问题时，最有价值的是告诉开发者到底缺的是哪个 dll。可在事件查看器 → Windows 日志 → 应用程序里找 ApkStart / emulator 的')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Audio/Store troubleshooting translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Audio/Store troubleshooting text has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Audio/Store troubleshooting text is not allowlisted: $key" }
}

# Startup and quick-reference troubleshooting text must remain explicitly translated and allowlisted.
foreach ($key in @('运行入口或窗口接管','① 确认你用的是新版程序','② 开机时长要有预期','③ 原生窗口没接管 → 退回带旋转按钮的嵌入窗口','从目录联接 / 非标准路径启动时容易触发；0.6.3 已让代理解析真实路径再匹配。若仍出现，附日志反馈。','④ 重置安卓数据（最后手段）','按 6.1 开启加速','下调内存与核心数','关闭占内存的程序','模拟器端口被占用','残留锁文件 / "Running multiple emulators with the same AVD"','自动清 AVD 锁并重试','确认没有别的模拟器在用同一运行时','系统镜像缺失/损坏/与旧数据不兼容','用干净用户数据重新开机','设置 → 运行时删镜像重下','快速启动快照损坏','丢弃旧快照走冷启动','下次正常退出会重建；或关掉快照','运行时组件被删/缺 VC++ 运行库','把运行时目录改到空间充足的盘；关掉快照/调小数据分区','路径含中文/特殊字符','CPU 缺少指令集（AVX/SSE4）','多为警告仍可开机；否则换支持 VT-x/AVX 的机器或旧版引擎','当前运行时不接受该 GPU 模式','按引擎版本重选可用的 GPU 模式','多组参数自动重试','桌面图标显示成 ApkStart 的图标 / 空白图标')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Startup troubleshooting translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Startup troubleshooting text has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Startup troubleshooting text is not allowlisted: $key" }
}
