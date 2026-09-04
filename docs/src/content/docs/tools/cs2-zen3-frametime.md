---
title: CS2 Zen3 Frametime.pow
description: An exported power plan for a Ryzen 5950X desktop — Ultimate Performance plus a handful of deliberate changes, with every difference listed.
sidebar:
  order: 6
tags:
  - power
  - latency
---

An exported power plan for a Ryzen 5950X desktop, saved so it survives a reinstall.
It is [Ultimate Performance](../../tweaks/power/#power.ultimate)
underneath, and this page lists everything that differs from it, so the file is not
a black box.

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

`powercfg /import` never overwrites an existing scheme — it always creates a new one
with a fresh GUID, so importing twice gives you two copies. Delete the spare.

## What differs from Ultimate Performance

Produced by importing the file into a scratch scheme and diffing `powercfg /qh`
against the stock Ultimate Performance scheme, hidden settings included. Everything
not listed here is identical to Ultimate. AC values only; this is a desktop.

### Deliberate

| Setting | This plan | Ultimate | Why |
| --- | --- | --- | --- |
| Minimum processor state | 5 % | 100 % | Lets idle cores drop their clock instead of holding P0. On Zen 3 the SMU decides the actual frequency anyway; this stops Windows requesting maximum on every core all the time, which costs idle heat. |
| Processor performance boost policy | 60 % | 100 % | How far above nominal Windows lets the processor boost opportunistically. Lower means a narrower band of frequency swings at the cost of the highest peak clock. |
| USB selective suspend | Off | On | Same reasoning as [`power.usb-suspend-off`](../../tweaks/power/#power.usb-suspend-off); baked into the plan so it survives a plan switch. |
| Turn off display after | Never | 15 min | A monitor waking up mid-session is a stutter and a black screen. |
| Display brightness | 75 % | 100 % | Only means something on a panel Windows can dim. Harmless on a desktop monitor. |

### Core parking timings — inert as long as parking is off

| Setting | This plan | Ultimate |
| --- | --- | --- |
| Core parking min cores | 100 % | 100 % |
| Core parking increase time | 3 intervals | 7 |
| Core parking decrease time | 10 intervals | 20 |
| Core parking overutilization threshold | 85 % | 60 % |

Both plans keep every core unparked, so the three timing values below the first
row never fire. They cost nothing and do nothing.

### Efficiency-class settings — ignored on a 5950X

| Setting | This plan | Ultimate |
| --- | --- | --- |
| Minimum processor state, class 1 and 2 | 5 % | 100 % |
| Energy performance preference, class 1 and 2 | 33 % | 0 % |

"Processor Power Efficiency Class 1 / 2" are the extra cores on a heterogeneous
CPU — Intel E-cores, Arm little cores. A 5950X has one class, so Windows never
consults these. Listed because they show up in the diff, not because they matter.

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

These are the stock **Balanced** values. Ultimate sets the storage ones to
"never sleep the link", which is the stricter choice for a desktop chasing DPC
latency — it is what
[`power.pcie-aspm-off`](../../tweaks/power/#power.pcie-aspm-off)
does for PCIe. This plan does not: the plan type says Balanced, so it was built
from a Balanced copy and the disk subgroup kept those defaults. If LatencyMon points at
`storport.sys` or `stornvme.sys` on your machine, set these to `0` before blaming
anything else:

```powershell
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK 0b2d69d7-a2a1-449c-9680-f91c70521c60 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK dab60367-53fe-4fbc-825e-521d069d2456 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK fc95af4d-40e7-4b6d-835a-56d131dbc80e 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_DISK dbc9e238-6de9-49e3-92cd-8c2b4946b472 0
powercfg /setactive SCHEME_CURRENT
```

**Power plan type** is the "personality" Windows reports for the scheme. It changes
what the Power Options dialog calls it and which built-in plan Windows treats it as
derived from; it does not itself change any processor or device behaviour.

## Rebuilding it without the file

The deliberate part is four `powercfg` lines on top of Ultimate Performance
(brightness left out; it does nothing on a desktop monitor):

```powershell
powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR PROCTHROTTLEMIN 5
powercfg /setacvalueindex SCHEME_CURRENT SUB_PROCESSOR 45bcc044-d885-43e2-8605-ee0ec6e96b59 60   # boost policy, no alias
powercfg /setacvalueindex SCHEME_CURRENT 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb8f07e226 0
powercfg /setacvalueindex SCHEME_CURRENT SUB_VIDEO VIDEOIDLE 0
powercfg /setactive SCHEME_CURRENT
```

That gives you the same thing minus the inherited Balanced storage values, which is
arguably the better version.

## What it costs

- **Idle power is lower than Ultimate**, not higher: the 5 % minimum state lets
  cores idle down. The trade is a few microseconds of ramp on the first burst of
  work after idle, which is what Ultimate's 100 % was there to avoid. Whether that
  ramp shows up in a frame-time capture is worth checking on your own machine.
- **Peak clock may be slightly lower** under the 60 % boost policy. If you want
  the last 100 MHz back, set it to 100.
- **The monitor never turns off on its own.** Lock the machine or turn it off by
  hand.

## Undo

```powershell
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e   # Balanced, or any other GUID from /list
powercfg /delete <guid of the imported plan>
```

Switching the active scheme is the whole undo; deleting the scheme is tidiness. No
registry outside the power subsystem is touched.

:::note[Laptops]
Not for a laptop. The DC half of the file is stock Balanced and was never tuned, and
"display never off" on battery is a bad idea. Use it as a reference for the AC
values, not as a plan to import.
:::
