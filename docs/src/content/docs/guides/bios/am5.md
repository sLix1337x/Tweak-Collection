---
title: AM5 BIOS
description: UCLK 1:1 and the DDR5-6000/6400 wall, FCLK on Auto and where it can go, the 1.3 V SoC cap, the 2025–2026 AGESA line (FGR, EXPO ULL), Curve Optimizer and Curve Shaper, vendor gaming modes measured, and X3D on Zen 4 versus Zen 5.
sidebar:
  order: 3
tags:
  - bios
  - power
  - latency
---

These are the **AM5-specific** settings (Ryzen 7000 and 9000 on B650/X670/B840/X870). The
names differ per vendor, which is why several are listed with their alternatives. The
settings that are the same on any board — memory profile, BIOS updates, fTPM, TSME,
Resizable BAR — are on [worth changing](../worth-changing/).

The headline difference from [AM4](../am4/): the fabric is no longer the thing being
tuned. On AM4 the job is to find the highest stable FCLK. On AM5 AMD's guidance is to
leave FCLK alone and get the *memory controller* into a 1:1 ratio with the memory.

## The ratio that matters: UCLK 1:1

Three clocks, and only one pair has to be locked together:

| Clock | What it is |
| --- | --- |
| **MCLK** | The memory clock. Half the advertised number, because DDR transfers on both edges — DDR5-6000 is MCLK 3000 MHz. |
| **UCLK** | The unified memory controller inside the I/O die. This is the one that must match MCLK. |
| **FCLK** | The Infinity Fabric. Decoupled from the other two on AM5, and best left on Auto. |

The memory controller walls at roughly **UCLK 3000 MHz**, with a good sample reaching
about 3200. That ceiling is where the sweet-spot numbers come from: DDR5-6000 is exactly
MCLK 3000, so it runs `UCLK:MCLK = 1:1`. Ask for more and the board engages a **2:1
divider**, halving UCLK, and the added controller latency generally eats the bandwidth
the higher clock just bought.

- **Zen 4 (7000):** AMD names **DDR5-6000** the sweet spot. 1:1.
- **Zen 5 (9000):** the JEDEC baseline moved to DDR5-5600 and AMD names **DDR5-6400** the
  sweet spot, reachable at 1:1 on a good sample. Independent scaling work still lands on
  DDR5-6000 with tight timings as the better buy — DDR5-8000 at 2:1 comes close on raw
  bandwidth without beating a proper 1:1 setup.

**Confirm the ratio rather than assuming it.** A kit sold as DDR5-6400 can quietly train
at 2:1. ZenTimings shows the live UCLK and the divider; so does the BIOS memory page on
most boards.

:::note[Two DIMMs, not four]
Every number above assumes one module per channel. Populating all four slots on AM5
costs a large part of the achievable speed, and no amount of voltage buys it back. Two
single-rank modules is the configuration these speeds were validated at.
:::

### Leave FCLK on Auto — with one measured exception

The AM4 reflex — lock FCLK, UCLK and MCLK 1:1:1 — does not carry over. AMD's own
guidance for Ryzen 7000 is that the 1:1:1 lock is no longer important, that the default
FCLK is **1733 MHz**, and that the best results come from leaving FCLK on Auto and
targeting `Auto:1:1` for the other two. Firmware since Zen 4 sets it itself, usually
landing around 2000 MHz.

The measured nuance, from community latency runs: a manual FCLK of **2133–2200 MHz**
buys a small, real latency improvement over the 2000 MHz Auto value where the sample
holds it. Most Zen 4 parts wall around 2133; Zen 5 more often reaches 2200. The gain is
single-digit and the stability cost is the usual fabric one, so this is a last-percent
step, not a starting point.

The inverse experiment has also been run: the "full 1:1:1 sync" configuration
circulating as an esports sleeper tip — DDR5-4400 with FCLK = UCLK = MCLK 2200 — was
bench-tested on a 9800X3D in 2026 and produced **no general gaming benefit**; the
bandwidth sacrificed costs more than the synchronization returns. It also trains
poorly, because AGESA was never optimized for timings that low. Skip it.

## Firmware: the 2025–2026 AGESA line

AM5 firmware moved significantly through 2025–2026, and two items on it are tuning
features rather than fixes.

| AGESA | Arrived | Content |
| --- | --- | --- |
| 1.2.0.3f / 1.2.0.3g | late 2025 – early 2026 | Memory compatibility and voltage-regulation refinements. |
| 1.2.7.0 | October 2025 | PSP firmware update, next-generation CPU enablement. Carried the TSME regression covered on [worth changing](../worth-changing/). |
| 1.3.0.0 / 1.3.0.0a | February 2026 | Fixes a Ryzen 9000 no-boot class, loads EXPO timings correctly and completely again, and adds **Fine Granularity Refresh** (below). |
| 1.3.0.1b | June 2026 | Adds **EXPO Ultra Low Latency** profile support, across 600- and 800-series boards; restores the TSME toggle (Patch A). |

### Fine Granularity Refresh (FGR)

Standard refresh stalls all banks at once; FGR refreshes one bank at a time, so the
rest stay available for requests. Its arrival on AM5 gives **tRFC2 and tRFCsb a
function for the first time** — previously inert values. Board defaults ship it
disabled; measured configurations use **Mixed**, which lets the controller switch
between per-bank and all-bank refresh as load demands.

The catch: FGR only works correctly when the kit's SPD stores valid tRFC2/tRFCpb
values, which cheap kits may not. Tune tRFC2 analogous to tRFC and tRFCsb at a
13/16 factor of tRFC2 as a starting point.

### EXPO Ultra Low Latency (ULL)

An extension to EXPO profiles shipping with 1.3.0.1b — tighter pre-baked latency
profiles per speed class, applied like any EXPO profile. Vendor material cites up to
**13 %** gaming gains; treat that as a marketing ceiling until independent captures
exist, and treat "EXPO support may vary by DRAM module" in the changelogs literally —
the kit needs a ULL-aware profile. Worth an A/B on any board that received it.

## SoC voltage, and the 1.3 V cap

**VSOC does not go above 1.3 V.** This is not a tuning preference. Ryzen 7000 parts were
destroyed in 2023 by excess SoC voltage — chips bulging, overheating and desoldering
themselves, taking the board with them in some cases — and X3D parts were the most
reported because they are the most sensitive to it.

The mechanism is worth knowing, because it was not the memory profile's fault: **EXPO
does not raise VSOC**. Board vendors assigned their own SoC voltage when an EXPO profile
was engaged, and some of them assigned a number well past what the part tolerated. AMD
root-caused it and shipped **AGESA 1.0.0.6**, then **1.0.0.7**, which cap the rail at
1.3 V. Memory overclocking and PBO were unaffected by the cap.

A fixed **1.20–1.25 V** covers DDR5-6000 EXPO at 1:1 on most samples, and a fixed value
beats Auto because Auto is the setting that caused the problem. Note that socket-pin
telemetry is not the voltage the die sees, so treat a reading near the cap as already
past it.

:::caution[Update the BIOS before enabling a memory profile]
A board still on pre-1.0.0.6 firmware will apply its own SoC voltage on EXPO with nothing
stopping it. This is the one BIOS update on this page that is not optional.
:::

:::caution[ASRock 800-series boards and dead 9800X3D chips]
Through 2025, an abnormal number of Ryzen 7 9800X3D failures — dozens of documented
cases, including repeat failures after CPU replacement — concentrated on ASRock AM5
boards. ASRock's early response attributed most cases to memory-compatibility boot
failures (BIOS 3.20, February 2025); AMD's August 2025 response attributed the failures
to board vendors not following its voltage guidelines, and ASRock shipped BIOS 3.40
(AGESA update) to "enhance CPU operating stability". Reports continued into late 2025
and ASRock opened a further investigation in February 2026. On an ASRock AM5 board,
running the latest BIOS is not optional; repeated CPU deaths on the same board are
grounds for replacing the board, not the CPU.
:::

## PBO, Curve Optimizer and Curve Shaper

The PBO2 toolkit on AM5 carries everything from earlier generations — PPT, TDC and EDC
limits, Boost Override and Scalar, and per-core Curve Optimizer — plus one Zen 5
addition.

**Curve Shaper** (Zen 5 only) applies voltage offsets at specific frequency and
temperature points instead of the single flat offset Curve Optimizer gives. A part that
is stable at −30 while hot and unstable at −15 while idle is exactly the case a flat
offset cannot express, and the usual reason a Curve Optimizer value gets abandoned.

**Per-core beats all-core.** One offset for every core is limited by the weakest core,
which leaves the good ones untouched. All-core is a reasonable first pass; per-core is
where the result is.

**A boost override of +200 MHz with PBO enabled is the whole overclock for most gaming
machines.** PBO is dynamic, so the override only permits a higher clock when the workload
asks for one — and games mostly do not ask. A 9800X3D averages around 5.4 GHz in a game
whatever the ceiling is set to.

:::caution[Curve Optimizer instability appears at idle]
Same as [AM4](../am4/#pbo-and-curve-optimizer): an offset that passes a render benchmark
is not validated. Undervolt instability presents as WHEA errors and reboots at idle or
light load, hours later. Leave the machine on and used rather than stress tested.
:::

### X3D: what is locked, and what never was

| Part | Multiplier / voltage | Curve Optimizer |
| --- | --- | --- |
| 5800X3D, 7800X3D | Locked. The cache sits **on top of** the compute die, and AMD locked manual control to protect it thermally. Ceiling is around 5050 MHz on a 7800X3D. | Available. Negative offsets always worked. |
| 9800X3D and later | Unlocked, with official overclocking support. AMD moved the cache **beneath** the cores, which fixed the heat path. | Available, plus Curve Shaper. |

The "X3D chips cannot be overclocked" line is half right and gets repeated as if it were
whole: undervolting via Curve Optimizer was never off-limits on any of them.

**Large V-Cache also reduces the payoff from memory tuning.** The cache absorbs much of
the latency being tuned. Fresh 2026 scaling data on a 9800X3D quantifies it: full manual
RAM optimization over a good EXPO profile bought at most **~7 % in 1 % lows** (Shadow of
the Tomb Raider), ~3 % average / ~6 % lows with ray tracing active (Cyberpunk 2077), and
under 5 FPS in Assetto Corsa Competizione — against double-digit gains from the same RAM
steps on a cache-poor CPU. The gap between a good EXPO profile and hand-tuned subtimings
is smaller on an X3D part than on a 7700X or 9950X — smaller in a game than in AIDA64, in
both cases.

### Vendor "gaming modes", measured

Board vendors ship one-click X3D modes — Gigabyte's X3D Turbo Mode 2.0, and the
"X3D Gaming Mode" class that disables SMT or the second CCD outright. Measured results
are thin:

- X3D Turbo Mode 2.0, tested on a 9800X3D across seven games (2026): a ~200 MHz /
  +0.1–0.15 V one-click overclock. Two titles gained 10–12 %; the other five gained
  0–2 %, and the "Extreme Gaming" profile raised averages while leaving lows nearly
  unchanged. Equivalent to a manual PBO offset any board can apply.
- The CCD/SMT-disabling variants trade threads for a scheduling shortcut that the
  chipset driver plus Game Bar already handle, and have been reported to make
  thread-hungry games *worse* (see [CS2 scheduling](../../../cs2/system/#cpu-scheduling)).

Neither replaces the tuning above.

## Fabric and link power states

The same idea as the [AM4 table](../am4/#fabric-and-link-power-states): stop a clock
domain or link from dropping into a low-power state so nothing has to wake before it
responds.

| Setting | Value | What it does |
| --- | --- | --- |
| DF C-states | Disabled | Keeps the Data Fabric out of its idle states — the fabric, not the cores. Associated with idle USB dropouts and WHEA reports on some boards. |
| Global C-states | **Leave enabled** | Core C-states. Disabling them costs boost headroom on Zen 4 and 5 for the same reason it does on Zen 3: the boost algorithm needs the idle states it is being denied. |
| Power Supply Idle Control | Typical Current Idle | Only where the machine drops out or reboots at idle. It is a fix for a symptom, not a tuning step. |
| ASPM Support / ASPM Control for CPU | Disabled | Keeps PCIe links out of L0s/L1. The firmware-side version of [`power.pcie-aspm-off`](../../../tweaks/power/#power.pcie-aspm-off). |

**Cost:** idle power and idle temperature on every one, and none of them raises a clock
ceiling or a frame rate. The effect, where there is one, is on wake-up latency and on DPC
spikes from a domain that had gone to sleep, so
[measure](../../benchmark/dpc-latency/) rather than assume.

## Memory training and boot time

Memory Context Restore and Power Down Enable are the AM5 settings behind a 30–40 second
POST, and they are covered with their trade on the
[worth changing page](../worth-changing/#memory-training-and-idle-memory-context-restore-power-down).

## A landing zone

Zen 4 or Zen 5, two DIMMs, no exotic cooling:

- **DDR5-6000 CL30 at UCLK 1:1**, EXPO enabled, FCLK on Auto (2133–2200 only as a
  validated last step).
- **VSOC fixed at 1.20–1.25 V**, on firmware at AGESA 1.0.0.7 or newer — and on a
  current 1.3.0.x branch for FGR and EXPO ULL.
- **PBO enabled** with a +200 MHz boost override and a per-core Curve Optimizer pass.
- **DF C-states disabled, Global C-states left on.**
- Zero WHEA-19 entries over a week, checked the same way as on
  [AM4](../am4/#fclk-and-the-error-nobody-looks-for).
