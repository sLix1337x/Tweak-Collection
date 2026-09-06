---
title: AM4 BIOS
description: FCLK coupling and the WHEA-19 audit, Curve Optimizer and PBO limits, module ranks, DF C-states, APBDIS, SOC P-state, spread spectrum and ASPM on AM4 boards.
sidebar:
  order: 2
tags:
  - bios
  - power
  - latency
---

These are the **AM4-specific** settings (Ryzen 1000–5000 on B450/X470/B550/X570). The
names differ per vendor, which is why several are listed with their alternatives. The
settings that are the same on any board — memory profile, BIOS updates, fTPM, TSME,
Resizable BAR — are on [worth changing](../worth-changing/).

## FCLK, and the error nobody looks for

On AM4 the Infinity Fabric clock runs 1:1 with the memory clock up to a hardware
ceiling, and on Zen 3 the rule is **find the highest stable FCLK**. The opposite of
AM5, where AMD's guidance is to leave the fabric on Auto because each memory speed has
its own optimal fabric clock.

A large share of Vermeer chips wall at **1866–1900 MHz**, some failing to POST at 1900
at any voltage — silicon lottery, not configuration. Dual-CCD parts fare *worse*, being
binned for core quality rather than I/O-die quality. AMD's advertised DDR4-4000 /
FCLK 2000 is reachable on a minority of chips.

**Audit before pushing.** Fabric instability need not crash anything: it appears as
WHEA event ID **19** ("corrected hardware error") in Event Viewer, and each correction
costs fabric latency that surfaces as a frame-time spike. One documented case ran
memtest-clean at 3800 CL14 while logging **4,000 corrected errors in an hour**. A
configuration with zero WHEA-19 entries over a week beats a faster one that logs them.

```powershell
Get-WinEvent -FilterHashtable @{LogName='System'; Id=19} -MaxEvents 20 |
  Select-Object TimeCreated, ProviderName
```

**Update the BIOS before chasing the last 66 MHz.** On identical RAM at an identical
FCLK, AGESA 1.1.9.0 alone took AIDA64 memory latency from 65.8 ns to about 56.5 ns — a
larger improvement than the fabric clock step tuning usually targets. The BIOS version
is a tuning variable on AM4, and carries the
[fTPM fix](../worth-changing/#ftpm-stutter-on-amd-platforms).

AM4 is still maintained: AGESA ComboAM4v2 **1.2.0.F** (September 2025) updated the fTPM
firmware for Vermeer explicitly "to improve game compatibility", and 2026 board
releases update the Secure Boot key set (2023 KEK/DB/PK) — which matters now that
anti-cheat platforms attest Secure Boot state. A board left on 2022-era firmware is
missing both.

Landing zone for a Zen 3 machine: DDR4-3600 CL16 or 3800 CL14–16, FCLK 1800–1900 at
1:1, zero WHEA-19. Voltage envelope: Vsoc 1.08–1.1 V, VDDG 1.0–1.05 V, VDDP 0.9–1.1 V.
More voltage frequently makes fabric stability worse.

## Module ranks: the free performance nobody configures

At identical clock and timings, a **dual-rank** kit beats a single-rank kit because the
controller interleaves ranks — one rank serves a request while the other recovers.
Community measurements on Zen 3 put the gain at up to **~10 % in some games**, for
zero tuning effort; the trade is that dual-rank is slightly harder to train at a given
frequency.

The practical mapping: 2×16 GB kits are dual-rank in most DDR4 lineups, 2×8 GB kits are
single-rank. A machine running 2×8 GB single-rank is leaving the interleave on the
table; four single-rank modules recover the same effect at the cost of the harder
4-DIMM training. Check what is installed with ZenTimings or the module label (1R vs 2R)
before attributing a performance gap to timings.

## PBO and Curve Optimizer

Undervolting via Curve Optimizer reliably helps sustained clocks: lower voltage at the
same frequency means less thermal back-off in a long session.

On the power limits, **capping EDC beats unlimited** on Zen 3. A widely reproduced
5950X result set PPT 200 / TDC 200 / EDC 150 rather than the board's "Motherboard"
maximum and measured *higher* effective clocks — about 5,030 MHz single-core and
4,600 MHz all-core — with Cinebench R23 temperatures dropping from 86–87 °C to 74 °C
and the score gaining 600 points. Zen 3's boost algorithm behaves badly at very high
current draw.

Curve values are per-core, not per-chip: the best cores tolerate far less negative
offset than the rest. A typical tuned set is −10 to −14 on the best two to four
cores and −20 to −30 on the remainder, plus a +125 MHz boost override.

:::caution[Curve Optimizer instability appears at idle, not under load]
A negative offset that passes Cinebench is not validated. Undervolt instability on
Zen 3 presents as WHEA errors and random reboots at **idle or light load**, hours
later. Test by leaving the machine on and unattended, not by stress testing.
:::

**Disabling Global C-States costs 100–150 MHz of boost** on these chips, because the
boost algorithm needs the idle states it is being denied — the same conclusion the
[outdated advice page](../outdated-advice/) reaches from the latency side.

## Fabric and link power states

These all stop a clock domain or link from dropping into a low-power state, so nothing
has to wake before responding.

| Setting | Value | What it does |
| --- | --- | --- |
| DF C-states | Disabled | Keeps the Data Fabric out of its idle states (distinct from core C-states below: this is the fabric, not the cores). Associated with idle USB dropouts and WHEA reports on some boards. |
| Spread Spectrum / Spread Spectrum Control | Disabled | Stops the small (≈0.5 %) modulation of the reference clock used for EMI compliance. Gives a fixed reference for the fabric and for any overclock derived from it. |
| APBDIS | 1 | Algorithmic Performance Boost Disable: the fabric stops switching Infinity Fabric P-states on its own. Only meaningful together with the next setting. |
| Fixed SOC Pstate | P0 | Pins the SOC to its highest P-state. This is what `APBDIS = 1` hands the decision to. |
| SoC/Uncore OC Mode | Enabled | Holds the SOC and uncore clocks at their maximum instead of scaling them down. |
| ASPM Support / ASPM Control for CPU / ASPM Mode Control | Disabled | Keeps PCIe links out of L0s/L1. The firmware-side version of [`power.pcie-aspm-off`](../../../tweaks/power/#power.pcie-aspm-off). |

**Cost:** idle power and idle temperature, on every one. None raises a clock ceiling or
a frame rate. The effect, where there is one, is on wake-up latency and DPC spikes from
a domain that had gone to sleep. Whether that appears in a frame-time capture depends
on the board and on what was spiking, so [measure](../../benchmark/dpc-latency/).

They stack: applied together on a machine that idles most of the day, this is a
noticeable amount of power for a benefit that only appears under a workload that was
already stuttering.
