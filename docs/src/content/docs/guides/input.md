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
pointer one unit. Every other position multiplies: below 6 the multiplier is a
fraction, so counts are dropped; above 6 it exceeds 1, so the pointer skips pixels.

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

:::note[The controller moderates interrupts too, and it is not configurable]
Windows' inbox xHCI driver (`usbxhci.sys`, Windows 10 1507 to Windows 11 26H1) sets every
interrupter's moderation interval (IMOD) to 50 µs, whatever the controller vendor. IMOD
is a minimum gap between interrupts, not a collection timer: once the counter has run
down, the next event interrupts immediately. At 1000 Hz (1000 µs apart) or 8000 Hz
(125 µs apart) the counter is normally already at zero, so an isolated mouse waits
nothing. A report waits for the remainder only if another event on the same interrupter
raised an interrupt in the previous 50 µs — the argument for putting the mouse on a
different xHCI controller from busy devices.

There is no registry value or driver property for it: the driver writes the fixed value
itself each time the controller enters D0. The interval lives in the controller's IMOD
register, which is memory-mapped hardware: changing it means computing the register
address from the controller's resources, writing it with a tool like RWEverything,
identifying the right interrupter by trial, and repeating the write after every reboot
and every return to D0.
:::

## USB port choice

Rear ports are wired to the chipset or directly to the CPU; front-panel ports go
through an internal header and often a hub, which adds a store-and-forward step to
every report.

Use rear ports, and not the same hub as a device that streams. A webcam or audio
interface saturating a shared controller shows up as input hitching.

## Power management on the USB stack

Selective suspend puts an idle device into a low-power state after an idle timeout, not
between reports, and waking it delays the next report. Windows leaves it off for HID
devices such as mice and keyboards unless the device opts in.
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
