---
title: Input
description: Mouse and keyboard settings that change what the machine does with input, and the ones that only look like they do.
sidebar:
  order: 1
tags:
  - input
  - latency
  - measurement
---

## Enhance pointer precision — turn it off

Settings → Bluetooth & devices → Mouse → Additional mouse settings → Pointer Options.

This is mouse acceleration: pointer distance depends on how fast the mouse moved, not
only how far, so the same physical movement gives a different result at a different
speed.

```powershell
# 0 0 0 disables the acceleration curve entirely
Get-ItemProperty 'HKCU:\Control Panel\Mouse' |
  Select-Object MouseSpeed, MouseThreshold1, MouseThreshold2
```

Games using raw input bypass this, so the effect is on the desktop and in games that
read the cursor rather than the device.

## Pointer speed — leave it at 6/11

The slider in the same dialog. Position 6 of 11 is 1:1: every mouse count moves the
pointer one unit. Every other position multiplies, and multipliers below 6 are
fractions, so counts are dropped and the pointer skips.

Change the mouse's DPI rather than this slider.

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

At 4 kHz or 8 kHz, verify the cost with a frame-time capture. This is one of the few
places where a latency setting can cost frames.

:::note[The controller batches reports too, and it is not configurable]
Intel xHCI controllers apply interrupt moderation with a default interval around 50 µs:
completions are batched and the CPU is interrupted when the timer expires. At 1000 Hz
polling, reports are 1000 µs apart and the window is noise. At 8000 Hz they are 125 µs
apart and the moderation window is a visible fraction of the interval, smearing
delivery timing.

There is no registry value or driver property for it. The interval lives in the
controller's IMOD register, which is memory-mapped hardware: changing it means
computing the register address from the controller's resources, writing it with a tool
like RWEverything, identifying the right interrupter by trial, and repeating at every
boot from a scheduled task, because the write does not survive a reboot.

The ceiling this removes exists only above 4 kHz, which is the argument for
1000–2000 Hz.
:::

## USB port choice

Rear ports are wired to the chipset or directly to the CPU; front-panel ports go
through an internal header and often a hub, which adds a store-and-forward step to
every report.

Use rear ports, and not the same hub as a device that streams. A webcam or audio
interface saturating a shared controller shows up as input hitching.

## Power management on the USB stack

Selective suspend and device idle states put a port or device into a low-power state
between reports; waking it delays the next one.
[`power.usb-suspend-off`](../../tweaks/power/#power.usb-suspend-off) disables this
globally, [USB-LatencySuite](../../tools/usb-latency-suite/) per device and per driver.

## What does not work

| Claim | Reality |
| --- | --- |
| `MouseDataQueueSize` / `KeyboardDataQueueSize` | A buffer depth in packets, not a polling interval and not a delay. Covered in [debunked: scheduler](../../reference/debunked/scheduler/). |
| Mouse "filter drivers" removed for latency | The class driver is not what holds up input. |
| Disabling the HID service | Breaks device enumeration to save nothing. |
| Registry "mouse fix" bundles | Almost all are the 6/11 slider and acceleration, written blind into keys that may not exist on a given build. |

## Measuring it

The only end-to-end measurement is a camera or a hardware latency tool. A high-speed
phone camera at 240 fps pointed at the screen and the mouse resolves to ±4 ms, enough
to distinguish a real change from a placebo.

What dominates input latency, in order: the frame rate cap relative to refresh rate,
whether V-Sync is on, whether the game's low-latency mode (Reflex, Anti-Lag) is on, and
the monitor's processing lag. Everything on this page is smaller than all four.
