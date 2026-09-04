---
title: Frame times
description: "PresentMon and CapFrameX: capturing a run, comparing two, and reading the 1% lows."
sidebar:
  order: 2
tags:
  - measurement
  - latency
---

Average FPS hides everything that matters. A game averaging 240 FPS with a 1% low of
90 feels considerably worse than a steady 144.

[PresentMon](https://github.com/GameTechDev/PresentMon) (Intel's, and the engine
behind CapFrameX and the overlay in recent AMD and Intel drivers) captures per-frame
present times. It is the raw capture layer: a CSV of present timings per frame.

[CapFrameX](https://www.capframex.com/) is the practical way to use it. It wraps the
same capture in a UI that records a run on a hotkey, computes the percentiles for
you, and — the part that matters here — loads two captures side by side and plots
them against each other. That is exactly the before/after comparison this page is
about, so it is the tool to start with unless you have a reason to script the CSVs
yourself.

A usable CapFrameX routine:

1. Same game, same map, same settings, same run — a replay, a benchmark scene or a
   fixed route. A different route is a different workload, and the numbers are then
   worth nothing.
2. Capture 60 seconds or more. Short captures are dominated by whatever the
   shader cache was doing.
3. Three captures per state, not one. Frame-time runs vary; a single pair of
   captures cannot tell a 2 % change from run-to-run noise.
4. Apply the tweak, reboot, repeat the same three captures.
5. Compare in the **Comparison** tab and look at the 1 % / 0.1 % lows and the
   frame-time plot, not at average FPS.

If the three baseline captures already disagree with each other by more than the
change you are chasing, stop: the workload is not repeatable enough to prove
anything, and no amount of tweaking will fix that.

**What to compare:**

- **1% and 0.1% low** — the metric that reflects perceived smoothness.
- **Frame time graph shape** — a flat line with occasional spikes points at
  something periodic: a background task, a telemetry upload, a shader compile.
- **Average FPS** — last, and only to confirm nothing regressed.

A tweak that raises average FPS by 2% and does nothing to the 1% low is noise. A
tweak that leaves average FPS alone and removes the spikes is a real fix. Game DVR
is the textbook example of the second kind.

