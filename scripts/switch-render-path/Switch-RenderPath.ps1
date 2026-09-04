<#
.SYNOPSIS
    Switch how Windows presents games and the desktop: MPO, Fullscreen
    Optimizations, windowed-game flip upgrade, and the DWM feature set.

.DESCRIPTION
    Four independent AXES, plus OPTIONS that sit outside every preset. Each has
    named states; the first state listed is what stock Windows does. Nothing here
    is tied to a particular machine - the states are defined by what they change,
    not by what any PC happened to look like.

      Mpo          On  | Off        Multi-Plane Overlay
      Dwm          Stock | Stripped DWM composition feature set
      Fso          On  | Off        Fullscreen Optimizations
      WindowedOpt  On  | Off        "Optimizations for windowed games"

    PRESETS are named combinations of those axes. You can also set any axis on
    its own; the axes are independent.

    OPTIONS are switches that are NOT part of any preset and are never changed
    by applying one. There is one:

      GameDvr      On  | Off        Xbox background recording and its hooks

    Game DVR is a recording feature, not a render path. It is offered because
    its capture hooks can knock a game off the direct flip path - but that is a
    choice you make once, not something a preset should decide for you.

    Absence matters throughout. Stock Windows does not ship most of these values
    at all, so the stock state DELETES them rather than writing a zero. For
    OverlayTestMode this is documented: 5 disables MPO, and the enable is the
    value's ABSENCE - writing 0 is not the same thing.

.PARAMETER Mode
    Menu    (default) - interactive
    Status  - report the current state of every axis and exit
    Backup  - export the affected keys and exit

.PARAMETER Preset
    Apply a named combination. See -Mode Status or the menu for the list.

.PARAMETER Mpo
    On  = Windows default (value absent). Off = OverlayTestMode 5.

.PARAMETER Dwm
    Stock = the 42 DWM feature values removed (Windows default).
    Stripped = them written.

.PARAMETER Fso
    On = Windows default. Off = a game asking for exclusive fullscreen gets it.

.PARAMETER WindowedOpt
    On = Windows default (windowed/borderless games get the flip model).
    Off is offered for completeness and is usually a downgrade - see the warning
    the tool prints.

.PARAMETER GameDvr
    On = Windows default (Xbox background recording available).
    Off = the AllowGameDVR policy set, capture disabled, recording off.
    An OPTION: no preset sets it, and applying a preset never changes it.

.PARAMETER Game
    Full path to one game's .exe. With -GameFso, sets Fullscreen Optimizations
    for THAT exe only - the same switch as the "Disable fullscreen
    optimizations" box on the exe's Compatibility tab. Per-exe, per-user, and
    it overrides the global Fso axis for that game.

.PARAMETER GameFso
    On = the exe follows the global Fso axis (flag absent).
    Off = the exe always gets exclusive fullscreen (Legacy Flip), whatever the
    global axis says. Requires -Game.

.PARAMETER Measure
    Process name (e.g. game.exe) to capture with PresentMon for -Seconds and
    report the present mode(s) it actually used. Needs presentmon.exe on PATH,
    next to this script, or given by -PresentMon. The game must be running.

.PARAMETER Seconds
    Capture length for -Measure. Default 10.

.PARAMETER PresentMon
    Path to presentmon.exe if it is not on PATH or next to the script.

.PARAMETER RestartDwm
    Kill dwm.exe after applying (typed KILLDWM confirmation), so the DWM/MPO
    values take effect without a reboot. Works on its own too.

.PARAMETER NoBackup
    Skip the registry export that normally precedes every change.

.PARAMETER BackupRoot
    Where backups are written. Default: _backups next to the script.
    The menu's [O] opens this folder and [X] prunes it, keeping the 3 newest.
    Both only ever touch folders named 'render-path-*', so a root shared with
    something else keeps its other contents.

.NOTES
    Version: 1.0.0
    License: MIT (see LICENSE)

    Exit codes: 0 = success or nothing to do; 1 = a change or backup was
    refused or failed (non-interactive paths); 2 = the environment cannot run
    this script safely (32-bit host, constrained language, not Windows).

.EXAMPLE
    .\Switch-RenderPath.ps1
    Interactive menu.

.EXAMPLE
    .\Switch-RenderPath.ps1 -Preset WindowsDefault

.EXAMPLE
    .\Switch-RenderPath.ps1 -Mpo Off
    Just the MPO kill switch, nothing else touched.

.EXAMPLE
    .\Switch-RenderPath.ps1 -Mpo Off -Fso Off -WhatIf

.EXAMPLE
    .\Switch-RenderPath.ps1 -GameDvr Off
    Kill Game DVR and leave every axis alone.

.EXAMPLE
    .\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe' -GameFso Off
    Exclusive fullscreen (Legacy Flip) for that one exe, nothing global touched.

.EXAMPLE
    .\Switch-RenderPath.ps1 -Measure game.exe -Seconds 15
    Capture the running game with PresentMon and print its present mode(s).
#>
#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Position = 0)]
    [ValidateSet('Menu', 'Status', 'Backup')]
    [string]$Mode = 'Menu',

    [ValidateSet('WindowsDefault', 'MpoOff', 'FsoOff', 'Lean', 'Stripped')]
    [string]$Preset,

    [ValidateSet('On', 'Off')]       [string]$Mpo,
    [ValidateSet('Stock', 'Stripped')][string]$Dwm,
    [ValidateSet('On', 'Off')]       [string]$Fso,
    [ValidateSet('On', 'Off')]       [string]$WindowedOpt,

    [ValidateSet('On', 'Off')]       [string]$GameDvr,

    [string]$Game,
    [ValidateSet('On', 'Off')]       [string]$GameFso,

    [string]$Measure,
    [ValidateRange(1, 600)]          [int]$Seconds = 10,
    [string]$PresentMon,

    [switch]$RestartDwm,
    [switch]$NoBackup,

    # No default expression on purpose: under Windows PowerShell 5.1, $PSScriptRoot
    # is an EMPTY STRING inside a param() default when the script has
    # [CmdletBinding()], which made an earlier version fail to start at all.
    [string]$BackupRoot
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ScriptDir =
    if     ($PSScriptRoot)                { $PSScriptRoot }
    elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
    else                                  { (Get-Location).Path }

if ([string]::IsNullOrWhiteSpace($BackupRoot)) { $BackupRoot = Join-Path $ScriptDir '_backups' }

# How many backup folders [X] keeps. Not a parameter: it is a housekeeping
# default, and the prune lists every folder and names the ones it will delete
# before asking, so the number never has to be guessed at.
$BackupKeep = 3

$ScriptVersion = '1.0.0'

# Backup folders are named '<prefix><label>-<stamp>'. The prefix is deliberately
# NOT derived from the script filename: the script was called render-path.ps1 up
# to 1.0.0, and changing the prefix would orphan every restore point already on
# disk - [O] and [X] would stop seeing them, which is the opposite of what a
# restore point is for.
$BackupPrefix = 'render-path-'

# ===========================================================================
# SCREEN
#
# Nothing in this tool prints straight to the console. Write-Ui appends to a
# buffer; Show-Ui then clears the screen and prints the whole buffer as one
# block, centred on the window. That is what keeps the terminal showing this
# tool and nothing else - every frame starts from a cleared screen, so neither
# the previous frame nor whatever the shell printed before the script started
# is left visible above it.
#
# The buffer is a list of lines; a line is a list of coloured segments, which
# is how the old Write-Host -NoNewline runs (label in one colour, value in
# another) survive as ONE line whose length can be measured before printing.
# ===========================================================================

$script:UiLines  = [System.Collections.Generic.List[object]]::new()
$script:UiOpen   = [System.Collections.Generic.List[object]]::new()
$script:UiPad    = ''
$script:UiScreen = $false   # $true once the menu owns the whole terminal
$script:UiFrameWidth = 0    # set once, from the widest row the menu can draw
$script:UiPresetMatch = $null   # which preset the last Show-State matched

# Box drawing needs a console that can ENCODE it; on an OEM code page the
# characters come out as '?' and the frame is worse than no frame. So the glyph
# set is chosen once, at startup, and everything draws through it.
#
# The characters are built from code points rather than written literally: the
# script is saved UTF-8 with a BOM today, but a future save as ANSI would
# silently turn a literal box character into mojibake, and this way it cannot.
$script:Glyph = @{
    TL = '+'; TR = '+'; BL = '+'; BR = '+'; V = '|'
    Rule = '-'; Dot = '-'; Mark = '>'; Dash = '-'; Bar = '='
}
function Initialize-UiGlyphs {
    $cp = try { [Console]::OutputEncoding.CodePage } catch { 0 }
    if ($cp -ne 65001) { return }   # keep the ASCII set
    # [string] on every one: a [char] cannot be multiplied to build a rule, and
    # the ASCII set above is strings, so the two must match shape exactly.
    $script:Glyph = @{
        TL   = [string][char]0x256D; TR = [string][char]0x256E   # rounded corners
        BL   = [string][char]0x2570; BR = [string][char]0x256F
        V    = [string][char]0x2502
        Rule = [string][char]0x2500                              # light horizontal
        Dot  = [string][char]0x00B7                              # middle dot
        Mark = [string][char]0x25B8                              # small right triangle
        Dash = [string][char]0x2014                              # em dash
        Bar  = [string][char]0x2500
    }
}
Initialize-UiGlyphs   # every code path draws, so decide once, here

function Get-UiSize {
    # RawUI is missing or throws in some hosts (redirected output, remoting),
    # and under StrictMode that is fatal rather than $null - hence the guard.
    $w = 0; $h = 0
    try {
        $sz = $Host.UI.RawUI.WindowSize
        $w  = [int]$sz.Width
        $h  = [int]$sz.Height
    } catch { }
    if ($w -le 0) { $w = 80 }
    if ($h -le 0) { $h = 25 }
    return [pscustomobject]@{ Width = $w; Height = $h }
}

function Get-UiTableWidth {
    # Out-String formats to a fixed width; keep the detail table inside the
    # window, because a block wider than the window cannot be centred.
    return [Math]::Max(60, (Get-UiSize).Width - 4)
}

function Split-UiText {
    # Word-wrap. A long description must not be the line that decides how wide
    # the frame is - that is what would push everything else off-centre.
    param([string]$Text, [int]$Width = 0)
    if ($Width -le 0) { $Width = Get-UiTableWidth }
    $out  = @()
    $line = ''
    foreach ($w in ($Text -split '\s+')) {
        if     ($line.Length -eq 0)                        { $line = $w }
        elseif (($line.Length + 1 + $w.Length) -le $Width) { $line += " $w" }
        else                                               { $out += $line; $line = $w }
    }
    if ($line.Length -gt 0) { $out += $line }
    return $out
}

function Write-Ui {
    # Same shape as the Write-Host calls it replaced, so -ForegroundColor and
    # -NoNewline keep working; the text just lands in the buffer instead.
    param(
        [Parameter(Position = 0)][AllowEmptyString()][string]$Text = '',
        [string]$ForegroundColor = '',
        [switch]$NoNewline
    )
    if ($Text.Length -gt 0) {
        [void]$script:UiOpen.Add([pscustomobject]@{ Text = $Text; Colour = $ForegroundColor })
    }
    if (-not $NoNewline) {
        [void]$script:UiLines.Add($script:UiOpen)
        $script:UiOpen = [System.Collections.Generic.List[object]]::new()
    }
}

function Write-UiBlock {
    # Multi-line text (Format-Table output) into the buffer, one line each, so
    # the table is measured and centred with everything else.
    param(
        [Parameter(Position = 0, ValueFromPipeline)][AllowEmptyString()][string]$Text = '',
        [string]$ForegroundColor = '',
        [int]$Indent = 0
    )
    process {
        # Out-String brackets a table with blank lines; the caller decides its
        # own spacing, so they are dropped here.
        $lines = @($Text -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
        $a = 0; $b = $lines.Count - 1
        while ($a -le $b -and $lines[$a] -eq '') { $a++ }
        while ($b -ge $a -and $lines[$b] -eq '') { $b-- }
        $pad = ' ' * $Indent
        for ($i = $a; $i -le $b; $i++) {
            # Blank rows stay blank: padding them would widen the measured block
            # for nothing and push the whole frame off centre.
            if ($lines[$i] -eq '') { Write-Ui ''; continue }
            Write-Ui ($pad + $lines[$i]) -ForegroundColor $ForegroundColor
        }
    }
}

function Test-UiPending {
    return (($script:UiLines.Count -gt 0) -or ($script:UiOpen.Count -gt 0))
}

function Clear-Screen {
    # Clear-Host only blanks the visible window - the scrollback above it is
    # still one wheel-turn away. ESC[3J drops the scrollback as well, which is
    # the half that actually hides what was in the terminal before.
    $vt = $false
    try { $vt = [bool]$Host.UI.SupportsVirtualTerminal } catch { }
    if ($vt) {
        $esc = [char]27
        try { [Console]::Write("$esc[2J$esc[3J$esc[H") } catch { }
    } else {
        # Legacy console with no VT: shrinking the buffer to the window height
        # discards the scrollback, and putting it back costs nothing.
        try {
            $rui = $Host.UI.RawUI
            $buf = $rui.BufferSize
            $keep = $buf.Height
            if ($keep -gt $rui.WindowSize.Height) {
                $buf.Height    = $rui.WindowSize.Height
                $rui.BufferSize = $buf
                $buf.Height    = $keep
                $rui.BufferSize = $buf
            }
        } catch { }
    }
    try { Clear-Host } catch { }
}

function Show-Ui {
    # Print the buffer and empty it. In screen mode the frame is centred both
    # ways on a cleared screen; otherwise it is only centred horizontally and
    # printed where the cursor already is (so -Mode Status still reads as
    # ordinary command output).
    if ($script:UiOpen.Count -gt 0) { Write-Ui }

    $lines = $script:UiLines
    $script:UiLines = [System.Collections.Generic.List[object]]::new()
    if ($lines.Count -eq 0) { return }

    $size  = Get-UiSize
    $width = 0
    foreach ($line in $lines) {
        $len = 0
        foreach ($seg in $line) { $len += $seg.Text.Length }
        if ($len -gt $width) { $width = $len }
    }

    # One pad for the whole block, not per line: centring each line separately
    # would tear the columns apart.
    $script:UiPad = ' ' * ([Math]::Max(0, [int](($size.Width - $width) / 2)))

    if ($script:UiScreen) {
        Clear-Screen
        # Two lines held back for the prompt that follows most frames. A frame
        # taller than the window simply starts at the top.
        # Count printed ROWS, not buffer lines: a line wider than the window
        # wraps, and counting it as one row throws the top padding off.
        $rows = 0
        foreach ($line in $lines) {
            $len = $script:UiPad.Length
            foreach ($seg in $line) { $len += $seg.Text.Length }
            $rows += [Math]::Max(1, [int][Math]::Ceiling($len / [double]$size.Width))
        }
        $top = [Math]::Max(0, [int](($size.Height - $rows - 2) / 2))
        for ($i = 0; $i -lt $top; $i++) { Write-Host '' }
    }

    foreach ($line in $lines) {
        if ($line.Count -eq 0) { Write-Host ''; continue }   # no pad on blank lines
        if ($script:UiPad.Length -gt 0) { Write-Host $script:UiPad -NoNewline }
        foreach ($seg in $line) {
            if ($seg.Colour) { Write-Host $seg.Text -NoNewline -ForegroundColor $seg.Colour }
            else             { Write-Host $seg.Text -NoNewline }
        }
        Write-Host ''
    }
}

function Read-Ui {
    # Show whatever is buffered, then ask - indented to the frame. Read-Host's
    # own prompt cannot be indented, so it is printed here and Read-Host is
    # called bare. Returns $null at EOF (Read-Host throws there), which every
    # caller treats as "no answer".
    param([string]$Prompt = '')
    Show-Ui
    Write-Host ''
    if ($Prompt) { Write-Host ($script:UiPad + $Prompt) -NoNewline -ForegroundColor Cyan }
    $ans = try { Read-Host } catch { $null }
    return $ans
}

function Close-Screen {
    # Leaving the tool: wipe the last frame so the shell prompt comes back to a
    # clean terminal, then print the parting line (if any) as ordinary output.
    param([string]$Message = '', [string]$Colour = 'Yellow')
    Clear-Screen
    $script:UiScreen = $false
    if ($Message) {
        Write-Ui ''
        Write-Ui "  $Message" -ForegroundColor $Colour
        Write-Ui ''
    }
    Show-Ui
}

# ---------------------------------------------------------------------------
# Preflight, before the data section: that section uses [pscustomobject] and
# ::new(), which is exactly what ConstrainedLanguage blocks, so a check placed
# after it would never run on the machine it is meant to protect.
# ---------------------------------------------------------------------------
function Test-Environment {
    $fatal = @()

    # A 32-bit PowerShell on 64-bit Windows sees HKLM\SOFTWARE redirected into
    # WOW6432Node. Every value would read as ABSENT - which looks exactly like
    # "stock Windows" - so the tool would misreport a configured machine and then
    # write to the wrong key. Refuse rather than be confidently wrong.
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess) {
        $fatal += @(
            'Running 32-bit PowerShell on 64-bit Windows.'
            '  HKLM\SOFTWARE is redirected to WOW6432Node here, so every value would'
            '  read as absent and every write would go to the wrong key.'
            '  Use C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'
            '  (System32 IS the 64-bit one) or pwsh.'
        ) -join [Environment]::NewLine
    }

    $lm = $ExecutionContext.SessionState.LanguageMode
    if ($lm -ne 'FullLanguage') {
        $fatal += "PowerShell is in $lm mode (AppLocker/WDAC). This script needs FullLanguage."
    }

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        if (-not (Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue)) {
            $fatal += 'This script is Windows-only.'
        }
    }

    if ($fatal.Count -gt 0) {
        Write-Ui ''
        Write-Ui 'CANNOT RUN HERE' -ForegroundColor Red
        foreach ($f in $fatal) { Write-Ui "  $f" -ForegroundColor Red }
        Write-Ui ''
        Show-Ui
        return $false
    }
    return $true
}
if (-not (Test-Environment)) { exit 2 }

# ===========================================================================
# THE AXES
#
# Every entry says, for each state of its axis, what the registry must hold.
# $null means "this value must not exist" - which is what stock Windows looks
# like for most of these.
# ===========================================================================

$DwmKey  = 'HKLM:\SOFTWARE\Microsoft\Windows\Dwm'
$GcsKey  = 'HKCU:\System\GameConfigStore'
$PolKey  = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
$GpuKey  = 'HKCU:\Software\Microsoft\DirectX\UserGpuPreferences'
$GdvKey  = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR'
# Per-exe compatibility layers. Value name = full exe path, data = a space-
# separated flag list, normally led by '~'. HKLM holds the "for all users"
# variant of the same box; it is read so the display is honest, never written.
$LayersKey   = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$LayersKeyLM = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
$FsoFlag     = 'DISABLEDXMAXIMIZEDWINDOWEDMODE'   # the "Disable fullscreen optimizations" box

# The DWM feature set. Stock Windows ships NONE of these, which is why the Stock
# state deletes them. The values written by 'Stripped' are a coherent set of DWM
# feature switches; they are not a Microsoft-documented configuration.
$DwmStripped = [ordered]@{
    ForceDirectDrawSync                     = 0
    FrameLatency                            = 2
    MaxQueuedPresentBuffers                 = 1
    DDisplayTestMode                        = 0
    DebugFailFast                           = 0
    DisableDeviceBitmaps                    = 1
    DisableHologramCompositor               = 1
    DisableLockingMemory                    = 1
    DisableProjectedShadowsRendering        = 1
    DisableProjectedShadows                 = 1
    DisallowNonDrawListRendering            = 1
    EnableCpuClipping                       = 1
    EnableRenderPathTestMode                = 0
    FlattenVirtualSurfaceEffectInput        = 1
    InkGPUAccelOverrideVendorWhitelist      = 1
    InteractionOutputPredictionDisabled     = 1
    MPCInputRouterWaitForDebugger           = 0
    OneCoreNoDWMRawGameController           = 0
    ResampleInLinearSpace                   = 1
    SDRBoostPercentOverride                 = 1
    SuperWetEnabled                         = 1
    AnimationAttributionEnabled             = 0
    AnimationsShiftKey                      = 0
    DisableAdvancedDirectFlip               = 1
    DisableDrawListCaching                  = 1
    EnableCommonSuperSets                   = 1
    EnableDesktopOverlays                   = 0
    EnableEffectCaching                     = 1
    EnableFrontBufferRenderChecks           = 0
    EnableMegaRects                         = 1
    EnablePrimitiveReordering               = 0
    EnableResizeOptimization                = 1
    HighColor                               = 0
    MaxD3DFeatureLevel                      = 0
    OverlayQualifyCount                     = 0
    OverlayDisqualifyCount                  = 0
    ParallelModePolicy                      = 1
    ResampleModeOverride                    = 1
    RenderThreadWatchdogTimeoutMilliseconds = 0
    ResizeTimeoutGdi                        = 0
    ResizeTimeoutModern                     = 0
    UseHWDrawListEntriesOnWARP              = 1
}

# Values stock Windows DOES keep in the DWM key. Used to spot tweak values this
# tool does not know about - reported, never written.
$DwmStockValues  = @('GradientWhitePixelGPUBlacklist', 'ShaderLinkingGPUBlacklist', 'OneCoreNoBootDWM')
$DwmStockPattern = '^DwmInitSessionActivityId_'

$Entries = [System.Collections.Generic.List[object]]::new()

function Add-Entry {
    param(
        [string]$Axis, [string]$Path, [string]$Name,
        [ValidateSet('DWord', 'String', 'Token', 'Flag')][string]$Kind,
        [hashtable]$States,
        [string]$Token,
        [hashtable]$Accepts      # optional: extra values that also count as that state
    )
    $Entries.Add([pscustomobject]@{
        Axis = $Axis; Path = $Path; Name = $Name; Kind = $Kind
        States = $States; Token = $Token; Accepts = $Accepts
    })
}

# --- Axis: Mpo -------------------------------------------------------------
# 5 disables MPO. The enable is the value's ABSENCE - writing 0 is NOT the same
# thing and does not re-enable it.
Add-Entry -Axis 'Mpo' -Path $DwmKey -Name 'OverlayTestMode' -Kind 'DWord' `
          -States @{ On = $null; Off = 5 }

# --- Axis: Dwm -------------------------------------------------------------
foreach ($n in $DwmStripped.Keys) {
    Add-Entry -Axis 'Dwm' -Path $DwmKey -Name $n -Kind 'DWord' `
              -States @{ Stock = $null; Stripped = [int]$DwmStripped[$n] }
}

# --- Axis: Fso -------------------------------------------------------------
# One value, and it is the whole lever: 1 means a game asking for exclusive
# fullscreen gets it, instead of Windows quietly substituting flip-model
# borderless. Game DVR used to travel with this axis and no longer does - it is
# an OPTION now (see below), because it is a recording feature, not a render
# path, and nobody should have to accept it to get a preset.
Add-Entry -Axis 'Fso' -Path $GcsKey -Name 'GameDVR_DXGIHonorFSEWindowsCompatible' -Kind 'DWord' `
          -States @{ On = 0; Off = 1 }

# --- Axis: WindowedOpt -----------------------------------------------------
# One token inside a semicolon-delimited REG_SZ that also carries AutoHDR and
# VRR settings, so it is edited token-wise, never overwritten wholesale.
# 'On' is the Windows default and can legitimately look like TWO things: the token
# absent (never configured) or the token set to 1 (explicitly enabled from the
# Graphics settings page). Both mean enabled, so both are accepted; applying On
# removes the token, which is the true default.
Add-Entry -Axis 'WindowedOpt' -Path $GpuKey -Name 'DirectXUserGlobalSettings' -Kind 'Token' `
          -Token 'SwapEffectUpgradeEnable' -States @{ On = $null; Off = '0' } `
          -Accepts @{ On = @($null, '1'); Off = @('0') }

# --- Option: GameDvr -------------------------------------------------------
# An OPTION, not an axis: no preset sets it, and it is not part of what a preset
# name means. Game DVR is a recording feature. It is offered here because its
# capture path can knock a game off the direct flip path, so someone tuning the
# render path may well want it gone - but that is their choice to make once,
# not a rider on every preset.
#
# THREE values, and all three are the point. GameDVR_Enabled alone does not hold:
# it is the GameConfigStore mirror of AppCaptureEnabled, and the Windows gaming
# stack reconciles the pair at logon, which is exactly how a written-and-verified
# value came back changed after a reboot (DESIGN-AND-AUDIT.md §15, bug 23).
# Writing both sides of the mirror is what makes the setting survive. The HKLM
# policy is the durable backstop that held when its sibling did not.
Add-Entry -Axis 'GameDvr' -Path $PolKey -Name 'AllowGameDVR' -Kind 'DWord' `
          -States @{ On = $null; Off = 0 }
Add-Entry -Axis 'GameDvr' -Path $GdvKey -Name 'AppCaptureEnabled' -Kind 'DWord' `
          -States @{ On = 1; Off = 0 }
Add-Entry -Axis 'GameDvr' -Path $GcsKey -Name 'GameDVR_Enabled' -Kind 'DWord' `
          -States @{ On = 1; Off = 0 }

# --- Per-game: GameFso -----------------------------------------------------
# Not in $Entries: there is one of these per exe, built on demand. Same shape
# as every other entry so Invoke-SetAxes handles it unchanged (backup, diff,
# consent, verify). 'Flag' = one word inside a space-separated list, kept
# token-wise so RUNASADMIN, HIGHDPIAWARE and friends on the same exe survive.
function New-GameEntry {
    param([string]$Exe)
    [pscustomobject]@{
        Axis = 'GameFso'; Path = $LayersKey; Name = $Exe; Kind = 'Flag'
        States = @{ On = $null; Off = $FsoFlag }; Token = $FsoFlag; Accepts = $null
    }
}

$AxisInfo = [ordered]@{
    Mpo = @{
        Title  = 'MPO'
        Long   = 'Multi-Plane Overlay'
        States = @('On', 'Off')
        Blurb  = 'Hardware composition of several planes. Off = one plane; an overlay drawn over a game then has to go through DWM instead.'
    }
    Dwm = @{
        Title  = 'DWM features'
        Long   = 'DWM feature set'
        States = @('Stock', 'Stripped')
        Blurb  = 'Shadows, caching, effects, present queue depth, advanced direct flip. Desktop composition, not the game''s own frame path.'
    }
    Fso = @{
        Title  = 'FSO'
        Long   = 'Fullscreen Optimizations'
        States = @('On', 'Off')
        Blurb  = 'On = "fullscreen" is quietly turned into flip-model borderless. Off = a game asking for exclusive fullscreen gets it.'
    }
    WindowedOpt = @{
        Title  = 'Windowed opt'
        Long   = 'Optimizations for windowed games'
        States = @('On', 'Off')
        Blurb  = 'On = windowed and borderless games are upgraded to the flip model. Turning this OFF usually costs independent flip in borderless.'
    }
    GameDvr = @{
        Title  = 'Game DVR'
        Long   = 'Game DVR / background recording'
        States = @('On', 'Off')
        Blurb  = 'Xbox background recording and its capture hooks. Off removes the hooks, which can otherwise knock a game off the direct flip path. Purely a recording feature - no preset touches it.'
    }
    GameFso = @{
        Title  = 'Game FSO'
        Long   = 'Fullscreen Optimizations for one exe'
        States = @('On', 'Off')
        Blurb  = 'The "Disable fullscreen optimizations" box on an exe''s Compatibility tab. Off = that game always gets exclusive fullscreen (Legacy Flip), whatever the global Fso axis says. Per exe, per user.'
    }
}

# $AllAxes is what a PRESET is made of. $AllOptions is everything else that the
# tool can write: independent switches that no preset sets and no preset name
# implies. Keeping the two lists apart is what lets 'preset: Windows default'
# stay true while an option is deliberately not at its Windows value.
$AllAxes    = @('Mpo', 'Dwm', 'Fso', 'WindowedOpt')
$AllOptions = @('GameDvr')
$OptionKeys = @{ GameDvr = 'G' }   # menu key per option

# Named combinations. Order matters only for display.
$Presets = [ordered]@{
    WindowsDefault = @{
        Title = 'Windows default'
        Blurb = 'Everything as Microsoft ships it. The baseline to compare against.'
        Set   = @{ Mpo = 'On';  Dwm = 'Stock';    Fso = 'On';  WindowedOpt = 'On' }
    }
    MpoOff = @{
        Title = 'MPO off only'
        Blurb = 'The documented workaround for MPO flicker / black flashes on mixed-refresh multi-monitor. Nothing else touched.'
        Set   = @{ Mpo = 'Off'; Dwm = 'Stock';    Fso = 'On';  WindowedOpt = 'On' }
    }
    FsoOff = @{
        Title = 'Exclusive fullscreen'
        Blurb = 'Fullscreen Optimizations off, so "fullscreen" means exclusive again. Rest at Windows default.'
        Set   = @{ Mpo = 'On';  Dwm = 'Stock';    Fso = 'Off'; WindowedOpt = 'On' }
    }
    Lean = @{
        Title = 'Lean'
        Blurb = 'MPO and FSO both off, DWM internals left alone. The low-risk half of the tuned setup.'
        Set   = @{ Mpo = 'Off'; Dwm = 'Stock';    Fso = 'Off'; WindowedOpt = 'On' }
    }
    Stripped = @{
        Title = 'Stripped'
        Blurb = 'MPO off, DWM feature set stripped, FSO off. Windowed optimizations stay ON deliberately - see the note on that axis.'
        Set   = @{ Mpo = 'Off'; Dwm = 'Stripped'; Fso = 'Off'; WindowedOpt = 'On' }
    }
}

$BackupKeys = @(
    'HKLM\SOFTWARE\Microsoft\Windows\Dwm'
    'HKCU\System\GameConfigStore'
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR'
    'HKCU\Software\Microsoft\DirectX\UserGpuPreferences'
    'HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR'
    'HKCU\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers'
)

# ===========================================================================
# REGISTRY HELPERS
# ===========================================================================

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-DesktopUser {
    # Who owns the interactive desktop of THIS session: the explorer.exe next to
    # us. When the tool was elevated under DIFFERENT credentials, HKCU is the
    # elevated account's hive - so the per-user values would land in the wrong
    # place with no error. Same class of bug as the 32-bit redirection: reads
    # and writes "work" and are silently about the wrong data.
    # -IncludeUserName needs elevation; the case that matters is elevated by
    # definition, and every failure path just returns $null (= no warning).
    try {
        $sid = (Get-Process -Id $PID -ErrorAction Stop).SessionId
        $exp = @(Get-Process -Name explorer -IncludeUserName -ErrorAction Stop |
                 Where-Object { $_.SessionId -eq $sid })
        if ($exp.Count -gt 0 -and $exp[0].UserName) { return $exp[0].UserName }
    } catch { }
    return $null
}

function Get-RawValue {
    param([string]$Path, [string]$Name)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { $key = Get-Item -LiteralPath $Path -ErrorAction Stop } catch { return $null }
    # RegistryKey.GetValue, not Get-ItemProperty: the latter EXPANDS REG_EXPAND_SZ
    # and treats -Name as a wildcard pattern.
    $v = $key.GetValue($Name, $null,
        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    # `return ,$v` - a bare return sends the value through the pipeline, which
    # enumerates an array and rebuilds it as Object[], destroying its type.
    return ,$v
}

function Get-ValueKind {
    param([string]$Path, [string]$Name)
    try { $k = (Get-Item -LiteralPath $Path).GetValueKind($Name) } catch { return $null }
    switch ($k) {
        'DWord'  { 'DWord' }
        'String' { 'String' }
        default  { "$k" }
    }
}

# --- semicolon-delimited "k=v;" strings (DirectXUserGlobalSettings) --------

function Get-TokenValue {
    param([string]$Path, [string]$Name, [string]$Token)
    $raw = Get-RawValue -Path $Path -Name $Name
    if ($null -eq $raw) { return $null }
    foreach ($pair in ([string]$raw -split ';')) {
        if ([string]::IsNullOrWhiteSpace($pair)) { continue }
        $kv = $pair -split '=', 2
        if ($kv.Count -eq 2 -and $kv[0].Trim() -ceq $Token) { return $kv[1].Trim() }
    }
    return $null
}

function Set-TokenValue {
    param([string]$Path, [string]$Name, [string]$Token, $Target)
    # Parsed into an ordered list, not a hashtable: everything that is not the
    # managed token - other k=v pairs AND any fragment that does not parse as
    # one - must survive the rewrite verbatim, in its original order.
    $raw   = Get-RawValue -Path $Path -Name $Name
    $parts = [System.Collections.Generic.List[string]]::new()
    $found = $false
    if ($null -ne $raw) {
        foreach ($pair in ([string]$raw -split ';')) {
            if ([string]::IsNullOrWhiteSpace($pair)) { continue }
            $kv = $pair -split '=', 2
            if ($kv.Count -eq 2 -and $kv[0].Trim() -ceq $Token) {
                # First occurrence is rewritten (or dropped); duplicates go.
                if (-not $found -and $null -ne $Target) { $parts.Add("$Token=$([string]$Target)") }
                $found = $true
            } else {
                $parts.Add($pair.Trim())
            }
        }
    }
    if (-not $found -and $null -ne $Target) { $parts.Add("$Token=$([string]$Target)") }

    if ($parts.Count -eq 0) {
        # Nothing left to say - remove the value entirely rather than leave "".
        if (Test-Path -LiteralPath $Path) {
            Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction SilentlyContinue
        }
        return
    }
    $text = (($parts | ForEach-Object { "$_;" }) -join '')
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType String -Value $text -Force | Out-Null
}

# --- space-separated flag lists (AppCompatFlags\Layers) ---------------------

function Get-FlagValue {
    # The flag itself when present, else $null - so it compares like any state.
    param([string]$Path, [string]$Name, [string]$Token)
    $raw = Get-RawValue -Path $Path -Name $Name
    if ($null -eq $raw) { return $null }
    if (@(([string]$raw) -split '\s+') -ccontains $Token) { return $Token }
    return $null
}

function Set-FlagValue {
    param([string]$Path, [string]$Name, [string]$Token, $Target)
    $raw   = Get-RawValue -Path $Path -Name $Name
    $parts = [System.Collections.Generic.List[string]]::new()
    if ($null -ne $raw) {
        foreach ($w in (([string]$raw) -split '\s+')) {
            if ($w -and $w -cne $Token) { $parts.Add($w) }
        }
    }
    if ($null -ne $Target) { $parts.Add($Token) }
    # Windows writes '~ FLAG ...' from the Compatibility tab; a list that is
    # only the '~' marker is an empty list and the value goes.
    $real = @($parts | Where-Object { $_ -ne '~' })
    if ($real.Count -eq 0) {
        if (Test-Path -LiteralPath $Path) {
            Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction SilentlyContinue
        }
        return
    }
    if (-not $parts.Contains('~')) { $parts.Insert(0, '~') }
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $Path -Name $Name -PropertyType String -Value ($parts -join ' ') -Force | Out-Null
}

# --- one interface for every kind -------------------------------------------

function Get-EntryCurrent {
    param([pscustomobject]$Entry)
    if ($Entry.Kind -eq 'Token') {
        return Get-TokenValue -Path $Entry.Path -Name $Entry.Name -Token $Entry.Token
    }
    if ($Entry.Kind -eq 'Flag') {
        return Get-FlagValue -Path $Entry.Path -Name $Entry.Name -Token $Entry.Token
    }
    return ,(Get-RawValue -Path $Entry.Path -Name $Entry.Name)
}

function Test-EntryIs {
    param([pscustomobject]$Entry, [string]$State)
    $cur = Get-EntryCurrent -Entry $Entry

    # A state can have several equally valid appearances - e.g. a Windows default
    # that is either "never written" or "written to its default value".
    $ok = @($Entry.States[$State])
    if ($Entry.Accepts -and $Entry.Accepts.ContainsKey($State)) { $ok = @($Entry.Accepts[$State]) }

    $matched = $false
    foreach ($target in $ok) {
        if ($null -eq $target -and $null -eq $cur) { $matched = $true; break }
        if ($null -eq $target -or  $null -eq $cur) { continue }
        if ("$cur" -ceq "$target") { $matched = $true; break }
    }
    if (-not $matched) { return $false }
    if ($null -eq $cur) { return $true }        # absent has no type to check
    # For plain values, the KIND has to match too: REG_SZ "5" where REG_DWORD 5
    # belongs carries the right text and is still ignored by the component reading it.
    if ($Entry.Kind -notin 'Token', 'Flag') {
        $kind = Get-ValueKind -Path $Entry.Path -Name $Entry.Name
        if ($kind -and $kind -ne $Entry.Kind) { return $false }
    }
    return $true
}

function Set-EntryTo {
    param([pscustomobject]$Entry, [string]$State)
    $target = $Entry.States[$State]
    if ($Entry.Kind -eq 'Token') {
        Set-TokenValue -Path $Entry.Path -Name $Entry.Name -Token $Entry.Token -Target $target
        return
    }
    if ($Entry.Kind -eq 'Flag') {
        Set-FlagValue -Path $Entry.Path -Name $Entry.Name -Token $Entry.Token -Target $target
        return
    }
    if ($null -eq $target) {
        if (Test-Path -LiteralPath $Entry.Path) {
            Remove-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name -Force -ErrorAction SilentlyContinue
        }
        return
    }
    if (-not (Test-Path -LiteralPath $Entry.Path)) { New-Item -Path $Entry.Path -Force | Out-Null }
    New-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name `
        -PropertyType $Entry.Kind -Value $target -Force | Out-Null
}

function Format-Target {
    param($V)
    if ($null -eq $V) { return '<absent>' }
    return [string]$V
}

# ===========================================================================
# AXIS STATE
# ===========================================================================

function Get-AxisState {
    param([string]$Axis)
    $rows = @($Entries | Where-Object { $_.Axis -eq $Axis })
    foreach ($s in $AxisInfo[$Axis].States) {
        $all = $true
        foreach ($e in $rows) { if (-not (Test-EntryIs -Entry $e -State $s)) { $all = $false; break } }
        if ($all) { return $s }
    }
    return 'MIXED'
}

function Get-StateColour {
    param([string]$Axis, [string]$State)
    if ($State -eq 'MIXED') { return 'Red' }
    if ($State -eq $AxisInfo[$Axis].States[0]) { return 'DarkGray' } # stock Windows
    return 'Green'                                                   # changed on purpose
}

function Get-StateLabel {
    # The same information as the colour, in words. Colour alone was carrying
    # the whole meaning, and on a machine sitting at Windows default every row
    # was the one colour that looks like ordinary text - so the display said
    # nothing at all to anyone who had not read the legend.
    param([string]$Axis, [string]$State)
    if ($State -eq 'MIXED') { return 'some of its values disagree - pick a state to settle it' }
    if ($State -eq $AxisInfo[$Axis].States[0]) { return 'Windows default' }
    return 'changed from default'
}

function Get-AllAxisStates {
    # One registry pass for all axes. Show-State feeds the SAME result to the
    # preset header and the axis rows, so the two cannot disagree if a value
    # changes between reads mid-frame - and the frame costs half the reads.
    $now = @{}
    foreach ($a in $AllAxes) { $now[$a] = Get-AxisState $a }
    return $now
}

function Get-PresetMatch {
    # Which preset, if any, the machine currently is.
    param([hashtable]$Now)
    if (-not $Now) { $Now = Get-AllAxisStates }
    foreach ($p in $Presets.Keys) {
        $ok = $true
        foreach ($a in $AllAxes) { if ($Now[$a] -ne $Presets[$p].Set[$a]) { $ok = $false; break } }
        if ($ok) { return $p }
    }
    return $null
}

function Get-UnknownDwmValues {
    # DWM tweak values this tool does not know about. Reported so you know the
    # "Stripped" definition may be incomplete on a given image. Never written.
    if (-not (Test-Path -LiteralPath $DwmKey)) { return @() }
    $known = @($Entries | Where-Object { $_.Path -eq $DwmKey } | ForEach-Object { $_.Name })
    $out = @()
    foreach ($n in (Get-Item -LiteralPath $DwmKey).GetValueNames()) {
        if ([string]::IsNullOrEmpty($n))     { continue }
        if ($known -contains $n)             { continue }
        if ($DwmStockValues -contains $n)    { continue }
        if ($n -match $DwmStockPattern)      { continue }
        $out += $n
    }
    return $out
}

# ===========================================================================
# PER-GAME AND PRESENT MODE
# ===========================================================================

function Get-GameFsoList {
    # Every exe with the per-exe FSO flag, in either hive. HKLM is the "for all
    # users" box; it wins for that exe and this tool does not write it.
    $out = @()
    foreach ($k in @($LayersKeyLM, $LayersKey)) {
        if (-not (Test-Path -LiteralPath $k)) { continue }
        $item = Get-Item -LiteralPath $k
        foreach ($n in $item.GetValueNames()) {
            if ($n -notlike '*.exe') { continue }
            if (-not (Get-FlagValue -Path $k -Name $n -Token $FsoFlag)) { continue }
            $out += [pscustomobject]@{ Exe = $n; Hive = $(if ($k -eq $LayersKey) { 'HKCU' } else { 'HKLM' }) }
        }
    }
    return $out
}

function Get-FsoOverrideNote {
    # The older global FSO-off tweak: HonorUserFSEBehaviorMode=1 makes Windows
    # obey FSEBehaviorMode, and 2 there means "no fullscreen optimizations". It
    # sits next to the value the Fso axis manages and silently overrides an
    # Fso=On reading. Reported, never written.
    $honor = Get-RawValue -Path $GcsKey -Name 'GameDVR_HonorUserFSEBehaviorMode'
    $mode  = Get-RawValue -Path $GcsKey -Name 'GameDVR_FSEBehaviorMode'
    if ("$honor" -eq '1' -and "$mode" -eq '2') {
        return 'GameDVR_HonorUserFSEBehaviorMode=1 with FSEBehaviorMode=2: the older global FSO-off tweak is active, so FSO is effectively OFF even where the axis above says On.'
    }
    return $null
}

function Get-ExpectedPresentMode {
    # What PresentMon should report, derived from the registry. A prediction,
    # not a measurement: driver, GPU overlay support and whatever is drawn over
    # the game all have a say. Names are PresentMon's own, so the two compare.
    param([hashtable]$Now, [switch]$ExeFsoOff)
    $fsoOff = ($Now.Fso -eq 'Off') -or $ExeFsoOff -or (Get-FsoOverrideNote)
    $mpo    = ($Now.Mpo -eq 'On')
    $full = if ($fsoOff) { 'Hardware: Legacy Flip' }
            elseif ($mpo) { 'Hardware Composed: Independent Flip' }
            else          { 'Hardware: Independent Flip' }
    $fullWhy = if ($fsoOff) { 'exclusive fullscreen, DWM out of the path' }
               elseif ($mpo) { 'FSO borderless on an MPO plane; falls back to Hardware: Independent Flip if the driver declines the overlay' }
               else          { 'FSO borderless, direct flip, no overlay plane' }
    $win = if ($Now.WindowedOpt -ne 'On') { 'Composed: Flip' }
           elseif ($mpo)                  { 'Hardware Composed: Independent Flip' }
           else                           { 'Hardware: Independent Flip' }
    $winWhy = if ($Now.WindowedOpt -ne 'On') { 'blit model: DWM copies every frame, no VRR, extra latency' }
              else { 'only while the window covers the screen with nothing drawn over it; otherwise Composed: Flip' }
    return [pscustomobject]@{ Full = $full; FullWhy = $fullWhy; Win = $win; WinWhy = $winWhy }
}

function Show-ExpectedMode {
    param([hashtable]$Now, [switch]$Interactive)
    $w   = Get-UiFrameWidth
    $x   = Get-ExpectedPresentMode -Now $Now
    $hint = if ($Interactive -and (Find-PresentMon)) { 'derived from the registry - press [V] to measure the real thing' }
            else { 'derived from the registry, not measured - use -Measure' }
    Write-UiSection 'EXPECTED PRESENT MODE' $hint
    foreach ($row in @(@('Fullscreen', $x.Full, $x.FullWhy), @('Borderless', $x.Win, $x.WinWhy))) {
        Write-Ui ('    {0,-14}' -f $row[0]) -NoNewline
        Write-Ui $row[1] -ForegroundColor Cyan
        foreach ($l in (Split-UiText $row[2] ($w - 20))) { Write-Ui ('                  ' + $l) -ForegroundColor DarkGray }
    }
    $note = Get-FsoOverrideNote
    if ($note) {
        Write-Ui ''
        foreach ($l in (Split-UiText "note: $note" ($w - 8))) { Write-Ui "    $l" -ForegroundColor Yellow }
    }
    $games = @(Get-GameFsoList)
    if ($games.Count -gt 0) {
        Write-Ui ''
        Write-Ui '    per-exe FSO off (Legacy Flip for these, whatever the axis says):' -ForegroundColor DarkGray
        foreach ($g in $games) {
            Write-Ui ('      {0}' -f $g.Exe) -ForegroundColor Green -NoNewline
            Write-Ui $(if ($g.Hive -eq 'HKLM') { '  (all users - not managed here)' } else { '' }) -ForegroundColor DarkGray
        }
    }
}

# --- PresentMon: the measurement the docs kept asking for -------------------

function Find-PresentMon {
    if ($PresentMon) { return $(if (Test-Path -LiteralPath $PresentMon) { $PresentMon } else { $null }) }
    $local = Join-Path $ScriptDir 'presentmon.exe'
    if (Test-Path -LiteralPath $local) { return $local }
    $cmd = Get-Command presentmon.exe, presentmon -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return $null
}

function Invoke-Measure {
    # Runs PresentMon against one process for a fixed time and reduces the CSV
    # to "which present mode, how often". ETW capture needs elevation.
    param([string]$Process, [int]$For)
    $exe = Find-PresentMon
    Write-UiSection 'MEASURED PRESENT MODE' "presentmon, $For s, $Process"
    if (-not $exe) {
        Write-Ui '    presentmon.exe not found - put it on PATH, next to this script, or pass -PresentMon.' -ForegroundColor Red
        Write-Ui '    https://github.com/GameTechDev/PresentMon/releases  (or: winget install Intel.PresentMon)' -ForegroundColor DarkGray
        return
    }
    if (-not (Test-Admin)) {
        Write-Ui '    ETW capture needs elevation - re-run elevated.' -ForegroundColor Red
        return
    }
    if ($Process -notlike '*.exe') { $Process += '.exe' }
    if (-not (Get-Process -Name ($Process -replace '\.exe$') -ErrorAction SilentlyContinue)) {
        Write-Ui "    $Process is not running. Start the game first, then measure." -ForegroundColor Yellow
        return
    }
    # Write-Host, not Write-Ui: this has to land NOW, before the capture blocks.
    Write-Host "  capturing $Process for $For s - keep the game in the foreground..." -ForegroundColor DarkGray
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        # --terminate_after_timed is not optional: --timed only stops the
        # RECORDING. Without it presentmon keeps its ETW session open and the
        # call never returns - a 3-second capture hung until it was killed.
        $csv = & $exe --process_name $Process --timed $For --terminate_after_timed `
                      --output_stdout --no_console_stats --no_track_input `
                      --session_name 'render-path' --stop_existing_session 2>$null
    } finally { $ErrorActionPreference = $prev }
    $rows = @($csv | Where-Object { $_ -match ',' } | ConvertFrom-Csv)
    if ($rows.Count -eq 0) {
        Write-Ui '    no frames captured - the process presented nothing in that time.' -ForegroundColor Yellow
        return
    }
    $total = $rows.Count
    foreach ($g in ($rows | Group-Object PresentMode | Sort-Object Count -Descending)) {
        $pct = [math]::Round(100 * $g.Count / $total)
        $col = if ($g.Name -like 'Hardware*') { 'Green' } else { 'Yellow' }
        Write-Ui ('    {0,4}%  ' -f $pct) -NoNewline
        Write-Ui $g.Name -ForegroundColor $col
    }
    Write-Ui ''
    Write-Ui ("    {0} frames. Anything but a Hardware mode means DWM is in the path." -f $total) -ForegroundColor DarkGray
}

# ===========================================================================
# BACKUP
# ===========================================================================

function New-Backup {
    param([string]$Label)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    try {
        # The stamp has one-second resolution, and -Force happily reuses an
        # existing folder - so two applies inside the same second would write
        # their exports into one folder and the first backup would be silently
        # overwritten. Take the next free name instead of merging them.
        $dir = Join-Path $BackupRoot "$BackupPrefix$Label-$stamp"
        $n = 1
        while (Test-Path -LiteralPath $dir) {
            $n++
            $dir = Join-Path $BackupRoot "$BackupPrefix$Label-$stamp-$n"
        }
        New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Ui ''
        Write-Ui "  BACKUP FAILED - could not create a folder under '$BackupRoot'" -ForegroundColor Red
        Write-Ui "  $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
    # New-Item -ItemType Directory -Force does NOT fail when the path is an
    # existing FILE - it returns that file and throws nothing. Without this
    # check a -BackupRoot pointing at a file produced a "successful" backup
    # containing nothing, and the registry was then written anyway.
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) {
        Write-Ui ''
        Write-Ui "  BACKUP FAILED - '$dir' is not a directory." -ForegroundColor Red
        Write-Ui "  Is -BackupRoot pointing at a file?" -ForegroundColor Red
        return $null
    }

    $failed = @()
    foreach ($k in $BackupKeys) {
        # Skip absent keys: reg.exe writes to stderr for those, and under Windows
        # PowerShell 5.1 native stderr in a redirecting pipeline becomes a
        # TERMINATING error while $ErrorActionPreference is 'Stop'.
        $psPath = $k -replace '^HKLM\\', 'HKLM:\' -replace '^HKCU\\', 'HKCU:\'
        if (-not (Test-Path -LiteralPath $psPath)) { continue }
        $file = Join-Path $dir (($k -replace '[\\ ]', '_') + '.reg')
        $prev = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $global:LASTEXITCODE = 0
        try   { & reg.exe export $k $file /y 2>&1 | Out-Null }
        catch { }
        finally { $ErrorActionPreference = $prev }
        # reg.exe reports failure by EXIT CODE. Redirecting its stderr - which
        # this has to do, see above - means a failed export raises nothing at
        # all, so the only honest evidence is the code and the file itself.
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $file)) {
            $failed += $k
        }
    }
    if ($failed.Count -gt 0) {
        Write-Ui ''
        Write-Ui "  BACKUP FAILED - $($failed.Count) key(s) could not be exported:" -ForegroundColor Red
        foreach ($k in $failed) { Write-Ui "    $k" -ForegroundColor Red }
        return $null
    }
    @(
        "Backup taken $(Get-Date -Format o) before '$Label'."
        ''
        'reg import each .reg file here to restore, from an elevated prompt.'
        'CAVEAT: import only adds/overwrites - it restores values that were'
        'DELETED, but does not remove values that were ADDED. For a clean'
        'round trip use the script itself.'
    ) | Set-Content -LiteralPath (Join-Path $dir 'README.txt') -Encoding UTF8 -ErrorAction SilentlyContinue
    return $dir
}

function Get-BackupFolders {
    # Newest first. Only folders this tool made - a -BackupRoot shared with
    # something else must not have its other contents listed, let alone deleted.
    #
    # Sorted by the TIMESTAMP IN THE NAME, not by the name itself: the name is
    # 'render-path-<label>-<stamp>', so a lexicographic sort orders by label
    # first and 'render-path-manual-20260829' outranks 'render-path-apply-20260901'.
    # That would make "keep the newest" keep the oldest. CreationTime is the
    # fallback for anything whose name does not carry a parsable stamp.
    if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) { return @() }
    return @(Get-ChildItem -LiteralPath $BackupRoot -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -like "$BackupPrefix*" } |
             Sort-Object -Descending -Property @{ Expression = {
                 if ($_.Name -match '(\d{8}-\d{6})') {
                     [datetime]::ParseExact($Matches[1], 'yyyyMMdd-HHmmss', $null)
                 } else { $_.CreationTime }
             } }, Name)
}

function Get-BackupSize {
    param([System.IO.DirectoryInfo]$Dir)
    try {
        $b = (Get-ChildItem -LiteralPath $Dir.FullName -Recurse -File -ErrorAction Stop |
              Measure-Object -Property Length -Sum).Sum
        if (-not $b) { $b = 0 }
        return [long]$b
    } catch { return 0 }
}

function Format-Bytes {
    param([long]$B)
    if ($B -ge 1MB) { return ('{0:N1} MB' -f ($B / 1MB)) }
    if ($B -ge 1KB) { return ('{0:N0} KB' -f ($B / 1KB)) }
    return "$B B"
}

function Open-BackupFolder {
    # Returns a one-line notice for the menu rather than printing, because the
    # next redraw would wipe anything printed here.
    if (-not (Test-Path -LiteralPath $BackupRoot -PathType Container)) {
        return "no backup folder yet - none has been written to '$BackupRoot'"
    }
    try {
        # explorer.exe, not Invoke-Item: started from an elevated process this
        # still opens in the user's own already-running Explorer, so the window
        # is not elevated and behaves normally.
        Start-Process -FilePath 'explorer.exe' -ArgumentList $BackupRoot -ErrorAction Stop
        return "opened $BackupRoot"
    } catch {
        return "could not open Explorer: $($_.Exception.Message)"
    }
}

function Invoke-PruneBackups {
    # Deleting restore points is destructive and irreversible, so it lists
    # exactly what goes, keeps the newest $Keep, and needs the word typed out -
    # the same gate Restart-Dwm uses.
    param([int]$Keep = 3)
    $all = @(Get-BackupFolders)
    if ($all.Count -eq 0) {
        Write-Ui ''
        Write-Ui '  No backups to prune.' -ForegroundColor Green
        return
    }
    $keepSet = @($all | Select-Object -First $Keep)
    $drop    = @($all | Select-Object -Skip $Keep)

    $total = 0
    Write-UiSection 'BACKUPS' "$($all.Count) folder(s) in $BackupRoot"
    foreach ($d in $all) {
        $sz = Get-BackupSize -Dir $d
        $total += $sz
        if ($keepSet -contains $d) {
            Write-Ui ('    keep    {0,-42} {1,10}' -f $d.Name, (Format-Bytes $sz)) -ForegroundColor DarkGray
        } else {
            Write-Ui ('    DELETE  {0,-42} {1,10}' -f $d.Name, (Format-Bytes $sz)) -ForegroundColor Red
        }
    }
    Write-Ui ('    {0,-50} {1,10}' -f 'total', (Format-Bytes $total)) -ForegroundColor DarkGray

    if ($drop.Count -eq 0) {
        Write-Ui ''
        Write-Ui "  Nothing to prune - only $($all.Count) backup(s), keeping $Keep." -ForegroundColor Green
        return
    }

    $freed = 0
    foreach ($d in $drop) { $freed += Get-BackupSize -Dir $d }
    $go = Confirm-Destructive -Word 'DELETE' -Warning (
        "This permanently deletes $($drop.Count) backup folder(s), $(Format-Bytes $freed)." +
        [Environment]::NewLine + '  Restore points cannot be recovered once removed.')
    if (-not $go) { return }

    $gone = 0; $failed = @()
    foreach ($d in $drop) {
        if (-not $PSCmdlet.ShouldProcess($d.FullName, 'delete backup folder')) { continue }
        try { Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction Stop; $gone++ }
        catch { $failed += "$($d.Name) - $($_.Exception.Message)" }
    }
    Write-Ui ''
    if ($WhatIfPreference) {
        Write-Ui '  -WhatIf: nothing was deleted.' -ForegroundColor Yellow
    } else {
        Write-Ui "  $gone backup folder(s) deleted, $(Format-Bytes $freed) freed." -ForegroundColor Green
    }
    foreach ($e in $failed) { Write-Ui "  FAILED: $e" -ForegroundColor Red }
}

# ===========================================================================
# APPLY
# ===========================================================================

function Invoke-SetAxes {
    # -Pool: the entries to pick from. Defaults to the fixed table; a per-game
    # entry is built on demand and passed in here.
    param([hashtable]$Wanted, [switch]$AssumeYes, [object[]]$Pool = $Entries)

    $pending = @()
    foreach ($axis in $Wanted.Keys) {
        $state = $Wanted[$axis]
        foreach ($e in ($Pool | Where-Object { $_.Axis -eq $axis })) {
            if (-not (Test-EntryIs -Entry $e -State $state)) {
                $pending += [pscustomobject]@{ Entry = $e; State = $state }
            }
        }
    }

    if ($pending.Count -eq 0) {
        Write-Ui ''
        Write-Ui '  Already in that configuration. Nothing to change.' -ForegroundColor Green
        Write-Ui ''
        return @()
    }

    # -WhatIf writes nothing, so a dry run is allowed to enumerate the changes
    # it would refuse to make.
    if (-not $WhatIfPreference -and
        @($pending | Where-Object { $_.Entry.Path -like 'HKLM:*' }).Count -gt 0 -and -not (Test-Admin)) {
        Write-Ui ''
        Write-Ui '  Elevation required: this change writes to HKLM. Re-run elevated.' -ForegroundColor Red
        $script:ApplyFailed = $true
        return @()
    }

    if (@($pending | Where-Object { $_.Entry.Path -like 'HKCU:*' }).Count -gt 0 -and (Test-Admin)) {
        $desktop = Get-DesktopUser
        $me      = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        if ($desktop -and $me -and ($desktop -ne $me)) {
            Write-Ui ''
            Write-Ui "  WARNING: elevated as '$me', but this desktop belongs to '$desktop'." -ForegroundColor Yellow
            Write-Ui "  The HKCU values below will land in the elevated account's hive and do" -ForegroundColor Yellow
            Write-Ui "  nothing for the user at the desktop. Elevate as that user instead." -ForegroundColor Yellow
        }
    }

    Write-Ui ''
    Write-Ui "  $($pending.Count) value(s) will change:" -ForegroundColor Cyan
    foreach ($p in $pending) {
        Write-Ui ('  [{0,-11}] {1,-42} {2}  ->  {3}' -f `
            $p.Entry.Axis, $p.Entry.Name,
            (Format-Target (Get-EntryCurrent -Entry $p.Entry)),
            (Format-Target $p.Entry.States[$p.State]))
    }
    Write-Ui ''

    # Under -WhatIf nothing will be written, so there is nothing to consent to.
    if (-not $AssumeYes -and -not $WhatIfPreference) {
        $ans = Read-Ui '  Apply? [y/N] '
        if ($ans -notmatch '^(y|yes|j|ja)$') {
            Write-Ui '  Aborted, nothing written.' -ForegroundColor Yellow
            return @()
        }
    }

    if (-not $NoBackup -and $PSCmdlet.ShouldProcess('affected registry keys', 'export backup')) {
        $dir = New-Backup -Label 'apply'
        if (-not $dir) {
            Write-Ui '  Refusing to change the registry without a backup.' -ForegroundColor Red
            Write-Ui '  Fix the location (-BackupRoot <path>), or pass -NoBackup.' -ForegroundColor Red
            $script:ApplyFailed = $true
            return @()
        }
        Write-Ui "  Backup: $dir" -ForegroundColor DarkGray
    }

    $changed = 0
    $failed  = @()
    $touched = @{}
    foreach ($p in $pending) {
        $e = $p.Entry
        $desc = if ($null -eq $e.States[$p.State]) { "clear $($e.Name)" }
                else { "set $($e.Name) = $($e.States[$p.State])" }
        if (-not $PSCmdlet.ShouldProcess($e.Path, $desc)) { continue }
        try { Set-EntryTo -Entry $e -State $p.State }
        catch {
            $failed += [pscustomobject]@{ Entry = $e; Reason = $_.Exception.Message }
            continue
        }
        # Read back. Deletes run with -ErrorAction SilentlyContinue, so a refused
        # one would otherwise be counted as a success.
        if (Test-EntryIs -Entry $e -State $p.State) {
            $changed++
            $touched[$e.Axis] = $true
        } else {
            $failed += [pscustomobject]@{
                Entry = $e; Reason = "still reads '$(Format-Target (Get-EntryCurrent -Entry $e))'" }
        }
    }

    Write-Ui ''
    if ($WhatIfPreference) {
        Write-Ui '  -WhatIf: nothing was written.' -ForegroundColor Yellow
        # The caller's Show-Aftermath sees an empty $touched on a dry run, so the
        # would-be aftermath is reported here, from $pending, where it is known.
        Show-Aftermath -Would -Touched @($pending | ForEach-Object { $_.Entry.Axis } | Sort-Object -Unique)
    } else {
        Write-Ui "  $changed value(s) written and verified." -ForegroundColor Green
    }
    if ($failed.Count -gt 0) {
        Write-Ui ''
        Write-Ui "  $($failed.Count) value(s) FAILED:" -ForegroundColor Red
        foreach ($f in $failed) {
            Write-Ui ('    [{0}] {1} - {2}' -f $f.Entry.Axis, $f.Entry.Name, $f.Reason) -ForegroundColor Red
        }
        Write-Ui '  Those axes are now MIXED. Check elevation and re-run.' -ForegroundColor Red
        $script:ApplyFailed = $true
    }
    if ($changed -eq 0) { return @() }
    return @($touched.Keys)
}

function Show-Aftermath {
    # -Would is the dry-run wording. A -WhatIf run used to say nothing here at
    # all, because the caller feeds this the axes that were actually WRITTEN and
    # a dry run writes none - so the one moment you are deciding whether to go
    # ahead was the one moment the tool did not mention the reboot.
    param([string[]]$Touched, [switch]$Would)
    if (-not $Touched -or $Touched.Count -eq 0) { return }
    $verb = if ($Would) { 'would need' } else { 'need' }
    Write-UiSection 'TO TAKE EFFECT' "these changes $verb more than the registry write"
    if ($Touched -contains 'Mpo' -or $Touched -contains 'Dwm') {
        Write-Ui '    REBOOT (or sign out) - DWM reads these once, at session init.' -ForegroundColor Yellow
    }
    if ($Touched -contains 'Fso' -or $Touched -contains 'WindowedOpt' -or $Touched -contains 'GameFso') {
        Write-Ui '    Restart the game - read at process start.' -ForegroundColor DarkGray
    }
    if ($Touched -contains 'GameDvr') {
        Write-Ui '    Sign out and back in - so the capture settings reload.' -ForegroundColor Yellow
    }
}

# ===========================================================================
# DESTRUCTIVE ACTIONS
#
# Never $PSCmdlet.ShouldContinue here: at EOF it throws, and given an answer it
# does not recognise its prompt loop falls through to the FIRST choice, which is
# Yes. A stray line in a redirected stdin is then read as consent - that once
# rebooted a machine during testing. Require the word to be typed instead;
# Read-Host returns '' at EOF, so every non-keyboard path declines.
# ===========================================================================
function Confirm-Destructive {
    param([string]$Warning, [string]$Word)
    Write-Ui ''
    Write-Ui "  $Warning" -ForegroundColor Red
    $typed = Read-Ui "  Type $Word (exactly) to confirm: "
    if ($null -eq $typed) { $typed = '' }
    if ($typed.Trim() -cne $Word) {
        Write-Ui '  Not confirmed - nothing done.' -ForegroundColor Yellow
        return $false
    }
    return $true
}

function Resolve-GameExe {
    # The value name IS the path, so a typo would create an entry for nothing.
    # Accept a path that exists on disk, or one Windows already has an entry
    # for (the exe may live on a drive that is not mounted right now).
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    $p = $Path.Trim().Trim('"')
    $known = @()
    foreach ($k in @($LayersKey, $LayersKeyLM)) {
        if (Test-Path -LiteralPath $k) { $known += (Get-Item -LiteralPath $k).GetValueNames() }
    }
    if ($known -contains $p) { return $p }
    if ($p -like '*.exe' -and (Test-Path -LiteralPath $p -PathType Leaf)) {
        return (Resolve-Path -LiteralPath $p).ProviderPath
    }
    Write-Ui ''
    Write-Ui "  '$p' is not an .exe on disk and has no compatibility entry - nothing done." -ForegroundColor Red
    return $null
}

function Restart-Dwm {
    # Returns $true only when dwm.exe was actually terminated, so the caller can
    # clear its reboot-pending flag - the replacement DWM re-reads the values.
    if (-not (Test-Admin)) {
        Write-Ui ''
        Write-Ui '  Restarting DWM needs elevation - dwm.exe cannot be killed from here.' -ForegroundColor Red
        return $false
    }
    $go = Confirm-Destructive -Word 'KILLDWM' -Warning (
        'Killing dwm.exe applies the DWM/MPO values without a reboot, but on some' +
        [Environment]::NewLine + '  builds it ends the session and you lose unsaved work.')
    if (-not $go) { return $false }
    if ($WhatIfPreference) {
        Write-Ui '  -WhatIf: dwm.exe not touched.' -ForegroundColor Yellow
        return $false
    }
    # No SilentlyContinue: a refused kill must not be reported as a success.
    try {
        Stop-Process -Name dwm -Force -ErrorAction Stop
        Write-Ui '  dwm.exe killed; Windows restarts it automatically.' -ForegroundColor Yellow
        return $true
    } catch {
        Write-Ui "  Could not kill dwm.exe: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# ===========================================================================
# DISPLAY
# ===========================================================================

# The preset rows are the widest thing the menu draws, so they set the width of
# the frame; the rules and the header line are then drawn to match, and Show-Ui
# centres the block as a whole.
function Get-PresetRows {
    $rows = @()
    $i = 0
    foreach ($p in $Presets.Keys) {
        $i++
        $set = $Presets[$p].Set
        $rows += [pscustomobject]@{
            Key  = $p
            Head = ('[{0}] {1,-22}' -f $i, $Presets[$p].Title)
            Axes = ((($AllAxes | ForEach-Object { '{0}={1,-9}' -f $_, $set[$_] }) -join ' ').TrimEnd())
        }
    }
    return $rows
}

function Get-UiFrameWidth {
    if ($script:UiFrameWidth -le 0) {
        $w = 62
        foreach ($r in (Get-PresetRows)) {
            # '  X ' marker column + head + axes, and a little air on the right.
            $len = 4 + $r.Head.Length + $r.Axes.Length + 2
            if ($len -gt $w) { $w = $len }
        }
        $script:UiFrameWidth = $w
    }
    return $script:UiFrameWidth
}

function Write-UiPanel {
    # The title bar. Left label and right status inside one box, drawn to the
    # frame width so it lines up with every section below it.
    param([string]$Left, [string]$Right, [string]$RightColour = 'Green')
    $g   = $script:Glyph
    $w   = Get-UiFrameWidth
    $gap = [Math]::Max(2, $w - 6 - $Left.Length - $Right.Length)
    Write-Ui ($g.TL + ($g.Rule * ($w - 2)) + $g.TR) -ForegroundColor Cyan
    Write-Ui ($g.V + '  ')  -ForegroundColor Cyan -NoNewline
    Write-Ui $Left          -ForegroundColor White -NoNewline
    Write-Ui (' ' * $gap)   -NoNewline
    Write-Ui $Right         -ForegroundColor $RightColour -NoNewline
    Write-Ui '  '           -NoNewline
    Write-Ui $g.V           -ForegroundColor Cyan
    Write-Ui ($g.BL + ($g.Rule * ($w - 2)) + $g.BR) -ForegroundColor Cyan
}

function Write-UiSection {
    # A named block with a one-line explanation of what the reader is looking
    # at. The explanation is the point: without it the state block was just
    # four words with no indication they described the live machine.
    param([string]$Title, [string]$Hint = '')
    $g = $script:Glyph
    Write-Ui ''
    Write-Ui ('  ' + $Title) -ForegroundColor Cyan -NoNewline
    if ($Hint) { Write-Ui ('  ' + $g.Dash + ' ' + $Hint) -ForegroundColor DarkGray }
    else       { Write-Ui '' }
    # -2, not -4: the rule is indented by 2 and must still end flush with the
    # right edge of the title panel, which starts at column 0.
    Write-Ui ('  ' + ($g.Rule * ((Get-UiFrameWidth) - 2))) -ForegroundColor DarkCyan
}

function Write-UiStateRow {
    # One axis or option: name, its live state, and what that state means in
    # words. Used by both the state block and the options block so the two
    # cannot drift apart.
    param([string]$Axis, [string]$State, [string]$Prefix = '    ')
    $g = $script:Glyph
    # Prefix AND title padded as one field, so an option row carrying a '[G] '
    # key still lines its state column up with the axis rows above it.
    Write-Ui ('{0,-20}' -f ($Prefix + $AxisInfo[$Axis].Title)) -NoNewline
    Write-Ui ('{0,-9}' -f $State) -ForegroundColor (Get-StateColour $Axis $State) -NoNewline
    Write-Ui ($g.Dot + '  ' + (Get-StateLabel $Axis $State)) -ForegroundColor DarkGray
}

function Show-State {
    $now   = Get-AllAxisStates
    $match = Get-PresetMatch -Now $now
    $w     = Get-UiFrameWidth
    $script:UiPresetMatch = $match     # Show-Presets marks the same row

    if ($match) {
        $n     = [array]::IndexOf(@($Presets.Keys), $match) + 1
        $right = 'matches preset [{0}]  {1}' -f $n, $Presets[$match].Title
        $col   = 'Green'
    } else {
        $right = 'custom combination - matches no preset'
        $col   = 'Yellow'
    }

    Write-Ui ''
    Write-UiPanel -Left "RENDER PATH v$ScriptVersion" -Right $right -RightColour $col

    Write-UiSection 'YOUR SYSTEM RIGHT NOW' 'what is live in the registry, read just now'
    foreach ($a in $AllAxes) { Write-UiStateRow -Axis $a -State $now[$a] }

    $unknown = @(Get-UnknownDwmValues)
    if ($unknown.Count -gt 0) {
        Write-Ui ''
        Write-Ui "    note: $($unknown.Count) DWM value(s) present that this tool does not manage:" -ForegroundColor Yellow
        foreach ($l in (Split-UiText ($unknown -join ', ') ($w - 10))) {
            Write-Ui ("          " + $l) -ForegroundColor DarkGray
        }
        Write-Ui '          they are left untouched by every state above.' -ForegroundColor DarkGray
    }
    Show-ExpectedMode -Now $now -Interactive:$script:UiScreen
}

function Show-Detail {
    $rows = foreach ($e in $Entries) {
        $o = [ordered]@{
            Axis    = $e.Axis
            Name    = $(if ($e.Kind -in 'Token', 'Flag') { "$($e.Name)\$($e.Token)" } else { $e.Name })
            Current = Format-Target (Get-EntryCurrent -Entry $e)
        }
        foreach ($s in $AxisInfo[$e.Axis].States) { $o[$s] = Format-Target $e.States[$s] }
        [pscustomobject]$o
    }
    # One section per axis, headed and indented like every other block, so the
    # detail view stops being the one place that ignores the layout. The table
    # itself comes from Format-Table and is indented on the way into the buffer.
    foreach ($a in ($AllAxes + $AllOptions)) {
        $tag = if ($AllOptions -contains $a) { 'option' } else { 'axis' }
        Write-UiSection $AxisInfo[$a].Long.ToUpper() $tag
        foreach ($l in (Split-UiText $AxisInfo[$a].Blurb ((Get-UiFrameWidth) - 8))) {
            Write-Ui "    $l" -ForegroundColor DarkGray
        }
        Write-Ui ''
        @($rows | Where-Object { $_.Axis -eq $a }) |
            Select-Object * -ExcludeProperty Axis |
            Format-Table -AutoSize | Out-String -Width ((Get-UiTableWidth) - 4) |
            Write-UiBlock -Indent 4
    }
}

function Show-Presets {
    # The marker is the link between the two blocks: it says "the state above IS
    # this row", which is the thing a first-time reader has no way to guess.
    param([switch]$Interactive)
    $g    = $script:Glyph
    $hint = if ($Interactive) { 'press a number to apply one' }
            else              { 'named combinations of the four axes above' }
    Write-UiSection 'PRESETS' $hint
    foreach ($r in (Get-PresetRows)) {
        $is = ($script:UiPresetMatch -eq $r.Key)
        if ($is) { Write-Ui ('  ' + $g.Mark + ' ') -ForegroundColor Green -NoNewline }
        else     { Write-Ui '    ' -NoNewline }
        Write-Ui $r.Head -ForegroundColor $(if ($is) { 'Green' } else { 'Cyan' }) -NoNewline
        Write-Ui $r.Axes -ForegroundColor DarkGray
    }
}

function Show-Options {
    # Options are not axes. They are written by the same machinery, but no
    # preset sets them, so applying a preset never silently changes one back.
    param([switch]$Interactive)
    $hint = if ($Interactive) { 'independent switches - no preset ever touches these' }
            else              { 'independent switches, outside every preset' }
    Write-UiSection 'OPTIONS' $hint
    foreach ($o in $AllOptions) {
        $prefix = if ($Interactive) { '    [{0}] ' -f $OptionKeys[$o] } else { '    ' }
        Write-UiStateRow -Axis $o -State (Get-AxisState $o) -Prefix $prefix
    }
}

# ===========================================================================
# MENU
# ===========================================================================

function Invoke-Menu {
    # From here on the tool owns the terminal: every frame is drawn centred on a
    # cleared screen, so nothing above it stays visible.
    $script:UiScreen = $true

    $rebootPending = $false
    $dead          = 0
    $notice        = ''
    $noticeColour  = 'DarkGray'
    $axisKeys      = @{ m = 'Mpo'; d = 'Dwm'; f = 'Fso'; w = 'WindowedOpt' }
    # $OptionKeys is option -> key; the menu needs the reverse, lower-cased.
    $optionKeys2   = @{}
    foreach ($o in $AllOptions) { $optionKeys2[$OptionKeys[$o].ToLower()] = $o }

    while ($true) {
        Show-State
        Show-Presets -Interactive
        Show-Options -Interactive
        Write-UiSection 'KEYS'
        Write-Ui '    [M] MPO   [D] DWM   [F] FSO   [W] WINDOWEDOPT   - CYCLE ONE AXIS'
        Write-Ui '    [T] DETAIL TABLE   [B] BACKUP NOW   [K] RESTART DWM NOW   [Q] QUIT'
        Write-Ui ('    [O] OPEN BACKUP FOLDER   [X] PRUNE BACKUPS (KEEP {0} NEWEST)' -f $BackupKeep)
        Write-Ui '    [P] PER-GAME FSO (ONE EXE)   [V] MEASURE PRESENT MODE (PRESENTMON)'
        if (-not (Test-Admin)) {
            Write-Ui '    NOT ELEVATED - Mpo / Dwm / Fso / Game DVR cannot be written.' -ForegroundColor Red
        }
        if ($rebootPending) {
            Write-Ui ''
            Write-Ui '    ! reboot still pending for the DWM/MPO changes' -ForegroundColor Yellow
        }
        # One-line results (bad key, backup path) ride along in the next frame
        # instead of being printed and then wiped by the redraw.
        if ($notice) {
            Write-Ui ''
            Write-Ui "    $notice" -ForegroundColor $noticeColour
        }
        $notice       = ''
        $noticeColour = 'DarkGray'

        $raw = Read-Ui '  choose: '
        if ([string]::IsNullOrWhiteSpace($raw)) {
            $dead++
            if ($dead -lt 3) { continue }
            Close-Screen -Message 'No input - leaving.' -Colour 'Yellow'
            return
        }
        $dead = 0
        $c = $raw.Trim()
        $touched = @()

        if ($c -match '^[1-9]$') {
            $idx = [int]$c - 1
            $names = @($Presets.Keys)
            if ($idx -lt $names.Count) {
                $touched = @(Invoke-SetAxes -Wanted $Presets[$names[$idx]].Set)
            } else { $notice = 'no preset with that number' }
        }
        elseif ($optionKeys2.ContainsKey($c.ToLower())) {
            # Options cycle exactly like an axis - same states, same writer -
            # they are just kept out of every preset.
            $opt    = $optionKeys2[$c.ToLower()]
            $states = $AxisInfo[$opt].States
            $cur    = Get-AxisState $opt
            $next = if ($cur -eq 'MIXED') { $states[0] }
                    else { $states[([array]::IndexOf($states, $cur) + 1) % $states.Count] }
            $touched = @(Invoke-SetAxes -Wanted @{ $opt = $next })
        }
        elseif ($axisKeys.ContainsKey($c.ToLower())) {
            $axis   = $axisKeys[$c.ToLower()]
            $states = $AxisInfo[$axis].States
            $cur    = Get-AxisState $axis
            # cycle to the next state; from MIXED, go to the first (stock) state
            $next = if ($cur -eq 'MIXED') { $states[0] }
                    else { $states[([array]::IndexOf($states, $cur) + 1) % $states.Count] }
            if ($axis -eq 'WindowedOpt' -and $next -eq 'Off') {
                Write-Ui ''
                Write-Ui '  Note: turning this off stops windowed/borderless games being upgraded' -ForegroundColor Yellow
                Write-Ui '  to the flip model, which usually LOSES independent flip in borderless.' -ForegroundColor Yellow
            }
            $touched = @(Invoke-SetAxes -Wanted @{ $axis = $next })
        }
        elseif ($c -match '^[Pp]$') {
            $exe = Resolve-GameExe (Read-Ui '  full path to the game .exe: ')
            if ($exe) {
                $entry = New-GameEntry -Exe $exe
                $next  = if (Get-EntryCurrent -Entry $entry) { 'On' } else { 'Off' }
                $touched = @(Invoke-SetAxes -Wanted @{ GameFso = $next } -Pool @($entry))
            }
        }
        elseif ($c -match '^[Vv]$') {
            $proc = Read-Ui '  process name to capture (e.g. game.exe): '
            if (-not [string]::IsNullOrWhiteSpace($proc)) { Invoke-Measure -Process $proc.Trim() -For $Seconds }
        }
        elseif ($c -match '^[Tt]$') { Show-Detail }
        elseif ($c -match '^[Bb]$') {
            $dir = New-Backup -Label 'manual'
            if ($dir) { $notice = "backup written to $dir"; $noticeColour = 'Green' }
        }
        elseif ($c -match '^[Oo]$') {
            $notice = Open-BackupFolder
            $noticeColour = if ($notice -like 'opened *') { 'Green' } else { 'Yellow' }
        }
        elseif ($c -match '^[Xx]$') { Invoke-PruneBackups -Keep $BackupKeep }
        elseif ($c -match '^[Kk]$') {
            # A successful kill applies the pending DWM/MPO values - the new
            # dwm.exe reads them at start - so the reboot reminder can go.
            if (Restart-Dwm) { $rebootPending = $false }
        }
        elseif ($c -match '^[Qq]$') {
            $msg = if ($rebootPending) { 'Remember: the DWM/MPO changes need a reboot.' } else { '' }
            Close-Screen -Message $msg -Colour 'Yellow'
            return
        }
        else { $notice = "'$c' is not one of the choices" }

        if ($touched.Count -gt 0) {
            Show-Aftermath -Touched $touched
            if (($touched -contains 'Mpo') -or ($touched -contains 'Dwm')) { $rebootPending = $true }
        }
        # Whatever the action put in the buffer is a screen of its own; without
        # the pause the next redraw would clear it before it could be read.
        if (Test-UiPending) { [void](Read-Ui '  press Enter ') }
    }
}

# ===========================================================================
# ENTRY POINT
#
# Exit codes: 0 = success or nothing to do, 1 = a change / backup was refused
# or failed (non-interactive paths only - the menu reports failures on screen
# and always exits 0), 2 = the environment cannot run this script safely.
# ===========================================================================

$script:ApplyFailed = $false

$wanted = @{}
if ($Preset)      { foreach ($k in $Presets[$Preset].Set.Keys) { $wanted[$k] = $Presets[$Preset].Set[$k] } }
if ($Mpo)         { $wanted['Mpo']         = $Mpo }
if ($Dwm)         { $wanted['Dwm']         = $Dwm }
if ($Fso)         { $wanted['Fso']         = $Fso }
if ($WindowedOpt) { $wanted['WindowedOpt'] = $WindowedOpt }
# An option, so -Preset never sets it: naming both on one command line is
# allowed and means exactly what it says.
if ($GameDvr)     { $wanted['GameDvr']     = $GameDvr }

if ($GameFso -and -not $Game) {
    Write-Ui '  -GameFso needs -Game <full path to the exe>.' -ForegroundColor Red
    Show-Ui
    exit 1
}
if ($Measure) {
    Invoke-Measure -Process $Measure -For $Seconds
    Write-Ui ''
    Show-Ui
    return
}

if ($wanted.Count -gt 0 -or $Game) {
    Show-State
    $touched = @()
    if ($wanted.Count -gt 0) { $touched = @(Invoke-SetAxes -Wanted $wanted -AssumeYes) }
    if ($Game) {
        $exe = Resolve-GameExe $Game
        if (-not $exe) { $script:ApplyFailed = $true }
        elseif ($GameFso) {
            $touched += @(Invoke-SetAxes -Wanted @{ GameFso = $GameFso } -Pool @(New-GameEntry -Exe $exe) -AssumeYes)
        } else {
            $cur = if (Get-EntryCurrent -Entry (New-GameEntry -Exe $exe)) { 'Off' } else { 'On' }
            Write-Ui ''
            Write-Ui ("  {0}  Game FSO = {1}" -f $exe, $cur) -ForegroundColor Cyan
        }
    }
    Show-Aftermath -Touched $touched
    if ($RestartDwm) { [void](Restart-Dwm) }
    Write-Ui ''
    Show-Ui
    if ($script:ApplyFailed) { exit 1 }
    return
}

# -RestartDwm with no axis change: do just that, not the menu. The typed
# KILLDWM confirmation still gates it.
if ($RestartDwm) {
    [void](Restart-Dwm)
    Write-Ui ''
    Show-Ui
    return
}

switch ($Mode) {
    'Status' {
        Show-State
        Show-Options
        Show-Detail
        Show-Presets
        Write-Ui ''
        Write-Ui '  Nothing changed. Run with no arguments for the menu.' -ForegroundColor DarkGray
        Write-Ui ''
    }
    'Backup' {
        $dir = New-Backup -Label 'manual'
        if ($dir) { Write-Ui "  Backup written to: $dir" -ForegroundColor Green }
        else      { Write-Ui '  No backup was written.' -ForegroundColor Red; $script:ApplyFailed = $true }
        Write-Ui ''
    }
    default { Invoke-Menu }
}

# Invoke-Menu prints its own frames; this is for Status / Backup.
Show-Ui
if ($script:ApplyFailed -and $Mode -ne 'Menu') { exit 1 }
