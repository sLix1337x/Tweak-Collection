---
title: AM4 fabric & link power
description: DF C-states, APBDIS, SOC P-state, spread spectrum and ASPM on AM4 boards.
sidebar:
  order: 2
tags:
  - bios
  - power
  - latency
---

These are **AM4 BIOS settings** (Ryzen 1000–5000 on B450/X470/B550/X570). The names
differ per vendor, which is why several are listed with their alternatives. They all
do the same class of thing: stop a clock domain or a link from dropping into a
low-power state, so nothing has to wake up before it can respond.

| Setting | Value | What it does |
| --- | --- | --- |
| DF C-states | Disabled | Keeps the Data Fabric out of its idle states. Distinct from core C-states below — this is the fabric, not the cores. Associated with idle USB dropouts and WHEA reports on some boards. |
| Spread Spectrum / Spread Spectrum Control | Disabled | Stops the small (≈0.5 %) modulation of the reference clock used for EMI compliance. Gives a fixed reference for the fabric and for any overclock derived from it. |
| APBDIS | 1 | Algorithmic Performance Boost Disable: the fabric stops switching Infinity Fabric P-states on its own. Only meaningful together with the next setting. |
| Fixed SOC Pstate | P0 | Pins the SOC to its highest P-state. This is what `APBDIS = 1` hands the decision to. |
| SoC/Uncore OC Mode | Enabled | Holds the SOC and uncore clocks at their maximum instead of scaling them down. |
| ASPM Support / ASPM Control for CPU / ASPM Mode Control | Disabled | Keeps PCIe links out of L0s/L1. The firmware-side version of [`power.pcie-aspm-off`](../../../tweaks/power/#power.pcie-aspm-off). |

**What this costs:** idle power and idle temperature, on every one of them. Nothing
here raises a clock ceiling or a frame rate — the effect, where there is one, is on
wake-up latency and on the DPC spikes that come from a domain that had gone to
sleep. Whether that shows up in a frame-time capture depends on the board and on
what was spiking in the first place, so
[measure it](../../benchmark/dpc-latency/) rather than
assuming.

They also stack: applied together on a machine that idles most of the day, this is a
noticeable amount of power for a benefit that only appears under a workload that was
already stuttering.

