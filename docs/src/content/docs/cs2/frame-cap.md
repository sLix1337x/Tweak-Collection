---
title: The frame cap
description: Limiter choice moves 1% lows by more than most tweaks, plus the tested G-Sync configuration.
sidebar:
  order: 3
tags:
  - cs2
  - latency
  - measurement
---

The relevant choice is the cap *mechanism*, not the cap *value*. At an identical frame
rate, the choice of limiter moved 1 % and 0.1 % lows by 10–30 FPS in the one published
comparison.

## The measurements

CapFrameX comparison in Cyberpunk 2077 (one published test, not CS2) at a 120 FPS cap,
recording averages, percentile lows and PC latency simultaneously:

| Limiter | Avg | 1 % low | 0.1 % low | Avg PC latency | Character |
| --- | --- | --- | --- | --- | --- |
| V-Sync | 119.9 | 118.8 | 118.2 | 52.1 ms | Perfect pacing, unusable latency |
| In-game limiter | 120 | 102.7 | 89.1 | 20.0 ms | Low latency, good lows |
| Driver "Max Frame Rate" | 120 | 92.3 | 77.4 | 19.0 ms | Low latency, worst lows |
| Reflex + V-Sync/G-Sync | 116.1 | 88.4 | 74.7 | 17.6 ms | Lowest latency, weak lows |
| RTSS (Async) | 120 | 101.8 | 90.1 | 20.1 ms | In-game latency, slightly better 0.1 % low |
| Special K (Normal) | 120 | 105.9 | 90.2 | 21.1 ms | Best non-V-Sync pacing, slight latency cost |

Every row but Reflex (116.1) holds the 120 FPS average; the spread in the worst 1 % of
frames is larger than most other tweaks produce. In this test the in-game limiter and
RTSS were within 0.1 ms of each other, and Special K and V-Sync paced more evenly than
RTSS.

Independent of limiter choice: **any consistent cap the machine can hold beats running
uncapped into GPU saturation** — a saturated pipeline queues frames, and queued frames
are latency.

## Which one for CS2

| Situation | Use | Why |
| --- | --- | --- |
| **MM / Premier** | RTSS in Async mode | Latency and 1 % low level with the in-game limiter, slightly more even 0.1 % low, and no `fps_max` caveat when the cap is hit. |
| **FACEIT** | Driver Max Frame Rate + Low Latency Mode Ultra | RTSS is blocked by the anti-cheat; worse pacing is the cost of playing. |
| **Either, without external tools** | `fps_max` | Avoids external tools; see the caveat below. |

`fps_max` produces inconsistent frame times **when the cap is actually being hit**,
because the engine-side limiter rations frame start times coarsely. Set below the
sustained rate it is fine; set where the game sits against it for a whole match, it
makes the frame times ragged.

## Picking the number

1. **Below the sustainable rate**, not at the average. A cap the 1 % lows can sustain
   removes the variance; a cap at the average clips peaks and leaves every dip intact.
   Start ~10–20 % under the measured average.
2. **Related to the refresh rate** on a variable-refresh display — see below.

## With G-Sync or FreeSync

A common mistake is disabling driver-level V-Sync "for latency". The tested
configuration is the opposite:

- **G-Sync on**
- **V-Sync on — in the driver settings only**, not in the game. Since driver 610.47
  (May 2026) the classic NVIDIA Control Panel is retired on clean installs; the same
  settings live in the NVIDIA App under Graphics → Program Settings.
- **Frame cap ~3 FPS below maximum refresh**

With variable refresh active, driver V-Sync acts as a ceiling guard at the top of the
VRR range, not as standalone V-Sync. With it off, spikes push past the range and tear.
The −3 cap keeps the pipeline inside the range so the guard never fires.

**Never lower the monitor's refresh rate to match a cap.** Use 240 Hz with a 237 cap,
not 144 Hz at 144. Lowering physical refresh shrinks the VRR window, risks
low-framerate-compensation behaviour, and increases latency at an identical frame rate.

Two CS2-specific notes. Valve's documentation warns that G-Sync in windowed mode can
produce visual glitches in CS2 and needs a game restart — set G-Sync to
fullscreen-only and run true fullscreen, which also composes correctly with the
[fullscreen-optimisations question](../game-settings/#fullscreen-optimisations).
Overdrive is per-refresh-rate: a preset clean at 240 FPS can inverse-ghost during dips
to 150, so tune it with TestUFO at the frame rates actually reached.

## Reflex

Reflex helps when the **GPU** is the bottleneck and the render queue is full. On a
CPU-bound CS2 machine the queue is already empty, so there is little to drain, while
the static cost remains: ~0.3 ms per frame, invisible at 144 FPS and measurable at
360+. Some high-frame-rate players run `-noreflex` with an external cap
and report steadier captures.

The measured frame-rate side, from the per-setting sweep: Reflex On cost 2.6 % of
average FPS while *improving* 1 % lows by 5 %, with input latency down 3–4 ms on
high-end hardware and up to 15 ms on low-end. Enabled and Enabled+Boost measured
identically within noise on a machine whose clocks did not sag.

There is no consensus:

- **Reflex On + Boost** is the standard professional-settings recommendation; Boost
  keeps GPU clocks up at low load, which protects lows.
- **Reflex Off + driver Low Latency Ultra + a driver cap** is what measured reports
  from weaker-CPU systems recommend.

Test both with the [AAABBBAAA protocol](../measuring/#the-protocol) and keep the
winner.

## Why the cap matters more in CS2 than in other games

CS2's simulation advances per rendered frame — sub-tick timestamps inputs finely, but
the state being timestamped only updates when a frame exists. Testing has shown
identical inputs producing different final positions, with the variance tracking frame
rate.

At 240 FPS a frame spans 4.2 ms of input quantisation; at 120 FPS, 8.3 ms. A
fluctuating frame rate is movement inconsistency that cannot be removed elsewhere.
