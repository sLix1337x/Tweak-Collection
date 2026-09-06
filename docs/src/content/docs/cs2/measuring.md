---
title: Measuring CS2
description: Why CS2 is difficult to benchmark repeatably, and the run protocol that makes two numbers comparable.
sidebar:
  order: 2
tags:
  - cs2
  - measurement
  - latency
---

CS2 is difficult to benchmark repeatably, so the default method of checking a claim —
apply it and look — produces noise that resembles signal.

General tooling: [the toolbox](../../guides/benchmark/toolbox/) and
[frame times](../../guides/benchmark/frame-times/). This page covers what changes for
CS2.

## Why the obvious method fails

The in-game counter on the Dust2 workshop benchmark wanders between runs on an
unchanged machine; the only consistent signal comes from starting a PresentMon-based
capture at exactly the same moment every time. A before/after screenshot from two
different runs measures a different number of bots alive at the sample window,
different utility thrown, a different shader-cache state and a different point in the
map's load curve. Most published "proof" for CS2 registry tweaks is methodology
failure, not measurement.

## The protocol

1. **Map:** the community-standard "FPS Benchmark" Dust2 workshop map. Results against
   a different map are not comparable to anyone else's.
2. **Capture:** CapFrameX (built on PresentMon), started at a **fixed offset** after
   the benchmark begins, not by hand. An AutoHotkey trigger or a published automation
   bundle removes the largest source of run-to-run variance.
3. **Runs:** at least three per state, outlier rejection around 3 %.
4. **Order:** **AAABBBAAA**. If the final A block does not land on the first, the
   machine drifted and the middle block means nothing.
5. **Read:** 1 % low and 0.1 % low averages. Average FPS hides stutter by definition.

## Traps specific to this measurement

**Do not run two PresentMon consumers at once.** Afterburner's capture, HWiNFO's
frame-time monitoring and CapFrameX all hook the same source; together they corrupt
results. They are also a DPC source in their own right.

**Hold the limiter constant.** `fps_max` and driver-level limiters produce materially
different lows at the same cap. Pick one for the whole comparison.
[Why](../frame-cap/).

**Purge standby before each run, or before none of them.** Doing it before some runs
and not others adds an unintended variable.

**Benchmark rigs need an audio device.** The January 26, 2026 update fixed a confirmed
performance issue in CS2 when running *without* a sound device — a headless or
audio-disabled test bench was measurably slower until that patch. Keep an endpoint
enabled on the benchmark machine.

**Watch for the game changing underneath the test.** CS2 is patched continuously and
some patches move performance. Two 2026 examples: Animgraph 2 (April 2026) cut the CPU
cost of animation — the scene's reference tester measured **+5 % on both averages and
1 % lows** on a 9800X3D machine, and another community benchmark put Dust2 1 % lows up
by a quarter — and the July 9, 2026 update officially "reduced the performance cost of
showing the scoreboard". A baseline from three months ago is a baseline against a
different game.

## Keep the baseline

Save a CapFrameX result for every configuration kept. Windows updates have repeatedly
cost CS2 performance, and a saved number from before is the only way to distinguish a
regression from imagination — re-run the baseline after each Patch Tuesday, before
changing any configuration.

Corollary: on a machine that has to stay working, delay non-security updates a week or
two and let the community find the regressions. Do not run
`DISM /Online /Cleanup-Image /StartComponentCleanup /ResetBase` — it makes updates
permanent and removes the rollback option.

## When the number drops mid-match

CS2 has had engine-side regressions where framerate collapses mid-match — starting
high, dropping sharply, triggered by spectating, the scoreboard or alt-tabbing, and
recoverable by disconnect + reconnect. If `disconnect` then `retry` restores it, the
problem is the game's UI thread, not the applied tweaks. Check that before searching
the configuration.

## What a good result looks like

There is no target number, because no two machines are comparable. Signs of a healthy
result:

- 0.1 % lows sitting close to the 1 % lows — what "stable frametimes" means
  numerically;
- the AAABBBAAA blocks landing where they should, meaning the machine is deterministic
  enough to test on at all;
- a DPC picture with no single driver dominating — a
  [separate measurement](../../guides/benchmark/dpc-latency/), and the one to take
  first if the lows are ragged rather than merely low.
