---
title: Undoing a tweak
description: Getting back to a clean state — by hand, from a restore point, or from a script's backup.
sidebar:
  order: 3
tags:
  - registry
  - services
  - power
---

Nothing in this collection is meant to be a one-way door. However a change was
applied, there is a route back.

This page is the generic one: what the Windows defaults actually are, so you can put
them back yourself without needing anything you ran to still be around.

## By hand

The route that always works, and the only one that still works years later.

### Registry values

Anything under `HKLM:\SOFTWARE\Policies\` is a policy value. **Delete it and Windows
falls straight back to its default** — no need to know what the default was. That
covers every tweak on the [privacy page](../../tweaks/privacy/) and the machine-wide
half of Game DVR.

The values that are *not* safe to simply delete are the ones that overwrite a
default Windows already set. Those need the original value putting back:

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

"Value absent" means Windows never wrote one — so deleting it is the correct undo,
not setting it to zero.

The three MMCSS `Games` rows are still listed because a stock Windows install does
ship them and tweak guides routinely overwrite them. Nothing reads two of
them — see [MMCSS `GPU Priority` and `SFIO
Priority`](../debunked/scheduler/#mmcss-gpu-priority-and-sfio-priority--invalid) — but putting
the stock values back is still the right undo.

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

Removes custom and duplicated schemes — including the Ultimate Performance plan —
and resets the built-in ones to their defaults.

### NVIDIA scheduled tasks

```powershell
Get-ScheduledTask | Where-Object TaskName -match 'NvTm|NvDriverUpdate|GeForce' |
  Enable-ScheduledTask
```

### Network adapters

The blunt instrument. Resets every advanced property, IP configuration and protocol
binding on every adapter back to driver defaults:

```powershell
netcfg -d
```

Reboot immediately afterwards.

:::danger
`netcfg -d` drops all network configuration on the machine. Do not run it over a
remote session, and do not run it on a machine with static IP settings you have not
written down first.
:::

## From a system restore point

Faster than picking through values by hand, if a suitable point still exists.

```powershell
Get-ComputerRestorePoint
```

Then restore through **System Properties → System Protection → System Restore**.

Worth checking first: System Protection is off by default on a lot of installs, and
Windows rate-limits restore points to one per 24 hours, so the point you assume is
there may not be.

## If the machine will not boot

The only change in this collection with any real chance of causing that is
[MSI mode](../../tweaks/nvidia/#nvidia.msi-mode), and
only on unusual hardware.

1. Interrupt boot twice to reach the recovery environment, then **Troubleshoot →
   Advanced options → Startup Settings → Safe Mode**.
2. In Safe Mode, delete the `MSISupported` value under
   `HKLM\SYSTEM\CurrentControlSet\Enum\PCI\<your GPU>\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties`.
3. Reboot normally.
