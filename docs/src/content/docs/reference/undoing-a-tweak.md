---
title: Undoing a tweak
description: Getting back to a clean state by hand, from a restore point, or from a script's backup.
sidebar:
  order: 3
tags:
  - registry
  - services
  - power
---

The Windows defaults, so they can be restored by hand without the original tool
present.

## By hand

### Registry values

Anything under `HKLM:\SOFTWARE\Policies\` is a policy value. **Deleting it returns
Windows to its default** without needing to know what that default was. That covers
every tweak on the [privacy page](../../tweaks/privacy/) and the machine-wide half of
Game DVR.

Values that overwrite a default Windows already set need the original value restored:

| Value | Windows default |
| --- | --- |
| `SystemResponsiveness` | `20` |
| `NetworkThrottlingIndex` | `10` |
| `HiberbootEnabled` | `1` |
| `GameDVR_Enabled` (HKCU) | `1` |
| MMCSS `Games\GPU Priority` | `8` |
| MMCSS `Games\Priority` | `2` |
| MMCSS `Games\Scheduling Category` | `Medium` |
| MMCSS `Games\SFIO Priority` | `Normal` |
| `TcpAckFrequency` (per interface) | value absent |
| `TCPNoDelay` (per interface) | value absent |
| `MSISupported` | value absent |

"Value absent" means Windows never wrote one, so deleting it is the correct undo, not
setting it to zero.

The MMCSS `Games` rows are listed because a stock Windows install ships them and tweak
guides overwrite them. Nothing reads two of them (see
[MMCSS `GPU Priority` and `SFIO Priority`](../debunked/scheduler/#mmcss-gpu-priority-and-sfio-priority--invalid)),
but restoring the stock values is still the correct undo.

### Services

```powershell
# check what a service is set to
Get-Service DiagTrack | Select-Object Name, StartType

# put one back
Set-Service -Name DiagTrack -StartupType Automatic
```

Windows defaults for the services anything here touches:

| Service | Default startup |
| --- | --- |
| `DiagTrack` | Automatic |
| `dmwappushservice` | Manual |
| `RetailDemo` | Manual |
| `MapsBroker` | Automatic (Delayed Start) |
| `Spooler` | Automatic |

### Power plans

```powershell
powercfg /restoredefaultschemes
```

Removes custom and duplicated schemes, including the Ultimate Performance plan,
and resets the built-in ones to their defaults.

### NVIDIA scheduled tasks

```powershell
Get-ScheduledTask | Where-Object TaskName -match 'NvTm|NvDriverUpdate|GeForce' |
  Enable-ScheduledTask
```

### Network adapters

Resets every advanced property, IP configuration and protocol binding on every adapter
to driver defaults:

```powershell
netcfg -d
```

Reboot immediately afterwards.

:::danger
`netcfg -d` drops all network configuration on the machine. Do not run it over a
remote session, and do not run it on a machine with static IP settings that have not
been written down first.
:::

## From a system restore point

```powershell
Get-ComputerRestorePoint
```

Then restore through **System Properties → System Protection → System Restore**.

System Protection is off by default on many installs, and Windows rate-limits restore
points to one per 24 hours, so an assumed restore point may not exist.

## If the machine will not boot

The only change here with a real chance of causing that is
[MSI mode](../../tweaks/nvidia/#nvidia.msi-mode), on unusual hardware.

1. Interrupt boot twice to reach the recovery environment, then **Troubleshoot →
   Advanced options → Startup Settings → Safe Mode**.
2. In Safe Mode, delete the `MSISupported` value under
   `HKLM\SYSTEM\CurrentControlSet\Enum\PCI\<GPU device>\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties`.
3. Reboot normally.
