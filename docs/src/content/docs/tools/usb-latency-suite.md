---
title: USB-LatencySuite.ps1
description: Turns off USB and HID power saving, idle and wake features, with a per-value backup and an exact revert.
sidebar:
  order: 4
tags:
  - latency
  - power
  - registry
---

Windows saves power on USB by letting devices go idle and suspending individual
ports. Waking one costs milliseconds and can delay or drop input reports. This
turns those mechanisms off — per driver and per device — and records the previous
value of everything it writes.

```
scripts/usb-latency-suite/
  USB-LatencySuite.ps1   the tool, WPF interface
  Run.vbs                double-click launcher
  README.md              the full reference, including the audit it came out of
```

## What it targets

| Mechanism | What it costs you |
| --- | --- |
| **Selective suspend** | The hub driver puts an idle port into a low-power state; waking it delays the next input report. |
| **Device idle / D-states** | The device drops to a lower power state between reports, and has to be brought back up before the next one. |
| **Link power management** | U1/U2 link states on USB 3.x. |
| **Wake capability** | Keeping wake armed keeps extra power-management logic in the path. |
| **Interrupt threshold** | The one genuine latency knob rather than a power switch: an interrupt per transfer instead of coalescing them. |

Each is an independent toggle, and the device list is built from a single
`Get-PnpDevice -PresentOnly` call, so one mouse can be tuned without touching the
webcam.

## Preview, apply, revert

**Preview** builds the plan and prints every change as `key :: value: old -> new`
without writing anything. Values already at the target are left out, so the preview
doubles as a status view.

**Apply** writes each value and records the previous state — including *"this value
did not exist"* — to `Backups\usb-tweaks-<timestamp>.json`. Failures are reported
per key rather than swallowed.

**Revert last** replays the newest backup: restores prior values, deletes values the
script created, re-arms any device whose wake it disarmed, then renames the backup
to `.reverted`.

`-SelfTest` round-trips that whole path against a scratch registry key and cleans up
after itself, which is what proves the revert actually restores rather than guesses.

:::note[No console window, and its own icon]
The interface is the only thing on screen. `Run.vbs` has no window of its own — it
elevates and starts PowerShell hidden in a single `ShellExecute`, so nothing paints
even for a frame. The script hides its own console as a second line of defence.

One deliberate exception: start it from a terminal you already had open and that
window is left alone, because it is yours and closing it would take your shell with
it.

The mark in the title bar and the taskbar icon is embedded in the script as base64
rather than shipped as a file beside it — the tool is meant to be one file you can
drop anywhere. It is the same heart the docs site uses as its favicon.

The one caveat worth knowing: `.vbs` is what buys the zero-flash launch, and
Microsoft has VBScript on a deprecation path. If a future Windows drops it, the
launcher is four lines of PowerShell away from being replaced — the script itself
does not depend on it.
:::

## What it replaced, and why that matters

This started as `USB_Static_Tweaks.reg` and `USB_Dynamic_Tweaks.bat`. Auditing those
two before rewriting them turned up the same class of problem as
[the old tweak scripts](../../reference/debunked/):

- **No backup and no revert.** Undoing it meant a restore point or rebuilding the
  registry by hand.
- **`wmic`**, which two of the five discovery passes depended on, is gone from
  current Windows 11 — and one of those passes was the only one that reached HID
  devices, so on a modern machine the mouse and keyboard were skipped entirely.
- **`ForceFullSpeed=1`** forces USB 2.0 devices to negotiate 12 Mbit/s instead of
  480 Mbit/s. It is a debugging switch and a bandwidth downgrade, and it breaks
  webcams, audio interfaces and storage. Removed.
- **`if exist "%%i\WDF"`** applied a filesystem test to a registry path, so it was
  always false and three values never got written at all.
- **Hard-coded English device names** in the `powercfg` calls, which miss on any
  other display language. Now driven by `powercfg /devicequery wake_armed`,
  intersected with the selected USB/HID set so the network adapter is never
  disarmed.

The two original files are not shipped here. They are described in the tool's README
as the "before", but one of their values is an active downgrade and none of them can
be undone.

## Worth knowing

- A reboot is required for driver-level changes.
- Parts of the `Enum` tree are ACL'd to SYSTEM rather than Administrators, so a few
  keys can fail to write. Those are listed individually in the output pane instead
  of being swallowed; everything else still applies.
- On a laptop this costs idle battery — the tool detects a battery and says so.

Full reference in the tool's own
[README](https://github.com/sLix1337x/Tweak-Collection/blob/main/scripts/usb-latency-suite/README.md).
