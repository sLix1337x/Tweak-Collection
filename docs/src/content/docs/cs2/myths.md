---
title: What does not work
description: The CS2-specific debunked list — dead cvars, inert registry values, and common advice that is actively backwards.
sidebar:
  order: 6
tags:
  - cs2
  - debunked
  - latency
---

The [main debunked section](../../reference/debunked/) covers Windows tweaks that fail
on their own terms. This page covers the ones that fail specifically for CS2: commands
the engine no longer honours, values that cannot reach UDP traffic, and instructions
that produce the opposite of their stated effect.

## Dead in the game

| Claim | Verdict | Why |
| --- | --- | --- |
| `-tickrate 128` makes the server 128-tick | **Dead** | CS2 is sub-tick. Never did this, even in CS:GO, outside a local listen server. |
| `cl_interp`, `cl_interp_ratio`, `cl_cmdrate`, `cl_updaterate` | **Dead** | Engine-managed or read-only. The CS:GO netcode canon ended with sub-tick. |
| `-high` for more FPS | **Myth** | Source 1-era flag. CS2 handles its own priority; the documented side effect is instability. |
| `-d3d9ex` / `-nod3d9ex` | **Dead** | Source 1 relics. |
| `-vulkan` for more FPS on Windows | **A loss** | Controlled 2026 benchmarking: DX11 789 avg / 217 1 % low against Vulkan's 676 avg. Vulkan is a Linux and Steam Deck path. |
| `-novid` | **Dead** | CS2 has no intro video; the flag is a no-op. |
| `engine_low_latency_sleep_after_client_tick true` | **Unverified** | Reflagged to a normal release cvar in current builds; whether it still functions is unproven. The old `gameinfo` override route remains a game-file edit and an anti-cheat risk. [Details](../game-settings/#disabled-engine-cvars). |
| "Enable Reflex 2 / Frame Warp" | **Fiction** | Announced, never shipped — no SDK, no driver flag, no game support. |
| Windows mouse settings / "disable acceleration for CS2" | **Dead control path** | Raw input is forced on and cannot be turned off; Windows pointer settings cannot reach it. |

## Cannot reach this game

| Claim | Verdict | Why |
| --- | --- | --- |
| `NetworkThrottlingIndex = ffffffff` lowers ping | **Myth** | Caps buffers indicated per receive DPC while multimedia threads are scheduled. No path to server latency, and removing the cap *raises* NDIS DPC time. [Mechanism](../../tweaks/latency/#latency.network-throttling-off). |
| `SystemResponsiveness = 0` frees 20 % CPU for the game | **Myth twice over** | The MMCSS reservation only applies to threads that register with MMCSS, and no CS2 registration has been demonstrated. Separately, `0` rounds to the default of 20. [Mechanism](../../tweaks/latency/#latency.system-responsiveness). |
| `TcpAckFrequency` / `TCPNoDelay` improve hit registration | **Wrong protocol** | TCP settings; CS2 gameplay traffic is UDP. |
| `netsh int tcp set global autotuninglevel=disabled` reduces input lag | **Myth** | TCP receive-window control — a throughput mechanism. Microsoft's position is that disabling it limits speeds; no path to UDP traffic or cursor feel. |
| `DisablePagingExecutive` / `LargeSystemCache` | **Harmful** | Server-oriented values that reduce memory available to games. Revert if an "optimisation pack" set them. [More](../../reference/debunked/storage-and-memory/). |
| Disable the pagefile for FPS | **Harmful** | Commit-limit crashes under pressure, no upside. System-managed on NVMe is correct. |
| `Win32PrioritySeparation` "26" | **Trap** | Programs profile is hex `0x26` = **decimal 38**. Typing 26 on the decimal radio writes `0x1A` — the long/fixed profile, the opposite. The stock value already resolves to short/variable via OS defaults. [Full decode](../../reference/win32priorityseparation/). |
| Force HPET (`useplatformclock true`) | **Harmful** | Adds latency per timer read. The `useplatformtick yes` companion is a debugging flag associated with input lag in extended testing. [More](../../reference/debunked/scheduler/). |
| `disabledynamictick yes` = free FPS | **Placebo, with a risk** | Debugging feature. On thermally constrained systems the extra wake-ups can *reduce* sustained clocks. |

## Actively backwards

The popular action here makes the outcome worse, not merely unchanged.

**"ReBAR always helps."** CS2 is the documented exception. Controlled Dust2 testing
found overall performance similar but roughly **6 % better 1 % lows with ReBAR
disabled**. Single-source, and free to check.

**"V-Sync must be off with G-Sync."** Inverted. With variable refresh active,
control-panel V-Sync acts as a ceiling guard rather than a frame-pacing mechanism; off,
it lets spikes exceed the range and tear. Tested configuration: G-Sync on,
control-panel V-Sync on, cap three below refresh.
[Details](../frame-cap/#with-g-sync-or-freesync).

**"Lower the monitor to match the cap."** Harmful for VRR. 144 Hz at a 144 cap instead
of 240 Hz at 237 shrinks the VRR window, risks low-framerate compensation, and
increases latency at an identical frame rate.

**"Always disable C-states for latency."** Inverted on AM5 X3D, where the documented
fix for micro-stutter is setting Global C-State Control explicitly to *Enabled* —
"Auto" on many boards silently means Disabled and breaks idle coordination between the
CCDs, the fabric and the scheduler. Blanket-disabling also kills turbo on locked CPUs.
If deep-C-state wake latency is a measured problem, the targeted fix is the idle
demote/promote thresholds, not `Processor Idle Disable`, which pins every core at C0
and costs the thermal headroom boost needs.

**"Unpark the cores for instant FPS."** Check first. Instrumented testing found stock
Windows 11 desktops never park at all; where parking does happen it is a tail-latency
problem, not an average-speed one. [The measurement](../system/#cpu-scheduling).

**"8 kHz polling is a free competitive edge."** Costs ~20 % of frame rate at 4 kHz and
~33 % at 8 kHz on mid-range CPUs in community captures. It also needs 1600+ DPI to
saturate, making the popular low-DPI pairing self-defeating.
[Details](../game-settings/#input).

**"Closing the RGB software is enough."** Its kernel driver stays loaded and in the DPC
chain; one 2026 Windows update blocked a driver family several such utilities ship
because it could crash games. Uninstall rather than close.

**"Monitoring tools are free because they only read sensors."** Sensor polling is a
documented DPC and stutter source. Diagnose with them, then close them.

## Actively backwards, firmware and hardware

**"Fit a discrete TPM module to fix fTPM stutter."** Inverted on any FACEIT machine:
dTPM modules are a documented source of attestation failures, and FACEIT's own guidance
is to switch back to fTPM. The fix is the fTPM firmware in a newer AGESA.
[Details](../../guides/bios/worth-changing/#ftpm-stutter-on-amd-platforms).

**"Push FCLK to 2000 — it is the AMD sweet spot."** Silicon lottery. Most Zen 3 chips
wall at 1866–1900, and a WHEA-19-free 1800 beats an error-logging 2000 every time —
each corrected error costs fabric latency that lands in the frame times.
[The audit](../../guides/bios/am4/#fclk-and-the-error-nobody-looks-for).

**"Max out the PBO limits for maximum boost."** Counter-productive on Zen 3: capping
EDC at 150 A measured higher sustained clocks, 12 °C lower temperatures and a higher
benchmark score than the board's unlimited profile.
[Numbers](../../guides/bios/am4/#pbo-and-curve-optimizer).

**"8× MSAA looks smoother."** Up to 18 % of average frame rate, the single most
expensive setting in the menu. [The cost map](../game-settings/#video-settings).

**"Shadows on Low removes enemy shadows."** False, and the wrong control: player
shadows are governed by Dynamic Shadows, which stays on All. Global Shadow Quality is a
pure cost slider. [Why](../game-settings/#the-shadow-setting-commonly-set-backwards).

## Overpromised rather than wrong

| Claim | Reality |
| --- | --- |
| Debloat scripts raise FPS significantly | Gains are background-stutter and boot-time, not frame rate — and aggressive scripts break Xbox services and security components anti-cheats check. |
| Custom ISOs (AtlasOS, ReviOS) give big FPS gains | Real effect is idle CPU and ~1.5 GB RAM. Vendor benchmark numbers are vendor-published. Direct conflict with FACEIT's requirements. |
| "25H2 is faster/slower than 24H2" | Neither. Same servicing branch; a 41-benchmark suite separated them by 0 % on average. |
| Disable SysMain / 8dot3 / last-access for FPS | Idle-resource services; last-access is already system-managed. Disabling SysMain removes memory compression as a side effect. |
| Switch to the native NVMe driver | Consumer gains were within run-to-run variance; the registry path was removed again. CS2 is not storage-bound after load. |
| DirectStorage will help CS2 | CS2 does not use it. Streaming API for open-world asset flow. |
| "Low Latency Profile spikes CPU clocks mid-game" | False mechanism. Triggers on *shell* interaction, dormant in a fullscreen game. |
| Disable Spectre/Meltdown mitigations for a big gain | Depends entirely on the CPU: over 10 % on older chips, noise on anything recent. On AMD the switch is near-inert — Zen 3 runs always-on STIBP that Windows-side tools cannot switch off, so the cost is in silicon and already inside every published benchmark. [More](../system/#cpu-mitigations). |
| Memory Context Restore and Power Down are free performance | Inverted. Context Restore trades retraining for boot speed and a marginal training state; Power Down adds idle latency. Both off is the fast, stable pair. [More](../../guides/bios/worth-changing/#memory-training-and-idle-memory-context-restore-power-down). |
| Force a global timer resolution with a timer tool | Requests have been per-process since Windows 10 2004, so the tool is not doing what its interface says without an undocumented registry value. [Mechanism](../../reference/debunked/scheduler/#forcing-a-global-timer-resolution--superseded). |
| Force MSI mode on an RTX 30 or 40 card | Already the driver default there. Verify, do not write; on some boards forcing it makes interrupt conflicts worse. [Mechanism](../../tweaks/nvidia/#nvidia.msi-mode). |

## The filter

A CS2 tweak arriving as a `.reg` file with no mechanism explained and no frame-time
data belongs on this page by default. The [method page](../../start/method/) states
the four questions every claim here has to answer.
