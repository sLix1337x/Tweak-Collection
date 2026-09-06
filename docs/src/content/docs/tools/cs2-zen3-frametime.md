---
title: CS2 Zen3 Frametime.pow
description: An exported power plan for a Ryzen 5950X desktop. Ultimate Performance plus a handful of deliberate changes, with every difference listed.
sidebar:
  order: 6
tags:
  - power
  - latency
---

An exported power plan for a Ryzen 5950X desktop.
[Ultimate Performance](../../tweaks/power/#power.ultimate) underneath; every difference
is listed below.

The plan is one step of the [CS2 build order](../../cs2/#build-order) and on its own is
worth less than the [frame-cap decision](../../cs2/frame-cap/).

```text
scripts/power-plans/
  CS2 Zen3 Frametime.pow   the export
  README.md                import / undo commands
```

## Import

```powershell
cd Tweak-Collection/scripts/power-plans
powercfg /import "CS2 Zen3 Frametime.pow"     # prints the new scheme's GUID
powercfg /setactive <guid>
```

`powercfg /import` never overwrites an existing scheme — it creates a new one with a
fresh GUID, so importing twice leaves two copies.

## What differs from Ultimate Performance

Produced by importing the file into a scratch scheme and diffing `powercfg /qh` against
the stock Ultimate Performance scheme, hidden settings included. Everything not listed
is identical to Ultimate. AC values only.

### Deliberate

| Setting | This plan | Ultimate | Why |
| --- | --- | --- | --- |
| Minimum processor state | 5 % | 100 % | Lets idle cores drop their clock instead of holding P0. On Zen 3 the SMU decides the actual frequency anyway; this stops Windows requesting maximum on every core continuously, which costs idle heat. |
| Processor performance boost policy | 60 % | 100 % | How far above nominal Windows lets the processor boost opportunistically. Lower narrows the band of frequency swings at the cost of peak clock. |
| USB selective suspend | Off | On | As [`power.usb-suspend-off`](../../tweaks/power/#power.usb-suspend-off), baked into the plan so it survives a plan switch. |
| Turn off display after | Never | 15 min | A monitor waking mid-session is a stutter and a black screen. |
| Display brightness | 75 % | 100 % | Applies only to a panel Windows can dim. |

### Core parking timings — inert as long as parking is off

| Setting | This plan | Ultimate |
| --- | --- | --- |
| Core parking min cores | 100 % | 100 % |
| Core parking increase time | 3 intervals | 7 |
| Core parking decrease time | 10 intervals | 20 |
| Core parking overutilization threshold | 85 % | 60 % |

Both plans keep every core unparked, so the three timing values never fire.

### Efficiency-class settings — ignored on a 5950X

| Setting | This plan | Ultimate |
| --- | --- | --- |
| Minimum processor state, class 1 and 2 | 5 % | 100 % |
| Energy performance preference, class 1 and 2 | 33 % | 0 % |

"Processor Power Efficiency Class 1 / 2" are the extra cores on a heterogeneous CPU:
Intel E-cores, Arm little cores. A 5950X has one class, so Windows never consults
these. Listed because they appear in the diff.

### Inherited from Balanced, not chosen

| Setting | This plan | Ultimate |
| --- | --- | --- |
| Power plan type | Balanced | High performance |
| AHCI link power management | HIPM | Active |
| AHCI link power management, adaptive | 100 ms | 0 |
| NVMe power state transition latency tolerance, primary / secondary | 15 ms / 100 ms | 0 / 0 |
| Allow sleep with remote opens | Yes | No |
| Dim display after | 585 s | 885 s |
| Energy saver display brightness weight | 70 % | 100 % |

These are the stock **Balanced** values. Ultimate sets the storage ones to "never sleep
the link", the stricter choice for a desktop chasing DPC latency, and the equivalent of
[`power.pcie-aspm-off`](../../tweaks/power/#power.pcie-aspm-off) for PCIe. This plan
was built from a Balanced copy, so the disk subgroup kept the Balanced defaults. Where
LatencyMon points at `storport.sys` or `stornvme.sys`, set these to `0`:

```powershell
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK 0b2d69d7-a2a1-449c-9680-f91c70521c60 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK dab60367-53fe-4fbc-825e-521d069d2456 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK fc95af4d-40e7-4b6d-835a-56d131dbc80e 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK dbc9e238-6de9-49e3-92cd-8c2b4946b472 0
powercfg /setactive SCHEME_CURRENT
```

**Power plan type** is the personality Windows reports for the scheme. It changes what
the Power Options dialog calls it and which built-in plan Windows treats it as derived
from; it does not change processor or device behaviour.

## Rebuilding it without the file

Four `powercfg` lines on top of Ultimate Performance (brightness omitted — no effect on
a desktop monitor):

```powershell
powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR 45bcc044-d885-43e2-8605-ee0ec6e96b59 60   # boost policy, no alias
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 0
powercfg /setactive SCHEME_CURRENT
```

This produces the same plan without the inherited Balanced storage values.

## What it costs

- **Idle power is lower than Ultimate**, not higher: the 5 % minimum state lets cores
  idle down. The trade is a few microseconds of ramp on the first burst of work after
  idle, which Ultimate's 100 % avoids. Check per machine whether that ramp appears in a
  frame-time capture.
- **Peak clock may be slightly lower** under the 60 % boost policy. Setting it to 100
  returns the last 100 MHz.
- **The monitor never turns off on its own.**

## Undo

```powershell
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e   # Balanced, or any other GUID from /list
powercfg /delete <guid of the imported plan>
```

Switching the active scheme is the undo; deleting the scheme is tidiness. No registry
outside the power subsystem is touched.

:::note[Laptops]
Not for a laptop. The DC half of the file is stock Balanced and untuned, and "display
never off" on battery is wrong. Use it as a reference for the AC values.
:::
