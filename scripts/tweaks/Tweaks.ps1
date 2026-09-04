<#
.SYNOPSIS
    Reversible Windows tweaks for stability, performance and privacy.

.DESCRIPTION
    Every tweak captures the machine's current state before it changes anything and
    writes it to a backup file. -Revert restores exactly what was captured, so nothing
    here is a one-way door.

    Only tweaks with a documented mechanism or a reproducible effect are included.
    Registry values that are cargo-culted around gaming forums but have no observable
    effect (or an actively harmful one) are documented in docs/ instead, not applied.

.PARAMETER UI
    Interactive picker. This is what runs when the script is started with no
    arguments: nothing is applied until you select tweaks and confirm.

.PARAMETER List
    Print every tweak with its category, risk and rationale.

.PARAMETER Status
    Show whether each tweak is currently applied.

.PARAMETER Apply
    Tweak ids and/or category names to apply. 'all' applies every tweak.

.PARAMETER Revert
    Tweak ids and/or category names to revert from the backup file. 'all' reverts
    everything recorded in the backup.

.PARAMETER BackupPath
    Where the pre-change state is stored. Defaults to
    %LOCALAPPDATA%\WindowsTweaks\backup.json. Keep this file — without it nothing
    can be reverted automatically.

.PARAMETER NoRestorePoint
    Skip the system restore point that -Apply normally tries to create first.

.EXAMPLE
    .\Tweaks.ps1

.EXAMPLE
    .\Tweaks.ps1 -List

.EXAMPLE
    .\Tweaks.ps1 -Apply privacy,latency -WhatIf

.EXAMPLE
    .\Tweaks.ps1 -Apply net.nagle,power.ultimate

.EXAMPLE
    .\Tweaks.ps1 -Revert all
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium', DefaultParameterSetName = 'UI')]
param(
    [Parameter(ParameterSetName = 'UI')]
    [switch]$UI,

    [Parameter(ParameterSetName = 'List', Mandatory = $true)]
    [switch]$List,

    [Parameter(ParameterSetName = 'Status', Mandatory = $true)]
    [switch]$Status,

    [Parameter(ParameterSetName = 'Apply', Mandatory = $true)]
    [string[]]$Apply,

    [Parameter(ParameterSetName = 'Revert', Mandatory = $true)]
    [string[]]$Revert,

    [string]$BackupPath = (Join-Path $env:LOCALAPPDATA 'WindowsTweaks\backup.json'),

    [switch]$NoRestorePoint
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

#region Tweak definitions
# Reg tweaks are declarative: the engine captures the old value, writes the new one,
# and puts the old one back on revert. Imperative tweaks supply Capture/Set/Undo/Test.

$Tweaks = @(

    #--- power -------------------------------------------------------------------
    @{
        Id       = 'power.ultimate'
        Category = 'power'
        Title    = 'Activate the Ultimate Performance power plan'
        Why      = 'Removes core parking and idle-state latency from the scheduler. Costs idle watts; on a desktop that is a fair trade.'
        Risk     = 'Low'
        Evidence = 'Documented (Microsoft power scheme, hidden by default on consumer SKUs)'
        Reboot   = $false
        Capture  = {
            $active = (powercfg /getactivescheme) -replace '^.*GUID:\s*([0-9a-f-]+).*$', '$1'
            @{ PreviousScheme = $active.Trim() }
        }
        Set      = {
            $ultimate = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
            # Duplicating an already-duplicated scheme is a no-op error; ignore it.
            powercfg /duplicatescheme $ultimate 2>&1 | Out-Null
            powercfg /setactive $ultimate
        }
        Undo     = {
            param($state)
            if ($state.PreviousScheme) { powercfg /setactive $state.PreviousScheme }
        }
        Test     = {
            (powercfg /getactivescheme) -match 'e9a42b02-d5df-448d-aa00-03f14749eb61'
        }
    }

    @{
        Id       = 'power.pcie-aspm-off'
        Category = 'power'
        Title    = 'Disable PCIe Active State Power Management'
        Why      = 'ASPM parks the PCIe link between transfers. Waking it adds microseconds to every GPU/NIC transaction and is a common source of DPC latency spikes.'
        Risk     = 'Low'
        Evidence = 'Documented (PCIe spec + Windows power subgroup SUB_PCIEXPRESS)'
        Reboot   = $false
        Capture  = { @{ Previous = (Get-PowerSettingIndex 'SUB_PCIEXPRESS' 'ASPM') } }
        Set      = { Set-PowerSettingIndex 'SUB_PCIEXPRESS' 'ASPM' 0 }
        Undo     = { param($state) if ($null -ne $state.Previous) { Set-PowerSettingIndex 'SUB_PCIEXPRESS' 'ASPM' $state.Previous } }
        Test     = { (Get-PowerSettingIndex 'SUB_PCIEXPRESS' 'ASPM') -eq 0 }
    }

    @{
        Id       = 'power.usb-suspend-off'
        Category = 'power'
        Title    = 'Disable USB selective suspend'
        Why      = 'Stops Windows suspending USB ports. Removes the wake-up delay on mice, keyboards and audio interfaces.'
        Risk     = 'Low'
        Evidence = 'Documented (Windows power subgroup 2a737441-…)'
        Reboot   = $false
        Capture  = { @{ Previous = (Get-PowerSettingIndex '2a737441-1930-4402-8d77-b2bebba308a3' '48e6b7a6-50f5-4782-a5d4-53bb8f07e226') } }
        Set      = { Set-PowerSettingIndex '2a737441-1930-4402-8d77-b2bebba308a3' '48e6b7a6-50f5-4782-a5d4-53bb8f07e226' 0 }
        Undo     = { param($state) if ($null -ne $state.Previous) { Set-PowerSettingIndex '2a737441-1930-4402-8d77-b2bebba308a3' '48e6b7a6-50f5-4782-a5d4-53bb8f07e226' $state.Previous } }
        Test     = { (Get-PowerSettingIndex '2a737441-1930-4402-8d77-b2bebba308a3' '48e6b7a6-50f5-4782-a5d4-53bb8f07e226') -eq 0 }
    }

    #--- system ------------------------------------------------------------------
    @{
        Id       = 'system.fast-startup-off'
        Category = 'system'
        Title    = 'Disable Fast Startup (hiberboot)'
        Why      = 'Fast Startup restores a hibernated kernel instead of booting cleanly, so driver and service state accumulates across "restarts". The single biggest source of "reboot fixed it, shutdown did not" weirdness. Hibernate itself stays available.'
        Risk     = 'Low'
        Evidence = 'Documented (HiberbootEnabled)'
        Reboot   = $true
        Reg      = @(
            @{ Path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'; Name = 'HiberbootEnabled'; Type = 'DWord'; Value = 0 }
        )
    }

    #--- latency -----------------------------------------------------------------
    @{
        Id       = 'latency.gamedvr-off'
        Category = 'latency'
        Title    = 'Disable Game DVR / background recording'
        Why      = 'Background capture keeps a rolling encode of the foreground game. Measurable frame-time cost on every GPU, and it is on by default.'
        Risk     = 'Low'
        Evidence = 'Documented (GameDVR policy); effect reproducible in frame-time captures'
        Reboot   = $false
        Reg      = @(
            @{ Path = 'HKCU:\System\GameConfigStore'; Name = 'GameDVR_Enabled'; Type = 'DWord'; Value = 0 }
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR'; Name = 'AllowGameDVR'; Type = 'DWord'; Value = 0 }
        )
    }

    @{
        Id       = 'latency.network-throttling-off'
        Category = 'latency'
        Title    = 'Disable multimedia network throttling'
        Why      = 'By default Windows caps non-multimedia network processing to ~10 packets/ms while any multimedia app runs. Uncapping it removes a hard ceiling on packet rate.'
        Risk     = 'Low'
        Evidence = 'Documented (Microsoft KB 2483177, NetworkThrottlingIndex)'
        Reboot   = $true
        Reg      = @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name = 'NetworkThrottlingIndex'; Type = 'DWord'; Value = 0xFFFFFFFF }
        )
    }

    @{
        Id       = 'latency.system-responsiveness'
        Category = 'latency'
        Title    = 'Reserve less CPU for background MMCSS work'
        Why      = 'SystemResponsiveness is the share of CPU MMCSS guarantees to background tasks. Default 20 (%), lowered to 10. Ten is the floor: the value is rounded down to a multiple of 10, and anything below 10 is treated as 20 - so the popular "set it to 0" advice lands you back on the default.'
        Risk     = 'Low'
        Evidence = 'Documented (MMCSS registry settings)'
        Reboot   = $true
        Reg      = @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'; Name = 'SystemResponsiveness'; Type = 'DWord'; Value = 10 }
        )
    }

    @{
        Id       = 'latency.mmcss-games'
        Category = 'latency'
        Title    = 'Raise the MMCSS scheduling category for the Games task'
        Why      = 'Games that register with MMCSS get scheduled in the High category instead of the default Medium. This is the only value in the Games task that does anything: GPU Priority and SFIO Priority are absent from mmcss.sys entirely, and Priority is ignored whenever Scheduling Category is High.'
        Risk     = 'Low'
        Evidence = 'Documented (MMCSS task profiles), confirmed against mmcss.sys'
        Reboot   = $true
        Reg      = @(
            @{ Path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games'; Name = 'Scheduling Category'; Type = 'String'; Value = 'High' }
        )
    }

    #--- net ---------------------------------------------------------------------
    @{
        Id       = 'net.nagle'
        Category = 'net'
        Title    = 'Disable Nagle / delayed ACK on active adapters'
        Why      = 'Delayed ACK holds an acknowledgement up to 200 ms waiting for a second segment. Games send small packets and never fill that window, so it is pure added latency. Applied per interface, only to adapters that are up.'
        Risk     = 'Medium'
        Evidence = 'Documented (TcpAckFrequency / TCPNoDelay); measurable on TCP game traffic, no effect on pure-UDP titles'
        Reboot   = $true
        Capture  = {
            $out = @()
            foreach ($guid in (Get-ActiveInterfaceGuid)) {
                $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                $out += @{
                    Path = $path
                    TcpAckFrequency = (Get-RegValue $path 'TcpAckFrequency')
                    TCPNoDelay      = (Get-RegValue $path 'TCPNoDelay')
                }
            }
            @{ Interfaces = $out }
        }
        Set      = {
            foreach ($guid in (Get-ActiveInterfaceGuid)) {
                $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                if (-not (Test-Path $path)) { continue }
                # 1 = ACK every segment immediately. The old batch scripts wrote 0 here,
                # which is not a valid value and is ignored by the stack.
                Set-RegValue $path 'TcpAckFrequency' 'DWord' 1
                Set-RegValue $path 'TCPNoDelay' 'DWord' 1
            }
        }
        Undo     = {
            param($state)
            foreach ($iface in $state.Interfaces) {
                Restore-RegValue $iface.Path 'TcpAckFrequency' 'DWord' $iface.TcpAckFrequency
                Restore-RegValue $iface.Path 'TCPNoDelay' 'DWord' $iface.TCPNoDelay
            }
        }
        Test     = {
            $guids = @(Get-ActiveInterfaceGuid)
            if ($guids.Count -eq 0) { return $false }
            foreach ($guid in $guids) {
                $path = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces\$guid"
                if ((Get-RegValue $path 'TcpAckFrequency') -ne 1) { return $false }
            }
            $true
        }
    }

    @{
        Id       = 'net.adapter-powersave-off'
        Category = 'net'
        Title    = 'Stop Windows powering down network adapters'
        Why      = 'Clears "Allow the computer to turn off this device to save power" on every physical NIC. Prevents link renegotiation stalls mid-session.'
        Risk     = 'Low'
        Evidence = 'Documented (Disable-NetAdapterPowerManagement)'
        Reboot   = $false
        Capture  = {
            $out = @()
            foreach ($a in (Get-PhysicalAdapter)) {
                $pm = Get-NetAdapterPowerManagement -Name $a.Name -ErrorAction SilentlyContinue
                if ($pm) { $out += @{ Name = $a.Name; AllowComputerToTurnOffDevice = [string]$pm.AllowComputerToTurnOffDevice } }
            }
            @{ Adapters = $out }
        }
        Set      = {
            foreach ($a in (Get-PhysicalAdapter)) {
                Disable-NetAdapterPowerManagement -Name $a.Name -NoRestart -ErrorAction SilentlyContinue
            }
            Restart-NetAdapterSafely
        }
        Undo     = {
            param($state)
            foreach ($a in $state.Adapters) {
                if ($a.AllowComputerToTurnOffDevice -eq 'Enabled') {
                    Enable-NetAdapterPowerManagement -Name $a.Name -NoRestart -ErrorAction SilentlyContinue
                }
            }
            Restart-NetAdapterSafely
        }
        Test     = {
            $adapters = @(Get-PhysicalAdapter)
            if ($adapters.Count -eq 0) { return $false }
            foreach ($a in $adapters) {
                $pm = Get-NetAdapterPowerManagement -Name $a.Name -ErrorAction SilentlyContinue
                if ($pm -and $pm.AllowComputerToTurnOffDevice -eq 'Enabled') { return $false }
            }
            $true
        }
    }

    @{
        Id       = 'net.eee-off'
        Category = 'net'
        Title    = 'Disable Energy Efficient Ethernet and flow control'
        Why      = 'EEE (802.3az) idles the PHY between frames; flow control lets the switch pause your link. Both trade latency for power/loss. Only keywords the adapter actually advertises are touched.'
        Risk     = 'Low'
        Evidence = 'Documented (standard NDIS advanced keywords). The old batch script set these to 1, which enabled them.'
        Reboot   = $false
        Capture  = { @{ Properties = @(Get-AdvancedPropertyState @('*EEE', 'AdvancedEEE', '*FlowControl')) } }
        Set      = { Set-AdvancedProperty @('*EEE', 'AdvancedEEE', '*FlowControl') '0' }
        Undo     = { param($state) Restore-AdvancedProperty $state.Properties }
        Test     = { Test-AdvancedProperty @('*EEE', 'AdvancedEEE', '*FlowControl') '0' }
    }

    @{
        Id       = 'net.interrupt-moderation-off'
        Category = 'net'
        Title    = 'Disable NIC interrupt moderation'
        Why      = 'Moderation batches interrupts to cut CPU load, at the cost of holding packets. Turning it off lowers latency and raises CPU usage — a real trade, not a free win. Skip it on a low-core CPU or a saturated 10G link.'
        Risk     = 'Medium'
        Evidence = 'Documented (*InterruptModeration). Measurable both ways; verify with your own testing.'
        Reboot   = $false
        Capture  = { @{ Properties = @(Get-AdvancedPropertyState @('*InterruptModeration')) } }
        Set      = { Set-AdvancedProperty @('*InterruptModeration') '0' }
        Undo     = { param($state) Restore-AdvancedProperty $state.Properties }
        Test     = { Test-AdvancedProperty @('*InterruptModeration') '0' }
    }

    #--- privacy -----------------------------------------------------------------
    @{
        Id       = 'privacy.telemetry'
        Category = 'privacy'
        Title    = 'Set telemetry to the minimum the SKU allows'
        Why      = 'AllowTelemetry=0 is honoured fully on Enterprise/Education and clamps to Basic on Home/Pro. The DiagTrack service is disabled by privacy.services-telemetry.'
        Risk     = 'Low'
        Evidence = 'Documented (DataCollection policy)'
        Reboot   = $false
        Reg      = @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'AllowTelemetry'; Type = 'DWord'; Value = 0 }
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'; Name = 'DoNotShowFeedbackNotifications'; Type = 'DWord'; Value = 1 }
        )
    }

    @{
        Id       = 'privacy.advertising-id'
        Category = 'privacy'
        Title    = 'Disable the per-user advertising ID'
        Why      = 'Stops apps correlating your activity across the system through a stable identifier.'
        Risk     = 'Low'
        Evidence = 'Documented (AdvertisingInfo policy)'
        Reboot   = $false
        Reg      = @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo'; Name = 'DisabledByGroupPolicy'; Type = 'DWord'; Value = 1 }
        )
    }

    @{
        Id       = 'privacy.activity-history'
        Category = 'privacy'
        Title    = 'Stop collecting and uploading activity history'
        Why      = 'Timeline data stops being written locally and stops being sent to the Microsoft account.'
        Risk     = 'Low'
        Evidence = 'Documented (PublishUserActivities / UploadUserActivities)'
        Reboot   = $true
        Reg      = @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'PublishUserActivities'; Type = 'DWord'; Value = 0 }
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'; Name = 'UploadUserActivities'; Type = 'DWord'; Value = 0 }
        )
    }

    @{
        Id       = 'privacy.consumer-features'
        Category = 'privacy'
        Title    = 'Block silently installed suggested apps'
        Why      = 'Stops Windows pulling promoted apps and Start menu suggestions onto a fresh install. Removes a background download and a set of scheduled tasks.'
        Risk     = 'Low'
        Evidence = 'Documented (CloudContent policy)'
        Reboot   = $false
        Reg      = @(
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableWindowsConsumerFeatures'; Type = 'DWord'; Value = 1 }
            @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'; Name = 'DisableSoftLanding'; Type = 'DWord'; Value = 1 }
        )
    }

    @{
        Id       = 'privacy.services-telemetry'
        Category = 'privacy'
        Title    = 'Disable the DiagTrack and dmwappushservice services'
        Why      = 'These are the transports that actually ship diagnostic data. Disabling them is the enforcement behind privacy.telemetry.'
        Risk     = 'Low'
        Evidence = 'Documented'
        Reboot   = $false
        Capture  = { @{ Services = @(Get-ServiceState @('DiagTrack', 'dmwappushservice')) } }
        Set      = { Set-ServiceDisabled @('DiagTrack', 'dmwappushservice') }
        Undo     = { param($state) Restore-ServiceState $state.Services }
        Test     = { Test-ServiceDisabled @('DiagTrack', 'dmwappushservice') }
    }

    #--- bloat -------------------------------------------------------------------
    @{
        Id       = 'bloat.services'
        Category = 'bloat'
        Title    = 'Disable services with no consumer use'
        Why      = 'Retail Demo (kiosk mode), Downloaded Maps Manager (offline maps) and the Print Spooler. The spooler is skipped automatically if a printer is installed — it is also the PrintNightmare attack surface, so turning it off on a printerless machine is a security win as much as a performance one.'
        Risk     = 'Medium'
        Evidence = 'Documented service purposes; guarded by a printer check'
        Reboot   = $false
        Capture  = { @{ Services = @(Get-ServiceState (Get-BloatServiceName)) } }
        Set      = { Set-ServiceDisabled (Get-BloatServiceName) }
        Undo     = { param($state) Restore-ServiceState $state.Services }
        Test     = { Test-ServiceDisabled (Get-BloatServiceName) }
    }

    #--- nvidia ------------------------------------------------------------------
    @{
        Id       = 'nvidia.msi-mode'
        Category = 'nvidia'
        Title    = 'Enable Message Signalled Interrupts for the GPU'
        Why      = 'Line-based interrupts are shared and serialised; MSI lets the GPU raise its own vector. One of the few interrupt tweaks with a reproducible DPC latency improvement.'
        Risk     = 'Medium'
        Evidence = 'Documented (PCI MSISupported). Rare hardware refuses to boot with MSI on — revert from Safe Mode if the display fails.'
        Reboot   = $true
        Capture  = {
            $out = @()
            foreach ($p in (Get-GpuMsiPath)) { $out += @{ Path = $p; Previous = (Get-RegValue $p 'MSISupported') } }
            @{ Devices = $out }
        }
        Set      = { foreach ($p in (Get-GpuMsiPath)) { Set-RegValue $p 'MSISupported' 'DWord' 1 } }
        Undo     = { param($state) foreach ($d in $state.Devices) { Restore-RegValue $d.Path 'MSISupported' 'DWord' $d.Previous } }
        Test     = {
            $paths = @(Get-GpuMsiPath)
            if ($paths.Count -eq 0) { return $false }
            foreach ($p in $paths) { if ((Get-RegValue $p 'MSISupported') -ne 1) { return $false } }
            $true
        }
    }

    @{
        Id       = 'nvidia.telemetry-tasks'
        Category = 'nvidia'
        Title    = 'Disable NVIDIA telemetry and update scheduled tasks'
        Why      = 'Crash reporting, update polling and the telemetry monitor run on a timer. Matched by name pattern rather than the hardcoded GUID the old script used, which stopped existing when GeForce Experience was replaced by the NVIDIA App.'
        Risk     = 'Low'
        Evidence = 'Documented (scheduled task names)'
        Reboot   = $false
        Capture  = { @{ Tasks = @(Get-NvidiaTaskState) } }
        Set      = {
            foreach ($t in (Get-NvidiaTask)) {
                Disable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
            }
        }
        Undo     = {
            param($state)
            foreach ($t in $state.Tasks) {
                if ($t.State -ne 'Disabled') {
                    Enable-ScheduledTask -TaskName $t.TaskName -TaskPath $t.TaskPath -ErrorAction SilentlyContinue | Out-Null
                }
            }
        }
        Test     = {
            $tasks = @(Get-NvidiaTask)
            if ($tasks.Count -eq 0) { return $false }
            -not ($tasks | Where-Object { $_.State -ne 'Disabled' })
        }
    }
)
#endregion

#region Helpers

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

# "Run with PowerShell" from Explorer opens a console that closes the instant the
# script ends, so an error message there is invisible. Pause only in that case —
# pausing when the script was started from an existing prompt is just noise.
function Test-LaunchedFromExplorer {
    try {
        $parentId = (Get-CimInstance Win32_Process -Filter "ProcessId = $PID" -ErrorAction Stop).ParentProcessId
        (Get-Process -Id $parentId -ErrorAction Stop).ProcessName -eq 'explorer'
    }
    catch { $false }
}

function Wait-BeforeClosing {
    if (-not (Test-LaunchedFromExplorer)) { return }
    Write-Host ''
    Write-Host '  Press any key to close...' -ForegroundColor DarkGray
    try { $null = [Console]::ReadKey($true) } catch { Start-Sleep -Seconds 10 }
}

# Rebuilt as one string rather than an array: the script path contains spaces on
# most machines, and Start-Process does not reliably quote array elements.
function Get-RelaunchArgument([string]$ScriptPath, $BoundParameters) {
    $line = '-NoProfile -ExecutionPolicy Bypass -File "{0}"' -f $ScriptPath
    foreach ($name in $BoundParameters.Keys) {
        $value = $BoundParameters[$name]
        if ($value -is [switch]) {
            if ($value.IsPresent) { $line += " -$name" }
        }
        elseif ($value -is [array]) {
            $line += ' -{0} "{1}"' -f $name, ($value -join ',')
        }
        else {
            $line += ' -{0} "{1}"' -f $name, $value
        }
    }
    $line
}

function Request-Elevation([string]$ScriptPath, $BoundParameters) {
    $exe = (Get-Process -Id $PID).Path
    if (-not $exe) { $exe = 'powershell.exe' }
    $arguments = Get-RelaunchArgument $ScriptPath $BoundParameters
    Start-Process -FilePath $exe -ArgumentList $arguments -Verb RunAs
}

function Get-RegValue([string]$Path, [string]$Name) {
    if (-not (Test-Path $Path)) { return $null }
    $item = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $item) { return $null }
    $item.$Name
}

function Set-RegValue([string]$Path, [string]$Name, [string]$Type, $Value) {
    if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
    New-ItemProperty -Path $Path -Name $Name -PropertyType $Type -Value $Value -Force | Out-Null
}

# $Previous of $null means "the value did not exist", so revert deletes it again.
function Restore-RegValue([string]$Path, [string]$Name, [string]$Type, $Previous) {
    if ($null -eq $Previous) {
        if (Test-Path $Path) { Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue }
    }
    else {
        Set-RegValue $Path $Name $Type $Previous
    }
}

function Get-PowerSettingIndex([string]$Subgroup, [string]$Setting) {
    $out = powercfg /query SCHEME_CURRENT $Subgroup $Setting 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $out) { return $null }
    $line = $out | Select-String 'Current AC Power Setting Index:\s*(0x[0-9a-f]+)'
    if (-not $line) { return $null }
    [Convert]::ToInt32($line.Matches[0].Groups[1].Value, 16)
}

function Set-PowerSettingIndex([string]$Subgroup, [string]$Setting, [int]$Index) {
    powercfg /setacvalueindex SCHEME_CURRENT $Subgroup $Setting $Index | Out-Null
    powercfg /setdcvalueindex SCHEME_CURRENT $Subgroup $Setting $Index | Out-Null
    powercfg /setactive SCHEME_CURRENT | Out-Null
}

function Get-PhysicalAdapter {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue | Where-Object { $_.Status -ne 'Not Present' }
}

function Get-ActiveInterfaceGuid {
    Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -eq 'Up' } |
        ForEach-Object { $_.InterfaceGuid }
}

function Restart-NetAdapterSafely {
    # Power-management changes need a bounce to take effect. Never touch the adapter
    # carrying the session if this is running over RDP.
    if ($env:SESSIONNAME -like 'RDP*') {
        Write-Warning 'RDP session detected: skipping adapter restart. Reboot to apply.'
        return
    }
    foreach ($a in (Get-PhysicalAdapter | Where-Object { $_.Status -eq 'Up' })) {
        Restart-NetAdapter -Name $a.Name -ErrorAction SilentlyContinue
    }
}

function Get-AdvancedPropertyState([string[]]$Keywords) {
    foreach ($a in (Get-PhysicalAdapter)) {
        foreach ($kw in $Keywords) {
            $p = Get-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $kw -ErrorAction SilentlyContinue
            if ($p) { @{ Name = $a.Name; Keyword = $kw; Value = [string]$p.RegistryValue[0] } }
        }
    }
}

function Set-AdvancedProperty([string[]]$Keywords, [string]$Value) {
    foreach ($a in (Get-PhysicalAdapter)) {
        foreach ($kw in $Keywords) {
            # Only write keywords the driver actually advertises. Blind REG ADD against
            # every adapter key — what the old script did — can leave an adapter with a
            # keyword its driver rejects, and it fails to bind on next boot.
            if (Get-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $kw -ErrorAction SilentlyContinue) {
                Set-NetAdapterAdvancedProperty -Name $a.Name -RegistryKeyword $kw -RegistryValue $Value -NoRestart -ErrorAction SilentlyContinue
            }
        }
    }
    Restart-NetAdapterSafely
}

function Restore-AdvancedProperty($Saved) {
    foreach ($p in $Saved) {
        Set-NetAdapterAdvancedProperty -Name $p.Name -RegistryKeyword $p.Keyword -RegistryValue $p.Value -NoRestart -ErrorAction SilentlyContinue
    }
    Restart-NetAdapterSafely
}

function Test-AdvancedProperty([string[]]$Keywords, [string]$Value) {
    $found = @(Get-AdvancedPropertyState $Keywords)
    if ($found.Count -eq 0) { return $false }
    -not ($found | Where-Object { $_.Value -ne $Value })
}

function Get-ServiceState([string[]]$Names) {
    foreach ($n in $Names) {
        $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
        if ($svc) {
            $start = (Get-CimInstance Win32_Service -Filter "Name='$n'" -ErrorAction SilentlyContinue).StartMode
            @{ Name = $n; StartMode = [string]$start; Status = [string]$svc.Status }
        }
    }
}

function Set-ServiceDisabled([string[]]$Names) {
    foreach ($n in $Names) {
        if (-not (Get-Service -Name $n -ErrorAction SilentlyContinue)) { continue }
        Stop-Service -Name $n -Force -ErrorAction SilentlyContinue
        Set-Service -Name $n -StartupType Disabled -ErrorAction SilentlyContinue
    }
}

function Restore-ServiceState($Saved) {
    foreach ($s in $Saved) {
        if (-not (Get-Service -Name $s.Name -ErrorAction SilentlyContinue)) { continue }
        $type = switch ($s.StartMode) {
            'Auto'    { 'Automatic' }
            'Manual'  { 'Manual' }
            'Disabled'{ 'Disabled' }
            default   { 'Manual' }
        }
        Set-Service -Name $s.Name -StartupType $type -ErrorAction SilentlyContinue
        if ($s.Status -eq 'Running' -and $type -ne 'Disabled') {
            Start-Service -Name $s.Name -ErrorAction SilentlyContinue
        }
    }
}

function Test-ServiceDisabled([string[]]$Names) {
    $present = @(Get-ServiceState $Names)
    if ($present.Count -eq 0) { return $false }
    -not ($present | Where-Object { $_.StartMode -ne 'Disabled' })
}

function Get-BloatServiceName {
    $names = @('RetailDemo', 'MapsBroker')
    # Killing the spooler on a machine with a printer breaks printing outright.
    $printers = @(Get-Printer -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch 'Microsoft (Print to PDF|XPS Document Writer)|OneNote|Fax' })
    if ($printers.Count -eq 0) { $names += 'Spooler' }
    $names
}

function Get-GpuMsiPath {
    Get-CimInstance Win32_PnPEntity -Filter "PNPClass='Display'" -ErrorAction SilentlyContinue |
        Where-Object { $_.PNPDeviceID -like 'PCI\*' } |
        ForEach-Object {
            "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        }
}

function Get-NvidiaTask {
    Get-ScheduledTask -ErrorAction SilentlyContinue |
        Where-Object { $_.TaskName -match 'NvTmRep|NvTmMon|NvTmRepOnLogon|NvDriverUpdate|NVIDIA GeForce Experience|NvProfileUpdater|NvNodeLauncher' }
}

function Get-NvidiaTaskState {
    foreach ($t in (Get-NvidiaTask)) {
        @{ TaskName = $t.TaskName; TaskPath = $t.TaskPath; State = [string]$t.State }
    }
}

#endregion

#region Engine

function Import-Backup([string]$Path) {
    if (-not (Test-Path $Path)) { return @{} }
    $raw = Get-Content -Path $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) { return @{} }
    $obj = $raw | ConvertFrom-Json
    $map = @{}
    foreach ($p in $obj.PSObject.Properties) { $map[$p.Name] = $p.Value }
    $map
}

function Export-Backup($Map, [string]$Path) {
    $dir = Split-Path -Parent $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Map | ConvertTo-Json -Depth 12 | Set-Content -Path $Path -Encoding UTF8
}

function Resolve-Selection([string[]]$Selection) {
    if ($Selection -contains 'all') { return $Tweaks }
    $picked = @()
    foreach ($s in $Selection) {
        $hits = @($Tweaks | Where-Object { $_.Id -eq $s -or $_.Category -eq $s })
        if ($hits.Count -eq 0) { throw "Unknown tweak or category: '$s'. Run -List to see what exists." }
        $picked += $hits
    }
    # Dedupe by id in table order. Sort-Object -Unique on a property does not see
    # hashtable keys on Windows PowerShell 5.1 and collapses everything to one entry.
    $seen = @{}
    foreach ($t in $picked) { $seen[$t.Id] = $true }
    $Tweaks | Where-Object { $seen.ContainsKey($_.Id) }
}

# A DWord reads back as Int32 on Windows PowerShell and UInt32 on PowerShell 7, so
# 0xFFFFFFFF compares as -1 on one and 4294967295 on the other. Compare the bits.
function Test-RegValueEqual([string]$Type, $Current, $Wanted) {
    if ($null -eq $Current) { return $false }
    if ($Type -eq 'DWord') {
        # 0xFFFFFFFF as a literal is Int32 -1, which masks nothing; spell the mask out.
        return ([int64]$Current -band 4294967295) -eq ([int64]$Wanted -band 4294967295)
    }
    $Current -eq $Wanted
}

function Test-TweakApplied($Tweak) {
    if ($Tweak.ContainsKey('Test')) { return [bool](& $Tweak.Test) }
    foreach ($r in $Tweak.Reg) {
        if (-not (Test-RegValueEqual $r.Type (Get-RegValue $r.Path $r.Name) $r.Value)) { return $false }
    }
    $true
}

function Invoke-TweakApply($Tweak, $Backup) {
    if ($Tweak.ContainsKey('Reg')) {
        $state = @{ Reg = @(foreach ($r in $Tweak.Reg) {
            @{ Path = $r.Path; Name = $r.Name; Type = $r.Type; Previous = (Get-RegValue $r.Path $r.Name) }
        }) }
    }
    else {
        $state = & $Tweak.Capture
    }

    # Capture first, store second, mutate last: a crash mid-apply still leaves a
    # backup that describes the machine before the change.
    $Backup[$Tweak.Id] = @{ CapturedAt = (Get-Date).ToString('o'); State = $state }
    Export-Backup $Backup $BackupPath

    if ($Tweak.ContainsKey('Reg')) {
        foreach ($r in $Tweak.Reg) { Set-RegValue $r.Path $r.Name $r.Type $r.Value }
    }
    else {
        & $Tweak.Set
    }
}

function Invoke-TweakRevert($Tweak, $Backup) {
    $entry = $Backup[$Tweak.Id]
    if (-not $entry) { throw "No backup recorded for '$($Tweak.Id)'." }
    $state = $entry.State

    if ($Tweak.ContainsKey('Reg')) {
        foreach ($r in $state.Reg) { Restore-RegValue $r.Path $r.Name $r.Type $r.Previous }
    }
    else {
        & $Tweak.Undo $state
    }
    $Backup.Remove($Tweak.Id)
    Export-Backup $Backup $BackupPath
}

function New-RestorePointSafely {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction Stop
        Checkpoint-Computer -Description 'Before Windows Tweaks' -RestorePointType 'MODIFY_SETTINGS' -ErrorAction Stop
        Write-Host 'Restore point created.' -ForegroundColor Green
    }
    catch {
        # Windows rate-limits restore points to one per 24h, and System Protection is
        # off by default on many installs. Neither is a reason to abort.
        Write-Warning "Could not create a restore point: $($_.Exception.Message)"
        Write-Warning 'The per-tweak backup file is still written. Continuing.'
    }
}

function Invoke-ApplySelected($Selected, $Backup) {
    Write-Host "About to apply $($Selected.Count) tweak(s):" -ForegroundColor Cyan
    $Selected | ForEach-Object { Write-Host "  [$($_.Risk.PadRight(6))] $($_.Id) - $($_.Title)" }
    Write-Host "Backup file: $BackupPath" -ForegroundColor DarkGray

    if (-not $NoRestorePoint -and $PSCmdlet.ShouldProcess('System', 'Create restore point')) {
        New-RestorePointSafely
    }

    $rebootNeeded = $false
    foreach ($t in $Selected) {
        if (-not $PSCmdlet.ShouldProcess($t.Id, 'Apply tweak')) { continue }
        try {
            Invoke-TweakApply $t $Backup
            Write-Host "  applied  $($t.Id)" -ForegroundColor Green
            if ($t.Reboot) { $rebootNeeded = $true }
        }
        catch {
            Write-Host "  FAILED   $($t.Id): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    if ($rebootNeeded) { Write-Host 'Reboot required for some of these to take effect.' -ForegroundColor Yellow }
}

function Invoke-RevertSelected($Selected, $Backup) {
    foreach ($t in $Selected) {
        if (-not $PSCmdlet.ShouldProcess($t.Id, 'Revert tweak')) { continue }
        try {
            Invoke-TweakRevert $t $Backup
            Write-Host "  reverted $($t.Id)" -ForegroundColor Green
        }
        catch {
            Write-Host "  FAILED   $($t.Id): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    Write-Host 'Reboot to fully restore the previous state.' -ForegroundColor Yellow
}

#endregion

#region Interactive UI

# The whole picker runs on the terminal's alternate screen buffer, so it takes over
# the window and the previous scrollback comes back untouched on exit.

$script:AltBufferActive = $false

function Enter-AltBuffer {
    $esc = [char]27
    try {
        if ($Host.UI.SupportsVirtualTerminal) {
            [Console]::Write("$esc[?1049h")
            $script:AltBufferActive = $true
        }
    }
    catch { }
    Clear-Host
    try { [Console]::CursorVisible = $false } catch { }
    try { [Console]::TreatControlCAsInput = $true } catch { }
}

function Exit-AltBuffer {
    $esc = [char]27
    try { [Console]::TreatControlCAsInput = $false } catch { }
    try { [Console]::CursorVisible = $true } catch { }
    if ($script:AltBufferActive) {
        [Console]::Write("$esc[?1049l")
        $script:AltBufferActive = $false
    }
    else {
        Clear-Host
    }
}

function Write-Seg([int]$X, [int]$Y, [string]$Text, $Fg, $Bg) {
    if ($X -lt 0 -or $Y -lt 0) { return }
    try { [Console]::SetCursorPosition($X, $Y) } catch { return }
    $splat = @{ Object = $Text; NoNewline = $true }
    if ($Fg) { $splat.ForegroundColor = $Fg }
    if ($Bg) { $splat.BackgroundColor = $Bg }
    Write-Host @splat
}

function Format-Fit([string]$Text, [int]$Width) {
    if ($Width -le 0) { return '' }
    if ($Text.Length -le $Width) { return $Text.PadRight($Width) }
    if ($Width -le 1) { return $Text.Substring(0, $Width) }
    $Text.Substring(0, $Width - 1) + '…'
}

function Get-RiskColor([string]$Risk) {
    switch ($Risk) {
        'Low'    { 'Green' }
        'Medium' { 'Yellow' }
        'High'   { 'Red' }
        default  { 'Gray' }
    }
}

# One flat list of header rows and tweak rows, in definition order.
function New-UIRow {
    $rows = @()
    foreach ($cat in ($Tweaks | ForEach-Object { $_.Category } | Select-Object -Unique)) {
        $rows += [PSCustomObject]@{ Kind = 'Header'; Category = $cat; Tweak = $null }
        foreach ($t in ($Tweaks | Where-Object { $_.Category -eq $cat })) {
            $rows += [PSCustomObject]@{ Kind = 'Tweak'; Category = $cat; Tweak = $t }
        }
    }
    $rows
}

function Get-TweakStatusMap {
    $map = @{}
    foreach ($t in $Tweaks) {
        $map[$t.Id] = try { [bool](Test-TweakApplied $t) } catch { $null }
    }
    $map
}

function Get-FrameLayout([int]$W, [int]$H, [int]$RowCount, [int]$YTop) {
    $boxW = [Math]::Min(76, $W - 4)
    $inner = $boxW - 2
    # 3 chrome lines above the list (border, title, separator) and 7 below it
    # (separator, 2 description lines, separator, 2 help lines, border), plus a row
    # of slack above and below so the frame never touches the console's last row.
    $viewH = [Math]::Min($RowCount, $H - 12)
    if ($viewH -lt 4) { $viewH = 4 }
    $boxH = $viewH + 10
    @{
        BoxW  = $boxW
        Inner = $inner
        ViewH = $viewH
        BoxH  = $boxH
        Left  = [Math]::Max(0, [int](($W - $boxW) / 2))
        Top   = $YTop + [Math]::Max(0, [int](($H - $boxH) / 2))
        # mark (4) + risk (8) + state (8), plus one leading space column.
        IdW   = $inner - 21
    }
}

function Write-TweakFrame($Rows, [int]$Cursor, [int]$Offset, $Selected, $Status, $Layout) {
    $left = $Layout.Left
    $top = $Layout.Top
    $boxW = $Layout.BoxW
    $inner = $Layout.Inner
    $viewH = $Layout.ViewH
    $idW = $Layout.IdW

    $chosenCount = @($Tweaks | Where-Object { $Selected[$_.Id] }).Count
    $onCount = @($Tweaks | Where-Object { $Status[$_.Id] -eq $true }).Count

    Write-Seg $left $top ('╔' + ('═' * $inner) + '╗') 'DarkCyan' $null

    $titleLeft = ' Tweak Collection'
    $titleRight = "$chosenCount selected · $onCount applied "
    $pad = $inner - $titleLeft.Length - $titleRight.Length
    if ($pad -lt 1) { $pad = 1; $titleRight = '' }
    Write-Seg $left ($top + 1) '║' 'DarkCyan' $null
    Write-Seg ($left + 1) ($top + 1) (Format-Fit $titleLeft ($inner - $pad - $titleRight.Length)) 'White' $null
    Write-Seg ($left + 1 + $titleLeft.Length) ($top + 1) ((' ' * $pad) + $titleRight) 'DarkGray' $null
    Write-Seg ($left + $boxW - 1) ($top + 1) '║' 'DarkCyan' $null

    $sepTop = '╟' + ('─' * $inner) + '╢'
    if ($Rows.Count -gt $viewH) {
        $note = " $($Offset + 1)-$([Math]::Min($Offset + $viewH, $Rows.Count)) of $($Rows.Count) "
        if ($note.Length -lt $inner - 2) {
            $sepTop = '╟' + ('─' * ($inner - $note.Length - 1)) + $note + '─╢'
        }
    }
    Write-Seg $left ($top + 2) $sepTop 'DarkCyan' $null

    for ($i = 0; $i -lt $viewH; $i++) {
        $y = $top + 3 + $i
        $idx = $Offset + $i
        Write-Seg $left $y '║' 'DarkCyan' $null
        Write-Seg ($left + $boxW - 1) $y '║' 'DarkCyan' $null

        if ($idx -ge $Rows.Count) {
            Write-Seg ($left + 1) $y (' ' * $inner) $null $null
            continue
        }

        $row = $Rows[$idx]
        if ($row.Kind -eq 'Header') {
            Write-Seg ($left + 1) $y (Format-Fit ('  ' + $row.Category.ToUpper()) $inner) 'DarkCyan' $null
            continue
        }

        $t = $row.Tweak
        $bg = if ($idx -eq $Cursor) { 'DarkBlue' } else { $null }
        $state = if ($Status[$t.Id] -eq $true) { 'applied' }
            elseif ($null -eq $Status[$t.Id]) { 'error' }
            else { '' }
        $mark = if ($Selected[$t.Id]) { '[x]' } else { '[ ]' }
        $markFg = if ($Selected[$t.Id]) { 'Cyan' } else { 'DarkGray' }
        $stateFg = if ($state -eq 'error') { 'Red' } else { 'Green' }

        Write-Seg ($left + 1) $y (' ' * $inner) $null $bg
        Write-Seg ($left + 2) $y $mark $markFg $bg
        Write-Seg ($left + 6) $y (Format-Fit $t.Id $idW) 'White' $bg
        Write-Seg ($left + 6 + $idW) $y (Format-Fit $t.Risk 8) (Get-RiskColor $t.Risk) $bg
        Write-Seg ($left + 6 + $idW + 8) $y (Format-Fit $state 8) $stateFg $bg
    }

    $yFoot = $top + 3 + $viewH
    Write-Seg $left $yFoot ('╟' + ('─' * $inner) + '╢') 'DarkCyan' $null

    # Whatever is under the cursor gets described, so nothing is picked blind.
    $cur = $Rows[$Cursor].Tweak
    if ($null -eq $cur) {
        # The cursor only ever lands on tweak rows, but a frame is not worth a crash.
        $descTitle = '  ' + $Rows[$Cursor].Category.ToUpper()
        $descMeta = ''
    }
    else {
        $reboot = if ($cur.Reboot) { 'reboot needed' } else { 'no reboot' }
        $descTitle = '  ' + $cur.Title
        $descMeta = "  $($cur.Evidence) · $reboot"
    }
    $lines = @(
        @{ Text = $descTitle; Fg = 'Gray' }
        @{ Text = $descMeta; Fg = 'DarkGray' }
        @{ Text = $null; Fg = $null }
        @{ Text = '  ↑↓ move   space select   a all   n none   c category'; Fg = 'DarkGray' }
        @{ Text = '  enter apply   d dry-run   r revert   s refresh   q quit'; Fg = 'DarkGray' }
    )
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $y = $yFoot + 1 + $i
        if ($null -eq $lines[$i].Text) {
            Write-Seg $left $y ('╟' + ('─' * $inner) + '╢') 'DarkCyan' $null
            continue
        }
        Write-Seg $left $y '║' 'DarkCyan' $null
        Write-Seg ($left + 1) $y (Format-Fit $lines[$i].Text $inner) $lines[$i].Fg $null
        Write-Seg ($left + $boxW - 1) $y '║' 'DarkCyan' $null
    }

    Write-Seg $left ($yFoot + 6) ('╚' + ('═' * $inner) + '╝') 'DarkCyan' $null
}

function Confirm-Apply($Selected) {
    Write-Host ''
    Write-Host "  These $($Selected.Count) tweak(s) will be applied:" -ForegroundColor Cyan
    Write-Host ''
    foreach ($t in $Selected) {
        Write-Host ("    {0,-8} {1,-32} {2}" -f $t.Risk, $t.Id, $t.Title) -ForegroundColor (Get-RiskColor $t.Risk)
    }
    Write-Host ''
    if ($Selected | Where-Object { $_.Reboot }) {
        Write-Host '  Some of these need a reboot to take effect.' -ForegroundColor Yellow
    }
    Write-Host "  Previous values are saved to $BackupPath" -ForegroundColor DarkGray
    Write-Host ''
    $answer = Read-Host '  Apply? [y/N]'
    if ($answer -notmatch '^\s*y') {
        Write-Host '  Cancelled — nothing was changed.' -ForegroundColor Yellow
        Start-Sleep -Milliseconds 700
        return $false
    }
    $true
}

function Show-TweakUI($Backup) {
    if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) {
        throw 'The interactive picker needs a real console. Use -List, -Status, -Apply or -Revert instead.'
    }

    $rows = @(New-UIRow)
    $selected = @{}
    foreach ($t in $Tweaks) { $selected[$t.Id] = $false }

    Clear-Host
    Write-Host ''
    Write-Host '  Reading current system state…' -ForegroundColor DarkGray
    $status = Get-TweakStatusMap

    Enter-AltBuffer
    try {
        $cursor = 0
        while ($rows[$cursor].Kind -ne 'Tweak') { $cursor++ }
        $offset = 0
        $lastW = -1
        $lastH = -1

        while ($true) {
            $w = [Console]::WindowWidth
            $h = [Console]::WindowHeight
            $yTop = 0
            try { $yTop = [Console]::WindowTop } catch { }

            if ($w -lt 62 -or $h -lt 16) {
                Clear-Host
                Write-Seg 0 $yTop 'Terminal too small — resize to at least 62x16.' 'Yellow' $null
                $null = [Console]::ReadKey($true)
                continue
            }

            $layout = Get-FrameLayout $w $h $rows.Count $yTop

            # Keep the cursor inside the viewport.
            if ($cursor -lt $offset) { $offset = $cursor }
            if ($cursor -ge $offset + $layout.ViewH) { $offset = $cursor - $layout.ViewH + 1 }
            $maxOffset = [Math]::Max(0, $rows.Count - $layout.ViewH)
            if ($offset -gt $maxOffset) { $offset = $maxOffset }
            if ($offset -lt 0) { $offset = 0 }

            if ($w -ne $lastW -or $h -ne $lastH) {
                Clear-Host
                $lastW = $w
                $lastH = $h
            }

            $viewH = $layout.ViewH
            $chosen = @($Tweaks | Where-Object { $selected[$_.Id] })

            Write-TweakFrame $rows $cursor $offset $selected $status $layout

            $key = [Console]::ReadKey($true)

            # Ctrl+C reaches us as input because TreatControlCAsInput is on.
            if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq 'C') { return }

            $moved = 0
            switch ($key.Key) {
                'UpArrow'   { $moved = -1 }
                'DownArrow' { $moved = 1 }
                'PageUp'    { $moved = -$viewH }
                'PageDown'  { $moved = $viewH }
                'Home'      { $cursor = 0; $moved = 1 }
                'End'       { $cursor = $rows.Count - 1; $moved = 0 }
                'Escape'    { return }
                'Spacebar'  {
                    $id = $rows[$cursor].Tweak.Id
                    $selected[$id] = -not $selected[$id]
                    $moved = 1
                }
                'Enter' {
                    if ($chosen.Count -eq 0) { break }
                    Exit-AltBuffer
                    if (-not (Confirm-Apply $chosen)) {
                        Enter-AltBuffer
                        $lastW = -1
                        break
                    }
                    Invoke-ApplySelected $chosen $Backup
                    Write-Host ''
                    Write-Host 'Press any key to return to the menu…' -ForegroundColor DarkGray
                    $null = [Console]::ReadKey($true)
                    $status = Get-TweakStatusMap
                    foreach ($t in $Tweaks) { $selected[$t.Id] = $false }
                    Enter-AltBuffer
                    $lastW = -1
                }
            }

            switch ($key.KeyChar) {
                'k' { $moved = -1 }
                'j' { $moved = 1 }
                'q' { return }
                'a' { foreach ($t in $Tweaks) { $selected[$t.Id] = $true } }
                'n' { foreach ($t in $Tweaks) { $selected[$t.Id] = $false } }
                'c' {
                    # Toggle the whole category the cursor is in.
                    $cat = $rows[$cursor].Category
                    $inCat = @($Tweaks | Where-Object { $_.Category -eq $cat })
                    $turnOn = @($inCat | Where-Object { -not $selected[$_.Id] }).Count -gt 0
                    foreach ($t in $inCat) { $selected[$t.Id] = $turnOn }
                }
                's' { $status = Get-TweakStatusMap }
                'd' {
                    if ($chosen.Count -eq 0) { break }
                    Exit-AltBuffer
                    # ShouldProcess reads $WhatIfPreference, so this reuses the real path.
                    $WhatIfPreference = $true
                    try { Invoke-ApplySelected $chosen $Backup }
                    finally { $WhatIfPreference = $false }
                    Write-Host ''
                    Write-Host 'Dry run only — nothing was changed. Press any key…' -ForegroundColor DarkGray
                    $null = [Console]::ReadKey($true)
                    Enter-AltBuffer
                    $lastW = -1
                }
                'r' {
                    $revertable = @($chosen | Where-Object { $Backup.ContainsKey($_.Id) })
                    Exit-AltBuffer
                    if ($revertable.Count -eq 0) {
                        Write-Host 'None of the selected tweaks have a backup entry to revert.' -ForegroundColor Yellow
                    }
                    else {
                        Invoke-RevertSelected $revertable $Backup
                    }
                    Write-Host ''
                    Write-Host 'Press any key to return to the menu…' -ForegroundColor DarkGray
                    $null = [Console]::ReadKey($true)
                    $status = Get-TweakStatusMap
                    Enter-AltBuffer
                    $lastW = -1
                }
            }

            if ($moved -ne 0) {
                $step = if ($moved -gt 0) { 1 } else { -1 }
                $target = [Math]::Max(0, [Math]::Min($rows.Count - 1, $cursor + $moved))
                # Headers are not selectable — keep walking past them.
                while ($target -ge 0 -and $target -lt $rows.Count -and $rows[$target].Kind -ne 'Tweak') {
                    $target += $step
                }
                if ($target -ge 0 -and $target -lt $rows.Count) { $cursor = $target }
            }
        }
    }
    finally {
        Exit-AltBuffer
    }
}

#endregion

#region Entry points

if ($List) {
    $Tweaks | ForEach-Object {
        [PSCustomObject]@{
            Id       = $_.Id
            Category = $_.Category
            Risk     = $_.Risk
            Reboot   = if ($_.Reboot) { 'yes' } else { 'no' }
            Title    = $_.Title
        }
    } | Format-Table -AutoSize -Wrap
    Write-Host 'Rationale and evidence for each tweak: https://slix1337x.github.io/Tweak-Collection/' -ForegroundColor DarkGray
    return
}

if (-not (Test-Admin)) {
    # The picker reads live system state, so it needs elevation. Offer to get it
    # rather than dying in a console window that closes before anyone can read why.
    if ($PSCmdlet.ParameterSetName -eq 'UI' -and -not [Console]::IsInputRedirected) {
        Write-Host ''
        Write-Host '  Administrator rights are needed to read and change system settings.' -ForegroundColor Yellow
        Write-Host '  Asking Windows to reopen this elevated...' -ForegroundColor DarkGray
        try {
            Request-Elevation $PSCommandPath $PSBoundParameters
            return
        }
        catch {
            Write-Host ''
            Write-Host "  Elevation was declined: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host ''
    Write-Host '  This needs an elevated PowerShell session (Run as administrator).' -ForegroundColor Red
    Write-Host '  .\Tweaks.ps1 -List works without it.' -ForegroundColor DarkGray
    Wait-BeforeClosing
    exit 1
}

if ($Status) {
    $Tweaks | ForEach-Object {
        $applied = try { Test-TweakApplied $_ } catch { $null }
        [PSCustomObject]@{
            Id      = $_.Id
            Applied = if ($null -eq $applied) { 'error' } elseif ($applied) { 'yes' } else { 'no' }
            Title   = $_.Title
        }
    } | Format-Table -AutoSize -Wrap
    return
}

$backup = Import-Backup $BackupPath

if ($Apply) {
    Invoke-ApplySelected (Resolve-Selection $Apply) $backup
    return
}

if ($Revert) {
    $selected = if ($Revert -contains 'all') {
        @($Tweaks | Where-Object { $backup.ContainsKey($_.Id) })
    }
    else {
        Resolve-Selection $Revert
    }

    if ($selected.Count -eq 0) {
        Write-Host "Nothing to revert — no matching entries in $BackupPath." -ForegroundColor Yellow
        return
    }

    Invoke-RevertSelected $selected $backup
    return
}

try {
    Show-TweakUI $backup
}
catch {
    Write-Host ''
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
    Wait-BeforeClosing
    exit 1
}

#endregion
