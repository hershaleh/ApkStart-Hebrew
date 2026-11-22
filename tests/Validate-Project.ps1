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

# Version compatibility: only the source-reviewed ApkStart release may be patched.
foreach ($required in @(
    "$verifiedVersion='0.6.3'",
    "if($version -eq $verifiedVersion)",
    "Status='UnsupportedVersion'",
    "Status='Supported'",
    "index.html','app.js','main.js','style.css','theme.css",
    "גרסה לא מאומתת — ההחלה חסומה"
)) {
    if (-not $source.Contains($required)) { throw "Version compatibility safeguard missing: $required" }
}
if ($source -notmatch "Status='UnsupportedVersion'.*לא יבוצעו שינויים") {
    throw 'Unverified ApkStart versions must be blocked with a clear warning.'
}

# Backup/restore integrity: validate path containment, allowlisted targets, backup hashes,
# and the patched-file hash before any restore or automatic rollback.
foreach ($required in @(
    'function Test-PathWithin',
    'function Get-SafeRelativePath',
    'BackupHash=(HashFile $backupPath)',
    'Get-FullPath ([string]$state.ManifestPath)',
    'Test-PathWithin $manifestPath $backupsRoot',
    'Test-PathWithin $backupRoot $backupsRoot',
    'Test-PathWithin $dest $targetRoot',
    'Test-PathWithin $backupPath $backupFiles',
    '(HashFile $backupPath) -ne [string]$entry.BackupHash',
    '(HashFile $dest) -ne [string]$entry.PatchedHash',
    'src/ui/index.html',
    'src/ui/app.js',
    'זהו גיבוי ישן ללא טביעת אצבע לגיבוי',
    'src\core\autodebug.js',
    'apkstart-hebrew-restore.tmp',
    'APKSTART-HEBREW'
)) {
    if (-not $source.Contains($required)) { throw "Backup/restore safety control missing: $required" }
}
if ($source -notmatch 'Schema -ne 1') { throw 'Restore must reject unsupported backup manifest schemas.' }
if ($source -notmatch 'Split-Path -Leaf \$manifestPath') { throw 'Restore must validate the manifest filename.' }
if ($source -notmatch 'IsPathRooted') { throw 'Restore must reject rooted relative paths.' }
if (-not $source.Contains('Remove-Item -LiteralPath $stateFile -Force')) { throw 'Restore must only clear the active backup pointer after a complete restore.' }


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


# Reviewed complete main-window HTML strings from the upstream interface audit.
foreach ($key in @(
    "引导与系统",
    "修复网络",
    "连当前 AVD 的快速启动快照也一起清（会先停运行时，能真正回收几 GB 快照）",
    "自动旋转开关默认打开",
    "打开（推荐 · 逻辑密度 190dpi，sw606dp 走平板排版）",
    "关闭（镜像默认密度，手机排版）",
    "平滑模式把一小段时间内的滚动合并成一次滑动手势，避免逐格抽搐，也不会每格都拉起一个 adb 进程。",
    "侧键映射需要全局鼠标钩子。钩子只在 ApkStart 应用窗口处于前台时安装，失焦或关闭立即卸载，不会拖慢桌面。",
    "以上映射只在应用窗口前台生效；切回桌面或关闭窗口后，鼠标行为完全恢复 Windows 原生。",
    "当前应用未配置按键映射。右键应用卡片可快速套用预设模板。",
    "自动（按加速状态）",
    "安卓数据分区（应用与游戏装这里）",
    "64 GB（50GB 级游戏）",
    "立即扩容",
    "扩容是就地做的：已装应用与存档都保留，只是下次打开应用会多花十几秒。",
    "下次重启运行时生效",
    "给安卓指定国内公共 DNS（阿里 / 腾讯）。安卓默认走主机的 DNS，主机挂着 VPN 或走公司网时解析会拖到几百毫秒，视频类应用首屏发慢。内网域名访问异常时可关掉。",
    "让应用提示音、视频声音正常播放。仅在你完全不需要声音、想再省一点 CPU 时关闭。",
    "收敛 vCPU 配额并降低进程优先级，CPU 优先让给 Windows 桌面。上面的「资源策略」已经会自动设置这一项。",
    "均衡（推荐）· 运行时让着前台窗口",
    "性能优先 · 运行时与前台同等优先级",
    "游戏 / 低延迟 · 运行时高优先级，适合 FPS、音游",
    "游戏模式会让安卓虚拟机保持较高 CPU 优先级并减少宿主侧轮询，输入与画面延迟最低；代价是整机其他程序会变慢。没有应用窗口时容器仍会自动降优先级停放。",
    "额外禁用 Play 商店、设置向导、打印服务等后台包，只留打开应用必需的环境。若遇到应用提示缺少 Google Play 服务，关掉此开关会自动恢复。",
    "启动 ApkStart 后就在后台把安卓环境引导好（窗口全程隐藏，不会看到模拟器）。之后点任何应用只剩一次「打开」，实测从 20 多秒降到几乎不用等。代价是空闲时常驻约 1GB 内存，关掉后第一次打开应用需要冷启动。",
    "安卓环境只开机一次并常驻；之后打开应用不再重跑整个系统，只启动该应用并停掉其他应用进程。关掉最后一个窗口会清后台、停放容器，下次点开仍是秒进。",
    "更新与下载源",
    "「自动」会同时问 GitHub 与 Gitee 的最新版本，把每个下载地址都真下 256KB 测一次速度，再从最快的那个地址下载；其中一个源不通不影响更新。",
    "GitHub 直连太慢时，额外测速 ghfast.top / gh-proxy.com 这两个公开转发服务（只转发公开的发布文件，不涉及账号）。关掉后只用直连和你自己填的前缀。",
    "填了就只用你填的前缀，不再尝试上面那两个公共镜像；留空则由「自动」逻辑决定。下载器会把它拼在真实地址前面。",
    "大文件按块并行下载。默认 8 线程已经能跑满大多数家宽；网络稳定时可以试 16。",
    "Gitee 更新源（可选）",
    "Gitee 只读 token（一般不用填）",
    "关掉后不再定时扫描；随时可以点「立即检测」手动跑一次。",
    "只对严重问题弹通知；已知的老问题不重复打扰。",
    "由 ApkStart 自己分配（emulator-5554，端口冲突时自动顺延），无需填写。",
    "现在只有一个 Android 14 通用镜像，x86 与 ARM 应用都能跑，首次遇到 ARM 应用时会自动下载，不需要手动切换。此开关仅用于旧配置兼容。",
    "关闭系统动画、放开后台进程上限并把当前应用加入电池白名单，低配电脑体感最明显。",
    "彻底断网（含移动数据），需要安静时打开。",
    "系统动画",
    "关掉后界面切换明显更快，功能不受影响。",
    "快捷方式带真实应用图标，双击直接进应用",
    "Windows 搜索能搜到应用名，任务栏也按应用分组",
    "桌面图标被误删或被安全软件拦掉时，点这里按当前设置全部补齐。",
    "修改后旧目录里已有的文件会自动搬到新目录；正在运行的文件互通不受影响。",
    "两侧目录会持续双向同步；在安卓应用里保存到该目录的文件，会出现在本机共享目录中。",
    "双击 APK 直接安装到 ApkStart（仅写入当前用户，无需管理员）",
    "运行时数据目录（系统镜像 · 已装应用 · 快照）",
    "这里占用空间最大（数 GB）。改到非系统盘可大幅减轻 C 盘压力；修改后需重启软件，已存在的数据不会自动搬移（请手动复制后删除旧目录）。",
    "安卓数据目录（应用、游戏与快速启动快照）",
    "卸载会取消 .apk 关联并移除程序；便携版请按提示手动删除目录。",
    "抖音 · 日常MIKU",
    "双击即装的 Windows 安卓应用启动器：APK 安装、桌面快捷方式、独立窗口运行、文件双向互通。",
    "打开使用手册（含故障解决方案）",
    "抖音 · @日常MIKU（联系作者）",
    "后台保留应用数",
    "0 · 最省内存（只留当前应用）",
    "多开模式下，超过这个数量的后台应用会被挂起（保留数据、秒切回），释放内存。"
)) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Main HTML translation missing: $key" }
    if ($translations[$key] -notmatch '[\\u0590-\\u05FF]') { throw "Main HTML phrase has no Hebrew translation: $key" }
}

$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($script, [ref]$tokens, [ref]$errors) | Out-Null
if ($errors.Count -gt 0) {
    $errors | ForEach-Object { Write-Error ("Line $($_.Extent.StartLineNumber), column $($_.Extent.StartColumnNumber): $($_.Message)") }
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

# System diagnostics and built-in manual guidance phrases must remain translated and allowlisted.
foreach ($key in @('完整的 Android 14 系统镜像','Google 自家内核驱动','Windows 自带功能"Windows 虚拟机监控程序平台"（HypervisorPlatform）','需要你亲自做的只有两类：','：重启进 BIOS → 打开 Intel VT-x / AMD SVM → Enabled（这一步软件无法代劳）。','Windows 功能 / 加速驱动','上次启动失败的真实原因、引导卡死、残留锁文件、孤儿模拟器进程、快照空壳、没有硬件加速','adb 未授权、offline、运行时在跑但 adb 看不到设备','磁盘余量、数据分区配置与实际不符、共享目录不可写','屏幕方向与物理面板冲突、独立窗口下自动全屏不生效','安卓侧没网、下载源不通、最近日志里的错误','从 0.6.3 起，本手册已经','手动打开：标题栏','按钮。想临时关掉自动弹出，可在自动检测设置里关闭通知，教程仍可从问题条目的「教程」按钮打开。')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "System diagnostics/manual translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "System diagnostics/manual phrase has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "System diagnostics/manual phrase is not allowlisted: $key" }
}

# Data-directory and feedback manual text must remain translated and explicitly allowlisted.
foreach ($key in @('用途','位置','展开后的系统镜像','应用图标','设置与清单','Windows ↔ 安卓共享目录','「重置安卓数据」只清用户数据层，系统镜像和 APK 文件保留；更新应用不会丢运行时、已装应用和快照。  建议 C 盘保留充足空间：镜像展开 + 数据分区 + 快照合计可达数 GB。空间不足会引发Installing/开机失败。','反馈问题时请附上三样东西，能大幅加快定位：','诊断报告','app.log 最后 20 行','你的版本与形态','打印 / 存为 PDF','两个源内容一致，国内建议用 Gitee：','形态','什么时候选','全屏 / 窗口切换','旋转横竖屏','自动全屏','强制横屏/竖屏','操作','方法','按键','作用','实验室','本手册对应 v0.6.3，随版本更新。若界面文案与此处略有出入，以软件内实际显示为准。')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Data/help manual translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Data/help manual phrase has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Data/help manual phrase is not allowlisted: $key" }
}

# Quick-start, file-sharing, and data-directory manual phrases must remain translated and allowlisted.
foreach ($key in @('双击 .apk 即安装','：在资源管理器里注册文件关联后，双击 APK → 自动解析 → 安装 → 生成桌面图标。','每个应用一个桌面图标','：图标从 APK 内部离线提取，双击图标 = 直接进应用。','应用就是一个窗口','：原生渲染，全屏铺满屏幕高度并居中，窗口模式可拖动缩放，每个应用单独记忆尺寸。','：桌面 + 开始菜单（）双快捷方式。','： ↔ 安卓内  双向同步。','：不依赖你机器上装的 MuMu / 雷电 / WSA 等任何模拟器。','第二个应用几乎瞬时启动','本机  与安卓内  秒级双向同步。 入口：设置 → 集成与文件 → 文件互通（可"立即同步"或"打开目录"）。','本手册对应 v0.6.3，随版本更新。若界面文案与此处略有出入，以软件内实际显示为准。','运行时（adb / emulator / 镜像）','随包内置，或 （轻量版）','AVD / 已装应用 / 快照','运行日志 / 诊断报告','：设置 → 诊断与修复 → 导出诊断报告；','：如"商店版 0.6.3"或"完整便携版 0.6.3"。')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Quick-start/data manual translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Quick-start/data manual phrase has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Quick-start/data manual phrase is not allowlisted: $key" }
}

# Reviewed installation, first-launch, and built-in manual guidance phrases.
foreach ($key in @('Gitee：（国内直连快得多）','从 Microsoft Store 安装。内置完整运行时，装完不联网，更新交给商店','（约 830 MB，解压 ~1.3 GB）','不想装、也不想等下载：解压即用，运行时全在包里','（约 1.3 GB）','想要桌面/开始菜单快捷方式和卸载项','（96 MiB，解压 ~227 MB）','。旧版（0.5.x 及更早）要么没有内置运行时、每次启动去找/下 1.5 GB 运行时，要么默认用嵌入窗口——这正是「很慢、打不开、出来一个带旋转按钮的窗口」的典型来源。如果你是从旧版升级，请确认桌面图标指向的是新版程序目录。','（仅轻量版）下载运行时','：adb、Android Emulator、Android 14 系统镜像，官方源实测 10+ MB/s，8 线程分块 + 断点续传。完整版 / 商店版跳过此步。','：xz 镜像展开到 （约 20 秒，只做一次）。','：ApkStart 自己生成带加密和 SELinux 标签的 ext4 用户数据（官方镜像里只是 1 MB 占位）。','：之后点应用只剩一次 ，冷启动约 23 秒，命中快照约 10 秒。','主界面里选「安装应用」；','支持  /  拆分包（自动用 ）。装完自动生成桌面 + 开始菜单快捷方式。','（先注册关联：设置 → 系统集成 → 关联 .apk 文件）；','位置：设置 → 诊断与修复 →','（或系统集成页同名按钮）','：主界面标题栏的「?」按钮、设置 → 关于里的「打开使用手册」都能直接打开，可搜索、滚动、打印/存 PDF。打开时会自动定位到与当前故障相关的章节。','硬件加速、安装失败、ARM 转译层、adb 授权、无声音等问题','手动打开：标题栏  按钮。想临时关掉自动弹出，可在自动检测设置里关闭通知，教程仍可从问题条目的「教程」按钮打开。')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Install/first-launch manual translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Install/first-launch manual phrase has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Install/first-launch manual phrase is not allowlisted: $key" }
}

# Reviewed settings navigation, display, updates, and acceleration manual phrases.
foreach ($key in @('操作','方法','全屏 / 窗口切换','旋转横竖屏','自动全屏','强制横屏/竖屏','只有"面板方向和应用方向不一致"的那一次才会重启运行时（约 40 秒，标题栏会给提示），同方向的应用之后都秒进。','从 0.6.0 起分八类，顶部有搜索框（输入"横屏""内存""代理"等关键词，跨分类命中）：','分类','主要内容','常用与安装','运行时与环境、一键完成、开机自启、磁盘占用与清理','显示与窗口','显示模式、自动全屏、屏幕方向、平板排版、窗口承载方式','操作与输入','鼠标键位、键盘映射','性能与资源','资源策略、画质、数据分区、系统语言、快照、开机预热','网络与下载','更新与下载源、加速镜像、下载线程数','诊断与修复','本机体检、驱动/兼容补丁、自动检测','集成与文件','桌面与应用、文件互通、系统集成','更新与关于','软件更新、关于','实验室','Windows 原生多窗口多开（实验性）、后台保留数','设置 → 更新与关于 → 检查更新，或托盘右键 → 检查更新。更新链路现测现选最快的源（GitHub / Gitee / 镜像），分块并行下载，失败自动换源。更新不会丢运行时、已装应用和快照。','新版便携版支持 增量更新','说明：只有用「检查更新」从 GitHub / Gitee 装便携版的用户走增量；从微软商店装的走 Store 通道。增量对已装应用、安卓数据、运行时和快照都没有影响。','模拟器要跑得快，需要 CPU 虚拟化加速。Windows 上只有两条路：','方式','是什么','谁需要管理员','装完要重启吗','Windows 自带功能"Windows 虚拟机监控程序平台"（HypervisorPlatform）','开此功能时','Google 自家内核驱动','装驱动时','没有加速也能跑','需要你亲自做的只有两类：','重启进 BIOS → 打开 Intel VT-x / AMD SVM → Enabled（这一步软件无法代劳）。','Windows 功能 / 加速驱动 ：见 6.1。')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Settings manual translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Settings manual phrase has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Settings manual phrase is not allowlisted: $key" }
}

# Reviewed diagnostics, report, tutorial, and runtime-image manual phrases.
foreach ($key in @('位置：设置 → 诊断与修复 → 开始体检','查什么：CPU 虚拟化（VT-x/SVM）是否开、Hyper-V/虚拟机监控程序平台是否可用、显卡/显存/驱动、内存、系统版本、 emulator -accel-check 、AEHD 驱动。','点「 应用推荐配置 」自动写安全项：内存 / 核心数 / 渲染分辨率 / 画质 / 无加速时强制软件模拟，并固化成一份本机驱动，以后自动套用。','结果分级： ok （正常）/ warn （能用但建议优化）/ bad （不处理跑不起来）。每条都有颜色和说明。','位置：设置 → 诊断与修复 →「自动检测 · 智能诊断」','后台每 10 分钟把机器查一遍，按六类列问题，每条可 一键处理 （重启运行时、清锁、清孤儿进程、作废快照、清理磁盘、重置安卓网络……），修完自动复检：','分类','覆盖的问题','运行时','上次启动失败的真实原因、引导卡死、残留锁文件、孤儿模拟器进程、快照空壳、没有硬件加速','设备连接','adb 未授权、offline、运行时在跑但 adb 看不到设备','存储','磁盘余量、数据分区配置与实际不符、共享目录不可写','设置','屏幕方向与物理面板冲突、独立窗口下自动全屏不生效','网络/日志','安卓侧没网、下载源不通、最近日志里的错误','两条原则：探测失败不会被当成问题（拿不到状态就报"不知道"，绝不瞎报）；同一个老问题不重复打扰。','报告是纯文本，含本机配置、自动选中的启动参数、日志和诊断结论。反馈问题时附上它，能大幅加快定位。','从 0.6.3 起，本手册已经 嵌入软件','自动检测/修复也会把教程送到你面前：','自动检测发现问题时，问题条目右侧有「教程」按钮，点开直达对应章节；','自动修复失败后，会自动弹出相应教程','同一个教程在一次运行里只自动弹一次，不会反复打断你。','ApkStart 不是在模拟一个"空安卓"，而是加载一个 完整的 Android 14 系统镜像 当底座。','0.6.3 只有 一个通用镜像 （Google Play x86_64），x86 和 ARM 应用都靠它跑——不再像老版本那样分"AOSP 镜像 / 兼容镜像"两套。','镜像缺失 / 损坏 / 与旧用户数据不兼容 → 开机失败、卡在引导、反复重启。','用户数据（ /data ）是薄差分层，系统镜像全机共享一份。')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Diagnostics/runtime manual translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Diagnostics/runtime manual phrase has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Diagnostics/runtime manual phrase is not allowlisted: $key" }
}


# Final reviewed troubleshooting and compatibility phrases.
$manualAllow = Get-Content -LiteralPath $manualAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($key in @('首次遇到 ARM 应用时，若翻译层组件还没就位，ApkStart 会自动补齐兼容镜像并重启运行时重试（见 6.3）。','两个坑：① 别只开 VirtualMachinePlatform，那不是模拟器要的加速；② 若 BIOS 里 VT-x/SVM 没开，先按 5.1 进 BIOS 打开，否则系统功能开了也没用。 显卡驱动超过 3 年的，去厂商官网更新；但 ApkStart 不会自动装驱动（装错更糟）。某些老显卡/核显需要走兼容补丁，见设置 → 诊断与修复 → 驱动 · 兼容补丁。','若报的是上表之外的原始英文，直接按 5.3 导出诊断报告反馈。','*本手册对应 v0.6.3，随版本更新。若界面文案与此处略有出入，以软件内实际显示为准。*','仅用于旧配置兼容，正常无需手动动','看到「红色『安装失败』+ 文案却说『正在自动切换兼容镜像后重试』」怎么办？','这是旧版的一个显示错误：镜像文件明明在磁盘上，但复用到一台没开翻译层的旧运行时，切换重试被跳过、直接报了失败，提示文案却照旧说"正在重试"。','你用的不是最新代码，请升级到 0.6.3 的最新构建','升级后再装一次即可。','少数应用自带更深的反模拟检测（强制校验真实传感器、基带等），无法在模拟器里运行；这类应用会给出中文说明，属于限制，不是故障。','确认镜像已就位','若显示未下载','完成后','点一次，等它起来。','想拿到确切的失败 DLL 名（进阶）：','adb 也崩溃怎么办','这一节会自动弹出：当启动失败 / 修复失败被判定为 DLL 类问题时，软件会直接打开到这里。也可随时从自动检测条目的「教程」按钮或标题栏')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Final troubleshooting manual translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Final troubleshooting manual phrase has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Final troubleshooting manual phrase is not allowlisted: $key" }
}


# Remaining standalone installation and display table entries.
$manualAllow = Get-Content -LiteralPath $manualAllowPath -Raw -Encoding UTF8 | ConvertFrom-Json
foreach ($key in @('设置 → 显示与窗口 → 自动全屏（配合"强制方向"效果最好）','设置 → 显示与窗口 → 屏幕方向','应用只提供 ARM 库，当前镜像没有 ARM 转译层','需更高系统镜像；当前为 Android 14（API 34），极少触发','清理磁盘，或把运行时数据目录改到空间充足的盘（设置 → 系统集成）','APK 路径含特殊字符/中文','把 APK 移到纯英文路径再装','面向很老 Android 的应用','依赖的设备特性/厂商库不存在','与已有应用 ContentProvider 冲突','重启运行时，等开机完成后重试','把 ApkStart 加杀毒白名单后重新解压；安装微软 VC++ 2015-2022 运行库')) {
    if ($null -eq $translations.PSObject.Properties[$key]) { throw "Manual translation missing: $key" }
    if ($translations[$key] -notmatch '[\u0590-\u05FF]') { throw "Manual phrase has no Hebrew translation: $key" }
    if ($null -eq @($manualAllow | Where-Object { $_ -ceq $key })[0]) { throw "Manual phrase is not allowlisted: $key" }
}


# Hebrew document metadata must be applied to all HTML surfaces, including the app shell and splash screen.
$scriptSource = Get-Content -LiteralPath $script -Raw -Encoding UTF8
if (-not $scriptSource.Contains("index.html','shell.html','manual.html','splash.html")) { throw 'HTML language metadata coverage is incomplete.' }
if (-not $scriptSource.Contains('<html lang="he" dir="rtl">')) { throw 'Hebrew HTML language/direction metadata is missing.' }
if (-not $scriptSource.Contains('[regex]::Replace')) { throw 'HTML metadata replacement must be explicit and bounded.' }

$languagePattern = '<html\s+lang=["'']zh-CN["'']\s*>'
if (-not [regex]::IsMatch('<html lang="zh-CN">', $languagePattern)) { throw 'HTML language metadata pattern does not match the upstream document.' }

# Main UI guidance and splash-screen translations added in batch 153.
$uiGuidance = @(
    '虚拟机窗口已打开。按下面 6 步操作一次，之后 ApkStart 会直接从磁盘启动，不再需要镜像。',
    '内存、核心数、渲染后端、端口、加速方式全部自动选择；启动失败会自动降级重试，不需要手动改。
            ApkStart 用',
    '系统镜像全机共享一份，应用数据用差分层保存；旧镜像、旧快照、日志和锁文件都可回收。日志超过上限会自动滚动，不会无限增长。「重置安卓数据」会真实删除数 GB 用户数据，仅保留系统本身。',
    '或右键托盘切换；全屏只放大窗口，不改变画面比例，切换不重启应用。',
    '打开后，每次点开应用直接铺满屏幕，不用再按 F11。配合下面的「横屏」使用效果最好
            —— 横屏面板的宽高比本来就贴合屏幕，全屏不会留黑边。',
    '安卓的横竖屏是',
    '虚拟手机面板的真实方向',
    '决定的。面板方向和应用自己声明的方向不一致时，
            安卓只会给应用中间一条窄画面、两侧补黑 —— 换窗口大小、改分辨率都填不满。
            「跟随应用」会在安装 APK 时读出应用的方向，启动时自动把面板换成一致的那个，
            所以红果、墨读这类应用会正立且铺满。方向不对时才重启一次运行时（约十几秒），
            之后再打开同一方向的应用都是秒进。',
    '原生窗口由模拟器直接渲染和排布，拖拽、缩放、旋转都跟手，不会出现黑边或点击错位，
            代价是多一个任务栏图标（横屏用托盘菜单或 Ctrl+Alt+R）。嵌入模式会把模拟器窗口塞进我们的窗口，
            观感更统一、自带旋转按钮，但在缩放/旋转/切换应用时容易掉帧并出现黑边。改动在下次打开应用时生效。',
    '模拟器原生把左键当成手指点击，按住拖动就是滑动，无需额外设置。',
    '模拟器默认把右键也当成一次点击（容易误触）。开启后右键只执行返回，不再触发点击。',
    '<li>运行时组件已随安装包内置，不再下载任何东西</li>',
    '<li>把系统镜像展开到用户目录（约 1 分钟，只需一次）</li>',
    '<li>准备硬件加速与中文输入法</li>',
    '<li>完成后双击 APK 或桌面图标即可秒开应用</li>'
)
foreach ($key in $uiGuidance) {
    $normalizedKey = [regex]::Replace([string]$key, '\s+', ' ').Trim()
    $matchedKey = $null
    foreach ($candidateProperty in $translations.PSObject.Properties) {
        $candidate = [string]$candidateProperty.Name
        if ([regex]::Replace($candidate, '\s+', ' ').Trim() -ceq $normalizedKey) {
            $matchedKey = $candidate
            break
        }
    }
    if ($null -eq $matchedKey) { throw "Main UI translation missing: $normalizedKey" }
    if ($translations[$matchedKey] -notmatch '[\u0590-\u05FF]') { throw "Main UI phrase has no Hebrew translation: $normalizedKey" }
}
