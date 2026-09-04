---
title: Input
description: Mouse and keyboard settings that change what the machine does with your input, and the ones that only look like they do.
sidebar:
  order: 1
tags:
  - input
  - latency
  - measurement
---

Input is the category with the highest ratio of advice to evidence on the whole
internet. What follows is split by what can actually be shown.

## Enhance pointer precision — turn it off

Settings → Bluetooth & devices → Mouse → Additional mouse settings → Pointer
Options.

This is mouse acceleration. With it on, the pointer distance depends on how fast
you moved, not only how far, so the same physical movement gives a different result
depending on speed. Every attempt at muscle memory is fighting it.

```powershell
# 0 0 0 disables the acceleration curve entirely
Get-ItemProperty 'HKCU:\Control Panel\Mouse' |
  Select-Object MouseSpeed, MouseThreshold1, MouseThreshold2
```

Most games using raw input bypass this anyway, so the effect is mostly on the
desktop and in games that read the cursor rather than the device.

## Pointer speed — leave it at 6/11

The slider in the same dialog. Position 6 of 11 is 1:1 — every mouse count moves
the pointer one unit. Every other position multiplies, and the multipliers below 6
are fractions, which means counts get dropped and the pointer skips.

If the pointer is too fast or too slow, change the mouse's DPI, not this slider.

## Polling rate — higher is not automatically better

Polling rate is how often the mouse reports. At 1000 Hz a report arrives every
1 ms, so the worst case for "the mouse noticed but Windows has not" is 1 ms.

- **125 Hz → 1000 Hz** is a real, measurable reduction of an 8 ms worst case to
  1 ms. Worth doing.
- **1000 Hz → 4000/8000 Hz** takes 1 ms to 0.25 ms or 0.125 ms. The remaining
  saving is a quarter of a millisecond, and the cost is a large increase in USB
  interrupts. On some systems 8 kHz polling produces measurable frame-time spikes
  and higher DPC latency, because the interrupt load lands on whichever core the
  USB controller is bound to.

If you run 4 kHz or 8 kHz, verify it with a frame-time capture rather than
assuming. This is one of the few places where a latency setting can cost frames.

## USB port choice

Rear ports are wired to the chipset or directly to the CPU; front-panel ports go
through an internal header and often a hub. A hub adds a store-and-forward step to
every report.

Plug the mouse and keyboard into rear ports, and preferably not into the same hub
as a device that streams — a webcam or an audio interface saturating a shared
controller shows up as input hitching.

## Power management on the USB stack

Selective suspend and device idle states let Windows put a port or a device into a
low-power state between reports, and waking it delays the next one. This is what
[`power.usb-suspend-off`](../../tweaks/power/#power.usb-suspend-off) turns off at
the global level, and what
[USB-LatencySuite](../../tools/usb-latency-suite/) turns off per device and per
driver.

## What does not work

| Claim | Reality |
| --- | --- |
| `MouseDataQueueSize` / `KeyboardDataQueueSize` | A buffer depth in packets, not a polling interval and not a delay. Covered in [debunked: scheduler](../../reference/debunked/scheduler/). |
| Mouse "filter drivers" removed for latency | The class driver is not what is holding your input. |
| Disabling the HID service | Breaks device enumeration to save nothing. |
| Registry "mouse fix" bundles | Almost all of them are the 6/11 slider and acceleration, written blind into keys that may not exist on your build. |

## Measuring it honestly

The only end-to-end measurement is a camera or a hardware latency tool. A
high-speed phone camera at 240 fps pointed at the screen and the mouse gives you
±4 ms, which is enough to tell a real change from a placebo — and more than enough
to show that most of what is in this category is a placebo.

The measures that dominate real input latency, in order: your frame rate cap
relative to refresh rate, whether V-Sync is on, whether the game's low-latency mode
(Reflex, Anti-Lag) is on, and your monitor's processing lag. Everything on this
page is smaller than all four.
