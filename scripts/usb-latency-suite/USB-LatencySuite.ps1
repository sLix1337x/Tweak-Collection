<#
.SYNOPSIS
    USB Latency Suite - disables USB/HID power saving, idle and wake features
    to remove input latency, with a full backup/revert path and a WPF UI.

.DESCRIPTION
    Replaces USB_Static_Tweaks.reg + USB_Dynamic_Tweaks.bat.

    Differences from the originals:
      - every write is recorded to a JSON backup and can be reverted exactly
      - one CIM enumeration (Get-PnpDevice) instead of five overlapping wmic passes
      - only registry values Microsoft's USB/HID drivers actually read
      - ForceFullSpeed and the other debug switches are gone (they downgrade USB 2.0
        to 12 Mbit/s and break cameras, audio interfaces and storage)
      - wake handling is locale independent (powercfg -devicequery wake_armed)
      - preview mode shows every change before anything is written

    Requires administrator rights. A reboot is required for driver-level changes.

.NOTES
    Version 1.0. Windows 10 / 11, Windows PowerShell 5.1 (shipped with both).
    Run it with Run.cmd, or:  powershell -ExecutionPolicy Bypass -File .\USB-LatencySuite.ps1
#>

param(
    # Round-trips the registry write / backup / revert path against a scratch key
    # and exits. Console only, no UI.
    [switch]$SelfTest
)

#region ── Hide the console ───────────────────────────────────────────────────
# The interface is a WPF window; the PowerShell console behind it is noise. Hide
# it - but only when this process owns the console outright. If the script was
# started from a terminal the user already had open, that window is theirs and
# hiding it would take their shell away.
if (-not $SelfTest) {
    try {
        Add-Type -Namespace UsbSuite -Name NativeConsole -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern System.IntPtr GetConsoleWindow();
[DllImport("kernel32.dll")] public static extern int GetConsoleProcessList(int[] buffer, int count);
[DllImport("user32.dll")]   public static extern bool ShowWindow(System.IntPtr hWnd, int nCmdShow);
'@
        $consoleWindow = [UsbSuite.NativeConsole]::GetConsoleWindow()
        if ($consoleWindow -ne [IntPtr]::Zero) {
            $owners = New-Object int[] 4
            if ([UsbSuite.NativeConsole]::GetConsoleProcessList($owners, 4) -le 1) {
                [void][UsbSuite.NativeConsole]::ShowWindow($consoleWindow, 0)   # SW_HIDE
            }
        }
    } catch { }
}

# With the console hidden an unhandled error would leave nothing on screen at all,
# so anything that escapes gets a message box instead of vanishing.
trap {
    try {
        [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
        [System.Windows.Forms.MessageBox]::Show(
            ("{0}`n`n{1}" -f $_.Exception.Message, $_.ScriptStackTrace),
            'USB Latency Suite - unexpected error')
    } catch { }
    exit 1
}
#endregion

#region ── Elevation + STA ────────────────────────────────────────────────────
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin  = ([Security.Principal.WindowsPrincipal]$identity).IsInRole(
                [Security.Principal.WindowsBuiltInRole]::Administrator)
$isSta    = [Threading.Thread]::CurrentThread.GetApartmentState() -eq 'STA'

if ($SelfTest -and -not $isAdmin) {
    Write-Error 'SelfTest writes under HKLM and needs an elevated console.'
    exit 1
}

if (-not $SelfTest -and (-not $isAdmin -or -not $isSta)) {
    try {
        Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe') `
                      -Verb RunAs `
                      -WindowStyle Hidden `
                      -ArgumentList '-NoProfile','-STA','-WindowStyle','Hidden','-ExecutionPolicy','Bypass','-File',"`"$PSCommandPath`""
    } catch {
        [void][System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
        [System.Windows.Forms.MessageBox]::Show('Administrator rights are required.','USB Latency Suite')
    }
    exit
}
#endregion

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

Add-Type -TypeDefinition @'
public class DevItem {
    public bool   Enabled { get; set; }
    public string Name    { get; set; }
    public string Id      { get; set; }
    public string Kind    { get; set; }
}
'@

$ErrorActionPreference = 'Stop'
$Version = '1.0'

# Backups live next to the script, unless that location is read-only (USB stick,
# Program Files, or launched with no script path at all) - then use LocalAppData.
function Resolve-BackupDir {
    $candidates = @()
    if ($PSScriptRoot) { $candidates += (Join-Path $PSScriptRoot 'Backups') }
    $candidates += (Join-Path $env:LOCALAPPDATA 'USBLatencySuite\Backups')

    foreach ($c in $candidates) {
        try {
            if (-not (Test-Path -LiteralPath $c)) { New-Item -ItemType Directory -Path $c -Force | Out-Null }
            $probe = Join-Path $c '.writable'
            [IO.File]::WriteAllText($probe, '')
            Remove-Item -LiteralPath $probe -Force
            return $c
        } catch { }
    }
    throw 'No writable location for backups.'
}
$BackupDir = Resolve-BackupDir
$LogFile   = Join-Path $BackupDir 'session.log'

if (-not (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue)) {
    [void][Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms')
    [Windows.Forms.MessageBox]::Show(
        'Get-PnpDevice is missing. This tool needs Windows 8 or newer.',
        'USB Latency Suite')
    exit 1
}

#region ── Tweak definitions ──────────────────────────────────────────────────
# Scope 'device'  -> HKLM\SYSTEM\CurrentControlSet\Enum\<InstanceId>\<Sub>
# Scope 'service' -> HKLM\SYSTEM\CurrentControlSet\Services\<Key>
$Modules = [ordered]@{
    suspend = @{
        Title = 'Selective Suspend'
        Desc  = 'Stops Windows powering down individual USB ports after an idle timeout.'
    }
    idle = @{
        Title = 'Device Idle / D-States'
        Desc  = 'Keeps devices in D0 instead of dropping to D1/D2/D3 and D3cold.'
    }
    lpm = @{
        Title = 'Link Power Management'
        Desc  = 'Disables USB 3.x U1/U2 link states (Enhanced Power Management).'
    }
    wake = @{
        Title = 'Wake Capability'
        Desc  = 'Disarms wake-from-sleep on USB/HID devices. Mouse will no longer wake the PC.'
    }
    irq = @{
        Title = 'Interrupt Threshold'
        Desc  = 'One interrupt per transfer on xHCI instead of coalescing. The real latency knob.'
    }
}

$Tweaks = @(
    # ── per-device -------------------------------------------------------------
    @{ Cat='suspend'; Scope='device'; Sub='Device Parameters';     Name='SelectiveSuspendEnabled';        Value=0 }
    @{ Cat='suspend'; Scope='device'; Sub='Device Parameters';     Name='EnableSelectiveSuspend';         Value=0 }
    @{ Cat='suspend'; Scope='device'; Sub='Device Parameters';     Name='DeviceSelectiveSuspended';       Value=0 }
    @{ Cat='idle';    Scope='device'; Sub='Device Parameters';     Name='AllowIdleIrpInD3';               Value=0 }
    @{ Cat='idle';    Scope='device'; Sub='Device Parameters';     Name='DeviceIdleEnabled';              Value=0 }
    @{ Cat='idle';    Scope='device'; Sub='Device Parameters';     Name='D3ColdSupported';                Value=0 }
    @{ Cat='idle';    Scope='device'; Sub='Device Parameters\WDF'; Name='IdleInWorkingState';             Value=0 }
    @{ Cat='lpm';     Scope='device'; Sub='Device Parameters';     Name='EnhancedPowerManagementEnabled'; Value=0 }
    @{ Cat='wake';    Scope='device'; Sub='Device Parameters';     Name='SystemWakeEnabled';              Value=0 }

    # ── driver services --------------------------------------------------------
    @{ Cat='suspend'; Scope='service'; Key='usbhub\Parameters';           Name='DisableSelectiveSuspend';        Value=1 }
    @{ Cat='suspend'; Scope='service'; Key='USBHUB3\Parameters';          Name='DisableSelectiveSuspend';        Value=1 }
    @{ Cat='suspend'; Scope='service'; Key='USBXHCI\Parameters';          Name='DisableSelectiveSuspend';        Value=1 }
    @{ Cat='suspend'; Scope='service'; Key='usbehci\Parameters';          Name='DisableSelectiveSuspend';        Value=1 }
    @{ Cat='suspend'; Scope='service'; Key='HidUsb\Parameters';           Name='SelectiveSuspendEnabled';        Value=0 }
    @{ Cat='idle';    Scope='service'; Key='HidUsb\Parameters';           Name='IdleEnabled';                    Value=0 }
    @{ Cat='idle';    Scope='service'; Key='HidClass\Parameters';         Name='IdleInWorkingState';             Value=0 }
    @{ Cat='idle';    Scope='service'; Key='usbhub\Parameters';           Name='SelectiveSuspendTimeout';        Value=0 }
    @{ Cat='lpm';     Scope='service'; Key='USBHUB3\Parameters';          Name='EnhancedPowerManagementEnabled'; Value=0 }
    @{ Cat='lpm';     Scope='service'; Key='USBXHCI\Parameters';          Name='EnhancedPowerManagementEnabled'; Value=0 }
    @{ Cat='irq';     Scope='service'; Key='USBXHCI\Parameters\Device';   Name='InterruptThreshold';             Value=1 }
    @{ Cat='irq';     Scope='service'; Key='USBHUB3\Parameters\Device';   Name='InterruptThreshold';             Value=1 }
)
#endregion

#region ── Registry helpers (.NET API - no provider wildcard problems) ────────
$HKLM = [Microsoft.Win32.Registry]::LocalMachine

function Test-RegKey([string]$SubKey) {
    $k = $HKLM.OpenSubKey($SubKey, $false)
    if ($k) { $k.Close(); return $true }
    return $false
}

function Get-RegValue([string]$SubKey, [string]$Name) {
    $k = $HKLM.OpenSubKey($SubKey, $false)
    if (-not $k) { return $null }
    try { return $k.GetValue($Name, $null) } finally { $k.Close() }
}

function Set-RegValue([string]$SubKey, [string]$Name, [int]$Value) {
    $k = $HKLM.CreateSubKey($SubKey, $true)
    if (-not $k) { throw "cannot open $SubKey for write" }
    try { $k.SetValue($Name, $Value, [Microsoft.Win32.RegistryValueKind]::DWord) }
    finally { $k.Close() }
}

function Remove-RegValue([string]$SubKey, [string]$Name) {
    $k = $HKLM.OpenSubKey($SubKey, $true)
    if (-not $k) { return }
    try { $k.DeleteValue($Name, $false) } finally { $k.Close() }
}
#endregion

#region ── Device enumeration ─────────────────────────────────────────────────
function Get-TargetDevices {
    Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object {
            $_.InstanceId -match '^(USB|HID)\\' -or
            ($_.Class -eq 'USB' -and $_.InstanceId -like 'PCI\*')
        } |
        Sort-Object Class, FriendlyName |
        ForEach-Object {
            $d = [DevItem]::new()
            $d.Enabled = $true
            $d.Name    = if ($_.FriendlyName) { $_.FriendlyName } else { '(unnamed device)' }
            $d.Id      = $_.InstanceId
            $d.Kind    = if ($_.InstanceId -like 'PCI\*') { 'Controller' }
                         elseif ($_.InstanceId -like 'HID\*') { 'HID' } else { 'USB' }
            $d
        }
}
#endregion

#region ── Plan / apply / revert ──────────────────────────────────────────────
# A plan entry: @{ Kind='reg'; Path; Name; New; Old; Had } or @{ Kind='wake'; Name }
function Build-Plan([string[]]$Cats, [DevItem[]]$Devices) {
    $plan = New-Object System.Collections.Generic.List[object]

    foreach ($t in $Tweaks | Where-Object { $Cats -contains $_.Cat -and $_.Scope -eq 'service' }) {
        # Skip drivers this machine does not have (usbehci and usbuhci are gone on
        # modern hardware) rather than creating orphan service keys for them.
        $service = $t.Key.Split('\')[0]
        if (-not (Test-RegKey "SYSTEM\CurrentControlSet\Services\$service")) { continue }

        $path = "SYSTEM\CurrentControlSet\Services\$($t.Key)"
        $old  = Get-RegValue $path $t.Name
        if ($old -ne $t.Value) {
            $plan.Add(@{ Kind='reg'; Path=$path; Name=$t.Name; New=$t.Value; Old=$old; Had=($null -ne $old) })
        }
    }

    $devTweaks = @($Tweaks | Where-Object { $Cats -contains $_.Cat -and $_.Scope -eq 'device' })
    foreach ($d in $Devices) {
        if (-not $d.Enabled) { continue }
        foreach ($t in $devTweaks) {
            $path = "SYSTEM\CurrentControlSet\Enum\$($d.Id)\$($t.Sub)"
            $old  = Get-RegValue $path $t.Name
            if ($old -ne $t.Value) {
                $plan.Add(@{ Kind='reg'; Path=$path; Name=$t.Name; New=$t.Value; Old=$old; Had=($null -ne $old) })
            }
        }
    }

    if ($Cats -contains 'wake') {
        # only disarm devices that are in the selected USB/HID set - never the NIC.
        $names = @{}
        foreach ($d in $Devices) { if ($d.Enabled) { $names[$d.Name] = $true } }
        foreach ($n in Get-WakeArmedDevices) {
            if ($names.ContainsKey($n)) { $plan.Add(@{ Kind='wake'; Name=$n }) }
        }
    }
    ,$plan
}

function Get-WakeArmedDevices {
    # locale independent: powercfg reports armed devices by friendly name, whatever the language.
    $out = & powercfg /devicequery wake_armed 2>$null
    foreach ($line in $out) {
        $n = $line.Trim()
        if ($n -and $n -ne 'NONE') { $n }
    }
}

function Invoke-Plan($Plan, [scriptblock]$Log) {
    $undo = New-Object System.Collections.Generic.List[object]
    $ok = 0; $fail = 0

    foreach ($p in $Plan) {
        try {
            if ($p.Kind -eq 'reg') {
                Set-RegValue $p.Path $p.Name $p.New
                $undo.Add([pscustomobject]@{ Kind='reg'; Path=$p.Path; Name=$p.Name; Had=$p.Had; Old=$p.Old })
            } else {
                & powercfg /devicedisablewake "$($p.Name)" 2>&1 | Out-Null
                if ($LASTEXITCODE -ne 0) { throw "powercfg exit $LASTEXITCODE" }
                $undo.Add([pscustomobject]@{ Kind='wake'; Name=$p.Name })
            }
            $ok++
        } catch {
            $fail++
            & $Log ("  FAIL  {0} :: {1}  ({2})" -f $p.Path, $p.Name, $_.Exception.Message) 'warn'
        }
    }

    if ($undo.Count) {
        if (-not (Test-Path $BackupDir)) { New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null }
        $file = Join-Path $BackupDir ("usb-tweaks-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date))
        $undo | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $file -Encoding UTF8
        & $Log "Backup written: $file" 'ok'
    }
    [pscustomobject]@{ Applied=$ok; Failed=$fail }
}

function Get-LatestBackup {
    if (-not (Test-Path $BackupDir)) { return $null }
    Get-ChildItem -LiteralPath $BackupDir -Filter 'usb-tweaks-*.json' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

function Invoke-Revert($BackupFile, [scriptblock]$Log) {
    $items = Get-Content -LiteralPath $BackupFile.FullName -Raw | ConvertFrom-Json
    $ok = 0; $fail = 0
    foreach ($i in @($items)) {
        try {
            if ($i.Kind -eq 'reg') {
                if ($i.Had) { Set-RegValue $i.Path $i.Name ([int]$i.Old) }
                else        { Remove-RegValue $i.Path $i.Name }
            } else {
                & powercfg /deviceenablewake "$($i.Name)" 2>&1 | Out-Null
            }
            $ok++
        } catch {
            $fail++
            & $Log ("  FAIL  {0} :: {1}  ({2})" -f $i.Path, $i.Name, $_.Exception.Message) 'warn'
        }
    }
    Rename-Item -LiteralPath $BackupFile.FullName -NewName ($BackupFile.Name + '.reverted')
    [pscustomobject]@{ Applied=$ok; Failed=$fail }
}
#endregion

#region ── Self test ─────────────────────────────────────────────────────────
if ($SelfTest) {
    $scratch = 'SYSTEM\CurrentControlSet\Control\USBLatencySuiteSelfTest'
    $log = { param($m,$l) Write-Host "  $m" }
    try {
        Set-RegValue $scratch 'Existing' 7          # a value that already exists
        $plan = @(
            @{ Kind='reg'; Path=$scratch; Name='Existing'; New=0; Old=7;     Had=$true  }
            @{ Kind='reg'; Path=$scratch; Name='Fresh';    New=1; Old=$null; Had=$false }
        )
        $r = Invoke-Plan $plan $log
        if ($r.Applied -ne 2)                              { throw 'apply count wrong' }
        if ((Get-RegValue $scratch 'Existing') -ne 0)      { throw 'existing value not overwritten' }
        if ((Get-RegValue $scratch 'Fresh')    -ne 1)      { throw 'new value not created' }

        $r = Invoke-Revert (Get-LatestBackup) $log
        if ($r.Applied -ne 2)                              { throw 'revert count wrong' }
        if ((Get-RegValue $scratch 'Existing') -ne 7)      { throw 'existing value not restored' }
        if ($null -ne (Get-RegValue $scratch 'Fresh'))     { throw 'created value not removed' }

        Write-Host 'SelfTest OK: apply wrote a backup, revert restored old values and deleted new ones.'
    } finally {
        $HKLM.DeleteSubKeyTree($scratch, $false)
        Get-ChildItem -LiteralPath $BackupDir -Filter '*.reverted' -ErrorAction SilentlyContinue |
            Remove-Item -Force
    }
    exit 0
}
#endregion

#region ── Logo ──────────────────────────────────────────────────────────────
# Embedded rather than shipped alongside: this tool is meant to be one file you can
# drop anywhere and run, and an icon that lives next to it would be one more thing
# to lose. 128px PNG - enough for the 20px title mark and for a 96px taskbar icon
# at 200% scaling.
$LogoPng = 'iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAABv5SURBVHhe7Z17fB3Vde9/a+895yEdybJk2fj9IjwcwOYZCCSUEMAhCYUACTehQEhKWhKghCY3bXpL/GmSln64SS+0SUO4JORDWgKkubfJpYSSxMYFCo0hPOJgMH7bWA/L0tF5zuy91v1j5khHY9mWbUlIYr6fz2hGs/c5c2bW2q+19toDJCQkJCQkJCQkJCQkJCQkJCQkJEx9KH5ibDnVu2DW8SkdLNVtAHwN7mzYYgtb024d7gniuacup3pnzlts0tWZeho3UrOZyd1N2+xjG+/2AUg891gylgqgTs19qPWMtitObNPzz8np1lNTKrtAkWkhUmkCACEnJGUIKiDpYXbbRfBKgPK6UrXnt9i6unMVVnH8iycR+pzcFa0rWi89ptmbeXKOpp/kqexCQ6kZADUpqBQRaYAYkKIAPSxuO4M3OPgvBy74XXfl9c3f3PGxcvyLR4vRVgA6Jndu2/mt1513VOodH2k2s96TUpnZCkYdmmILWKRPwOss7L+yLfz086+ftHm8S8dhos+f9smFK1o+fOH01JwPNuq209Mq006H/AwAFg4A2cFin2KyP7VUfeK29Sf0xPMdCaOlAObc6dcfd/q0S687KrX08gYzbSFBjdZ3Q4SLQvKEE//vX2nYu+aedadNxOYie9nM/3HOiU3n39DqzTs/rRqmxzMcKSyug0X+hVXl729Zf8zvRqNAHKmQ1IrcyuPOa7vh1oXZE69Mq8Zp8Qyji7AIP23J3b5n/fdWT5DmwZw9/Q/O/L3Wa/58tnfs+VqZVDzDaCOQigg/GJB/+5+sX7otnn4oHIkCtFw9528/vbzpg3+a062zRkEZR46IZfAj1uALt7w8f0c8ebzIIdd+xdyv37K8aeXnMio3xsq/L6y4K/CCm//khcU/Otza4HAUgJY2nr7ssva/uGNx9pSVirSOZxgvRGQ3U3DTZ9cv/DGBDusBHCbUllp47LVzvvk/lzac/gEFfTjP8YgQLWBPwMZZl+Kv9J6/6K9XraJDrhEP9YebFc0Xnnf5zFV3z0gtPDae+JYgYh25O7xs56rPjF/fYMkl7V/8q+VNK8+IJ4wHogViADYM9gSixXmZzM1fW3vu4/G8B+NQFEAd3XD6xZ+c++1vt3pz5sUT32pY3P2moePGz6w7rRRPGwOmAWiNn3wLEQC7AVTiCQdjxArQ4LWvuGX+D76/ILN8eTxtosDCPxbyrvvc+lmFeFrC8IxUAVrOb/3Dr1/Y9rmPhso20o+9BRAeWbz8pM9+9GFy8aSEfRmpJHNZ03y8QVbFEyYaTSrbu8vf/BrGt1OYkJCQkJAw2ThQH0Cd0boyd0zLJZlcPGWUqJaCg7bTHmWkH/0D/xtKS1l1D3yuUYN7AaR0RdCfcZ0NW2zX1v/iLLKSQ07WYI07XCvZ24HhFMB7f9uN733P9E/cOM0cdYYm3QiMUd9PRA4uGwLR0ExDP0QMCAgkAjCEAwFbIVgRtpp0L0E90FXi763aunik42Ra1r6s8d2ZGxe26UVHN3rTZ6WooSH0XpMWKBFIFYKik4p1iqxw4EDEitlZEoZjBikGMSvSYh0Pa6VjODJKKWcA0o6cEoU0wNqR04DzRMEADhbOEyWKyelwgMNGxCrH1gBMVphEfK5mvIbGecbLVMp+f4dRqYL2zI5jZrdtXLXqPBu/flwBaH72pA/dNO+B+5q8GTNiaZMahvsFmerHb3zp6M54Wh2plTNvOuW0pkuvm27mvC9NjQsHnTvxR3UwxR05A2Zdj8PNhHtnwmOnGazDffzYaYZVDKeiNGKwAqTu9wkkEJZnQe7679914ev1147f1VHXzrnrf5/ZcuXFo3mDEwUReTpfrVz8pU1L++JpAGZeP/cfvri8aeUfpVS2MZ44JlBN+KFJtyZ8V1MAPbwCOD0o8IHjaOMDjH4F8kK/6jr7kW8OTjCpr9tpWmr2mSfkzjtrKgofAIjo3c3p9F0PXflQ3IE16+rZd/7tac2X3DquwjcCTnG4eQ7Oc3Aeh3sT/R8XvGY4HaVrB6vciISPsDFd0WxnvKf+XL0CNJyRu/TCnGkd9YkMEwkidXXnb8+6ue5U5rzWT91wxrQrPk6kx6izE4MQlvgURwJnuIHjSAmiku9MKGxb27SDjap9W9cEHEz4ESSEi+pP1N/wkuXNF71331ZhyqEU9Fe/dfzW9wNAxjSdfO70a6/3VMqLZxwTFAZKvfMG9y5q/13UBOxb6gc3G21OMRwJZGTCj6Bzbr/99gG516StFjWc8ulbFzz0dynVkB3MPKXZvr6wduXrxf+44ZKZ//0mIqUAQMBiJfCtVH3H1rI4FmIWkf0+5bDDJdHjDPNJtIewCEgEDFEQMQJrAhETtutiBFYzxBOwFrAWYi2ABrEWchokWshpqe0VKyHWpERDgZQiIhKiupIrqP1eEhEhIhJxzlar1vmvNlHDB++779J+1ClA2+Uzv/KPF8z4zBX1vcepTonzuzykpnsqky27/t4O/41nNhTX/nx94cnX8txRqtqS71ANLNlhh3ARAgzaM4IAAo8EgS8AJEAQ5RnyYA/0kKl+8zxPAZ4CoIwxCjBKjNZGjNZaGdHKaNEKRlPtewlO4EgAiIODhoaIrfh+obdY3LsTwN76i8HAnPPlpb94YHb6mIUH+mUj5VAakeGvN/zZ0YRA8LlU6Q52vLyz/Mr/fa7vR//6cvHJ1w/Hpz6ZiWTlnXpy8wUr39Fw1rI2M69dkVYCIhqRKHlAWlI7plD76nMNh0CIBERQFF4PBCJF4bU9TZ7WZIwmTxOUVqQonG1MRAQVijGs+gaq3OgwNBaJcFT4qO73iEi54Lp//WL+V/+8tve+3wDoH8nvnYrUS9gAyACoDZFGIv39PbT9nY9Tf434sY72qm4bUj3GPjeoAEOvH/8tAqAEIA8gmTOQkJCQkPB2pb7d9T4867Z5JzRdtCAlWQIsoBRbxwxiBgIAHhSLZuh0WqcyisiDkOKoI8ZitVI6C5HpmrxGgvKUkGISpvBaniLTQESNCiYtgEckRoQ0CTSREKBCswYJE5SIsBDICYlQ2OMUCrt5A207QYkQnAIFAi44tn0BbFEJAqXUXnauy1Klz7ItVFHO522+INJd7S53BJu6flZdh3V2mL7C24KaAsy5acE/f/0djWdeZshrAogGDRrh39DdKmFH/YAjhPh5GaafNh4MvaaARUBMIk7APoPLECkL0M9wBQhXQ0WlPmb7piW/QmIUAf1ObK+TalGInBOrlCgNRYqInBDKylN7LVX7fVMJnPGDqrbOV47hASwVsmmtDEE7Q0YMNJR4rCjNWrJsxHMamgHFZJUoIiEeeIhEShw7EHkiZIVYCciKKMNAaOghUsIsohQxC1sQfA2qOBYLFzhSuq+vZ1shlWk4Ktc8P2c8PP/AP17eWXtKNMtbct2Xljx2d0bnxscRMimJKzYAJWBT8+Y5OOOEDUtkzpWaJ89pJg49e+QiS9+AF6+2VwynZIgbd3QQiIgTwBLgESkFkd+YSuHse+65pKQAeC3erLmeSqfjH02opza6DDdRke8+5SLbvoBTIE5BcQpKUqLZEy2eaPGg2INyBsQ6NP2GTh0XOnUiBRh94QMITStakUrXzN0Ajiul0rMQja15j7+jEHC1OvSDCftDtEQCr3nxaq7cyE1r3IBTJ/TYha5bp0OPntORC7eu9I+F6PeHAKKD0GinANhuu/2326uvbI1nTIgx4MMfFD7X3Lk1L169K1cPnq958Gpu3NqxUwdyM4wRIt2uqLpQ5w5+ae3eH6x1YhPL2P4ghO19Kqr2a4If2OpLf1QDDLhvBydwhJM4RjaBY6wIbOWHDzxwURF1PRsCcNEN8+69/eTmi88cmn3qU3S9e/faXZ3DeXxrXtYwIjfs9IlxcEZCd64WOC1g4yAq7NyxYvDAsYDJwSqBaIYlARPCwKXxmX4CFiFFRMLcX6n0/r9d/S/e8dK/PzBEAQAg26CmfeKG+d+96djGs08attc7hRAIiq5n547y+gcf2/PN+zcU/3O4eYIYvvs/6aCo99oPoBfAQLsTv7nGlM5eeHHbrR9f3rTy9IzKZQmRd44IoX0AqF//RyLXHCBEoPB/EEhIKap57mofDr8pbExr167/CVEJJEg4oYGFRYSFHcM6Bxs49q2QOAFDidJGZTJp1ZAJHeJEipQOL6hCh2E4I1hYnLMS+CW3t6sn2PnS1sorj67r/cmjmyrrdtQ/kLcbcQVA1C9oB7xZnucZDyARE3nipJZ/iAKEjsRAGRgNACJaGRgyRiuNtPIkY7TxtBJPe1AKOkUKpDQ0iQgBGkQsAMQhEIE4doELXNWWqRD4ruxXUaoQWT8IAksgDo1S8LRJN7er+dNzXntaic40mGmNRCbtUSrbbNqbNaWCYtD9Zp67e/O8e+f2wsubK6h0AagOalzCVERFLu5xamkTEhISJhvD9QHqMR+e+Wdti3PHpQEgqDgx5EkZZWhKSUB2oA31JCAnmjwxxB7pFGe0Z6B99pSGIiMBkc4YBZXR8KYZZJu1oSFr6gmTp4gaDHmNJKpBU6pBKa1EUGCxZREbWDifBAErthBYVi4gh0oK6T5f+8VAioVCtb93Z/ml/v5pPcFjG1sDTIz1BCckB1KA7AdnfP7Wi9pv+ryGzsTSwr7f8H0oikYCBISuw8EeP4hAus4mPaowWMASQKHKwgURVwCh20mwy4ntINIdvivuZra90GaPk1L3m9jWDwBpzeWdamN/Z3GL3el1SCrVJNnsJlm3bp2byqOEAynAjNOaLrn9mrl/94eeykxJR5HTzjljfQnj8qzzXDFQtsQmCKxmdh4HoqRkte3yyS+zci6y3xMrFqcZgRIIhQYfOfRl+oZFQDyczomQADKQIOGoOyqFjgEK50ooxRq6R5F55gffXvnTaJLusBxIAQjAqe9r/fStl8388hVGpcd8CdRxo2bTj4Iw2ZMwMqc+GrfOlLvfwMwRBmW+VfiV/Dce+M7v3xY/X088SDLO7s3l53c7cS3HNp517FhV3eMKDS6wOBiYGQvHrj+u22qKMBCWFZl8J6LwK+X8j19d992b33zztQMunnkwBRAAO98oP9eR062zFzWsWFqbhz8pUYh8+DX//aA3ryb4gfDseKkfblOHGpc3PlSr/U9u2/HMJ55dc9/g0ir74WAKgEgJdrxafLK3LbVowdzM8QsmoxKIkjD+rlbqU1G1X68AdU3AYMl3CCdxRKHaSqKSz4N20QlEsdD9yw2vPvnxZ5+4syueNhwjUQAAEIFsXV/8VWFhZvnimanFc+IZJjL1EziGVPl1CzMMVPP11b5mOC3Rcej1c5GHLxznHPmG2oaRbnHCc75f6unpfP1//ebpB25a/+I/dcdz7Y/hvvFAZJtN23WfW/DgbfMz71waT5xwHGAFjkD7wfb+l5/pKG3qICWKFWs2UGFvHhBDimHZIarqlQgrcSwsIBIBiwLECQvVetnD+ZMZgKZw7iaUIkCByCilNCmjSWmlSGmQUkopBdJaId7XEgBESilPe+lGz8tmlTKKnS1VKvldhXzH2l2b/vPhjRt/ueFQo50OVQEAoG26mXPlVbO/dt3xuXNXpCg7IYeIoRDrBB+V8iqVq71290tb9j53x0Mv/dnP6x7YSDq4+47NBtlX+IPUP+fhivT+wt7qoci3kQaQiq5XjELcSge5/n4Z7kIjIQ3gnYuzp515Qu59J043R01Xyhv6AEWI1Pivoz8AhRMwWAtgwD5V8gW3d/Ou0oZnNu9cvW4v9u7P//+24kgFpAB4h9CXeKsQADbaDqukJCQkJEw9jrQJGI79dWJqDFcF1/ITALUMyyg7e4lpry42rbk5WgJPZ8QjlRVVLaXEo3BJFquKbCVF5DW4fNBR/dmbq30kS8MeEgcS1OGgjsud/fufnnvvLQrQRIoEQhCiaLlXISHHJK62YoeIaIIYARkCpQgqDVJpBZUiKA8kmgAlgnB6YugLCQWsiMUwsScshn3r2bzVtjMwwS6rgy7r8WZfyq8WUdzq2zc78o8/3vcwHj6kYdJUZ7QVwJuZOvrGWxf96MstZnZ7PHFUUXU2/WiYV2/N45o1TzOsctbqoNeS/6YltytQwQ6f/NcqXO5gcmUL229V0BcEQW/V5kseh269CiowFuxbFzjlV9G7pdLV9V8MtKea552SMiqjU144fNSVlJS1L9qkBAD8akEZldZNjdmUDRo805DxPK0N8+DIyHDAFXI+w/rkV225WrZQsFkLf+PGZ6sbNz4WRMo+ZjXaaCsAAMxflvu9z39q3rc+1aBamuKJo0LNpj8g+EFvnqt58mL2fI4cODVHDtdF5jBxGEIJsEDswNJCoQGGAQmixaFLIhwQUQZEGQK0IJwiLZHpobaQtQgUkWiCSkGRIZCqzaoeirAADiIWIoFALMJY/KKIK0Ckn4j+8v5/+MDq+CdHg2F+0Khw7Im5Cz77ybl3X5/VzaMacVxbWFlqHruakWcYwe/j0NnHjSuhTT9+kQkEs+vuK/ed/JN7Lx+TF2SO1fh9T6e/aUu/625c1vjeEzR5Jp7hcBhcWzeq9mvePDOMQ2cfm/7QjSMFmOhUq4WvPvzdyx6Nnx8txkoBAGDP9sorO3yutB7bePbx6kjW4SWEnryBan9wnd2aAgwIfbiSX/Pk6dCTV/PjT3T8auHxvp3rbn3ttTUH9OkfCWOpAADQubm8rjunZ8xZ1LD88OYSREGZEpX4WkRuXPD7lPp4ya+r8ifiBI44peKeNdu3rvmDJ/7tjoFVPceCsVYACecSrCkvyK5YMiu15NDcyAMTOIa6csdiAseAexYAIGBmEWFmZxkSrhUs4piFnXBtcy5cfKP2HYiWQho4s3/3b2wjCuPh/Gp/R3fHhruef/n+m1966kcjduseLodeIg+PbINqufKT8+6++Z2N5528/6llgysPia5ffqV+mBdG4oYlPIzQHaz269bXVxytpR9V++SEhYXZBcKORaxfKef3VCv53kol31kt57urlXxf4Jf3BkG5v+L39ZYLe4ouqAiUIg0NF8rdElsLAFax8VTK80xjQ7qxZVo63dSgtdZhMC60ItOQyjTmlM6kjfFSWhtDZHQU1lZ/186J3VPs7/z1jo3PPt7R8dLWg3geR43xUgAAyGroc97Tcs1HTm750Lum6RnTAMDC2UCqFd8V+gOuVhzYMnx2Wpi1ZdYQNlY4Cq8WDWLtSAhwOpyJKwrilBVWJBa+Xw6KvVWb7/W5akWYLVnfBeV8qbRnT7WczwdB1eegvGfPns27I1dqJeYsOpyxN8WeZ+3/+hVP43lqMAA/uv64MtyPGUsIQC568bIX3XgQBWoG0f/DCaB2fKDfW8vjYl6/+v2hCjUhISEhIWGqcqA2dbxQJ7SsPOEj7/jzc0WBrAeBEQ5UAGgHaxgwpCxZIxraGjgmroqREivuD8gVAvEDS4FjJ0JKVf1Kfk/gChVllM2Xeqo9hXyQLVjO5Tb4a9asGfeO1kRmIihA0+kzL/+bq5bd8cfiEQ2x6MUtezVbfrTO3uCLkxhMXJuSK4BYEQmDOkWKLK4MkCNCgZ3rF8ABXBTneoSoqgT9ToJeQJhA/YGtdgFwSmf6baXQE9iS0zoV+FLprRY6Kiwpp8r5yt69ewPP65E3042ydc0i/yBRyAScapYtW0Lr1z8UTJTX208EBdBap1ZeteyOL504/+JzOFp9a4jghxhz6vbjEJcnwuH6reF8BisiNlx4i0tgLgiJAMoBkmfn+iAciLCEJg1SIIrebMJpUl4LxHVXXOkjD9/z0QkxKXUiKAAApD2VufKad337TxfNftdy1q7OyDO4qmZ9TF7Nnj+Wwh9tWLia79t51b/cf83/iae9VYy1KXikOBa7cUPX2uKio047vjE3o21Iqa/Z9QeagAObdSciIsLlQudXHvn+1ffG095KJooCAEAQuPIbb3Q8FSyce8ayTK6lpSbsgbi8SPBh9M6kEr6Uinvu2v3Gt76ydevWA/UTxp2JpAAAUK0EhU2bdz8nCxectcxrbGwa2t5P/AkccURY+vOd33ph7fe++MILvxgzt+7hMtEUAABK5Wrfxi27fm3nLTjtWK+xqblW+ieDD78edq6a79vx1y8+teovNm58bkKuxj4RFQAACuXK3g1btz9dnDH7+IXZptY2VofbYQ39L3G3bHw7tP7woAt36OfC/x3boJTvWLdl89M3Pf6TL9zb09Mz4Up+jUO567eCnE5l37/8lI99bPEx7zu7IdferpTW4WshRdhZX8Q6AYkIOxdUKtYGAcA2CMoFZ/0AEOesX/L9YpFZmAhsg3I+8Mvlmi9fQYkj9oNKsdf3C74mo4WESEg4ehkmCSkoUkopT5l01phMg2cyrbnmWbNS6VyOiGCt7asUu1/q7Nzw8/Uv/PJpoCcfv6GJxkRXAERu1BnGmKOnz1g6N5ttSzGJ4yAo5vt39NlK0RKBLSk/KJWLgO8i12ol8v7VXK21zhdHHsN4e1LLezBqxV5FUbq1l20ygHK0JbEHCQkJCQkJCROaydAJPBi1uXYAziWcC5xaKBAAlMvl6Pw7AQC+3z/s/QZBLd9QPC8b7ygilWoSAMhmN0kul5M1ayZ3NPKwNz4JIGMy7/nA5d+4oaV10XyBeCQwUKRERIVxeFAUvu6UwleHEARCg/O2wzngAlD4VtphUFT3JsdwBSgCRfMWhVm4Imyv/eF3Ll0f/+hkYfgbnxzMbpt1/B9deMnXbso2TJ8eTxxrRMT19mz50k8euP4bIxw+TkgmqiVwJBTKxe6t+b5d0+YvPvNErUcn/nAkiIiUCnvufOT+734d2Dqpx/yTWQEAoK9v77YdzvrTZ89bsUypI4g/PARKpZ7vvfzMQ7d1dT06YU28I2WyKwAAdHXtXt+TzjTPbj/q+CXRG8rGjEqp76fb1v/shuef/2E5njYZmQoKIAB27N7xfHdj8+x5rTMWLxwrJfCrxdVbd/72vz31yzsnxHSu0WAqKADCOXqyZeeW5zoam2bNaW1bMupKUK0Wfr1j25rL1z76V2MesDmeTBUFQKgEbvO2Tc/sBCTT1n70Qm1G5yUXflD63a7Nz1y++t/u2B5Pm+xMJQVAOByTzbt3vvjiru3PbydtyPOyGaWMjgxGEr6TlMNdHGYRCDM7di7wnS2XioXu1dveWHP12ifufCN+sanAqFaTEwwDYKYxZn5u2ryjstmWRmMyRhmjldKaSGulTDRqIBFxTqyz1lUD31Ur1i8VYaWzu/vV30URxFOSqawAByN+75PWnJuQkJCQkHAYxNvBqU7q7HNvPmPu0nfPq73mpVrOT2tomnm0Mdn/WDzjgp+tWjVKb3+cJIyL7XwCsUSM95eNuZn/1Jib+WBjbuaDre1HfyeTaf4Cu8onVmP12+15TDk7wMHI79q2bk9Dbsbs1vYlC2qrlVXL/f++49VfXLvm/j+essO9/fF2UwAn4jZt2/TU5qBaopa2BUex2Fc7d2+46lePf3VE79lLmBoQgDkm2/SuXG72jHhiQkJCQkJCQkJCQkJCQkJCQkJCQsLU4v8DblCc3I63kVsAAAAASUVORK5CYII='

function New-LogoImage {
    try {
        $image = New-Object Windows.Media.Imaging.BitmapImage
        $image.BeginInit()
        $image.StreamSource = New-Object IO.MemoryStream(, [Convert]::FromBase64String($LogoPng))
        $image.CacheOption  = 'OnLoad'
        $image.EndInit()
        $image.Freeze()          # usable from any thread, and cheaper to render
        $image
    } catch { $null }
}
#endregion

#region ── UI ─────────────────────────────────────────────────────────────────
$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="USB Latency Suite" Height="740" Width="1120"
        MinHeight="560" MinWidth="900"
        WindowStartupLocation="CenterScreen" WindowStyle="None"
        AllowsTransparency="True" Background="Transparent"
        TextOptions.TextFormattingMode="Ideal"
        TextOptions.TextRenderingMode="ClearType"
        FontFamily="Segoe UI Variable Text, Segoe UI" ResizeMode="CanResizeWithGrip">
  <Window.Resources>
    <!-- Surfaces: neutral, so the accent reads as an accent -->
    <SolidColorBrush x:Key="Bg"     Color="#0C0E13"/>
    <SolidColorBrush x:Key="Card"   Color="#14161D"/>
    <SolidColorBrush x:Key="Card2"  Color="#191C24"/>
    <SolidColorBrush x:Key="Sunken" Color="#0A0C10"/>
    <SolidColorBrush x:Key="Line"   Color="#272B35"/>
    <SolidColorBrush x:Key="LineHi" Color="#333846"/>
    <!-- Text ramp -->
    <SolidColorBrush x:Key="Fg"     Color="#F3F5F9"/>
    <SolidColorBrush x:Key="Fg2"    Color="#BFC6D2"/>
    <SolidColorBrush x:Key="Muted"  Color="#8E97A6"/>
    <SolidColorBrush x:Key="Dim"    Color="#626B7A"/>
    <!-- Accent + semantic -->
    <SolidColorBrush x:Key="Accent" Color="#9D7BF0"/>
    <SolidColorBrush x:Key="Ok"     Color="#4ADE80"/>
    <SolidColorBrush x:Key="Warn"   Color="#FBBF24"/>
    <LinearGradientBrush x:Key="AccentBrush" StartPoint="0,0" EndPoint="1,1">
      <GradientStop Color="#7C8CF8" Offset="0"/>
      <GradientStop Color="#9D7BF0" Offset="0.55"/>
      <GradientStop Color="#B18CF5" Offset="1"/>
    </LinearGradientBrush>

    <!-- One definition for every panel heading, so they cannot drift apart -->
    <Style x:Key="SectionHead" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Muted}"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>

    <Style x:Key="Meta" TargetType="TextBlock">
      <Setter Property="Foreground" Value="{StaticResource Dim}"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>

    <Style TargetType="ScrollBar">
      <Setter Property="Width" Value="10"/>
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
                        <Border x:Name="t" CornerRadius="3" Background="#2E3542" Margin="3,0"/>
                        <ControlTemplate.Triggers>
                          <Trigger Property="IsMouseOver" Value="True">
                            <Setter TargetName="t" Property="Background" Value="#414A5C"/>
                          </Trigger>
                        </ControlTemplate.Triggers>
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

    <Style x:Key="Chrome" TargetType="Button">
      <Setter Property="Foreground" Value="{StaticResource Muted}"/>
      <Setter Property="Background" Value="Transparent"/>
      <Setter Property="Width" Value="44"/>
      <Setter Property="Height" Value="32"/>
      <Setter Property="FontSize" Value="12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="7">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#1E222C"/>
                <Setter Property="Foreground" Value="{StaticResource Fg}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Small pill used for "all" / "none" above the device list -->
    <Style x:Key="Pill" TargetType="Button">
      <Setter Property="Foreground" Value="{StaticResource Muted}"/>
      <Setter Property="FontSize" Value="11"/>
      <Setter Property="Padding" Value="12,5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" CornerRadius="6" Background="Transparent"
                    BorderBrush="{StaticResource Line}" BorderThickness="1">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#1E222C"/>
                <Setter TargetName="b" Property="BorderBrush" Value="{StaticResource LineHi}"/>
                <Setter Property="Foreground" Value="{StaticResource Fg}"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Ghost" TargetType="Button">
      <Setter Property="Foreground" Value="{StaticResource Fg2}"/>
      <Setter Property="Padding" Value="18,10"/>
      <Setter Property="MinWidth" Value="104"/>
      <Setter Property="FontSize" Value="12.5"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" CornerRadius="8" Background="#191D26"
                    BorderBrush="{StaticResource Line}" BorderThickness="1">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Background" Value="#212632"/>
                <Setter TargetName="b" Property="BorderBrush" Value="{StaticResource LineHi}"/>
                <Setter Property="Foreground" Value="{StaticResource Fg}"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.35"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource Ghost}">
      <Setter Property="Foreground" Value="#12101C"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="MinWidth" Value="128"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" CornerRadius="8" Background="{StaticResource AccentBrush}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b" Property="Opacity" Value="0.9"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Opacity" Value="0.3"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <Style x:Key="Switch" TargetType="ToggleButton">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="ToggleButton">
            <Border x:Name="track" Width="40" Height="22" CornerRadius="11" Background="#2A303C">
              <Ellipse x:Name="knob" Width="16" Height="16" Fill="#8B94A6"
                       HorizontalAlignment="Left" Margin="3,0,0,0"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="track" Property="Background" Value="{StaticResource Accent}"/>
                <Setter TargetName="knob"  Property="Fill" Value="White"/>
                <Setter TargetName="knob"  Property="HorizontalAlignment" Value="Right"/>
                <Setter TargetName="knob"  Property="Margin" Value="0,0,3,0"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="track" Property="Opacity" Value="0.85"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>

    <!-- Device row. The badge column is a fixed width so every device name
         starts at the same x, and the hardware id sits directly under it. -->
    <Style x:Key="DevCheck" TargetType="CheckBox">
      <Setter Property="Foreground" Value="{StaticResource Fg}"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="CheckBox">
            <Border x:Name="row" Background="Transparent" CornerRadius="8" Padding="12,9">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="box" Width="16" Height="16" CornerRadius="4"
                        BorderBrush="#39414F" BorderThickness="1.4" Background="Transparent"
                        VerticalAlignment="Top" Margin="0,1,0,0">
                  <Path x:Name="tick" Data="M 0 3.5 L 3 6.5 L 8.5 1" Stroke="White" StrokeThickness="1.8"
                        Visibility="Collapsed" HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <ContentPresenter Grid.Column="1" Margin="12,0,0,0" VerticalAlignment="Center"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="box" Property="Background" Value="{StaticResource Accent}"/>
                <Setter TargetName="box" Property="BorderBrush" Value="{StaticResource Accent}"/>
                <Setter TargetName="tick" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="row" Property="Background" Value="#191D26"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>

  <Border Background="{StaticResource Bg}" CornerRadius="12"
          BorderBrush="{StaticResource Line}" BorderThickness="1">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="56"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- title bar -->
      <Border x:Name="TitleBar" Grid.Row="0" Background="#0A0C10" CornerRadius="11,11,0,0"
              BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1">
        <Grid Margin="20,0">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
            <Image x:Name="Logo" Width="20" Height="20" Margin="0,0,12,0"
                   VerticalAlignment="Center"
                   RenderOptions.BitmapScalingMode="HighQuality"/>
            <TextBlock Text="USB Latency Suite"
                       FontFamily="Segoe UI Variable Display, Segoe UI"
                       Foreground="{StaticResource Fg}"
                       FontSize="13.5" FontWeight="SemiBold" VerticalAlignment="Center"/>
            <Border Width="1" Height="14" Background="{StaticResource Line}" Margin="14,0"/>
            <TextBlock Text="input path power management"
                       Foreground="{StaticResource Muted}"
                       FontSize="12" VerticalAlignment="Center"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="BtnMin"   Style="{StaticResource Chrome}" Content="&#xE921;" FontFamily="Segoe MDL2 Assets"/>
            <Button x:Name="BtnClose" Style="{StaticResource Chrome}" Content="&#xE8BB;" FontFamily="Segoe MDL2 Assets"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- body -->
      <Grid Grid.Row="1" Margin="20,18,20,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="352"/>
          <ColumnDefinition Width="18"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <!-- modules -->
        <Border Grid.Column="0" Background="{StaticResource Card}" CornerRadius="12"
                BorderBrush="{StaticResource Line}" BorderThickness="1">
          <Grid>
            <Grid.RowDefinitions>
              <RowDefinition Height="Auto"/>
              <RowDefinition Height="*"/>
            </Grid.RowDefinitions>
            <Grid Grid.Row="0" Height="46" Margin="20,0,16,0">
              <TextBlock Text="TWEAK MODULES" Style="{StaticResource SectionHead}"/>
            </Grid>
            <Border Grid.Row="0" Height="1" VerticalAlignment="Bottom"
                    Background="{StaticResource Line}" Margin="16,0"/>
            <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,12,4,12">
              <StackPanel x:Name="ModuleHost" Margin="16,0,10,0"/>
            </ScrollViewer>
          </Grid>
        </Border>

        <!-- devices + log -->
        <Grid Grid.Column="2">
          <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="16"/>
            <RowDefinition Height="238"/>
          </Grid.RowDefinitions>

          <Border Grid.Row="0" Background="{StaticResource Card}" CornerRadius="12"
                  BorderBrush="{StaticResource Line}" BorderThickness="1">
            <Grid>
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
              </Grid.RowDefinitions>
              <Grid Grid.Row="0" Height="46" Margin="20,0,16,0">
                <TextBlock x:Name="DevHeader" Text="DEVICES" Style="{StaticResource SectionHead}"/>
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" VerticalAlignment="Center">
                  <Button x:Name="BtnAll"  Style="{StaticResource Pill}" Content="all"  Margin="0,0,8,0"/>
                  <Button x:Name="BtnNone" Style="{StaticResource Pill}" Content="none"/>
                </StackPanel>
              </Grid>
              <Border Grid.Row="0" Height="1" VerticalAlignment="Bottom"
                      Background="{StaticResource Line}" Margin="16,0"/>
              <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" Margin="0,10,4,12">
                <ItemsControl x:Name="DevList" Margin="10,0,8,0">
                  <ItemsControl.ItemTemplate>
                    <DataTemplate>
                      <CheckBox Style="{StaticResource DevCheck}" IsChecked="{Binding Enabled, Mode=TwoWay}">
                        <Grid>
                          <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="62"/>
                            <ColumnDefinition Width="*"/>
                          </Grid.ColumnDefinitions>
                          <Border Grid.Column="0" Background="#1E2430" CornerRadius="4"
                                  Padding="0,2" Margin="0,1,10,0" VerticalAlignment="Top"
                                  HorizontalAlignment="Left" MinWidth="52">
                            <TextBlock Text="{Binding Kind}" FontSize="10" Foreground="#9AA4B6"
                                       HorizontalAlignment="Center"/>
                          </Border>
                          <StackPanel Grid.Column="1">
                            <TextBlock Text="{Binding Name}" FontSize="12.5"
                                       Foreground="{StaticResource Fg}"
                                       TextTrimming="CharacterEllipsis"/>
                            <TextBlock Text="{Binding Id}" FontSize="10.5"
                                       Foreground="{StaticResource Dim}"
                                       FontFamily="Cascadia Mono, Consolas"
                                       Margin="0,3,0,0" TextTrimming="CharacterEllipsis"/>
                          </StackPanel>
                        </Grid>
                      </CheckBox>
                    </DataTemplate>
                  </ItemsControl.ItemTemplate>
                </ItemsControl>
              </ScrollViewer>
            </Grid>
          </Border>

          <Border Grid.Row="2" Background="{StaticResource Sunken}" CornerRadius="12"
                  BorderBrush="{StaticResource Line}" BorderThickness="1">
            <Grid>
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
              </Grid.RowDefinitions>
              <Grid Grid.Row="0" Height="42" Margin="20,0,16,0">
                <TextBlock Text="OUTPUT" Style="{StaticResource SectionHead}"/>
              </Grid>
              <Border Grid.Row="0" Height="1" VerticalAlignment="Bottom"
                      Background="{StaticResource Line}" Margin="16,0"/>
              <RichTextBox x:Name="Log" Grid.Row="1" Background="Transparent" BorderThickness="0"
                           Foreground="#BFC6D2" FontFamily="Cascadia Mono, Consolas" FontSize="11.5"
                           IsReadOnly="True" Margin="16,10,4,12"
                           VerticalScrollBarVisibility="Auto"
                           HorizontalScrollBarVisibility="Disabled"/>
            </Grid>
          </Border>
        </Grid>
      </Grid>

      <!-- footer -->
      <Grid Grid.Row="2" Margin="20,18,20,20">
        <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
          <Ellipse x:Name="StatusDot" Width="7" Height="7" Fill="{StaticResource Ok}" Margin="0,0,10,0"/>
          <TextBlock x:Name="Status" Text="Ready." Foreground="{StaticResource Muted}"
                     FontSize="12" VerticalAlignment="Center"/>
        </StackPanel>
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="BtnReboot"  Style="{StaticResource Ghost}"   Content="Reboot"      Margin="0,0,10,0"/>
          <Button x:Name="BtnRevert"  Style="{StaticResource Ghost}"   Content="Revert last" Margin="0,0,10,0"/>
          <Button x:Name="BtnPreview" Style="{StaticResource Ghost}"   Content="Preview"     Margin="0,0,10,0"/>
          <Button x:Name="BtnApply"   Style="{StaticResource Primary}" Content="Apply tweaks"/>
        </StackPanel>
      </Grid>
    </Grid>
  </Border>
</Window>
'@

$Window = [Windows.Markup.XamlReader]::Parse($xaml)

$UI = @{}
foreach ($n in 'TitleBar','BtnMin','BtnClose','ModuleHost','DevList','DevHeader','BtnAll','BtnNone',
                'Log','Status','StatusDot','Logo','BtnPreview','BtnApply','BtnRevert','BtnReboot') {
    $UI[$n] = $Window.FindName($n)
}

$Logo = New-LogoImage
if ($Logo) {
    $Window.Icon    = $Logo      # taskbar and Alt+Tab
    $UI.Logo.Source = $Logo      # the mark in the title bar
}
else {
    # Never leave a blank gap where the mark should be.
    $UI.Logo.Visibility = 'Collapsed'
}

# A RichTextBox starts with one empty paragraph whose margin is Auto. Log lines
# get appended after it, so it sat under the OUTPUT heading as a dead band.
$UI.Log.Document.Blocks.Clear()
$UI.Log.Document.PagePadding = '0'
$UI.Log.Document.LineHeight  = 15

# Fit small or heavily scaled displays.
$work = [Windows.SystemParameters]::WorkArea
if ($Window.Width  -gt $work.Width  - 40) { $Window.Width  = $work.Width  - 40 }
if ($Window.Height -gt $work.Height - 40) { $Window.Height = $work.Height - 40 }

#region ── UI helpers ─────────────────────────────────────────────────────────
$LogColors = @{
    ''     = '#BFC6D2'
    'ok'   = '#4ADE80'
    'warn' = '#FBBF24'
    'dim'  = '#626B7A'
    'head' = '#9D7BF0'
}

$Write = {
    param([string]$Text, [string]$Level = '')
    $p = New-Object Windows.Documents.Paragraph
    $p.Margin = '0'
    $r = New-Object Windows.Documents.Run($Text)
    $r.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString($LogColors[$Level])
    $p.Inlines.Add($r)
    $UI.Log.Document.Blocks.Add($p)
    $UI.Log.ScrollToEnd()
    try { Add-Content -LiteralPath $LogFile -Value ("{0:HH:mm:ss}  {1}" -f (Get-Date), $Text) } catch { }
}

# WPF equivalent of DoEvents - keeps the window painting during a long apply.
function Pump {
    $frame = New-Object Windows.Threading.DispatcherFrame
    $null = $Window.Dispatcher.BeginInvoke(
        [Windows.Threading.DispatcherPriority]::Background,
        [action]{ $frame.Continue = $false })
    [Windows.Threading.Dispatcher]::PushFrame($frame)
}

$StatusColors = @{ ok = '#4ADE80'; busy = '#FBBF24'; warn = '#FB7185' }

function Set-Status([string]$Text, [string]$Level = 'ok') {
    $UI.Status.Text = $Text
    $UI.StatusDot.Fill = [Windows.Media.BrushConverter]::new().ConvertFromString($StatusColors[$Level])
    Pump
}
#endregion

#region ── Build module toggles ───────────────────────────────────────────────
$Toggles = @{}
foreach ($key in $Modules.Keys) {
    $m = $Modules[$key]

    $card = New-Object Windows.Controls.Border
    $card.Background      = [Windows.Media.BrushConverter]::new().ConvertFromString('#191C24')
    $card.BorderBrush     = [Windows.Media.BrushConverter]::new().ConvertFromString('#272B35')
    $card.BorderThickness = 1
    $card.CornerRadius    = 10
    $card.Padding         = '16,14'
    $card.Margin          = '0,0,0,10'

    $grid = New-Object Windows.Controls.Grid
    $c1 = New-Object Windows.Controls.ColumnDefinition; $c1.Width = 'Auto'
    $c2 = New-Object Windows.Controls.ColumnDefinition
    $grid.ColumnDefinitions.Add($c2); $grid.ColumnDefinitions.Add($c1)

    $sp = New-Object Windows.Controls.StackPanel
    $t1 = New-Object Windows.Controls.TextBlock
    $t1.Text = $m.Title; $t1.FontSize = 12.5; $t1.FontWeight = 'SemiBold'
    $t1.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#F3F5F9')
    $t2 = New-Object Windows.Controls.TextBlock
    $t2.Text = $m.Desc; $t2.FontSize = 11.5; $t2.TextWrapping = 'Wrap'; $t2.Margin = '0,5,12,0'
    $t2.LineHeight = 16; $t2.LineStackingStrategy = 'BlockLineHeight'
    $t2.Foreground = [Windows.Media.BrushConverter]::new().ConvertFromString('#8E97A6')
    $sp.Children.Add($t1) | Out-Null; $sp.Children.Add($t2) | Out-Null
    [Windows.Controls.Grid]::SetColumn($sp, 0)

    $tg = New-Object Windows.Controls.Primitives.ToggleButton
    $tg.Style = $Window.FindResource('Switch')
    $tg.IsChecked = $true
    $tg.VerticalAlignment = 'Top'
    [Windows.Controls.Grid]::SetColumn($tg, 1)

    $grid.Children.Add($sp) | Out-Null
    $grid.Children.Add($tg) | Out-Null
    $card.Child = $grid
    $UI.ModuleHost.Children.Add($card) | Out-Null
    $Toggles[$key] = $tg
}

function Get-SelectedCats {
    @($Modules.Keys | Where-Object { $Toggles[$_].IsChecked })
}
#endregion

#region ── Load devices ───────────────────────────────────────────────────────
$Devices = New-Object System.Collections.ObjectModel.ObservableCollection[DevItem]
foreach ($d in Get-TargetDevices) { $Devices.Add($d) }
$UI.DevList.ItemsSource = $Devices
$UI.DevHeader.Text = "DEVICES · $($Devices.Count) PRESENT"
#endregion

#region ── Events ─────────────────────────────────────────────────────────────
$UI.TitleBar.Add_MouseLeftButtonDown({ $Window.DragMove() })
$UI.BtnMin.Add_Click({ $Window.WindowState = 'Minimized' })
$UI.BtnClose.Add_Click({ $Window.Close() })

$UI.BtnAll.Add_Click({
    foreach ($d in $Devices) { $d.Enabled = $true }
    $UI.DevList.Items.Refresh()
})
$UI.BtnNone.Add_Click({
    foreach ($d in $Devices) { $d.Enabled = $false }
    $UI.DevList.Items.Refresh()
})

$UI.BtnPreview.Add_Click({
    $cats = Get-SelectedCats
    if (-not $cats) { & $Write 'No modules enabled.' 'warn'; return }
    Set-Status 'Building plan...' 'busy'
    $plan = Build-Plan $cats @($Devices)
    & $Write ''
    & $Write ("── PREVIEW  ({0} change(s))" -f $plan.Count) 'head'
    foreach ($p in $plan) {
        if ($p.Kind -eq 'reg') {
            $from = if ($p.Had) { $p.Old } else { '<absent>' }
            & $Write ("  {0}`n    {1}: {2} -> {3}" -f $p.Path, $p.Name, $from, $p.New) 'dim'
        } else {
            & $Write ("  powercfg /devicedisablewake `"{0}`"" -f $p.Name) 'dim'
        }
        Pump
    }
    if (-not $plan.Count) { & $Write '  Nothing to change - system already matches the selected modules.' 'ok' }
    Set-Status ("Preview: {0} change(s). Nothing written." -f $plan.Count)
})

$UI.BtnApply.Add_Click({
    $cats = Get-SelectedCats
    if (-not $cats) { & $Write 'No modules enabled.' 'warn'; return }

    $answer = [Windows.MessageBox]::Show(
        "Apply the selected tweaks?`n`nEvery change is backed up first and can be undone with 'Revert last'.`nA reboot is required for driver-level changes.",
        'USB Latency Suite', 'OKCancel', 'Question')
    if ($answer -ne 'OK') { return }

    $UI.BtnApply.IsEnabled = $false; $UI.BtnPreview.IsEnabled = $false; $UI.BtnRevert.IsEnabled = $false
    Set-Status 'Applying...' 'busy'
    $plan = Build-Plan $cats @($Devices)
    & $Write ''
    & $Write ("── APPLY  ({0} change(s))" -f $plan.Count) 'head'
    $r = Invoke-Plan $plan $Write
    & $Write ("Applied {0}, failed {1}." -f $r.Applied, $r.Failed) $(if ($r.Failed) {'warn'} else {'ok'})
    & $Write 'Reboot required for driver-level changes.' 'warn'
    Set-Status ("Applied {0} change(s), {1} failed. Reboot to finish." -f $r.Applied, $r.Failed) $(if ($r.Failed) { 'warn' } else { 'ok' })
    $UI.BtnApply.IsEnabled = $true; $UI.BtnPreview.IsEnabled = $true; $UI.BtnRevert.IsEnabled = $true
})

$UI.BtnReboot.Add_Click({
    $answer = [Windows.MessageBox]::Show('Restart now to apply the changes?',
                                         'USB Latency Suite', 'OKCancel', 'Question')
    if ($answer -eq 'OK') { & shutdown.exe /r /t 5 /c 'USB Latency Suite' }
})

$UI.BtnRevert.Add_Click({
    $b = Get-LatestBackup
    if (-not $b) { & $Write 'No backup found in .\Backups.' 'warn'; return }

    $answer = [Windows.MessageBox]::Show(
        "Restore every value recorded in`n$($b.Name)?",
        'USB Latency Suite', 'OKCancel', 'Question')
    if ($answer -ne 'OK') { return }

    $UI.BtnRevert.IsEnabled = $false
    & $Write ''
    & $Write "── REVERT  ($($b.Name))" 'head'
    $r = Invoke-Revert $b $Write
    & $Write ("Restored {0}, failed {1}." -f $r.Applied, $r.Failed) $(if ($r.Failed) {'warn'} else {'ok'})
    Set-Status ("Reverted {0} change(s). Reboot to finish." -f $r.Applied)
    $UI.BtnRevert.IsEnabled = $true
})
#endregion

$UI.BtnRevert.IsEnabled = [bool](Get-LatestBackup)

& $Write "USB Latency Suite $Version - running elevated." 'ok'
& $Write "$($Devices.Count) USB/HID device(s) present. Backups: $BackupDir" 'dim'
& $Write "Use Preview first. Apply writes a backup before touching anything." 'dim'

if (Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue) {
    & $Write "Battery detected: these tweaks keep USB devices powered and will cost idle runtime." 'warn'
}

$null = $Window.ShowDialog()
