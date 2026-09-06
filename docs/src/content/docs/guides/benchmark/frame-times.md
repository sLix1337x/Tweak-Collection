---
title: Frame times
description: "PresentMon and CapFrameX: capturing a run, comparing two, and reading the 1% lows."
sidebar:
  order: 2
tags:
  - measurement
  - latency
---

Average FPS hides stutter. A game averaging 240 FPS with a 1 % low of 90 is worse in
play than a steady 144.

[PresentMon](https://github.com/GameTechDev/PresentMon) — Intel's, and the engine behind
CapFrameX and the overlay in recent AMD and Intel drivers — captures per-frame present
times as a CSV.

[CapFrameX](https://www.capframex.com/) wraps the same capture in a UI that records on
a hotkey, computes percentiles, and loads two captures side by side. Use it unless
scripting the CSVs directly.

CapFrameX routine:

1. Same game, map, settings and run: a replay, a benchmark scene or a fixed route. A
   different route is a different workload.
2. Capture 60 seconds or more. Short captures are dominated by shader cache activity.
3. Three captures per state. A single pair cannot distinguish a 2 % change from
   run-to-run noise.
4. Apply the tweak, reboot, repeat the same three captures.
5. Compare in the **Comparison** tab: 1 % / 0.1 % lows and the frame-time plot, not
   average FPS.

If the three baseline captures disagree with each other by more than the change under
test, the workload is not repeatable enough to prove anything.

**What to compare:**

- **1 % and 0.1 % low** — reflects perceived smoothness.
- **Frame time graph shape** — a flat line with periodic spikes points at a background
  task, a telemetry upload or a shader compile.
- **Average FPS** — last, only to confirm nothing regressed.

A tweak that raises average FPS by 2 % and does nothing to the 1 % low is noise. One
that leaves average FPS alone and removes the spikes is a fix.

