---
title: How a tweak earns its place
description: The four questions a tweak has to answer before it ships here instead of going on the rejected list.
sidebar:
  order: 2
tags:
  - measurement
  - debunked
---

Tweaks that fail these four questions are on the
[debunked list](../../reference/debunked/) with the reason.

## 1. What mechanism does it change?

Which subsystem, and how. A tweak whose mechanism cannot be named is folklore.

`NetworkThrottlingIndex` has an answer: it is the maximum number of `NET_BUFFER_LIST`
structures a miniport may indicate per receive DPC while a registered MMCSS thread in
the Medium or High category is scheduled.

"Set `RMBandwidthFeature` to 1896072192" does not. The field is a display-bandwidth
override with no stated relationship to frame rate, and the number is not derived from
a measurement.

## 2. Is it still true on current Windows?

Windows 11 has removed, renamed and re-defaulted much of what older guides were built
on, and the guides are not re-checked.

`netsh int tcp set global chimney=disabled` targets a feature deprecated in Server
2016, and `wmic` was dropped from Windows 11 24H2. Scripts carrying either redirect
output to `nul` and report success.

Everything here is checked against a current Windows 11 install. Where a setting has a
version cut-off, the page states it.

## 3. What does it cost?

Disabling NIC interrupt moderation lowers latency and raises CPU load. Ultimate
Performance stops core parking and burns idle watts. Disabling Fast Startup makes boot
slower and system state cleaner.

A tweak claiming pure upside usually does nothing.

## 4. Can it be undone?

The script captures the previous value before writing and stores it in a backup file.
A setting that cannot be captured and restored goes in
[settings outside the registry](../../reference/settings-outside-the-registry/) with
manual instructions instead.

## The ratings

**Risk** is about what happens if the tweak misbehaves on a given machine:

| Rating | Meaning |
| --- | --- |
| <span class="risk-low">Low</span> | Worst case it does nothing. Reversible without drama. |
| <span class="risk-medium">Medium</span> | A real trade-off, or a small chance of a device misbehaving until reverted. |
| <span class="risk-high">High</span> | Can prevent booting or break a device. Nothing in the script is rated this. |

**Evidence** is about how well established the effect is:

- **Documented**: Microsoft or the hardware vendor documents the setting and what it does.
- **Measurable**: not formally documented, but the effect reproduces in frame-time or DPC latency captures.
- **Situational**: a real effect, but whether it helps depends on the hardware and workload.

Nothing below "Situational" ships in the script. Everything below that is on the
[debunked list](../../reference/debunked/).

## Why the list is short

The batch scripts this collection replaced wrote roughly sixty registry values. Against
the four questions:

- Several wrote values the kernel does not accept and silently ignores, such as
  `TcpAckFrequency = 0`.
- Several called commands that no longer exist on Windows 11.
- About a third were NVIDIA `RM*` keys with no observable effect.
- One block set `*EEE = 1` and `*FlowControl = 1` — which *enables* both — under a
  header stating it disabled them.
- One disabled Receive Side Scaling, capping network throughput to a single CPU core.

Twenty tweaks survived.
