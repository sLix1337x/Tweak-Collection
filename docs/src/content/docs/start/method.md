---
title: How a tweak earns its place
description: The four questions a tweak has to answer before it ships here instead of going on the rejected list.
sidebar:
  order: 2
tags:
  - measurement
  - debunked
---

Most tweaks in circulation do not survive contact with these four questions. The
ones that fail are on the [debunked list](../../reference/debunked/) instead, with
the reason.

## 1. What mechanism does it change?

Not "it makes the system snappier" — which subsystem, and how. A tweak whose
mechanism cannot be named is folklore, and applying it is moving numbers around.

`NetworkThrottlingIndex` is a real answer: Windows caps non-multimedia network
processing at roughly ten packets per millisecond while a multimedia application is
running, and this value is that cap.

"Set `RMBandwidthFeature` to 1896072192" is not an answer. The number is an
undocumented bit field, and nobody circulating it can say what it means.

## 2. Is it still true on current Windows?

This is where most old tweak guidance dies. Windows 11 has removed, renamed and
re-defaulted a great deal of what these guides were built on, and the guides do not
get re-checked.

Two examples that still circulate widely: `netsh int tcp set global
chimney=disabled` targets a feature removed after Windows 7, and `wmic` was dropped
from Windows 11 24H2 entirely. Scripts carrying either usually redirect output to
`nul`, so they report success for years.

Everything here is checked against a current Windows 11 install. Where a setting has
a version cut-off, the page says so.

## 3. What does it cost?

Almost nothing is free, and the cost belongs in writing. Disabling NIC interrupt
moderation lowers latency and raises CPU load. Ultimate Performance stops core
parking and burns idle watts. Disabling Fast Startup makes boot slower and system
state cleaner.

A tweak with a stated cost is honest. A tweak claiming pure upside usually does
nothing at all.

## 4. Can it be undone?

The script captures the previous value before it writes a new one and stores it in a
backup file. A setting that cannot be captured and restored does not go in the
script — it goes in
[settings outside the registry](../../reference/settings-outside-the-registry/) with
instructions instead.

## The ratings

**Risk** is about what happens if the tweak misbehaves on your hardware:

| Rating | Meaning |
| --- | --- |
| <span class="risk-low">Low</span> | Worst case it does nothing. Reversible without drama. |
| <span class="risk-medium">Medium</span> | A real trade-off, or a small chance of a device misbehaving until reverted. |
| <span class="risk-high">High</span> | Can prevent booting or break a device. Nothing in the script is rated this. |

**Evidence** is about how well established the effect is:

- **Documented** — Microsoft or the hardware vendor documents the setting and what it does.
- **Measurable** — not formally documented, but the effect reproduces in frame-time or DPC latency captures.
- **Situational** — a real effect, but whether it helps depends on your hardware and workload.

Nothing ships in the script below "Situational". Everything below that is on the
[debunked list](../../reference/debunked/).

## Why the list is short

The batch scripts this collection replaced wrote roughly sixty registry values.
Applying the four questions to them:

- Several wrote values the kernel does not accept and silently ignores, such as
  `TcpAckFrequency = 0`.
- Several called commands that no longer exist on Windows 11.
- About a third were undocumented NVIDIA `RM*` keys with no observable effect.
- A few did the opposite of what the comment above them claimed — one block set
  `*EEE = 1` and `*FlowControl = 1`, which *enables* both, under a header saying it
  was disabling them.
- One disabled Receive Side Scaling, which caps network throughput to a single CPU
  core.

Twenty tweaks survived. A short list that can be defended is worth more than a long
one that cannot.
