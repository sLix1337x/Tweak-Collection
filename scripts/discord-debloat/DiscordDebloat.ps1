<#
.SYNOPSIS
    Discord Debloat Suite - strips a Discord Stable install down to a minimal,
    fast-starting core while keeping voice, Krisp and the desktop client working.

.DESCRIPTION
    WPF tool (PowerShell 5.1 / 7+). $script:DebloatProfile declares every file and
    folder the tool removes; each entry was checked against a stock install and
    against a running client. A default run takes 1074 files / 607.5 MB down to
    194 files / 314.6 MB.

.PARAMETER InstallPath
    INTERNAL / TESTING ONLY. Overrides the detected Discord install root.
    Leave it unset: the tool finds the real client by itself - a running process
    first, then the standard per-user folders, then Squirrel's uninstall key.

.PARAMETER DryRun
    Start with simulation mode pre-armed: nothing is deleted, everything is logged.

.PARAMETER AppDataPath
    INTERNAL / TESTING ONLY. Overrides Discord's roaming profile
    (%APPDATA%\discord). Pass it together with -InstallPath, never alone - the
    install tree and the profile must describe the same Discord.

.PARAMETER Selftest
    Headless. Applies the full profile to -InstallPath and prints a report.
    No GUI, no elevation. Intended for verifying the engine against a copy.
#>
[CmdletBinding()]
param(
    [string] $InstallPath = "$env:LOCALAPPDATA\Discord",
    [string] $AppDataPath = "$env:APPDATA\discord",
    [switch] $DryRun,
    [switch] $Selftest
)

$ErrorActionPreference = 'Continue'
$script:ToolVersion = '1.1.0'

# ---------------------------------------------------------------- elevation --
if (-not $Selftest) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] `
                [Security.Principal.WindowsIdentity]::GetCurrent()
               ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin) {
        $exe  = if ($PSVersionTable.PSVersion.Major -ge 6) { 'pwsh' } else { 'powershell' }
        # -STA: WPF will not start in an MTA apartment. Both hosts default to STA
        # today, but the relaunch must not depend on that default.
        $argl = @('-NoProfile','-STA','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`"",
                  '-InstallPath',"`"$InstallPath`"",
                  '-AppDataPath',"`"$AppDataPath`"")
        if ($DryRun) { $argl += '-DryRun' }
        try   { Start-Process $exe -ArgumentList $argl -Verb RunAs }
        catch { Write-Host 'Administrator rights are required.' -ForegroundColor Red }
        exit
    }
}

#===============================================================================
#  DELETION PROFILE  -  ground truth extracted from the folder comparison
#===============================================================================
$script:DebloatProfile = [ordered]@{

    # --- files/folders directly under the install root ------------------------
    RootJunk = @{
        Label = 'Installer leftovers'
        Note  = 'Update.exe, Squirrel packages, download cache, stray icon'
        Files = @('Update.exe', 'SquirrelSetup.log', 'app.ico')
        Dirs  = @('download', 'packages', 'SquirrelTemp')
    }

    # --- GPU / rendering libraries -------------------------------------------
    # Removing these forces Discord onto the software renderer, so the tool also
    # forces enableHardwareAcceleration=false whenever this category is applied.
    GpuLibs = @{
        Label = 'GPU + hardware-acceleration libraries'
        Note  = 'ANGLE, SwiftShader, Vulkan, DirectX shader compilers'
        Files = @('libEGL.dll', 'libGLESv2.dll', 'd3dcompiler_47.dll', 'dxcompiler.dll',
                  'dxil.dll', 'vk_swiftshader.dll', 'vk_swiftshader_icd.json', 'vulkan-1.dll')
        Dirs  = @()
    }

    # --- extra Chromium resource packs ---------------------------------------
    ChromePaks = @{
        Label = 'Extra Chromium assets'
        Note  = 'HiDPI resource packs, legacy V8 snapshot, crash reporter, bootstrap manifest'
        Files = @('chrome_100_percent.pak', 'chrome_200_percent.pak', 'snapshot_blob.bin',
                  'discord_wer.dll', 'app.ico', 'Discord.exe.sig', '.first-run')
        Dirs  = @('resources\bootstrap')
    }

    # --- whole module folders that get deleted --------------------------------
    ModulesRemove = @{
        Label = 'Optional native modules'
        Note  = 'cloudsync, overlay, dispatch, erlpack, game utils, media, notifications, rpc, spellcheck, zstd'
        Dirs  = @('discord_cloudsync', 'discord_desktop_overlay', 'discord_dispatch',
                  'discord_erlpack', 'discord_game_utils', 'discord_media',
                  'discord_notifications', 'discord_rpc',
                  'discord_spellcheck', 'discord_zstd')
    }

    # --- modules that survive --------------------------------------------------
    # ModulesKeep is what actually drives deletion: anything under modules\ whose
    # BASE NAME is not listed here is removed. ModulesRemove.Dirs above is
    # documentation only.
    #
    # *** BASE NAMES ONLY - never the -N suffix. ***
    # Module folders are <name>-<moduleVersion> and Discord bumps those versions
    # independently of the client version: discord_voice-1 becomes discord_voice-2.
    # Matching the full folder name meant that on any install whose modules had
    # moved on, discord_desktop_core-2 was not "kept", so it landed in the
    # Optional modules sweep and the tool DELETED core.asar - the entire desktop
    # app - along with the voice engine. Compare with Get-ModuleBaseName.
    #
    # discord_modules (7.9 MB: discord_modules.node + Game SDK / Aegis DLLs) is kept
    # after a regression on a live client. Do not move it into the removal set
    # without runtime evidence.
    ModulesKeep = @('discord_desktop_core', 'discord_krisp', 'discord_modules',
                    'discord_utils', 'discord_voice')

    # --- optional extras ------------------------------------------------------
    # Opt-in, default off.
    #
    # KRISP IS ALL-OR-NOTHING. Keeping discord_krisp-1 while deleting its .kef models
    # is what killed the microphone on a live client.
    # Reason: getModulePath() resolves through updater.node -> installer.db, which is
    # a SQLite registry that never consults the filesystem. discord_krisp is recorded
    # there as install_state="Installed", so the
    #     const krispPath = ...getModulePath('discord_krisp');
    #     if (krispPath != null) { VoiceEngine.setKrispPath(krispPath); }
    # guard in discord_voice/index.js can never take the null branch - the engine is
    # always pointed at the folder, models present or not. discord_voice.node also
    # exports KrispVADSetup / KrispVADProcess / KrispActivationThreshold, i.e. Krisp
    # supplies voice-ACTIVITY detection, not just noise suppression, and Voice
    # Activity is Discord's default input mode. No VAD model => the mic never keys.
    # So the models are no longer trimmed; the whole folder goes or none of it does.
    # --- Krisp model presets --------------------------------------------------
    # Decoded from the .kef containers themselves: each holds a JSON config naming
    # its inference nets and the sample rate it serves. The nc-* models are NOT
    # quality tiers you can pick freely - they are sample-rate tiers, and Discord
    # selects by the negotiated audio rate. bvc is the odd one out: it is the only
    # model carrying a second net (csd.thw, conversational speech detection), which
    # is what separates your voice from other people's - i.e. Background Voice
    # Cancellation, a distinct opt-in feature rather than a bigger NC model.
    #
    #   krisp-vad-o-v2.kef        0.6 MB   8/16 kHz  voice-activity detection
    #   krisp-nc-o-nb-v2.kef      2.7 MB      8 kHz  noise cancel, narrowband
    #   krisp-nc-o-lite-v1.kef    2.8 MB     16 kHz  noise cancel, wideband/low-CPU
    #   krisp-nc-o-med-v7.kef     5.6 MB     32 kHz  noise cancel, super-wideband
    #   krisp-bvc-o-pro-v3.kef   14.4 MB     32 kHz  background VOICE cancellation
    #
    # Selection happens in Discord's renderer, which is served from Discord's own
    # servers - it is not in app.asar, core.asar or discord_krisp.node, so which
    # model a given setting requests cannot be determined statically. That is why
    # 'All' is the default and vad + the 32 kHz nc model are never dropped by a
    # preset short of removing the module outright.
    KrispModule = 'discord_krisp'
    KrispModels = [ordered]@{
        'krisp-vad-o-v2.kef'      = 'voice-activity detection - never remove, this is what breaks the mic'
        'krisp-nc-o-nb-v2.kef'    = 'noise cancellation, 8 kHz narrowband'
        'krisp-nc-o-lite-v1.kef'  = 'noise cancellation, 16 kHz wideband / low CPU'
        'krisp-nc-o-med-v7.kef'   = 'noise cancellation, 32 kHz super-wideband - the likely default path'
        'krisp-bvc-o-pro-v3.kef'  = 'background VOICE cancellation (pnc + csd nets)'
    }
    # Preset -> the .kef files it deletes. 'None' is handled separately: it removes
    # the whole module folder via Aggressive.Krisp below.
    KrispPresets = [ordered]@{
        # Wildcards, not literal names: the models carry their own version suffix
        # (krisp-nc-o-med-v7) and Discord ships new revisions of them.
        'All'       = @{ Label = 'All models'; Patterns = @() }
        'NoBvc'     = @{ Label = 'No background voice cancellation'
                         Patterns = @('krisp-bvc-*.kef') }
        'Essential' = @{ Label = 'Essential only - VAD + full-band noise cancellation'
                         Patterns = @('krisp-bvc-*.kef', 'krisp-nc-o-lite-*.kef',
                                      'krisp-nc-o-nb-*.kef') }
        'None'      = @{ Label = 'Remove Krisp entirely'; Patterns = @() }
    }

    Aggressive = @{
        Krisp = @{
            Label  = 'Krisp module'
            Module = 'discord_krisp'
            Note   = 'noise suppression + voice-activity detection - whole folder, 40.4 MB'
        }
        Mediapipe = @{
            Label  = 'MediaPipe library'
            Module = 'discord_voice'
            File   = 'mediapipe.dll'
            Note   = 'background-blur runtime - its .tflite models are already removed'
        }
    }

    # --- trimming *inside* the surviving modules -------------------------------
    ModuleTrim = @{
        Label = 'Trim surviving modules'
        Note  = 'manifests, helper EXEs, background-blur models - tray art is kept'
        Map   = [ordered]@{
            'discord_desktop_core' = @{
                # 'app' is NOT trimmed. It is 252 KB and holds
                # images\systemtray\win32\tray*.png  - the Windows tray icon,
                # images\thumbar\win32\*             - the taskbar preview buttons,
                # images\badges\badge-*.ico          - the unread-count overlay.
                # Removing it makes the tray icon disappear. 0.08% of the saving for
                # three visible features is a bad trade.
                Dirs  = @()
                Files = @('package.json')
            }
            # discord_krisp is deliberately NOT trimmed - see the Aggressive
            # block above. Gutting it while installer.db still lists it as
            # Installed is what broke voice activity detection.
            'discord_utils' = @{
                Dirs  = @('node_modules\node-addon-api')
                Files = @('DiscordSystemHelper.exe', 'manifest.json', 'package.json',
                          'node_modules\bindings\LICENSE.md',
                          'node_modules\bindings\README.md',
                          'node_modules\file-uri-to-path\.npmignore',
                          'node_modules\file-uri-to-path\History.md',
                          'node_modules\file-uri-to-path\LICENSE',
                          'node_modules\file-uri-to-path\README.md',
                          'node_modules\file-uri-to-path\package.json',
                          'node_modules\windows-notification-state\LICENSE',
                          'node_modules\windows-notification-state\README.md')
            }
            'discord_voice' = @{
                # UNVERIFIED RISK: discord_voice.node contains the literal string
                # 'audio_effects_helper.exe' and spawns it as a child process; it is
                # the sandboxed host for the audio-effects pipeline. It is only
                # 0.28 MB. No runtime evidence either way yet - if a mic problem
                # survives keeping Krisp intact, take this off the list first.
                Dirs  = @()
                Files = @('manifest.json', 'package.json',
                          'audio_effects_helper.exe', 'gpu_encoder_helper.exe',
                          'selfie_segmentation.tflite', 'selfie_segmentation_landscape.tflite')
            }
        }
    }
}

# AppData folders wiped by the cache cleaner
$script:CacheDirs = @(
    'Cache', 'Code Cache', 'GPUCache', 'CacheStorage', 'ShaderCache', 'DawnCache',
    'DawnGraphiteCache', 'DawnWebGPUCache', 'GrShaderCache', 'VideoDecodeStats',
    'logs', 'Crashpad', 'crashpad', 'Dictionaries', 'blob_storage',
    'component_crx_cache', 'shared_proto_db', 'Session Storage', 'sentry',
    'WebStorage', 'Databases', 'MediaFoundationWidevineCdm', 'WidevineCdm',
    'Service Worker', 'Shared Dictionary', 'SharedStorage', 'SharedStorage-wal',
    'DIPS', 'DIPS-wal', 'module_data\crashpad'
)

#===============================================================================
#  ENGINE  -  pure functions, GUI-independent (also used by -Selftest)
#===============================================================================

<#
    Canonical absolute path: expands 8.3 short components and strips any trailing
    separator.

    This exists because %TEMP% is routinely handed out in 8.3 form
    (C:\Users\ADMINI~1\AppData\Local\Temp) while Get-ChildItem / Get-Process report
    long paths. Comparing or slicing the two forms against each other has caused real
    defects here - a mangled restore folder, and the wrong processes being terminated.
    Anything that compares paths, or derives one from another, must canonicalise first.
#>
function Resolve-LongPath {
    param([string] $Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $Path }
    $out = $Path
    try   { $out = (Get-Item -LiteralPath $Path -ErrorAction Stop).FullName }
    catch { try { $out = [System.IO.Path]::GetFullPath($Path) } catch { } }
    return $out.TrimEnd('\')
}

<#
    Path of $Full relative to $Base, without substring arithmetic.
    [System.IO.Path]::GetRelativePath does not exist on PowerShell 5.1, and
    $Full.Substring($Base.Length + 1) is exactly the bug described above, so both
    sides are canonicalised before being compared.
#>
function Get-RelativePathSafe {
    param([string] $Base, [string] $Full)
    $b = (Resolve-LongPath $Base); $f = (Resolve-LongPath $Full)
    if ($b.Equals($f, [StringComparison]::OrdinalIgnoreCase)) { return '' }
    if ($f.StartsWith($b + '\', [StringComparison]::OrdinalIgnoreCase)) {
        return $f.Substring($b.Length + 1)
    }
    try {
        $rel = ([uri]("$b\")).MakeRelativeUri([uri]$f).ToString()
        return ([uri]::UnescapeDataString($rel) -replace '/', '\')
    } catch { return (Split-Path $f -Leaf) }
}

<#
    Module folders are <name>-<moduleVersion>: discord_voice-1, discord_voice-2.
    That version is Discord's, bumped per module and independently of the client
    version, so it differs between users and over time. Every profile decision must
    key off the base name - see the warning on ModulesKeep.
#>
function Get-ModuleBaseName {
    param([string] $FolderName)
    return ($FolderName -replace '-\d+$', '')
}

<#
    Every folder under modules\ whose base name matches $Base. There can legitimately
    be more than one during an update, and all of them belong to that module.
#>
function Get-ModuleFolders {
    param([string] $ModulesRoot, [string] $Base)
    if (-not (Test-Path -LiteralPath $ModulesRoot)) { return @() }
    return @(Get-ChildItem -LiteralPath $ModulesRoot -Directory -ErrorAction SilentlyContinue |
             Where-Object { (Get-ModuleBaseName $_.Name) -eq $Base } |
             Sort-Object Name)
}

<#
    The payload folder inside a module folder: discord_voice-1\discord_voice.
    Falls back to the sole child directory if Discord ever renames the inner one.
#>
function Get-ModuleInnerDir {
    param([string] $ModuleFolder, [string] $Base)
    $direct = Join-Path $ModuleFolder $Base
    if (Test-Path -LiteralPath $direct) { return $direct }
    $kids = @(Get-ChildItem -LiteralPath $ModuleFolder -Directory -ErrorAction SilentlyContinue)
    if ($kids.Count -eq 1) { return $kids[0].FullName }
    return $null
}

<#
    Finds the Discord the user is actually running, rather than assuming
    %LOCALAPPDATA%\Discord exists.

    Order: an explicitly supplied path wins; then a running client, which is the
    only source that is true by observation rather than convention; then the
    standard per-user locations for each variant; then Squirrel's uninstall key.
    Returns $null when nothing is found, so callers can say so instead of
    operating on a path that is not there.
#>
function Get-DiscordInstallRoot {
    param([string] $Preferred)

    if ($Preferred -and (Test-Path -LiteralPath $Preferred)) { return (Resolve-LongPath $Preferred) }

    $variants = @('Discord', 'DiscordCanary', 'DiscordPTB', 'DiscordDevelopment')

    # A running client: walk ...\<root>\app-<ver>\Discord.exe back up to <root>.
    foreach ($proc in @(Get-Process -ErrorAction SilentlyContinue |
                        Where-Object { $variants -contains $_.ProcessName })) {
        try {
            if (-not $proc.Path) { continue }
            $appDir = Split-Path $proc.Path -Parent
            if ((Split-Path $appDir -Leaf) -notlike 'app-*') { continue }
            $root = Split-Path $appDir -Parent
            if ($root -and (Test-Path -LiteralPath $root)) { return (Resolve-LongPath $root) }
        } catch { }
    }

    foreach ($v in $variants) {
        $c = Join-Path $env:LOCALAPPDATA $v
        if (-not (Test-Path -LiteralPath $c)) { continue }
        if (Test-Path -LiteralPath (Join-Path $c 'Update.exe')) { return (Resolve-LongPath $c) }
        if (@(Get-ChildItem -LiteralPath $c -Directory -Filter 'app-*' -ErrorAction SilentlyContinue).Count -gt 0) {
            return (Resolve-LongPath $c)
        }
    }

    foreach ($v in $variants) {
        foreach ($hive in @('HKCU:', 'HKLM:')) {
            $k = "$hive\Software\Microsoft\Windows\CurrentVersion\Uninstall\$v"
            try {
                $loc = (Get-ItemProperty -Path $k -Name InstallLocation -ErrorAction Stop).InstallLocation
                if ($loc -and (Test-Path -LiteralPath $loc)) { return (Resolve-LongPath $loc) }
            } catch { }
        }
    }
    return $null
}

function Get-ActiveAppDir {
    param([string] $Root)
    if (-not (Test-Path -LiteralPath $Root)) { return $null }
    $best = $null; $bestVer = [version]'0.0.0.0'
    foreach ($d in (Get-ChildItem -LiteralPath $Root -Directory -Filter 'app-*' -ErrorAction SilentlyContinue)) {
        try {
            $v = [version]($d.Name.Substring(4))
            if ($v -gt $bestVer) { $bestVer = $v; $best = $d.FullName }
        } catch { }
    }
    if ($best) { [pscustomobject]@{ Path = $best; Version = $bestVer } } else { $null }
}

function Get-PathSize {
    param([string] $Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 0L }
    try {
        $item = Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        if ($item.PSIsContainer) {
            $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
                    Measure-Object -Property Length -Sum).Sum
            if ($null -eq $sum) { return 0L }
            return [long]$sum
        }
        return [long]$item.Length
    } catch { return 0L }
}

function Format-Size {
    param([long] $Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} KB' -f ($Bytes / 1KB)) }
    return "$Bytes B"
}

<#
    Builds the full list of targets without touching anything.
    Returns objects: Category, Path, Kind (File/Dir), Size, Display
#>
function Get-DebloatPlan {
    param(
        [Parameter(Mandatory)] [string] $Root,
        [hashtable] $Options = @{}
    )

    $o = @{
        OldVersions   = $true
        RootJunk      = $true
        GpuLibs       = $true
        ChromePaks    = $true
        ModulesRemove = $true
        ModuleTrim    = $true
        Locales       = $true
        KeepLocales   = @('en-US.pak')
        Logs          = $true
        AggrKrisp     = $false
        AggrMediapipe = $false
        KrispPreset   = 'All'
    }
    foreach ($k in $Options.Keys) { $o[$k] = $Options[$k] }
    # legacy alias: AggrKrisp was a plain "remove the whole module" boolean
    if ($o.AggrKrisp) { $o.KrispPreset = 'None' }

    $Root   = Resolve-LongPath $Root
    $plan   = New-Object System.Collections.Generic.List[object]
    $active = Get-ActiveAppDir -Root $Root
    if (-not $active) { return $plan }
    $app    = $active.Path
    $appRel = Split-Path $app -Leaf
    $P      = $script:DebloatProfile

    # Validate the preset against the profile rather than a script-scope list:
    # Get-DebloatPlan is serialised into a bare worker runspace that only receives
    # $script:DebloatProfile, so anything else would be $null there.
    $kp = [string]$o.KrispPreset
    if (-not $P.KrispPresets.Contains($kp)) { $kp = 'All' }
    $o.KrispPreset = $kp

    # Rel is the path relative to $Root, tracked explicitly rather than derived
    # by string arithmetic: the root and the enumerated paths can legitimately
    # differ in form (8.3 vs long names, casing), which makes substring maths wrong.
    function New-Target {
        param($Category, $Path, $Kind, $Display, $Rel)
        if (-not (Test-Path -LiteralPath $Path)) { return $null }
        [pscustomobject]@{
            Category = $Category
            Path     = $Path
            Kind     = $Kind
            Rel      = $Rel
            Size     = (Get-PathSize -Path $Path)
            Display  = $Display
        }
    }

    # 1. superseded app-* folders
    if ($o.OldVersions) {
        foreach ($d in (Get-ChildItem -LiteralPath $Root -Directory -Filter 'app-*' -ErrorAction SilentlyContinue)) {
            if ($d.FullName -ne $app) {
                $t = New-Target 'Old versions' $d.FullName 'Dir' $d.Name $d.Name
                if ($t) { $plan.Add($t) }
            }
        }
    }

    # 2. installer leftovers at the install root
    if ($o.RootJunk) {
        foreach ($f in $P.RootJunk.Files) {
            $t = New-Target 'Installer leftovers' (Join-Path $Root $f) 'File' $f $f
            if ($t) { $plan.Add($t) }
        }
        foreach ($d in $P.RootJunk.Dirs) {
            $t = New-Target 'Installer leftovers' (Join-Path $Root $d) 'Dir' "$d\" $d
            if ($t) { $plan.Add($t) }
        }
    }

    # 3. GPU libraries
    if ($o.GpuLibs) {
        foreach ($f in $P.GpuLibs.Files) {
            $t = New-Target 'GPU libraries' (Join-Path $app $f) 'File' $f "$appRel\$f"
            if ($t) { $plan.Add($t) }
        }
    }

    # 4. extra Chromium assets
    if ($o.ChromePaks) {
        foreach ($f in $P.ChromePaks.Files) {
            $t = New-Target 'Chromium assets' (Join-Path $app $f) 'File' $f "$appRel\$f"
            if ($t) { $plan.Add($t) }
        }
        foreach ($d in $P.ChromePaks.Dirs) {
            $t = New-Target 'Chromium assets' (Join-Path $app $d) 'Dir' "$d\" "$appRel\$d"
            if ($t) { $plan.Add($t) }
        }
    }

    # 5. optional module folders
    if ($o.ModulesRemove) {
        $modRoot = Join-Path $app 'modules'
        if (Test-Path -LiteralPath $modRoot) {
            foreach ($d in (Get-ChildItem -LiteralPath $modRoot -Directory -ErrorAction SilentlyContinue)) {
                if ($P.ModulesKeep -notcontains (Get-ModuleBaseName $d.Name)) {
                    $t = New-Target 'Optional modules' $d.FullName 'Dir' $d.Name "$appRel\modules\$($d.Name)"
                    if ($t) { $plan.Add($t) }
                }
            }
        }
    }

    # 6. trim the surviving modules
    #    Keys are BASE module names; the actual -N folder is resolved at runtime so
    #    the trim keeps working when Discord bumps a module version.
    if ($o.ModuleTrim) {
        $modRoot = Join-Path $app 'modules'
        foreach ($modBase in $P.ModuleTrim.Map.Keys) {
            $spec = $P.ModuleTrim.Map[$modBase]
            foreach ($folder in (Get-ModuleFolders -ModulesRoot $modRoot -Base $modBase)) {
                $inner = Get-ModuleInnerDir -ModuleFolder $folder.FullName -Base $modBase
                if (-not $inner) { continue }
                $innerLeaf = Split-Path $inner -Leaf
                $relBase   = "$appRel\modules\$($folder.Name)\$innerLeaf"
                foreach ($f in $spec.Files) {
                    $t = New-Target 'Module trim' (Join-Path $inner $f) 'File' "$($folder.Name)\$f" "$relBase\$f"
                    if ($t) { $plan.Add($t) }
                }
                foreach ($d in $spec.Dirs) {
                    $t = New-Target 'Module trim' (Join-Path $inner $d) 'Dir' "$($folder.Name)\$d\" "$relBase\$d"
                    if ($t) { $plan.Add($t) }
                }
            }
        }
    }

    # 6b. Krisp model preset. 'None' falls through to the whole-folder removal
    #     below; the de-dupe at the end drops these file entries when that happens.
    $modRootX = Join-Path $app 'modules'
    if ($o.KrispPreset -ne 'All' -and $o.KrispPreset -ne 'None') {
        $pats = @($P.KrispPresets[[string]$o.KrispPreset].Patterns)
        foreach ($folder in (Get-ModuleFolders -ModulesRoot $modRootX -Base $P.KrispModule)) {
            $inner = Get-ModuleInnerDir -ModuleFolder $folder.FullName -Base $P.KrispModule
            if (-not $inner) { continue }
            $innerLeaf = Split-Path $inner -Leaf
            foreach ($pat in $pats) {
                foreach ($kf in (Get-ChildItem -LiteralPath $inner -File -Filter $pat -ErrorAction SilentlyContinue)) {
                    $t = New-Target 'Krisp models' $kf.FullName 'File' $kf.Name `
                                    "$appRel\modules\$($folder.Name)\$innerLeaf\$($kf.Name)"
                    if ($t) { $plan.Add($t) }
                }
            }
        }
    }

    # 6c. opt-in extras
    if ($o.KrispPreset -eq 'None') {
        foreach ($folder in (Get-ModuleFolders -ModulesRoot $modRootX -Base $P.Aggressive.Krisp.Module)) {
            $t = New-Target 'Optional extras' $folder.FullName 'Dir' `
                            "$($folder.Name)\" "$appRel\modules\$($folder.Name)"
            if ($t) { $plan.Add($t) }
        }
    }
    if ($o.AggrMediapipe) {
        $mp = $P.Aggressive.Mediapipe
        foreach ($folder in (Get-ModuleFolders -ModulesRoot $modRootX -Base $mp.Module)) {
            $inner = Get-ModuleInnerDir -ModuleFolder $folder.FullName -Base $mp.Module
            if (-not $inner) { continue }
            $innerLeaf = Split-Path $inner -Leaf
            $t = New-Target 'Optional extras' (Join-Path $inner $mp.File) 'File' $mp.File `
                            "$appRel\modules\$($folder.Name)\$innerLeaf\$($mp.File)"
            if ($t) { $plan.Add($t) }
        }
    }

    # 7. language packs
    if ($o.Locales) {
        $locRoot = Join-Path $app 'locales'
        if (Test-Path -LiteralPath $locRoot) {
            foreach ($f in (Get-ChildItem -LiteralPath $locRoot -File -Filter '*.pak' -ErrorAction SilentlyContinue)) {
                if ($o.KeepLocales -notcontains $f.Name) {
                    $t = New-Target 'Language packs' $f.FullName 'File' "locales\$($f.Name)" "$appRel\locales\$($f.Name)"
                    if ($t) { $plan.Add($t) }
                }
            }
        }
    }

    # 8. stray logs
    if ($o.Logs) {
        foreach ($f in (Get-ChildItem -LiteralPath $Root -File -Filter '*.log' -ErrorAction SilentlyContinue)) {
            $t = New-Target 'Logs' $f.FullName 'File' $f.Name $f.Name
            if ($t) { $plan.Add($t) }
        }
        foreach ($f in (Get-ChildItem -LiteralPath $app -File -Filter '*.log' -ErrorAction SilentlyContinue)) {
            $t = New-Target 'Logs' $f.FullName 'File' $f.Name "$appRel\$($f.Name)"
            if ($t) { $plan.Add($t) }
        }
        $modRoot = Join-Path $app 'modules'
        if (Test-Path -LiteralPath $modRoot) {
            foreach ($f in (Get-ChildItem -LiteralPath $modRoot -File -Filter '*.log' -Recurse -ErrorAction SilentlyContinue)) {
                # Was $f.FullName.Substring($modRoot.Length + 1) - the 8.3 trap.
                $sub = Get-RelativePathSafe -Base $modRoot -Full $f.FullName
                $t = New-Target 'Logs' $f.FullName 'File' $f.Name "$appRel\modules\$sub"
                if ($t) { $plan.Add($t) }
            }
        }
    }

    # De-duplicate, and drop anything already contained in a folder the plan
    # deletes wholesale - otherwise those entries double-count in the size
    # estimate and fail at delete time because their parent is already gone.
    $prefixes = @($plan | Where-Object { $_.Kind -eq 'Dir' } |
                  ForEach-Object { $_.Path.TrimEnd('\') + '\' })
    $seen  = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $final = New-Object System.Collections.Generic.List[object]
    foreach ($t in $plan) {
        if (-not $seen.Add($t.Path)) { continue }
        $covered = $false
        foreach ($pre in $prefixes) {
            if ($t.Path.Length -gt $pre.Length -and
                $t.Path.StartsWith($pre, [StringComparison]::OrdinalIgnoreCase)) { $covered = $true; break }
        }
        if (-not $covered) { $final.Add($t) }
    }

    # Invariant check. Every target must carry a Rel that actually round-trips back
    # to the file it describes, because Rel is what the backup writes and what the
    # restore reads - a wrong one silently restores to the wrong place. This class
    # of defect (8.3 vs long paths, substring arithmetic) has bitten this project
    # three times, so it is asserted here rather than left to review.
    foreach ($t in $final) {
        $bad = $null
        if ([string]::IsNullOrWhiteSpace($t.Rel)) {
            $bad = 'empty Rel'
        } elseif ([System.IO.Path]::IsPathRooted($t.Rel)) {
            $bad = 'Rel is absolute'
        } else {
            $rebuilt = Resolve-LongPath (Join-Path $Root $t.Rel)
            if (-not $rebuilt.Equals((Resolve-LongPath $t.Path), [StringComparison]::OrdinalIgnoreCase)) {
                $bad = "Rel does not round-trip (Root\Rel -> $rebuilt)"
            }
        }
        if ($bad) {
            Write-Warning ("Get-DebloatPlan: {0} for '{1}' [{2}]" -f $bad, $t.Path, $t.Category)
            $t | Add-Member -NotePropertyName RelInvalid -NotePropertyValue $bad -Force
        }
    }
    return $final
}

<#
    Reads the logs a signed Discord writes into %APPDATA%\discord\logs and reports
    which Krisp models this machine has actually loaded.

    This exists because model selection happens in Discord's renderer, which is
    served from Discord's servers - it cannot be determined from anything on disk
    on disk. The log is the only oracle, and it is per-machine, so the Krisp
    preset becomes an evidence-based choice here instead of a guess baked in from
    someone else's install.

    Deliberately NOT in $script:EngineNames: no worker body calls it, it only feeds
    the advisory line under the Krisp dropdown.
#>
function Get-KrispUsage {
    # Takes the Discord PROFILE folder (%APPDATA%\discord), not %APPDATA% itself, so it
    # honours -AppDataPath. It used to default to $env:APPDATA and was called with no
    # argument, so the advisory reported the LIVE profile even when the tool had been
    # pointed elsewhere for testing.
    param([string] $ProfilePath = (Join-Path $env:APPDATA 'discord'))

    $res = [pscustomobject]@{
        Found = $false; Models = @(); VadSetups = 0; NcSetups = 0; Logs = 0; Unread = 0
    }
    if ([string]::IsNullOrWhiteSpace($ProfilePath)) { return $res }
    $dir = Join-Path $ProfilePath 'logs'
    if (-not (Test-Path -LiteralPath $dir)) { return $res }

    $logs = @(Get-ChildItem -LiteralPath $dir -File -Filter 'discord_krisp*.log' -ErrorAction SilentlyContinue)
    if ($logs.Count -eq 0) { return $res }

    $models = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    $vad = 0; $nc = 0; $unread = 0
    foreach ($f in $logs) {
        # Discord keeps the live log open, so this MUST be opened with
        # FileShare.ReadWrite - [System.IO.File]::ReadLines() takes no share flag
        # and throws a sharing violation while the client is running. Swallowing
        # that quietly is how you end up reporting the rotated log's counts as if
        # they were the whole picture; $unread makes the failure visible instead.
        $fs = $null; $sr = $null
        try {
            $fs = [System.IO.File]::Open($f.FullName, [System.IO.FileMode]::Open,
                                         [System.IO.FileAccess]::Read,
                                         [System.IO.FileShare]::ReadWrite)
            $sr = New-Object System.IO.StreamReader($fs)
            while ($null -ne ($line = $sr.ReadLine())) {
                if ($line -match 'Setting Krisp model:\s*([A-Za-z0-9_]+)') { $null = $models.Add($Matches[1]) }
                elseif ($line -match 'KrispVADSetup') { $vad++ }
                elseif ($line -match 'KrispNCSetup')  { $nc++ }
            }
        } catch {
            $unread++
        } finally {
            if ($sr) { $sr.Dispose() }
            if ($fs) { $fs.Dispose() }
        }
    }
    $res.Found     = $true
    $res.Models    = @($models)
    $res.VadSetups = $vad
    $res.NcSetups  = $nc
    $res.Logs      = $logs.Count
    $res.Unread    = $unread
    return $res
}

function Stop-DiscordProcesses {
    param([string] $Root)
    $killed = 0

    # $Root can arrive as an 8.3 short path - %TEMP% is routinely
    # C:\Users\ADMINI~1\... - while Get-Process reports long paths. Comparing the
    # two raw forms never matches, which used to drop through to the name-based
    # fallback below and terminate the user's REAL Discord while the tool was
    # pointed at a copy for testing. Canonicalise before comparing.
    $full = $Root
    try   { $full = (Get-Item -LiteralPath $Root -ErrorAction Stop).FullName }
    catch { try { $full = [System.IO.Path]::GetFullPath($Root) } catch { } }
    $full = $full.TrimEnd('\')

    $procs = @(Get-Process -ErrorAction SilentlyContinue | Where-Object {
        try { $_.Path -and $_.Path.StartsWith($full + '\', [StringComparison]::OrdinalIgnoreCase) } catch { $false }
    })
    if (-not $procs) {
        # Only guess by process name when we are actually operating on the live
        # install. Anywhere else, "no matching process" means there is genuinely
        # nothing of ours running - it must not mean "kill whatever is called
        # Discord", or testing against a copy takes the real client down with it.
        $live = $null
        try { $live = (Join-Path $env:LOCALAPPDATA 'Discord').TrimEnd('\') } catch { }
        if ($live -and $full.Equals($live, [StringComparison]::OrdinalIgnoreCase)) {
            $procs = @(Get-Process -Name 'Discord', 'DiscordCanary', 'DiscordPTB', 'Update' -ErrorAction SilentlyContinue)
        }
    }
    foreach ($p in $procs) {
        try { $p | Stop-Process -Force -ErrorAction Stop; $killed++ } catch { }
    }
    if ($killed) { Start-Sleep -Milliseconds 900 }
    return $killed
}

function Set-DiscordSettings {
    param(
        [Parameter(Mandatory)] [string] $AppDataPath,
        [hashtable] $Values
    )
    $file = Join-Path $AppDataPath 'settings.json'
    $obj  = [ordered]@{}
    if (Test-Path -LiteralPath $file) {
        try {
            $existing = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            foreach ($p in $existing.PSObject.Properties) { $obj[$p.Name] = $p.Value }
        } catch { }
    }
    foreach ($k in $Values.Keys) { $obj[$k] = $Values[$k] }
    if (-not (Test-Path -LiteralPath $AppDataPath)) {
        New-Item -ItemType Directory -Path $AppDataPath -Force | Out-Null
    }
    # Depth 8 silently truncates and reports it only on the warning stream, which
    # the worker never surfaces - a settings.json nested deeper than 8 would be
    # written back corrupted. 64 is far past anything Discord or its client mods
    # produce.
    $json = ([pscustomobject]$obj | ConvertTo-Json -Depth 64)
    [System.IO.File]::WriteAllText($file, $json, (New-Object System.Text.UTF8Encoding($false)))
    return $file
}

#===============================================================================
#  BACKUP / RESTORE
#===============================================================================
$script:BackupRoot = Join-Path $env:LOCALAPPDATA 'DiscordDebloat\Backups'

function New-DebloatBackup {
    param(
        [Parameter(Mandatory)] [string] $Root,
        [Parameter(Mandatory)] [object] $Plan,
        [scriptblock] $Report = $null
    )
    $stamp  = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
    $dest   = Join-Path $script:BackupRoot $stamp
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    $entries = New-Object System.Collections.Generic.List[object]

    foreach ($t in $Plan) {
        $rel = $t.Rel
        $to  = Join-Path (Join-Path $dest 'files') $rel
        try {
            $parent = Split-Path $to -Parent
            if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
            Copy-Item -LiteralPath $t.Path -Destination $to -Recurse -Force -ErrorAction Stop
            $entries.Add([pscustomobject]@{ Rel = $rel; Kind = $t.Kind; Size = $t.Size })
        } catch {
            if ($Report) { & $Report 'warn' "backup skipped: $rel" }
        }
    }

    $manifest = [pscustomobject]@{
        Created     = (Get-Date).ToString('s')
        Source      = $Root
        ToolVersion = $script:ToolVersion
        Count       = $entries.Count
        Bytes       = (($entries | Measure-Object -Property Size -Sum).Sum)
        Entries     = $entries
    }
    $manifest | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $dest 'manifest.json') -Encoding UTF8
    return $dest
}

function Get-DebloatBackups {
    if (-not (Test-Path -LiteralPath $script:BackupRoot)) { return @() }
    $out = New-Object System.Collections.Generic.List[object]
    foreach ($d in (Get-ChildItem -LiteralPath $script:BackupRoot -Directory -ErrorAction SilentlyContinue |
                    Sort-Object Name -Descending)) {
        $mf = Join-Path $d.FullName 'manifest.json'
        if (-not (Test-Path -LiteralPath $mf)) { continue }
        try {
            $m = Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
            $out.Add([pscustomobject]@{
                Name    = $d.Name
                Path    = $d.FullName
                Created = $m.Created
                Count   = $m.Count
                Bytes   = [long]$m.Bytes
                Source  = $m.Source
                Display = ('{0}   -   {1} items   -   {2}' -f $d.Name, $m.Count, (Format-Size ([long]$m.Bytes)))
            })
        } catch { }
    }
    return $out
}

function Restore-DebloatBackup {
    param(
        [Parameter(Mandatory)] [string] $BackupPath,
        [scriptblock] $Report = $null
    )
    $m       = Get-Content -LiteralPath (Join-Path $BackupPath 'manifest.json') -Raw | ConvertFrom-Json
    $filesRt = Join-Path $BackupPath 'files'
    $ok = 0; $fail = 0
    foreach ($e in $m.Entries) {
        $from = Join-Path $filesRt $e.Rel
        $to   = Join-Path $m.Source $e.Rel
        try {
            $parent = Split-Path $to -Parent
            if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }

            # Copy-Item -Recurse onto an EXISTING directory copies the source
            # *inside* it, producing discord_media-1\discord_media-1. That happens
            # on any second restore, or whenever Discord has recreated the folder.
            # For directories, create the destination and copy the contents in.
            $isDir = $false
            try { $isDir = (Get-Item -LiteralPath $from -ErrorAction Stop).PSIsContainer } catch { }
            if ($isDir) {
                if (-not (Test-Path -LiteralPath $to)) { New-Item -ItemType Directory -Path $to -Force | Out-Null }
                foreach ($k in @(Get-ChildItem -LiteralPath $from -Force -ErrorAction SilentlyContinue)) {
                    Copy-Item -LiteralPath $k.FullName -Destination $to -Recurse -Force -ErrorAction Stop
                }
            } else {
                Copy-Item -LiteralPath $from -Destination $to -Force -ErrorAction Stop
            }
            $ok++
            if ($Report) { & $Report 'ok' "restored  $($e.Rel)" }
        } catch {
            $fail++
            if ($Report) { & $Report 'err' "failed    $($e.Rel)" }
        }
    }
    return [pscustomobject]@{ Restored = $ok; Failed = $fail; Source = $m.Source }
}

#===============================================================================
#  HEADLESS SELF-TEST
#===============================================================================
if ($Selftest) {
    Write-Host ''
    Write-Host '  Discord Debloat Suite - engine self-test' -ForegroundColor Cyan
    Write-Host "  target: $InstallPath" -ForegroundColor DarkGray
    Write-Host ''
    $InstallPath = Resolve-LongPath $InstallPath
    $active = Get-ActiveAppDir -Root $InstallPath
    if (-not $active) { Write-Host '  no app-* folder found' -ForegroundColor Red; exit 1 }
    Write-Host ("  detected version : {0}" -f $active.Version)
    $before = Get-PathSize -Path $InstallPath
    Write-Host ("  size before      : {0}" -f (Format-Size $before))

    $plan = Get-DebloatPlan -Root $InstallPath
    Write-Host ("  plan targets     : {0}  ({1})" -f $plan.Count, (Format-Size (($plan | Measure-Object Size -Sum).Sum)))
    Write-Host ''
    foreach ($g in ($plan | Group-Object Category | Sort-Object { -($_.Group | Measure-Object Size -Sum).Sum })) {
        Write-Host ('    {0,-20} {1,4} items   {2,10}' -f $g.Name, $g.Count,
                    (Format-Size (($g.Group | Measure-Object Size -Sum).Sum)))
    }
    Write-Host ''
    if ($DryRun) { Write-Host '  DRY RUN - nothing deleted' -ForegroundColor Yellow; exit 0 }

    foreach ($t in $plan) { Remove-Item -LiteralPath $t.Path -Recurse -Force -ErrorAction SilentlyContinue }
    $after = Get-PathSize -Path $InstallPath
    Write-Host ("  size after       : {0}" -f (Format-Size $after)) -ForegroundColor Green
    Write-Host ("  freed            : {0}" -f (Format-Size ($before - $after))) -ForegroundColor Green
    Write-Host ''
    exit 0
}

#===============================================================================
#  UI
#===============================================================================
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml

$xamlText = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Discord Debloat Suite" Height="768" Width="1160"
        WindowStartupLocation="CenterScreen" WindowStyle="None"
        Background="Transparent"
        ResizeMode="CanMinimize" FontFamily="Segoe UI" SnapsToDevicePixels="True"
        TextOptions.TextFormattingMode="Display">

  <WindowChrome.WindowChrome>
    <WindowChrome CaptionHeight="0" CornerRadius="0" GlassFrameThickness="0"
                  ResizeBorderThickness="0" UseAeroCaptionButtons="False"/>
  </WindowChrome.WindowChrome>

  <Window.Resources>
    <SolidColorBrush x:Key="Bg"      Color="#0A0B0F"/>
    <SolidColorBrush x:Key="Side"    Color="#0D0F14"/>
    <SolidColorBrush x:Key="Card"    Color="#131620"/>
    <SolidColorBrush x:Key="CardHi"  Color="#171B26"/>
    <SolidColorBrush x:Key="Stroke"  Color="#232837"/>
    <SolidColorBrush x:Key="Soft"    Color="#1B1F2B"/>
    <SolidColorBrush x:Key="TxtHi"   Color="#E9ECF4"/>
    <SolidColorBrush x:Key="TxtMid"  Color="#9AA1B4"/>
    <SolidColorBrush x:Key="TxtLo"   Color="#5F6678"/>
    <SolidColorBrush x:Key="Ok"      Color="#34D399"/>
    <SolidColorBrush x:Key="Warn"    Color="#FBBF24"/>
    <SolidColorBrush x:Key="Err"     Color="#F87171"/>
    <SolidColorBrush x:Key="Accent"  Color="#6D6BF2"/>
    <SolidColorBrush x:Key="AccentLo" Color="#8B7CF6"/>
    <SolidColorBrush x:Key="Hair"    Color="#2A3145"/>

    <!-- Icons come from Segoe MDL2 Assets, which ships with Windows 10 and 11, so
         the tool stays a single file with no embedded artwork. -->
    <FontFamily x:Key="Icons">Segoe MDL2 Assets</FontFamily>

    <!-- One shared shadow, applied only to the top-level content cards. Effects are
         per-element render passes, so this is deliberately not sprinkled on every
         border. -->
    <DropShadowEffect x:Key="Elev" BlurRadius="26" ShadowDepth="5" Direction="270"
                      Color="#000000" Opacity="0.42"/>
    <DropShadowEffect x:Key="ElevSoft" BlurRadius="14" ShadowDepth="2" Direction="270"
                      Color="#000000" Opacity="0.30"/>

    <LinearGradientBrush x:Key="Grad" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#6366F1" Offset="0"/>
      <GradientStop Color="#A855F7" Offset="1"/>
    </LinearGradientBrush>

    <LinearGradientBrush x:Key="GradSoft" StartPoint="0,0" EndPoint="1,0">
      <GradientStop Color="#1A1B33" Offset="0"/>
      <GradientStop Color="#221A33" Offset="1"/>
    </LinearGradientBrush>

    <!-- Faint top highlight so cards read as lit from above instead of flat fills. -->
    <LinearGradientBrush x:Key="CardGrad" StartPoint="0,0" EndPoint="0,1">
      <GradientStop Color="#181C28" Offset="0"/>
      <GradientStop Color="#131620" Offset="0.55"/>
    </LinearGradientBrush>

    <LinearGradientBrush x:Key="GradHot" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#7C7CF8" Offset="0"/>
      <GradientStop Color="#BE6BFA" Offset="1"/>
    </LinearGradientBrush>

    <!-- Same gradient at ~85% so the Mica backdrop tints through without the UI
         losing its own identity. Only applied when DWM accepted the backdrop. -->
    <LinearGradientBrush x:Key="ShellBgMica" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#D90B0C11" Offset="0"/>
      <GradientStop Color="#D90A0B0F" Offset="0.55"/>
      <GradientStop Color="#D90D0B12" Offset="1"/>
    </LinearGradientBrush>

    <LinearGradientBrush x:Key="ShellBg" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#0B0C11" Offset="0"/>
      <GradientStop Color="#0A0B0F" Offset="0.55"/>
      <GradientStop Color="#0D0B12" Offset="1"/>
    </LinearGradientBrush>

    <!-- ============================ scrollbar ============================ -->
    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="8"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ScrollBar">
            <Grid Background="Transparent">
              <Track x:Name="PART_Track" IsDirectionReversed="True">
                <Track.Thumb>
                  <Thumb>
                    <Thumb.Template>
                      <ControlTemplate TargetType="Thumb">
                        <Border CornerRadius="4" Background="#2C3243" Margin="2,0"/>
                      </ControlTemplate>
                    </Thumb.Template>
                  </Thumb>
                </Track.Thumb>
                <Track.IncreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageDownCommand" Opacity="0" Focusable="False"/>
                </Track.IncreaseRepeatButton>
                <Track.DecreaseRepeatButton>
                  <RepeatButton Command="ScrollBar.PageUpCommand" Opacity="0" Focusable="False"/>
                </Track.DecreaseRepeatButton>
              </Track>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============================ buttons ============================== -->
    <!-- Buttons and cards below lean on GradHot for hover, so the accent reads as a
         light source rather than a flat colour swap. -->
    <Style x:Key="Primary" TargetType="Button">
      <Setter Property="Effect" Value="{StaticResource ElevSoft}"/>
      <Setter Property="Height" Value="42"/>
      <Setter Property="Foreground" Value="White"/>
      <Setter Property="FontSize" Value="13"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Grid>
              <Border x:Name="Glow" CornerRadius="10" Background="{StaticResource Grad}"
                      Opacity="0.30" Margin="0,3,0,-3"/>
              <Border x:Name="B" CornerRadius="10" Background="{StaticResource Grad}">
                <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="18,0"/>
              </Border>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Glow" Property="Opacity" Value="0.55"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="B" Property="Opacity" Value="0.30"/>
                <Setter TargetName="Glow" Property="Opacity" Value="0"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Ghost" TargetType="Button">
      <Setter Property="Height" Value="42"/>
      <Setter Property="Foreground" Value="{StaticResource TxtMid}"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" CornerRadius="10" Background="{StaticResource Soft}"
                    BorderBrush="{StaticResource Stroke}" BorderThickness="1">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center" Margin="18,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="#20242F"/>
                <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter TargetName="B" Property="Opacity" Value="0.35"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Danger" TargetType="Button" BasedOn="{StaticResource Ghost}">
      <Setter Property="Foreground" Value="#F87171"/>
    </Style>

    <Style x:Key="Chip" TargetType="Button">
      <Setter Property="Height" Value="22"/>
      <Setter Property="Margin" Value="6,0,0,0"/>
      <Setter Property="Foreground" Value="{StaticResource TxtLo}"/>
      <Setter Property="FontSize" Value="10.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" CornerRadius="6" Background="#171B26"
                    BorderBrush="{StaticResource Stroke}" BorderThickness="1" Padding="9,0">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="#1E2230"/>
                <Setter TargetName="B" Property="BorderBrush" Value="#6D6BF2"/>
                <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Chrome" TargetType="Button">
      <Setter Property="Width" Value="42"/>
      <Setter Property="Height" Value="34"/>
      <Setter Property="Foreground" Value="{StaticResource TxtLo}"/>
      <Setter Property="FontFamily" Value="Segoe MDL2 Assets"/>
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="B" CornerRadius="7" Background="Transparent">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="#1E2230"/>
                <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============================== nav ================================ -->
    <Style x:Key="Nav" TargetType="RadioButton">
      <Setter Property="Height" Value="42"/>
      <Setter Property="Margin" Value="12,2,12,2"/>
      <Setter Property="Foreground" Value="{StaticResource TxtMid}"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Grid>
              <Border x:Name="B" CornerRadius="10" Background="Transparent"
                      BorderBrush="Transparent" BorderThickness="1"/>
              <Border x:Name="Bar" Width="3" HorizontalAlignment="Left" CornerRadius="2"
                      Background="{StaticResource GradHot}" Margin="0,9" Opacity="0"/>
              <Grid Margin="17,0,10,0">
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="26"/><ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <TextBlock x:Name="Ico" Grid.Column="0" Text="{TemplateBinding Tag}"
                           FontFamily="{StaticResource Icons}" FontSize="14.5"
                           VerticalAlignment="Center" Opacity="0.75"/>
                <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
              </Grid>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="#161A27"/>
                <Setter TargetName="Ico" Property="Opacity" Value="1"/>
                <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="B" Property="Background" Value="{StaticResource GradSoft}"/>
                <Setter TargetName="B" Property="BorderBrush" Value="#2E2A4A"/>
                <Setter TargetName="Bar" Property="Opacity" Value="1"/>
                <Setter TargetName="Ico" Property="Opacity" Value="1"/>
                <Setter TargetName="Ico" Property="Foreground" Value="{StaticResource AccentLo}"/>
                <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- =========================== checkbox ============================== -->
    <Style x:Key="Chk" TargetType="CheckBox">
      <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Grid Background="Transparent">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border x:Name="Box" Width="19" Height="19" CornerRadius="6"
                      Background="#171B26" BorderBrush="#2C3243" BorderThickness="1.3"
                      VerticalAlignment="Top" Margin="0,1,13,0">
                <Path x:Name="Tick" Data="M 4 9 L 7.4 12.4 L 14 5.4" Stroke="White"
                      StrokeThickness="2" StrokeStartLineCap="Round" StrokeEndLineCap="Round"
                      Visibility="Collapsed"/>
              </Border>
              <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Box" Property="BorderBrush" Value="#4A5164"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Box" Property="Background" Value="{StaticResource Grad}"/>
                <Setter TargetName="Box" Property="BorderBrush" Value="#7C6CF5"/>
                <Setter TargetName="Tick" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.4"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ============================= radio =============================== -->
    <Style x:Key="Rad" TargetType="RadioButton">
      <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,0,10"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Grid Background="Transparent">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Grid Width="19" Height="19" Margin="0,0,13,0" VerticalAlignment="Center">
                <Ellipse x:Name="Ring" Fill="#171B26" Stroke="#2C3243" StrokeThickness="1.3"/>
                <Ellipse x:Name="Dot" Width="9" Height="9" Fill="{StaticResource Grad}" Visibility="Collapsed"/>
              </Grid>
              <ContentPresenter Grid.Column="1" VerticalAlignment="Center"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="Ring" Property="Stroke" Value="#4A5164"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="Ring" Property="Stroke" Value="#7C6CF5"/>
                <Setter TargetName="Dot" Property="Visibility" Value="Visible"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- =========================== combo box ============================= -->
    <Style x:Key="ComboItem" TargetType="ComboBoxItem">
      <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Padding" Value="13,9"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBoxItem">
            <Border x:Name="Bd" Background="Transparent" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#1F2534"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="Bd" Property="Background" Value="#252C3E"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Combo" TargetType="ComboBox">
      <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="ItemContainerStyle" Value="{StaticResource ComboItem}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ComboBox">
            <Grid>
              <ToggleButton Focusable="False" ClickMode="Press"
                            IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="ToggleButton">
                    <Border x:Name="Bd" Background="#171B26" BorderBrush="#2C3243" BorderThickness="1"
                            CornerRadius="8" Padding="13,9">
                      <Grid>
                        <Grid.ColumnDefinitions>
                          <ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/>
                        </Grid.ColumnDefinitions>
                        <Path Grid.Column="1" Data="M0,0 L4.5,4.5 L9,0" Stroke="#9AA1B4"
                              StrokeThickness="1.6" VerticalAlignment="Center" Margin="10,2,0,0"/>
                      </Grid>
                    </Border>
                    <ControlTemplate.Triggers>
                      <Trigger Property="IsMouseOver" Value="True">
                        <Setter TargetName="Bd" Property="BorderBrush" Value="#4A5164"/>
                      </Trigger>
                      <Trigger Property="IsChecked" Value="True">
                        <Setter TargetName="Bd" Property="BorderBrush" Value="#7C6CF5"/>
                      </Trigger>
                    </ControlTemplate.Triggers>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <ContentPresenter Margin="14,0,36,0" VerticalAlignment="Center" IsHitTestVisible="False"
                                Content="{TemplateBinding SelectionBoxItem}"/>
              <Popup x:Name="PART_Popup" AllowsTransparency="True" Placement="Bottom"
                     IsOpen="{TemplateBinding IsDropDownOpen}" PopupAnimation="Fade" Focusable="False">
                <Border Background="#131620" BorderBrush="#2C3243" BorderThickness="1"
                        CornerRadius="8" Margin="0,4,0,0"
                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}">
                  <ItemsPresenter/>
                </Border>
              </Popup>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- =========================== list items ============================ -->
    <Style x:Key="PlainItem" TargetType="ListBoxItem">
      <Setter Property="Padding" Value="0"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <ContentPresenter/>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="PickItem" TargetType="ListBoxItem">
      <Setter Property="Padding" Value="14,11"/>
      <Setter Property="Margin" Value="0,0,0,6"/>
      <Setter Property="Foreground" Value="{StaticResource TxtMid}"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ListBoxItem">
            <Border x:Name="B" CornerRadius="9" Background="#141824"
                    BorderBrush="{StaticResource Stroke}" BorderThickness="1" Padding="{TemplateBinding Padding}">
              <ContentPresenter/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="B" Property="Background" Value="#191E2C"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="B" Property="Background" Value="#1E1B33"/>
                <Setter TargetName="B" Property="BorderBrush" Value="#6D6BF2"/>
                <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- ========================= text presets ============================ -->
    <Style x:Key="Stat" TargetType="TextBlock">
      <Setter Property="FontSize" Value="27"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
    </Style>

    <Style x:Key="H1" TargetType="TextBlock">
      <Setter Property="FontSize" Value="21"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Foreground" Value="{StaticResource TxtHi}"/>
    </Style>
    <Style x:Key="Sub" TargetType="TextBlock">
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Foreground" Value="{StaticResource TxtLo}"/>
      <Setter Property="Margin" Value="0,5,0,0"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
    </Style>
    <Style x:Key="Eyebrow" TargetType="TextBlock">
      <Setter Property="FontSize" Value="10"/>
      <Setter Property="FontWeight" Value="Bold"/>
      <Setter Property="Foreground" Value="{StaticResource TxtLo}"/>
    </Style>
    <Style x:Key="Note" TargetType="TextBlock">
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Foreground" Value="{StaticResource TxtLo}"/>
      <Setter Property="TextWrapping" Value="Wrap"/>
      <Setter Property="Margin" Value="32,3,0,0"/>
    </Style>

    <!-- ========================== data templates ========================= -->
    <DataTemplate x:Key="LogTpl">
      <Grid Margin="0,0,0,3">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="62"/><ColumnDefinition Width="38"/><ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <TextBlock Text="{Binding Time}" Foreground="#464C5C" FontFamily="Consolas" FontSize="11"/>
        <TextBlock Grid.Column="1" Text="{Binding Tag}" Foreground="{Binding Color}"
                   FontFamily="Consolas" FontSize="11" FontWeight="Bold"/>
        <TextBlock Grid.Column="2" Text="{Binding Msg}" Foreground="#AEB5C6"
                   FontFamily="Consolas" FontSize="11.5" TextWrapping="Wrap"/>
      </Grid>
    </DataTemplate>

    <DataTemplate x:Key="BreakTpl">
      <Border Background="#141824" CornerRadius="9" Padding="14,11" Margin="0,0,0,7"
              BorderBrush="{StaticResource Stroke}" BorderThickness="1">
        <Grid>
          <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="86"/>
          </Grid.ColumnDefinitions>
          <TextBlock Text="{Binding Name}" Foreground="#D5DAE6" FontSize="12.5"/>
          <Border Grid.Column="1" Background="#1D2130" CornerRadius="5" Padding="7,2" Margin="0,0,12,0">
            <TextBlock Text="{Binding Count}" Foreground="#7E8598" FontSize="10.5" FontWeight="SemiBold"/>
          </Border>
          <TextBlock Grid.Column="2" Text="{Binding Size}" Foreground="#8E7CF0" FontSize="12"
                     FontWeight="SemiBold" HorizontalAlignment="Right"/>
        </Grid>
      </Border>
    </DataTemplate>
  </Window.Resources>

  <!-- ================================ shell ============================== -->
  <Border x:Name="ShellRoot" CornerRadius="0" Background="{StaticResource ShellBg}"
          BorderBrush="#1E2230" BorderThickness="0">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="252"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <!-- ============================ sidebar ============================ -->
      <Border Background="{StaticResource Side}" CornerRadius="0">
        <Grid>
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <StackPanel Margin="22,26,22,22">
            <StackPanel Orientation="Horizontal">
              <Grid Width="40" Height="40">
                <!-- soft bloom behind the mark -->
                <Border CornerRadius="14" Background="{StaticResource GradHot}" Opacity="0.30"
                        Margin="-3"/>
                <Border CornerRadius="12" Background="{StaticResource Grad}">
                  <TextBlock Text="&#xE74D;" FontFamily="{StaticResource Icons}" Foreground="White"
                             FontSize="17" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
              </Grid>
              <StackPanel Margin="13,0,0,0" VerticalAlignment="Center">
                <TextBlock Text="DEBLOAT" Foreground="{StaticResource TxtHi}" FontSize="14.5"
                           FontWeight="Bold"/>
                <TextBlock x:Name="LblVersion" Text="suite v1.0.0" Foreground="{StaticResource TxtLo}"
                           FontSize="10"/>
              </StackPanel>
            </StackPanel>
          </StackPanel>

          <StackPanel Grid.Row="1" Margin="0,6,0,0">
            <TextBlock Text="WORKSPACE" Style="{StaticResource Eyebrow}" Margin="26,0,0,8"/>
            <RadioButton x:Name="NavOverview" Style="{StaticResource Nav}" Content="Overview" Tag="&#xE9D9;" IsChecked="True"/>
            <RadioButton x:Name="NavDebloat"  Style="{StaticResource Nav}" Content="Debloat"  Tag="&#xE74D;"/>
            <RadioButton x:Name="NavTweaks"   Style="{StaticResource Nav}" Content="Tweaks"   Tag="&#xE713;"/>
            <RadioButton x:Name="NavCache"    Style="{StaticResource Nav}" Content="Cache"    Tag="&#xE8B7;"/>
            <TextBlock Text="SAFETY" Style="{StaticResource Eyebrow}" Margin="26,20,0,8"/>
            <RadioButton x:Name="NavBackup"   Style="{StaticResource Nav}" Content="Backups"  Tag="&#xE81C;"/>
            <RadioButton x:Name="NavAbout"    Style="{StaticResource Nav}" Content="About"    Tag="&#xE946;"/>
          </StackPanel>

          <Border Grid.Row="2" Margin="16,0,16,16" CornerRadius="11" Padding="14,12"
                  Background="#12151E" BorderBrush="{StaticResource Stroke}" BorderThickness="1">
            <StackPanel>
              <StackPanel Orientation="Horizontal">
                <Ellipse x:Name="StatusDot" Width="7" Height="7" Fill="#FBBF24" VerticalAlignment="Center"/>
                <TextBlock x:Name="StatusText" Text="detecting..." Foreground="{StaticResource TxtMid}"
                           FontSize="11" Margin="8,0,0,0"/>
              </StackPanel>
              <TextBlock x:Name="StatusPath" Text="" Foreground="{StaticResource TxtLo}" FontSize="9.5"
                         Margin="0,6,0,0" TextTrimming="CharacterEllipsis"/>
            </StackPanel>
          </Border>
        </Grid>
      </Border>

      <!-- ============================ content ============================ -->
      <Grid Grid.Column="1">
        <Grid.RowDefinitions>
          <RowDefinition Height="52"/>
          <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <!-- title bar -->
        <Border x:Name="TitleBar" Background="Transparent">
          <Grid>
            <TextBlock x:Name="LblCrumb" Text="Overview" Foreground="{StaticResource TxtLo}"
                       FontSize="11.5" VerticalAlignment="Center" Margin="30,0,0,0"/>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,0,12,0"
                        VerticalAlignment="Center">
              <Border x:Name="SimBadge" CornerRadius="6" Background="#2A2410" BorderBrush="#5A4A14"
                      BorderThickness="1" Padding="8,3" Margin="0,0,12,0" Visibility="Collapsed">
                <TextBlock Text="SIMULATION" Foreground="#FBBF24" FontSize="9.5" FontWeight="Bold"/>
              </Border>
              <Button x:Name="BtnMin"   Style="{StaticResource Chrome}" Content="&#xE921;"/>
              <Button x:Name="BtnClose" Style="{StaticResource Chrome}" Content="&#xE8BB;"/>
            </StackPanel>
          </Grid>
        </Border>

        <Grid Grid.Row="1" Margin="30,0,30,26">

          <!-- ========================= OVERVIEW ========================== -->
          <Grid x:Name="PgOverview">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
              <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
            </Grid.RowDefinitions>

            <StackPanel>
              <TextBlock Text="Overview" Style="{StaticResource H1}"/>
              <TextBlock Style="{StaticResource Sub}"
                         Text="Scan the installation and see exactly how much of it is removable before anything is touched."/>
            </StackPanel>

            <!-- stat tiles -->
            <Grid Grid.Row="1" Margin="0,22,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/><ColumnDefinition Width="14"/>
                <ColumnDefinition Width="*"/><ColumnDefinition Width="14"/>
                <ColumnDefinition Width="*"/><ColumnDefinition Width="14"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="18,16"
                      BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                <StackPanel>
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE8B7;" FontFamily="{StaticResource Icons}" FontSize="11"
                               Foreground="{StaticResource TxtLo}" VerticalAlignment="Center"/>
                    <TextBlock Text="CURRENT SIZE" Style="{StaticResource Eyebrow}" Margin="7,0,0,0"/>
                  </StackPanel>
                  <TextBlock x:Name="StatCurrent" Text="--" Foreground="{StaticResource TxtHi}"
                             FontSize="24" FontWeight="SemiBold" Margin="0,8,0,0"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="2" Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="18,16"
                      BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                <StackPanel>
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE74D;" FontFamily="{StaticResource Icons}" FontSize="11"
                               Foreground="{StaticResource TxtLo}" VerticalAlignment="Center"/>
                    <TextBlock Text="REMOVABLE" Style="{StaticResource Eyebrow}" Margin="7,0,0,0"/>
                  </StackPanel>
                  <TextBlock x:Name="StatRemovable" Text="--" Foreground="#8E7CF0"
                             FontSize="24" FontWeight="SemiBold" Margin="0,8,0,0"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="4" Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="18,16"
                      BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                <StackPanel>
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE73E;" FontFamily="{StaticResource Icons}" FontSize="11"
                               Foreground="{StaticResource TxtLo}" VerticalAlignment="Center"/>
                    <TextBlock Text="SIZE AFTER" Style="{StaticResource Eyebrow}" Margin="7,0,0,0"/>
                  </StackPanel>
                  <TextBlock x:Name="StatAfter" Text="--" Foreground="{StaticResource Ok}"
                             FontSize="24" FontWeight="SemiBold" Margin="0,8,0,0"/>
                </StackPanel>
              </Border>
              <Border Grid.Column="6" Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="18,16"
                      BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                <StackPanel>
                  <StackPanel Orientation="Horizontal">
                    <TextBlock Text="&#xE8A5;" FontFamily="{StaticResource Icons}" FontSize="11"
                               Foreground="{StaticResource TxtLo}" VerticalAlignment="Center"/>
                    <TextBlock Text="FILES TO DROP" Style="{StaticResource Eyebrow}" Margin="7,0,0,0"/>
                  </StackPanel>
                  <TextBlock x:Name="StatFiles" Text="--" Foreground="{StaticResource TxtHi}"
                             FontSize="24" FontWeight="SemiBold" Margin="0,8,0,0"/>
                </StackPanel>
              </Border>
            </Grid>

            <Grid Grid.Row="2" Margin="0,20,0,14">
              <TextBlock Text="Breakdown by category" Foreground="{StaticResource TxtMid}"
                         FontSize="13" FontWeight="SemiBold" VerticalAlignment="Center"/>
              <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                <Button x:Name="BtnRescan" Style="{StaticResource Ghost}" Content="Rescan" Width="110" Height="36"/>
                <Button x:Name="BtnGoDebloat" Style="{StaticResource Primary}" Content="Continue"
                        Width="130" Height="36" Margin="10,0,0,0"/>
              </StackPanel>
            </Grid>

            <ScrollViewer Grid.Row="3" VerticalScrollBarVisibility="Auto">
              <ListBox x:Name="ListBreak" Background="Transparent" BorderThickness="0"
                       ItemTemplate="{StaticResource BreakTpl}"
                       ItemContainerStyle="{StaticResource PlainItem}"
                       ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
            </ScrollViewer>
          </Grid>

          <!-- ========================== DEBLOAT ========================== -->
          <Grid x:Name="PgDebloat" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel>
              <TextBlock Text="Debloat" Style="{StaticResource H1}"/>
              <TextBlock Style="{StaticResource Sub}"
                         Text="Pick what to remove from your Discord install. Voice, Krisp, input capture, the tray icon and the desktop core are always kept."/>
            </StackPanel>

            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,20,0,0">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/><ColumnDefinition Width="16"/><ColumnDefinition Width="300"/>
                </Grid.ColumnDefinitions>

                <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="20,18"
                        BorderBrush="{StaticResource Stroke}" BorderThickness="1" VerticalAlignment="Top">
                  <StackPanel>
                    <TextBlock Text="REMOVAL CATEGORIES" Style="{StaticResource Eyebrow}" Margin="0,0,0,16"/>

                    <CheckBox x:Name="ChkOldVersions" Style="{StaticResource Chk}" IsChecked="True"
                              Content="Superseded app-* folders"/>
                    <TextBlock Style="{StaticResource Note}" Text="Old client versions left behind by past updates."/>

                    <CheckBox x:Name="ChkRootJunk" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="Installer leftovers and auto-updater"/>
                    <TextBlock Style="{StaticResource Note}" Text="Update.exe, packages\, download\ - Discord can no longer self-update after this."/>

                    <CheckBox x:Name="ChkModules" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="Optional native modules"/>
                    <TextBlock Style="{StaticResource Note}" Text="Overlay, Rich Presence, spellcheck, cloud sync, dispatch, erlpack, zstd, media, notifications."/>

                    <CheckBox x:Name="ChkTrim" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="Trim the modules that stay"/>
                    <TextBlock Style="{StaticResource Note}" Text="Tray/thumbar artwork, manifests, helper EXEs, background-blur models. Krisp is never touched here."/>

                    <CheckBox x:Name="ChkGpu" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="GPU and hardware-acceleration libraries"/>
                    <TextBlock Style="{StaticResource Note}" Foreground="#C9A227"
                               Text="ANGLE / SwiftShader / Vulkan / DirectX. Hardware acceleration is force-disabled in settings.json when this is on."/>

                    <CheckBox x:Name="ChkPaks" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="Extra Chromium assets"/>
                    <TextBlock Style="{StaticResource Note}" Text="HiDPI resource packs, legacy V8 snapshot, crash reporter DLL."/>

                    <CheckBox x:Name="ChkLocales" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="Unused language packs"/>
                    <TextBlock Style="{StaticResource Note}"
                               Text="These are Chromium's own strings - right-click menus, spellcheck entries, error pages. They do not change Discord's UI language, which comes from your account."/>
                    <Border Margin="32,10,0,0" Background="#0E1119" CornerRadius="9"
                            BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                      <Grid>
                        <Grid.RowDefinitions>
                          <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid Margin="14,12,14,10">
                          <TextBlock x:Name="LblLangCount" Text="keep:" Style="{StaticResource Eyebrow}"
                                     VerticalAlignment="Center"/>
                          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
                            <Button x:Name="BtnLangSystem" Style="{StaticResource Chip}" Content="system"/>
                            <Button x:Name="BtnLangEnglish" Style="{StaticResource Chip}" Content="english"/>
                            <Button x:Name="BtnLangAll" Style="{StaticResource Chip}" Content="all"/>
                            <Button x:Name="BtnLangNone" Style="{StaticResource Chip}" Content="none"/>
                          </StackPanel>
                        </Grid>
                        <ScrollViewer Grid.Row="1" MaxHeight="188" VerticalScrollBarVisibility="Auto"
                                      Margin="0,0,0,6">
                          <ItemsControl x:Name="LangHost" Margin="14,0,10,8">
                            <ItemsControl.ItemsPanel>
                              <ItemsPanelTemplate><WrapPanel Orientation="Horizontal"/></ItemsPanelTemplate>
                            </ItemsControl.ItemsPanel>
                          </ItemsControl>
                        </ScrollViewer>
                        <TextBlock x:Name="LblLangWarn" Grid.Row="2" Margin="14,0,14,12" FontSize="11"
                                   Foreground="#C9A227" TextWrapping="Wrap" Visibility="Collapsed"
                                   Text="en-US.pak is Chromium's final fallback. Without it, native menus may show blank labels."/>
                      </Grid>
                    </Border>

                    <CheckBox x:Name="ChkLogs" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="Stray log files"/>
                  </StackPanel>
                </Border>

                <StackPanel Grid.Column="2">
                  <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="20,18"
                          BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                    <StackPanel>
                      <TextBlock Text="RUN OPTIONS" Style="{StaticResource Eyebrow}" Margin="0,0,0,16"/>
                      <CheckBox x:Name="ChkBackup" Style="{StaticResource Chk}" IsChecked="True"
                                Content="Back up removed files"/>
                      <TextBlock Style="{StaticResource Note}" Text="Copies only what is deleted, so a restore is possible later."/>
                      <CheckBox x:Name="ChkSim" Style="{StaticResource Chk}" Margin="0,15,0,0"
                                Content="Simulation (delete nothing)"/>
                      <TextBlock Style="{StaticResource Note}" Text="Walks the whole plan and logs every target without touching disk."/>
                      <CheckBox x:Name="ChkShortcut" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                                Content="Create desktop shortcut"/>
                      <TextBlock Style="{StaticResource Note}" Text="Points straight at Discord.exe, bypassing Update.exe."/>
                    </StackPanel>
                  </Border>

                  <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="20,18" Margin="0,14,0,0"
                          BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                    <StackPanel>
                      <TextBlock Text="OPTIONAL EXTRAS" Style="{StaticResource Eyebrow}"/>
                      <TextBlock Style="{StaticResource Note}" Margin="0,6,0,14"
                                 Text="Leave both off unless you know you do not need what they provide."/>
                      <TextBlock Text="Krisp models" Foreground="#E9ECF4" FontSize="12.5" FontWeight="SemiBold"/>
                      <ComboBox x:Name="CmbKrisp" Style="{StaticResource Combo}" Margin="0,8,0,0"
                                SelectedIndex="0">
                        <ComboBoxItem>All models</ComboBoxItem>
                        <ComboBoxItem>No background voice cancellation</ComboBoxItem>
                        <ComboBoxItem>Essential only</ComboBoxItem>
                        <ComboBoxItem>Remove Krisp entirely</ComboBoxItem>
                      </ComboBox>
                      <TextBlock x:Name="TxtKrispNote" Style="{StaticResource Note}" Margin="0,8,0,0"/>
                      <TextBlock x:Name="TxtKrispEvidence" Style="{StaticResource Note}" Margin="0,8,0,0"/>
                      <CheckBox x:Name="ChkAggrMediapipe" Style="{StaticResource Chk}" Margin="0,15,0,0"
                                Content="Remove mediapipe.dll"/>
                      <TextBlock Style="{StaticResource Note}" Foreground="#C9A227"
                                 Text="8.3 MB. Riskier: Discord still advertises background blur, so toggling it on could upset the voice engine."/>
                    </StackPanel>
                  </Border>

                  <Border Background="#1A1508" CornerRadius="12" Padding="16,14" Margin="0,14,0,0"
                          BorderBrush="#3D3212" BorderThickness="1">
                    <StackPanel>
                      <TextBlock Text="AFTER DEBLOATING" Foreground="#C9A227" FontSize="10" FontWeight="Bold"/>
                      <TextBlock Foreground="#9A8534" FontSize="11" TextWrapping="Wrap" Margin="0,8,0,0"
                                 Text="Auto-update stops working. Screen-share, overlay, Rich Presence, spellcheck and background blur are gone. Krisp noise suppression is kept unless you opt out above. Reinstall Discord to undo, or restore from a backup."/>
                    </StackPanel>
                  </Border>
                </StackPanel>
              </Grid>
            </ScrollViewer>

            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
              <Button x:Name="BtnPreview" Style="{StaticResource Ghost}" Content="Preview plan" Width="140"/>
              <Button x:Name="BtnRunDebloat" Style="{StaticResource Primary}" Content="Run debloat"
                      Width="180" Margin="12,0,0,0"/>
            </StackPanel>
          </Grid>

          <!-- =========================== TWEAKS ========================== -->
          <Grid x:Name="PgTweaks" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel>
              <TextBlock Text="Tweaks" Style="{StaticResource H1}"/>
              <TextBlock Style="{StaticResource Sub}"
                         Text="Configuration-level changes. These edit settings.json and Windows registry values - no files are deleted here."/>
            </StackPanel>

            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,20,0,0">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/><ColumnDefinition Width="16"/><ColumnDefinition Width="320"/>
                </Grid.ColumnDefinitions>

                <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="20,18"
                        BorderBrush="{StaticResource Stroke}" BorderThickness="1" VerticalAlignment="Top">
                  <StackPanel>
                    <TextBlock Text="CLIENT SETTINGS" Style="{StaticResource Eyebrow}" Margin="0,0,0,16"/>
                    <CheckBox x:Name="ChkTwHwAccel" Style="{StaticResource Chk}" IsChecked="True"
                              Content="Disable hardware acceleration"/>
                    <TextBlock Style="{StaticResource Note}" Text="Required if the GPU libraries were removed."/>
                    <CheckBox x:Name="ChkTwSkipUpdate" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="Block host updates"/>
                    <TextBlock Style="{StaticResource Note}" Text="SKIP_HOST_UPDATE = true, BACKGROUND_AUTO_UPDATE = false."/>
                    <CheckBox x:Name="ChkTwNoTray" Style="{StaticResource Chk}" Margin="0,15,0,0"
                              Content="Close to taskbar instead of tray"/>
                    <TextBlock Style="{StaticResource Note}" Text="MINIMIZE_TO_TRAY = false - Discord fully exits on close."/>

                    <TextBlock Text="WINDOWS INTEGRATION" Style="{StaticResource Eyebrow}" Margin="0,26,0,16"/>
                    <CheckBox x:Name="ChkTwAutostart" Style="{StaticResource Chk}" IsChecked="True"
                              Content="Remove autostart entries"/>
                    <TextBlock Style="{StaticResource Note}" Text="Clears Discord from Run / RunOnce and disables matching scheduled tasks."/>
                    <CheckBox x:Name="ChkTwFso" Style="{StaticResource Chk}" IsChecked="True" Margin="0,15,0,0"
                              Content="Disable fullscreen optimizations"/>
                    <TextBlock Style="{StaticResource Note}" Text="Sets the DISABLEDXMAXIMIZEDWINDOWEDMODE compatibility flag on Discord.exe."/>
                  </StackPanel>
                </Border>

                <Border Grid.Column="2" Background="#0E1119" CornerRadius="12" Padding="18,16"
                        BorderBrush="{StaticResource Stroke}" BorderThickness="1" VerticalAlignment="Top">
                  <StackPanel>
                    <TextBlock Text="settings.json PREVIEW" Style="{StaticResource Eyebrow}"/>
                    <TextBlock x:Name="LblSettingsPath" Text="" Foreground="{StaticResource TxtLo}"
                               FontSize="9.5" Margin="0,6,0,12" TextTrimming="CharacterEllipsis"/>
                    <Border Background="#0A0C12" CornerRadius="8" Padding="14,12"
                            BorderBrush="#1C202C" BorderThickness="1">
                      <TextBlock x:Name="TxtSettingsPreview" FontFamily="Consolas" FontSize="11"
                                 Foreground="#93C5A8" TextWrapping="Wrap" Text="{}{ }"/>
                    </Border>
                  </StackPanel>
                </Border>
              </Grid>
            </ScrollViewer>

            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
              <Button x:Name="BtnApplyTweaks" Style="{StaticResource Primary}" Content="Apply tweaks" Width="180"/>
            </StackPanel>
          </Grid>

          <!-- ============================ CACHE ========================== -->
          <Grid x:Name="PgCache" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel>
              <TextBlock Text="Cache" Style="{StaticResource H1}"/>
              <TextBlock Style="{StaticResource Sub}"
                         Text="Wipes the roaming profile caches. Safe to run any time - Discord rebuilds what it needs on next launch."/>
            </StackPanel>

            <Grid Grid.Row="1" Margin="0,20,0,0">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/><ColumnDefinition Width="16"/><ColumnDefinition Width="320"/>
              </Grid.ColumnDefinitions>

              <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="20,18"
                      BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                <Grid>
                  <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
                  </Grid.RowDefinitions>
                  <TextBlock Text="TARGET FOLDERS" Style="{StaticResource Eyebrow}" Margin="0,0,0,12"/>
                  <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                    <ListBox x:Name="ListCache" Background="Transparent" BorderThickness="0"
                             ItemTemplate="{StaticResource BreakTpl}"
                             ItemContainerStyle="{StaticResource PlainItem}"
                             ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
                  </ScrollViewer>
                </Grid>
              </Border>

              <StackPanel Grid.Column="2">
                <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="20,18"
                        BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                  <StackPanel>
                    <TextBlock Text="OPTIONS" Style="{StaticResource Eyebrow}" Margin="0,0,0,16"/>
                    <CheckBox x:Name="ChkCaLocalStorage" Style="{StaticResource Chk}"
                              Content="Also clear Local Storage"/>
                    <TextBlock Style="{StaticResource Note}" Foreground="#C9A227"
                               Text="Logs you out - you will need your password and 2FA again."/>
                    <TextBlock x:Name="LblCacheTotal" Text="--" Foreground="#8E7CF0" FontSize="24"
                               FontWeight="SemiBold" Margin="0,20,0,0"/>
                    <TextBlock Text="reclaimable right now" Foreground="{StaticResource TxtLo}" FontSize="11"/>
                  </StackPanel>
                </Border>
              </StackPanel>
            </Grid>

            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
              <Button x:Name="BtnRescanCache" Style="{StaticResource Ghost}" Content="Rescan" Width="130"/>
              <Button x:Name="BtnRunCache" Style="{StaticResource Primary}" Content="Clear cache"
                      Width="180" Margin="12,0,0,0"/>
            </StackPanel>
          </Grid>

          <!-- =========================== BACKUPS ========================= -->
          <Grid x:Name="PgBackup" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel>
              <TextBlock Text="Backups" Style="{StaticResource H1}"/>
              <TextBlock Style="{StaticResource Sub}"
                         Text="Each debloat run can archive exactly the files it deletes. Restoring copies them back into place."/>
            </StackPanel>

            <Border Grid.Row="1" Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="20,18"
                    BorderBrush="{StaticResource Stroke}" BorderThickness="1" Margin="0,20,0,0">
              <Grid>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <TextBlock Text="AVAILABLE SNAPSHOTS" Style="{StaticResource Eyebrow}" Margin="0,0,0,14"/>
                <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto">
                  <ListBox x:Name="ListBackups" Background="Transparent" BorderThickness="0"
                           ItemContainerStyle="{StaticResource PickItem}" DisplayMemberPath="Display"
                           ScrollViewer.HorizontalScrollBarVisibility="Disabled"/>
                </ScrollViewer>
              </Grid>
            </Border>

            <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
              <Button x:Name="BtnOpenBackups" Style="{StaticResource Ghost}" Content="Open folder" Width="140"/>
              <Button x:Name="BtnDeleteBackup" Style="{StaticResource Danger}" Content="Delete" Width="110" Margin="12,0,0,0"/>
              <Button x:Name="BtnRestore" Style="{StaticResource Primary}" Content="Restore selected"
                      Width="180" Margin="12,0,0,0"/>
            </StackPanel>
          </Grid>

          <!-- ============================ ABOUT ========================== -->
          <Grid x:Name="PgAbout" Visibility="Collapsed">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
              <StackPanel>
                <TextBlock Text="About" Style="{StaticResource H1}"/>
                <TextBlock Style="{StaticResource Sub}"
                           Text="Strips a Discord Stable install down to a verified minimal build - roughly 607 MB down to 315 MB."/>

                <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="22,20" Margin="0,22,0,0"
                        BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                  <StackPanel>
                    <TextBlock Text="WHAT SURVIVES" Style="{StaticResource Eyebrow}" Margin="0,0,0,12"/>
                    <TextBlock Foreground="#B4BBCB" FontSize="12.5" TextWrapping="Wrap" LineHeight="21"
                               Text="Discord.exe, ffmpeg.dll, icudtl.dat, resources.pak, v8_context_snapshot.bin, updater.node, resources\app.asar, installer.db, your chosen locale packs, and five modules: discord_desktop_core, discord_krisp, discord_modules, discord_utils, discord_voice."/>
                  </StackPanel>
                </Border>

                <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="22,20" Margin="0,14,0,0"
                        BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                  <StackPanel>
                    <TextBlock Text="WHAT STAYS EVEN THOUGH UPDATES ARE OFF" Style="{StaticResource Eyebrow}" Margin="0,0,0,12"/>
                    <TextBlock Foreground="#B4BBCB" FontSize="12.5" TextWrapping="Wrap" LineHeight="21"
                               Text="updater.node and installer.db are never removed. Despite the name, updater.node is also the module registry - it is what resolves discord_voice and discord_utils to a path on disk. Deleting it breaks voice, not just updating."/>
                  </StackPanel>
                </Border>

                <Border Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="22,20" Margin="0,14,0,0"
                        BorderBrush="{StaticResource Stroke}" BorderThickness="1">
                  <StackPanel>
                    <TextBlock Text="WHAT YOU GIVE UP" Style="{StaticResource Eyebrow}" Margin="0,0,0,12"/>
                    <TextBlock Foreground="#B4BBCB" FontSize="12.5" TextWrapping="Wrap" LineHeight="21"
                               Text="Auto-update, in-game overlay, Rich Presence, spellcheck, cloud sync, hardware-accelerated rendering and video encoding, background blur, non-English UI, and HiDPI Chromium artwork. Krisp noise suppression is kept by default - it also supplies voice-activity detection."/>
                  </StackPanel>
                </Border>

                <Border Background="#1A0F0F" CornerRadius="12" Padding="22,20" Margin="0,14,0,0"
                        BorderBrush="#3A1D1D" BorderThickness="1">
                  <StackPanel>
                    <TextBlock Text="IMPORTANT" Foreground="#F87171" FontSize="10" FontWeight="Bold"/>
                    <TextBlock Foreground="#C08585" FontSize="12" TextWrapping="Wrap" LineHeight="20" Margin="0,10,0,0"
                               Text="This deletes files from a third-party application. It is not endorsed by Discord and a future Discord release may behave differently. Keep the backup option enabled, and reinstall Discord if anything misbehaves. Run the Overview scan and Preview plan first."/>
                  </StackPanel>
                </Border>

                <TextBlock x:Name="LblAboutMeta" Foreground="{StaticResource TxtLo}" FontSize="11"
                           Margin="2,20,0,0" TextWrapping="Wrap"/>
                <TextBlock x:Name="LblCredits" Foreground="#4A5064" FontSize="10.5"
                           Margin="2,10,0,4" TextWrapping="Wrap"/>
              </StackPanel>
            </ScrollViewer>
          </Grid>

          <!-- =========================== CONSOLE ========================= -->
          <Grid x:Name="ConsoleOverlay" Visibility="Collapsed">
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/><RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <StackPanel>
              <TextBlock x:Name="LblConsoleTitle" Text="Working" Style="{StaticResource H1}"/>
              <TextBlock x:Name="LblConsoleSub" Style="{StaticResource Sub}" Text=""/>
            </StackPanel>

            <Border Grid.Row="1" Background="{StaticResource CardGrad}" CornerRadius="14" Effect="{StaticResource Elev}" Padding="20,18"
                    BorderBrush="{StaticResource Stroke}" BorderThickness="1" Margin="0,20,0,0">
              <StackPanel>
                <Grid Margin="0,0,0,12">
                  <TextBlock x:Name="LblProgress" Text="starting..." Foreground="{StaticResource TxtMid}" FontSize="12.5"/>
                  <TextBlock x:Name="LblPct" Text="0%" Foreground="{StaticResource TxtHi}" FontSize="12.5"
                             FontWeight="SemiBold" HorizontalAlignment="Right"/>
                </Grid>
                <Border x:Name="ProgTrack" Height="7" CornerRadius="4" Background="#171B26">
                  <Border x:Name="ProgFill" Height="7" CornerRadius="4" Background="{StaticResource Grad}"
                          HorizontalAlignment="Left" Width="0"/>
                </Border>
              </StackPanel>
            </Border>

            <Border Grid.Row="2" Background="#0A0C12" CornerRadius="12" Margin="0,14,0,0"
                    BorderBrush="{StaticResource Stroke}" BorderThickness="1">
              <ScrollViewer x:Name="LogScroll" VerticalScrollBarVisibility="Auto" Padding="18,14">
                <ListBox x:Name="LogList" Background="Transparent" BorderThickness="0"
                         ItemTemplate="{StaticResource LogTpl}"
                         ItemContainerStyle="{StaticResource PlainItem}"
                         ScrollViewer.HorizontalScrollBarVisibility="Disabled"
                         VirtualizingStackPanel.IsVirtualizing="True"/>
              </ScrollViewer>
            </Border>

            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,18,0,0">
              <Button x:Name="BtnStop" Style="{StaticResource Danger}" Content="Stop" Width="120"/>
              <Button x:Name="BtnConsoleDone" Style="{StaticResource Primary}" Content="Done"
                      Width="150" Margin="12,0,0,0" IsEnabled="False"/>
            </StackPanel>
          </Grid>

        </Grid>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

#------------------------------------------------------------------ load ----
try {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$xamlText)
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Host "XAML load failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
$script:window = $window

foreach ($m in [regex]::Matches($xamlText, 'x:Name="([^"]+)"')) {
    $n = $m.Groups[1].Value
    $el = $window.FindName($n)
    if ($null -ne $el) { Set-Variable -Name $n -Scope Script -Value $el }
}

# Detect rather than assume, and canonicalise once so nothing downstream ever
# compares an 8.3 path against a long one.
$script:Root = Get-DiscordInstallRoot -Preferred $InstallPath
if (-not $script:Root) { $script:Root = Resolve-LongPath $InstallPath }
$script:AppData   = Resolve-LongPath $AppDataPath
$script:LangBoxes = @()
$script:Plan      = @()
$script:PlanBytes = 0L
$script:SizeNow   = 0L

$LblVersion.Text  = "suite v$script:ToolVersion"
$LblCredits.Text = "Discord Debloat Suite v$script:ToolVersion  -  built by Amaaz and sLix1337"
$StatusPath.Text  = $script:Root
$LblSettingsPath.Text = (Join-Path $script:AppData 'settings.json')
$LblAboutMeta.Text = "Profile derived from a 1074-file stock tree; the default run leaves 194 files. " +
                     "Backups live in $script:BackupRoot"

#------------------------------------------------------- shared worker state --
$script:Sync = [hashtable]::Synchronized(@{})
$script:Sync.Queue   = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
$script:Sync.Pct     = 0
$script:Sync.Label   = ''
$script:Sync.Running = $false
$script:Sync.Cancel  = $false
$script:Sync.Summary = ''

$script:LogItems = New-Object 'System.Collections.ObjectModel.ObservableCollection[object]'
$LogList.ItemsSource = $script:LogItems

$script:ActivePs = $null
$script:ActiveRs = $null
$script:WasRunning = $false

<#
    Engine functions shipped into the worker runspace.

    Derived from this script's own AST instead of a hand-written list. The worker
    runspace is bare, so EVERY function a work body reaches - including helpers that
    Get-DebloatPlan merely calls - has to be serialised into it. A hand-maintained
    list goes stale the moment a helper is added, and the failure appears only at
    runtime, inside the worker, as "The term 'X' is not recognized". No headless test
    can catch it, because dot-sourcing the engine defines everything anyway. That is
    exactly how Resolve-LongPath went missing and aborted a live run at 8%.

    Everything defined above the UI banner counts as engine; the GUI helpers and the
    worker prelude below it do not.
#>
$script:EngineNames = @()
try {
    $selfText = Get-Content -LiteralPath $PSCommandPath -Raw -ErrorAction Stop
    $uiAt = $selfText.IndexOf("`n#  UI`r`n")
    if ($uiAt -lt 0) { $uiAt = $selfText.Length }
    $selfAst = [System.Management.Automation.Language.Parser]::ParseInput($selfText, [ref]$null, [ref]$null)
    $script:EngineNames = @(
        $selfAst.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false) |
            Where-Object { $_.Extent.StartOffset -lt $uiAt } |
            ForEach-Object { $_.Name } |
            Sort-Object -Unique)
} catch { }
if ($script:EngineNames.Count -eq 0) {
    # Fallback only if the AST route fails; the list above is the source of truth.
    $script:EngineNames = @('Resolve-LongPath', 'Get-RelativePathSafe', 'Get-ModuleBaseName',
                            'Get-ModuleFolders', 'Get-ModuleInnerDir', 'Get-DiscordInstallRoot',
                            'Get-ActiveAppDir', 'Get-PathSize', 'Format-Size', 'Get-DebloatPlan',
                            'Get-KrispUsage', 'Stop-DiscordProcesses', 'Set-DiscordSettings',
                            'New-DebloatBackup', 'Get-DebloatBackups', 'Restore-DebloatBackup')
}
$script:EngineText = ($script:EngineNames | ForEach-Object {
    "function $_ {`r`n" + (Get-Command $_ -CommandType Function).Definition + "`r`n}"
}) -join "`r`n"

$script:WorkerPrelude = @'
$script:DebloatProfile = $W_Profile
$script:CacheDirs      = $W_CacheDirs
$script:ToolVersion    = $W_ToolVersion
$script:BackupRoot     = $W_BackupRoot
$ErrorActionPreference = 'Continue'
Invoke-Expression $W_Engine

function Say {
    param([string]$Tag, [string]$Msg)
    $c = switch ($Tag) { 'ok' {'#34D399'} 'warn' {'#FBBF24'} 'err' {'#F87171'} 'sim' {'#8E7CF0'} default {'#5F6678'} }
    $t = switch ($Tag) { 'ok' {'OK'}      'warn' {'WRN'}     'err' {'ERR'}     'sim' {'SIM'}     default {'..'} }
    $W_Sync.Queue.Enqueue([pscustomobject]@{
        Time = (Get-Date).ToString('HH:mm:ss'); Tag = $t; Msg = $Msg; Color = $c })
}
function Prog {
    param([int]$Pct, [string]$Label = '')
    $W_Sync.Pct = $Pct
    if ($Label) { $W_Sync.Label = $Label }
}
function Cancelled { return [bool]$W_Sync.Cancel }
function Row { param($Size, $Text) '{0,10}   {1}' -f (Format-Size ([long]$Size)), $Text }
'@

$script:WorkerEpilogue = @'
} catch {
    Say 'err' "unhandled: $($_.Exception.Message)"
    foreach ($ln in (($_.ScriptStackTrace -split "`r?`n") | Where-Object { $_ })) { Say 'err' "  $ln" }
    $W_Sync.Summary = 'Failed - see the log.'
} finally {
    $W_Sync.Running = $false
}
'@

#--------------------------------------------------------------- UI helpers --
function Set-Page {
    param([string] $Name)
    foreach ($p in @($PgOverview, $PgDebloat, $PgTweaks, $PgCache, $PgBackup, $PgAbout, $ConsoleOverlay)) {
        $p.Visibility = 'Collapsed'
    }
    $page = (Get-Variable -Name $Name -Scope Script).Value
    $page.Visibility = 'Visible'

    # A short fade plus a few pixels of upward drift. Movement is most of what makes
    # an interface feel finished, and it costs two animations per page change.
    try {
        $fade = New-Object Windows.Media.Animation.DoubleAnimation(0, 1,
                    (New-Object Windows.Duration ([TimeSpan]::FromMilliseconds(170))))
        $fade.EasingFunction = New-Object Windows.Media.Animation.CubicEase -Property @{ EasingMode = 'EaseOut' }
        $page.BeginAnimation([Windows.UIElement]::OpacityProperty, $fade)

        $tt = New-Object Windows.Media.TranslateTransform
        $page.RenderTransform = $tt
        $slide = New-Object Windows.Media.Animation.DoubleAnimation(8, 0,
                    (New-Object Windows.Duration ([TimeSpan]::FromMilliseconds(200))))
        $slide.EasingFunction = New-Object Windows.Media.Animation.CubicEase -Property @{ EasingMode = 'EaseOut' }
        $tt.BeginAnimation([Windows.Media.TranslateTransform]::YProperty, $slide)
    } catch { }
}

function Show-Console {
    param([string] $Title, [string] $Sub)
    $script:LogItems.Clear()
    $LblConsoleTitle.Text = $Title
    $LblConsoleSub.Text   = $Sub
    $LblProgress.Text     = 'starting...'
    $LblPct.Text          = '0%'
    try { $ProgFill.BeginAnimation([Windows.FrameworkElement]::WidthProperty, $null) } catch { }
    $ProgFill.Width       = 0
    $BtnStop.IsEnabled       = $true
    $BtnConsoleDone.IsEnabled= $false
    $LblCrumb.Text = $Title
    Set-Page 'ConsoleOverlay'
}

function Set-Status {
    param([string] $Text, [string] $Color)
    $StatusText.Text = $Text
    $StatusDot.Fill  = [Windows.Media.BrushConverter]::new().ConvertFromString($Color)
}

# The .pak that matches the Windows display language, if the install ships one.
function Get-SystemLocalePak {
    param([string[]] $Available)
    $ci = [System.Globalization.CultureInfo]::InstalledUICulture
    foreach ($cand in @("$($ci.Name).pak", "$($ci.TwoLetterISOLanguageName).pak")) {
        if ($Available -contains $cand) { return $cand }
    }
    return $null
}

function Get-LocaleDisplayName {
    param([string] $Code)
    # Native language name, with the region reduced to its short tag so the
    # labels stay narrow enough to read: "en-GB  -  English (GB)".
    $lang   = $Code.Split('-')[0]
    $region = if ($Code -match '-') { $Code.Split('-')[1] } else { $null }
    $name   = $Code
    try {
        $n = [System.Globalization.CultureInfo]::GetCultureInfo($lang).NativeName
        if ($n) {
            if ($n -match '^(.*?)\s*\(') { $n = $Matches[1] }
            $name = $n.Substring(0, 1).ToUpper() + $n.Substring(1)
        }
    } catch { }
    if ($region) { "$name ($($region.ToUpper()))" } else { $name }
}

# Builds one checkbox per locale pak actually present in the install.
function Build-LocaleList {
    $LangHost.Items.Clear()
    $script:LangBoxes = @()
    $active = Get-ActiveAppDir -Root $script:Root
    if (-not $active) { Update-LocaleSummary; return }
    $locRoot = Join-Path $active.Path 'locales'
    if (-not (Test-Path -LiteralPath $locRoot)) { Update-LocaleSummary; return }

    $paks = @(Get-ChildItem -LiteralPath $locRoot -File -Filter '*.pak' -ErrorAction SilentlyContinue |
              Sort-Object Name)
    $names   = @($paks | ForEach-Object { $_.Name })
    $sysPak  = Get-SystemLocalePak -Available $names
    $default = @('en-US.pak')
    if ($sysPak) { $default += $sysPak }

    foreach ($f in $paks) {
        $code = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        $cb   = New-Object Windows.Controls.CheckBox
        $cb.Style       = $window.FindResource('Chk')
        $cb.Content     = "$code  -  $(Get-LocaleDisplayName $code)"
        $cb.ToolTip     = "$($f.Name)   $(Format-Size $f.Length)"
        $cb.Tag         = $f.Name
        $cb.FontSize    = 11.5
        $cb.Width       = 186
        $cb.Margin      = New-Object Windows.Thickness 0, 0, 8, 9
        $cb.IsChecked   = ($default -contains $f.Name)
        $cb.Add_Click({
            Update-LocaleSummary
            if ($PgOverview.Visibility -eq 'Visible') { Invoke-Scan }
        })
        $LangHost.Items.Add($cb) | Out-Null
        $script:LangBoxes += $cb
    }
    Update-LocaleSummary
}

function Update-LocaleSummary {
    $kept = @($script:LangBoxes | Where-Object { $_.IsChecked })
    $tot  = @($script:LangBoxes).Count
    $LblLangCount.Text = if ($tot -eq 0) { 'KEEP:  no locales found' }
                         else { "KEEP:  $($kept.Count) OF $tot" }
    $hasEn = @($kept | Where-Object { $_.Tag -eq 'en-US.pak' }).Count -gt 0
    $LblLangWarn.Visibility = if ($tot -gt 0 -and -not $hasEn) { 'Visible' } else { 'Collapsed' }
}

function Set-LocaleSelection {
    param([string] $Mode)
    $names  = @($script:LangBoxes | ForEach-Object { $_.Tag })
    $sysPak = Get-SystemLocalePak -Available $names
    foreach ($cb in $script:LangBoxes) {
        switch ($Mode) {
            'all'     { $cb.IsChecked = $true }
            'none'    { $cb.IsChecked = $false }
            'english' { $cb.IsChecked = ($cb.Tag -eq 'en-US.pak') }
            'system'  { $cb.IsChecked = ($cb.Tag -eq 'en-US.pak' -or ($sysPak -and $cb.Tag -eq $sysPak)) }
        }
    }
    Update-LocaleSummary
    if ($PgOverview.Visibility -eq 'Visible') { Invoke-Scan }
}

# Debloat page -> Krisp preset. Index order must match the ComboBoxItems in the XAML.
$script:KrispOrder = @('All', 'NoBvc', 'Essential', 'None')

function Get-KrispPreset {
    $i = [int]$CmbKrisp.SelectedIndex
    if ($i -lt 0 -or $i -ge $script:KrispOrder.Count) { return 'All' }
    return $script:KrispOrder[$i]
}

# One-shot at startup: what has this machine's Discord actually loaded?
function Update-KrispEvidence {
    $u = Get-KrispUsage -ProfilePath $script:AppData
    if (-not $u.Found) {
        $TxtKrispEvidence.Text = "No Krisp log found under $script:AppData\logs, so there is nothing to base a narrower choice on here. Keep All models."
        $TxtKrispEvidence.Foreground = '#5F6678'
        return
    }
    $m = @($u.Models)
    if ($m.Count -eq 0) {
        $TxtKrispEvidence.Text = ('Krisp log found ({0} file[s]) but no model was ever loaded - Discord has not run noise suppression on this machine.' -f $u.Logs)
        $TxtKrispEvidence.Foreground = '#5F6678'
        return
    }
    $caveat = if ($u.Unread -gt 0) { (' ({0} log file[s] could not be read.)' -f $u.Unread) } else { '' }
    if ($m.Count -eq 1 -and $m[0] -eq 'full_NC') {
        $TxtKrispEvidence.Text = ('Evidence from your own client: full_NC is the only model ever loaded ({0} setups), and voice-activity detection ran {1} times. "Essential only" keeps exactly those two files - the other three have never been read.{2}' -f $u.NcSetups, $u.VadSetups, $caveat)
        $TxtKrispEvidence.Foreground = '#34D399'
    } else {
        $TxtKrispEvidence.Text = ('Evidence from your own client: models loaded = {0} ({1} NC setups, {2} VAD setups). Keep whichever models back those - a narrower preset may remove one you use.{3}' -f ($m -join ', '), $u.NcSetups, $u.VadSetups, $caveat)
        $TxtKrispEvidence.Foreground = '#C9A227'
    }
}

function Update-KrispNote {
    $preset = Get-KrispPreset
    $warn   = '#C9A227'
    $plain  = '#5F6678'
    switch ($preset) {
        'All' {
            $TxtKrispNote.Text = 'Nothing removed (26.0 MB kept). Noise cancellation, background voice cancellation and voice-activity detection all work.'
            $TxtKrispNote.Foreground = $plain
        }
        'NoBvc' {
            $TxtKrispNote.Text = 'Frees 14.4 MB. Drops krisp-bvc-o-pro-v3.kef only - background VOICE cancellation, the mode that removes other people talking near you. Ordinary noise cancellation and voice-activity detection are untouched.'
            $TxtKrispNote.Foreground = $plain
        }
        'Essential' {
            $TxtKrispNote.Text = 'Frees 19.9 MB. Keeps voice-activity detection and the 32 kHz noise-cancellation model; drops background voice cancellation and the 8 kHz / 16 kHz models. If Discord negotiates a lower sample rate, noise cancellation may go unavailable.'
            $TxtKrispNote.Foreground = $warn
        }
        'None' {
            $TxtKrispNote.Text = 'Frees 40.4 MB. Do not pick this if you need noise cancellation (KRISP). Krisp also drives voice-activity detection, so if your mic stops keying after this, put discord_krisp-1 back.'
            $TxtKrispNote.Foreground = $warn
        }
    }
}

function Get-UiOptions {
    $keep = @($script:LangBoxes | Where-Object { $_.IsChecked } | ForEach-Object { $_.Tag })
    @{
        OldVersions   = [bool]$ChkOldVersions.IsChecked
        RootJunk      = [bool]$ChkRootJunk.IsChecked
        GpuLibs       = [bool]$ChkGpu.IsChecked
        ChromePaks    = [bool]$ChkPaks.IsChecked
        ModulesRemove = [bool]$ChkModules.IsChecked
        ModuleTrim    = [bool]$ChkTrim.IsChecked
        Locales       = [bool]$ChkLocales.IsChecked
        KeepLocales   = $keep
        Logs          = [bool]$ChkLogs.IsChecked
        KrispPreset   = Get-KrispPreset
        AggrMediapipe = [bool]$ChkAggrMediapipe.IsChecked
    }
}

function Update-SettingsPreview {
    $v = [ordered]@{}
    if ($ChkTwSkipUpdate.IsChecked) { $v['SKIP_HOST_UPDATE'] = $true; $v['BACKGROUND_AUTO_UPDATE'] = $false }
    if ($ChkTwHwAccel.IsChecked)    { $v['enableHardwareAcceleration'] = $false }
    if ($ChkTwNoTray.IsChecked)     { $v['MINIMIZE_TO_TRAY'] = $false }
    if ($ChkTwAutostart.IsChecked)  { $v['OPEN_ON_STARTUP'] = $false }
    if ($v.Count -eq 0) { $TxtSettingsPreview.Text = '{ }'; return }
    $lines = foreach ($k in $v.Keys) { '  "{0}": {1}' -f $k, $v[$k].ToString().ToLower() }
    $TxtSettingsPreview.Text = "{`r`n" + ($lines -join ",`r`n") + "`r`n}"
}

#------------------------------------------------------------------ scan -----
function Invoke-Scan {
    Set-Status 'scanning...' '#FBBF24'
    $window.Dispatcher.Invoke([action]{}, [Windows.Threading.DispatcherPriority]::Render)

    $active = Get-ActiveAppDir -Root $script:Root
    if (-not $active) {
        Set-Status 'not found' '#F87171'
        $StatCurrent.Text = '--'; $StatRemovable.Text = '--'
        $StatAfter.Text   = '--'; $StatFiles.Text = '--'
        $ListBreak.ItemsSource = $null
        $BtnRunDebloat.IsEnabled = $false
        $BtnPreview.IsEnabled    = $false
        return
    }

    $BtnRunDebloat.IsEnabled = $true
    $BtnPreview.IsEnabled    = $true
    Set-Status "v$($active.Version)" '#34D399'

    $script:SizeNow   = Get-PathSize -Path $script:Root
    $script:Plan      = Get-DebloatPlan -Root $script:Root -Options (Get-UiOptions)
    $sum              = ($script:Plan | Measure-Object -Property Size -Sum).Sum
    $script:PlanBytes = if ($null -eq $sum) { 0L } else { [long]$sum }

    $StatCurrent.Text   = Format-Size $script:SizeNow
    $StatRemovable.Text = Format-Size $script:PlanBytes
    $StatAfter.Text     = Format-Size ([Math]::Max(0, $script:SizeNow - $script:PlanBytes))
    $StatFiles.Text     = "$($script:Plan.Count)"

    $rows = @($script:Plan | Group-Object Category | ForEach-Object {
        $b = ($_.Group | Measure-Object -Property Size -Sum).Sum
        [pscustomobject]@{ Name = $_.Name; Count = $_.Count; Size = (Format-Size ([long]$b)); Raw = [long]$b }
    } | Sort-Object Raw -Descending)
    $ListBreak.ItemsSource = $rows
}

function Invoke-CacheScan {
    $rows = New-Object System.Collections.Generic.List[object]
    $total = 0L
    if (Test-Path -LiteralPath $script:AppData) {
        foreach ($d in $script:CacheDirs) {
            $p = Join-Path $script:AppData $d
            if (Test-Path -LiteralPath $p) {
                $s = Get-PathSize -Path $p
                $total += $s
                $rows.Add([pscustomobject]@{
                    Name  = $d
                    Count = (@(Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue)).Count
                    Size  = (Format-Size $s); Raw = $s })
            }
        }
    }
    $ListCache.ItemsSource = @($rows | Sort-Object Raw -Descending)
    $LblCacheTotal.Text = Format-Size $total
}

function Update-BackupList {
    $b = @(Get-DebloatBackups)
    $ListBackups.ItemsSource = $b
    $BtnRestore.IsEnabled     = ($b.Count -gt 0)
    $BtnDeleteBackup.IsEnabled= ($b.Count -gt 0)
}

#---------------------------------------------------------------- worker -----
function Start-Worker {
    param(
        [Parameter(Mandatory)] [string]      $Title,
        [string]      $Sub  = '',
        [Parameter(Mandatory)] [scriptblock] $Body,
        [hashtable]   $Vars = @{}
    )
    if ($script:Sync.Running) { return }
    foreach ($b in @($BtnRunDebloat, $BtnPreview, $BtnApplyTweaks, $BtnRunCache, $BtnRestore)) {
        if ($b) { $b.IsEnabled = $false }
    }

    Show-Console -Title $Title -Sub $Sub
    $script:Sync.Queue   = New-Object 'System.Collections.Concurrent.ConcurrentQueue[object]'
    $script:Sync.Pct     = 0
    $script:Sync.Label   = 'starting...'
    $script:Sync.Cancel  = $false
    $script:Sync.Summary = ''
    $script:Sync.Running = $true
    $script:WasRunning   = $true

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'STA'
    $rs.ThreadOptions  = 'ReuseThread'
    $rs.Open()
    $p = $rs.SessionStateProxy
    $p.SetVariable('W_Sync',        $script:Sync)
    $p.SetVariable('W_Engine',      $script:EngineText)
    $p.SetVariable('W_Profile',     $script:DebloatProfile)
    $p.SetVariable('W_CacheDirs',   $script:CacheDirs)
    $p.SetVariable('W_ToolVersion', $script:ToolVersion)
    $p.SetVariable('W_BackupRoot',  $script:BackupRoot)
    foreach ($k in $Vars.Keys) { $p.SetVariable($k, $Vars[$k]) }

    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $null = $ps.AddScript($script:WorkerPrelude + "`r`ntry {`r`n" + $Body.ToString() + "`r`n" + $script:WorkerEpilogue)

    $script:ActivePs = $ps
    $script:ActiveRs = $rs
    $script:ActiveHandle = $ps.BeginInvoke()
}

function Update-Console {
    # drain log queue
    $item = $null
    $n = 0
    while ($n -lt 120 -and $script:Sync.Queue.TryDequeue([ref]$item)) {
        $script:LogItems.Add($item)
        $n++
    }
    if ($n -gt 0) {
        while ($script:LogItems.Count -gt 4000) { $script:LogItems.RemoveAt(0) }
        $LogScroll.ScrollToEnd()
    }

    $pct = [int]$script:Sync.Pct
    $LblPct.Text      = "$pct%"
    $LblProgress.Text = [string]$script:Sync.Label
    $w = $ProgTrack.ActualWidth
    if ($w -gt 0) {
        $target = [Math]::Max(0, [Math]::Min($w, $w * $pct / 100))
        # Animate instead of assigning: the bar is driven by a 70 ms timer, so a raw
        # assignment reads as a stutter while an eased tween reads as motion.
        try {
            $a = New-Object Windows.Media.Animation.DoubleAnimation($target,
                     (New-Object Windows.Duration ([TimeSpan]::FromMilliseconds(220))))
            $a.EasingFunction = New-Object Windows.Media.Animation.CubicEase -Property @{ EasingMode = 'EaseOut' }
            $ProgFill.BeginAnimation([Windows.FrameworkElement]::WidthProperty, $a)
        } catch { $ProgFill.Width = $target }
    }

    # finished?
    if ($script:WasRunning -and -not $script:Sync.Running -and $script:Sync.Queue.IsEmpty) {
        $script:WasRunning = $false
        $BtnStop.IsEnabled        = $false
        $BtnConsoleDone.IsEnabled = $true
        foreach ($b in @($BtnRunDebloat, $BtnPreview, $BtnApplyTweaks, $BtnRunCache, $BtnRestore)) {
            if ($b) { $b.IsEnabled = $true }
        }
        if ($script:Sync.Summary) { $LblConsoleSub.Text = [string]$script:Sync.Summary }
        if ($script:ActivePs) {
            try { $script:ActivePs.EndInvoke($script:ActiveHandle) } catch { }
            foreach ($er in @($script:ActivePs.Streams.Error)) {
                $script:LogItems.Add([pscustomobject]@{
                    Time = (Get-Date).ToString('HH:mm:ss'); Tag = 'ERR'
                    Msg = "worker: $($er.Exception.Message)"; Color = '#F87171' })
            }
            try { $script:ActivePs.Dispose(); $script:ActiveRs.Dispose() } catch { }
            $script:ActivePs = $null; $script:ActiveRs = $null
            $LogScroll.ScrollToEnd()
        }
    }
}

$script:Pump = New-Object Windows.Threading.DispatcherTimer
$script:Pump.Interval = [TimeSpan]::FromMilliseconds(70)
$script:Pump.Add_Tick({ Update-Console })
$script:Pump.Start()

#=============================================================== work bodies ==
$script:BodyDebloat = {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Say 'info' "install root : $W_Root"
    if ($W_Sim) { Say 'sim' 'SIMULATION MODE - nothing will be deleted' }

    $active = Get-ActiveAppDir -Root $W_Root
    if (-not $active) {
        Say 'err' 'No app-* folder found. Is Discord installed here?'
        $W_Sync.Summary = 'Nothing to do'; $W_Sync.Pct = 100; $W_Sync.Running = $false; return
    }
    Say 'ok' "Discord $($active.Version)"
    $before = Get-PathSize -Path $W_Root
    Say 'info' "size before  : $(Format-Size $before)"

    Prog 4 'Closing Discord...'
    if ($W_Sim) {
        Say 'sim' 'would terminate running Discord processes'
    } else {
        $k = Stop-DiscordProcesses -Root $W_Root
        if ($k -gt 0) { Say 'ok' "$k process(es) terminated" } else { Say 'info' 'Discord was not running' }
    }

    Prog 8 'Building removal plan...'
    $plan = @(Get-DebloatPlan -Root $W_Root -Options $W_Options)
    if ($plan.Count -eq 0) {
        Say 'warn' 'Nothing matched the profile - this install already looks stripped.'
        $W_Sync.Summary = 'Nothing to remove'; $W_Sync.Pct = 100; $W_Sync.Running = $false; return
    }
    $planBytes = [long](($plan | Measure-Object -Property Size -Sum).Sum)
    Say 'ok' "$($plan.Count) targets queued, $(Format-Size $planBytes)"

    if ($W_Backup) {
        Prog 12 'Creating restore point...'
        if ($W_Sim) {
            Say 'sim' "would archive $($plan.Count) items into $W_BackupRoot"
        } else {
            try {
                $bp = New-DebloatBackup -Root $W_Root -Plan $plan -Report { param($t, $m) Say $t $m }
                Say 'ok' "backup stored at $bp"
            } catch {
                Say 'err' "backup failed: $($_.Exception.Message)"
            }
        }
    }

    $i = 0; $freed = 0L; $errs = 0; $done = 0; $cancelled = $false
    foreach ($t in $plan) {
        if (Cancelled) { $cancelled = $true; Say 'warn' 'Stopped by user.'; break }
        $i++
        Prog ([int](20 + ($i / $plan.Count) * 70)) "Removing $($t.Display)"
        if (-not (Test-Path -LiteralPath $t.Path)) { continue }
        if ($W_Sim) {
            Say 'sim' (Row $t.Size $t.Display); $freed += $t.Size; $done++
            continue
        }
        try {
            Remove-Item -LiteralPath $t.Path -Recurse -Force -ErrorAction Stop
            $freed += $t.Size; $done++
            Say 'ok' (Row $t.Size $t.Display)
        } catch {
            $errs++
            Say 'err' "$($t.Display)  ->  $($_.Exception.Message)"
        }
    }

    if (-not $cancelled -and $W_Options.GpuLibs -and -not $W_Sim) {
        Prog 92 'Forcing software rendering...'
        try {
            $f = Set-DiscordSettings -AppDataPath $W_AppData -Values @{
                enableHardwareAcceleration = $false; SKIP_HOST_UPDATE = $true }
            Say 'ok' "hardware acceleration disabled in $(Split-Path $f -Leaf)"
        } catch { Say 'warn' "could not update settings.json: $($_.Exception.Message)" }
    } elseif ($W_Options.GpuLibs -and $W_Sim) {
        Say 'sim' 'would set enableHardwareAcceleration = false'
    }

    if (-not $cancelled -and $W_Shortcut) {
        Prog 95 'Creating shortcut...'
        $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Discord (debloated).lnk'
        $exe = Join-Path $active.Path 'Discord.exe'
        if ($W_Sim) {
            Say 'sim' "would create $lnk"
        } else {
            try {
                $wsh = New-Object -ComObject WScript.Shell
                $sc  = $wsh.CreateShortcut($lnk)
                $sc.TargetPath       = $exe
                $sc.WorkingDirectory = $active.Path
                $sc.IconLocation     = $exe
                $sc.Description      = 'Discord (debloated) - launches the client directly'
                $sc.Save()
                Say 'ok' 'desktop shortcut created'
            } catch { Say 'warn' "shortcut failed: $($_.Exception.Message)" }
        }
    }

    $sw.Stop()
    Prog 100 $(if ($cancelled) { 'Stopped' } else { 'Complete' })
    $after = if ($W_Sim) { $before - $freed } else { Get-PathSize -Path $W_Root }
    Say 'info' "size after   : $(Format-Size $after)"
    Say $(if ($errs -gt 0) { 'warn' } else { 'ok' }) `
        "$done item(s) processed, $(Format-Size $freed) freed, $errs error(s), $([int]$sw.Elapsed.TotalSeconds)s"
    if (-not $W_Sim -and -not $cancelled) { Say 'ok' 'Restart Discord to apply.' }
    $W_Sync.Summary = if ($W_Sim) {
        "Simulation finished - $(Format-Size $freed) would be freed across $done items."
    } elseif ($cancelled) {
        "Stopped early - $(Format-Size $freed) freed before cancelling."
    } else {
        "$(Format-Size $freed) freed. $(Format-Size $before) -> $(Format-Size $after)."
    }
    $W_Sync.Running = $false
}

$script:BodyTweaks = {
    Say 'info' "settings file: $W_AppData\settings.json"
    Prog 10 'Closing Discord...'
    $k = Stop-DiscordProcesses -Root $W_Root
    if ($k -gt 0) { Say 'ok' "$k process(es) terminated" } else { Say 'info' 'Discord was not running' }

    Prog 30 'Writing settings.json...'
    $vals = @{}
    if ($W_TwSkipUpdate) { $vals['SKIP_HOST_UPDATE'] = $true; $vals['BACKGROUND_AUTO_UPDATE'] = $false }
    if ($W_TwHwAccel)    { $vals['enableHardwareAcceleration'] = $false }
    if ($W_TwNoTray)     { $vals['MINIMIZE_TO_TRAY'] = $false }
    if ($W_TwAutostart)  { $vals['OPEN_ON_STARTUP'] = $false; $vals['START_MINIMIZED'] = $false }
    if ($vals.Count -gt 0) {
        try {
            $f = Set-DiscordSettings -AppDataPath $W_AppData -Values $vals
            foreach ($k2 in ($vals.Keys | Sort-Object)) { Say 'ok' "$k2 = $($vals[$k2].ToString().ToLower())" }
            Say 'ok' "written to $f"
        } catch { Say 'err' "write failed: $($_.Exception.Message)" }
    } else { Say 'info' 'no client settings selected' }

    if ($W_TwAutostart) {
        Prog 60 'Removing autostart entries...'
        $hits = 0
        foreach ($rk in @('HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                          'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
                          'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce')) {
            if (-not (Test-Path $rk)) { continue }
            $props = (Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue)
            if (-not $props) { continue }
            foreach ($pr in $props.PSObject.Properties) {
                if ($pr.Name -like 'PS*') { continue }
                # Match Discord's own entry, not every value with "discord" in it:
                # BetterDiscord / Vencord / third-party updaters live here too and
                # a bare *discord* substring test removes those as well.
                $isDiscord = ($pr.Name -match '^discord(canary|ptb|development)?$') -or
                             ("$($pr.Value)" -match '[\/](Discord|DiscordCanary|DiscordPTB)[\/].*\.exe')
                if ($isDiscord) {
                    try {
                        Remove-ItemProperty -Path $rk -Name $pr.Name -Force -ErrorAction Stop
                        Say 'ok' "removed $rk\$($pr.Name)"; $hits++
                    } catch { Say 'warn' "could not remove $($pr.Name)" }
                }
            }
        }
        try {
            $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue | Where-Object { $_.TaskName -like '*discord*' })
            foreach ($t in $tasks) {
                Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
                Say 'ok' "disabled task $($t.TaskName)"; $hits++
            }
        } catch { }
        if ($hits -eq 0) { Say 'info' 'no autostart entries found' }
    }

    if ($W_TwFso) {
        Prog 85 'Disabling fullscreen optimizations...'
        $active = Get-ActiveAppDir -Root $W_Root
        if ($active) {
            $exe  = Join-Path $active.Path 'Discord.exe'
            $lay  = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
            try {
                if (-not (Test-Path $lay)) { New-Item -Path $lay -Force | Out-Null }

                # MERGE, never overwrite. The Layers value is a single string holding
                # every compat flag for that exe ("~ RUNASADMIN HIGHDPIAWARE"), so a
                # blind Set-ItemProperty silently destroys whatever the user had set
                # through Explorer's Compatibility tab. Verified: writing the flag over
                # "~ RUNASADMIN HIGHDPIAWARE" left only the new flag.
                $flag     = 'DISABLEDXMAXIMIZEDWINDOWEDMODE'
                $existing = $null
                try { $existing = (Get-ItemProperty -Path $lay -Name $exe -ErrorAction Stop).$exe } catch { }

                $tokens = @()
                if ($existing) {
                    $tokens = @($existing -split '\s+' | Where-Object { $_ -and $_ -ne '~' })
                }
                if ($tokens -contains $flag) {
                    Say 'info' "$flag was already set on Discord.exe"
                } else {
                    $tokens += $flag
                    $value = '~ ' + ($tokens -join ' ')
                    Set-ItemProperty -Path $lay -Name $exe -Value $value -Force -ErrorAction Stop
                    if ($tokens.Count -gt 1) {
                        Say 'ok' "$flag added, kept: $(($tokens | Where-Object { $_ -ne $flag }) -join ', ')"
                    } else {
                        Say 'ok' "$flag set on Discord.exe"
                    }
                }
            } catch { Say 'err' "compat flag failed: $($_.Exception.Message)" }
        } else { Say 'warn' 'Discord.exe not found - skipped' }
    }

    Prog 100 'Complete'
    Say 'ok' 'Restart Discord to apply.'
    $W_Sync.Summary = 'Tweaks applied. Restart Discord to pick them up.'
    $W_Sync.Running = $false
}

$script:BodyCache = {
    if (-not (Test-Path -LiteralPath $W_AppData)) {
        Say 'err' "profile folder not found: $W_AppData"
        $W_Sync.Summary = 'Nothing to do'; $W_Sync.Pct = 100; $W_Sync.Running = $false; return
    }
    Say 'info' "profile: $W_AppData"
    Prog 5 'Closing Discord...'
    $k = Stop-DiscordProcesses -Root $W_Root
    if ($k -gt 0) { Say 'ok' "$k process(es) terminated" } else { Say 'info' 'Discord was not running' }

    $targets = @($W_CacheDirs)
    if ($W_LocalStorage) { $targets += 'Local Storage' }

    $i = 0; $freed = 0L; $hit = 0; $cancelled = $false
    foreach ($d in $targets) {
        if (Cancelled) { $cancelled = $true; Say 'warn' 'Stopped by user.'; break }
        $i++
        Prog ([int](10 + ($i / $targets.Count) * 85)) "Clearing $d"
        $p = Join-Path $W_AppData $d
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $s = Get-PathSize -Path $p
        try {
            if ($d -eq 'logs') {
                # discord_krisp*.log is the only record of which Krisp model this
                # machine loads - it is what the Krisp advisory on the Debloat page
                # reads, and the only trail for diagnosing a voice fault. Clear the
                # rest of the folder, keep those.
                $kept = 0L
                foreach ($lf in @(Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue)) {
                    if ($lf.Name -like 'discord_krisp*.log') { $kept += $lf.Length; continue }
                    Remove-Item -LiteralPath $lf.FullName -Recurse -Force -ErrorAction SilentlyContinue
                }
                $s = [Math]::Max(0, $s - $kept)
                $freed += $s; $hit++
                Say 'ok' (Row $s "$d  (Krisp logs kept)")
            } else {
                Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction Stop
                $freed += $s; $hit++
                Say $(if ($d -eq 'Local Storage') { 'warn' } else { 'ok' }) (Row $s $d)
            }
        } catch {
            Say 'err' "$d  ->  $($_.Exception.Message)"
        }
    }
    if ($W_LocalStorage) { Say 'warn' 'Local Storage cleared - you will have to sign in again.' }

    Prog 100 $(if ($cancelled) { 'Stopped' } else { 'Complete' })
    Say 'ok' "$hit folder(s) cleared, $(Format-Size $freed) freed"
    $W_Sync.Summary = "$(Format-Size $freed) reclaimed from the Discord profile."
    $W_Sync.Running = $false
}

$script:BodyRestore = {
    Say 'info' "restoring from $W_BackupPath"
    Prog 5 'Closing Discord...'
    $k = Stop-DiscordProcesses -Root $W_Root
    if ($k -gt 0) { Say 'ok' "$k process(es) terminated" }
    Prog 20 'Copying files back...'
    try {
        $r = Restore-DebloatBackup -BackupPath $W_BackupPath -Report { param($t, $m) Say $t $m }
        Prog 100 'Complete'
        Say 'ok' "$($r.Restored) restored, $($r.Failed) failed"
        $W_Sync.Summary = "$($r.Restored) item(s) restored into $($r.Source)."
    } catch {
        Say 'err' $_.Exception.Message
        $W_Sync.Summary = 'Restore failed.'
    }
    $W_Sync.Running = $false
}

#================================================================== wiring ====
$TitleBar.Add_MouseLeftButtonDown({ try { $window.DragMove() } catch { } })
$BtnMin.Add_Click({ $window.WindowState = 'Minimized' })
$BtnClose.Add_Click({
    if ($script:Sync.Running) { $script:Sync.Cancel = $true }
    $window.Close()
})

$navMap = @{
    NavOverview = @{ Page = 'PgOverview'; Crumb = 'Overview' }
    NavDebloat  = @{ Page = 'PgDebloat';  Crumb = 'Debloat'  }
    NavTweaks   = @{ Page = 'PgTweaks';   Crumb = 'Tweaks'   }
    NavCache    = @{ Page = 'PgCache';    Crumb = 'Cache'    }
    NavBackup   = @{ Page = 'PgBackup';   Crumb = 'Backups'  }
    NavAbout    = @{ Page = 'PgAbout';    Crumb = 'About'    }
}
foreach ($navName in $navMap.Keys) {
    $ctl  = (Get-Variable -Name $navName -Scope Script).Value
    $info = $navMap[$navName]
    $ctl.Add_Checked([System.Windows.RoutedEventHandler]{
        param($s, $e)
        $me = $navMap[$s.Name]
        if ($script:Sync.Running) { $s.IsChecked = $false; return }
        Set-Page $me.Page
        $LblCrumb.Text = $me.Crumb
        switch ($me.Page) {
            'PgOverview' { Invoke-Scan }
            'PgCache'    { Invoke-CacheScan }
            'PgBackup'   { Update-BackupList }
            'PgTweaks'   { Update-SettingsPreview }
        }
    })
}

$BtnRescan.Add_Click({ Build-LocaleList; Invoke-Scan })
$BtnGoDebloat.Add_Click({ $NavDebloat.IsChecked = $true })
$BtnRescanCache.Add_Click({ Invoke-CacheScan })

foreach ($cb in @($ChkOldVersions, $ChkRootJunk, $ChkGpu, $ChkPaks, $ChkModules,
                  $ChkTrim, $ChkLocales, $ChkLogs, $ChkAggrMediapipe)) {
    $cb.Add_Click({ if ($PgOverview.Visibility -eq 'Visible') { Invoke-Scan } })
}
$CmbKrisp.Add_SelectionChanged({
    Update-KrispNote
    if ($PgOverview.Visibility -eq 'Visible') { Invoke-Scan }
})
Update-KrispNote
Update-KrispEvidence
$BtnLangAll.Add_Click({     Set-LocaleSelection 'all' })
$BtnLangNone.Add_Click({    Set-LocaleSelection 'none' })
$BtnLangEnglish.Add_Click({ Set-LocaleSelection 'english' })
$BtnLangSystem.Add_Click({  Set-LocaleSelection 'system' })
foreach ($cb in @($ChkTwHwAccel, $ChkTwSkipUpdate, $ChkTwNoTray, $ChkTwAutostart, $ChkTwFso)) {
    $cb.Add_Click({ Update-SettingsPreview })
}
$ChkSim.Add_Click({
    $SimBadge.Visibility = if ($ChkSim.IsChecked) { 'Visible' } else { 'Collapsed' }
    $BtnRunDebloat.Content = if ($ChkSim.IsChecked) { 'Run simulation' } else { 'Run debloat' }
})

function Start-DebloatRun {
    param([bool] $Simulate)
    $opts = Get-UiOptions
    Start-Worker -Title $(if ($Simulate) { 'Plan preview' } else { 'Debloating' }) `
                 -Sub   $(if ($Simulate) { 'Dry run - every target is listed, nothing is touched.' }
                          else { 'Removing files. Do not close the window.' }) `
                 -Body  $script:BodyDebloat `
                 -Vars  @{
                     W_Root     = $script:Root
                     W_AppData  = $script:AppData
                     W_Options  = $opts
                     W_Sim      = $Simulate
                     W_Backup   = ([bool]$ChkBackup.IsChecked -and -not $Simulate)
                     W_Shortcut = [bool]$ChkShortcut.IsChecked
                 }
}

$BtnPreview.Add_Click({ Start-DebloatRun -Simulate $true })

$BtnRunDebloat.Add_Click({
    if ($ChkSim.IsChecked) { Start-DebloatRun -Simulate $true; return }
    $msg = "This permanently deletes files from:`r`n$script:Root`r`n`r`n" +
           "Auto-update, overlay, Rich Presence, spellcheck and hardware acceleration will stop working.`r`n`r`n" +
           $(if ($ChkBackup.IsChecked) { 'A restore point will be created first.' }
             else { 'NO BACKUP will be created.' }) +
           "`r`n`r`nContinue?"
    $r = [Windows.MessageBox]::Show($msg, 'Confirm debloat', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    Start-DebloatRun -Simulate $false
})

$BtnApplyTweaks.Add_Click({
    Start-Worker -Title 'Applying tweaks' -Sub 'Writing configuration and registry values.' `
                 -Body $script:BodyTweaks `
                 -Vars @{
                     W_Root          = $script:Root
                     W_AppData       = $script:AppData
                     W_TwHwAccel     = [bool]$ChkTwHwAccel.IsChecked
                     W_TwSkipUpdate  = [bool]$ChkTwSkipUpdate.IsChecked
                     W_TwNoTray      = [bool]$ChkTwNoTray.IsChecked
                     W_TwAutostart   = [bool]$ChkTwAutostart.IsChecked
                     W_TwFso         = [bool]$ChkTwFso.IsChecked
                 }
})

$BtnRunCache.Add_Click({
    if ($ChkCaLocalStorage.IsChecked) {
        $r = [Windows.MessageBox]::Show(
            "Clearing Local Storage signs you out of Discord.`r`n`r`nContinue?",
            'Confirm cache clear', 'YesNo', 'Warning')
        if ($r -ne 'Yes') { return }
    }
    Start-Worker -Title 'Clearing cache' -Sub 'Wiping the roaming profile caches.' `
                 -Body $script:BodyCache `
                 -Vars @{
                     W_Root         = $script:Root
                     W_AppData      = $script:AppData
                     W_LocalStorage = [bool]$ChkCaLocalStorage.IsChecked
                 }
})

$BtnRestore.Add_Click({
    $sel = $ListBackups.SelectedItem
    if (-not $sel) { [Windows.MessageBox]::Show('Select a snapshot first.', 'Restore') | Out-Null; return }
    $r = [Windows.MessageBox]::Show(
        "Copy $($sel.Count) item(s) from`r`n$($sel.Name)`r`nback into $($sel.Source)?",
        'Confirm restore', 'YesNo', 'Question')
    if ($r -ne 'Yes') { return }
    Start-Worker -Title 'Restoring' -Sub "From snapshot $($sel.Name)" `
                 -Body $script:BodyRestore `
                 -Vars @{ W_Root = $script:Root; W_BackupPath = $sel.Path }
})

$BtnDeleteBackup.Add_Click({
    $sel = $ListBackups.SelectedItem
    if (-not $sel) { return }
    $r = [Windows.MessageBox]::Show("Permanently delete snapshot $($sel.Name)?", 'Delete backup', 'YesNo', 'Warning')
    if ($r -ne 'Yes') { return }
    Remove-Item -LiteralPath $sel.Path -Recurse -Force -ErrorAction SilentlyContinue
    Update-BackupList
})

$BtnOpenBackups.Add_Click({
    if (-not (Test-Path -LiteralPath $script:BackupRoot)) {
        New-Item -ItemType Directory -Path $script:BackupRoot -Force | Out-Null
    }
    Start-Process explorer.exe $script:BackupRoot
})

$BtnStop.Add_Click({
    $script:Sync.Cancel = $true
    $BtnStop.IsEnabled = $false
})

$BtnConsoleDone.Add_Click({
    Build-LocaleList
    Invoke-Scan
    Update-BackupList
    Invoke-CacheScan
    $NavOverview.IsChecked = $true
    Set-Page 'PgOverview'
    $LblCrumb.Text = 'Overview'
})

$window.Add_Closing({
    $script:Sync.Cancel = $true
    try { $script:Pump.Stop() } catch { }
})

#--------------------------------------------------------------- window chrome --
<#
    Rounded corners and the Mica backdrop come from DWM, not from WPF, so they work
    identically under Windows PowerShell 5.1 and PowerShell 7 - it is a Win32 call,
    not a framework feature. Both need Windows 11; on Windows 10
    DwmSetWindowAttribute returns a failure HRESULT and we simply keep the opaque
    shell background, which is exactly how the tool looked before.

    Mica is only visible if nothing opaque is painted on top of it, hence the
    translucent shell tint and the transparent composition-target background.
#>
if (-not ('DwmChrome' -as [type])) {
    Add-Type -Namespace '' -Name 'DwmChrome' -MemberDefinition @'
[DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
'@ -ErrorAction SilentlyContinue
}

$script:MicaOn = $false
$window.Add_SourceInitialized({
    try {
        $helper = New-Object System.Windows.Interop.WindowInteropHelper($window)
        $hwnd   = $helper.Handle
        if ($hwnd -eq [IntPtr]::Zero) { return }

        # DWMWA_WINDOW_CORNER_PREFERENCE = 33, DWMWA_ROUND = 2
        $round = 2
        [void][DwmChrome]::DwmSetWindowAttribute($hwnd, 33, [ref]$round, 4)

        # DWMWA_SYSTEMBACKDROP_TYPE = 38, DWMSBT_MAINWINDOW (Mica) = 2
        $mica = 2
        $hr = [DwmChrome]::DwmSetWindowAttribute($hwnd, 38, [ref]$mica, 4)

        if ($hr -eq 0) {
            $src = [System.Windows.Interop.HwndSource]::FromHwnd($hwnd)
            if ($src -and $src.CompositionTarget) {
                $src.CompositionTarget.BackgroundColor = [System.Windows.Media.Colors]::Transparent
            }
            # let the backdrop show through the shell tint
            $ShellRoot.Background = $window.FindResource('ShellBgMica')
            $script:MicaOn = $true
        }
    } catch { }
})

#------------------------------------------------------------------- start ---
if ($DryRun) {
    $ChkSim.IsChecked      = $true
    $SimBadge.Visibility   = 'Visible'
    $BtnRunDebloat.Content = 'Run simulation'
}
Update-SettingsPreview
Build-LocaleList
Invoke-Scan
$null = $window.ShowDialog()
