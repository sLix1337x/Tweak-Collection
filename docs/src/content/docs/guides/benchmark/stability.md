---
title: Stability
description: Reliability Monitor, minidumps, memtest86 and load testing — for crashes rather than frames.
sidebar:
  order: 4
tags:
  - measurement
---

For stability rather than performance, the tools are different:

| Tool | What it catches |
| --- | --- |
| **Windows Reliability Monitor** (`perfmon /rel`) | The timeline view of crashes and failed updates. Start here — it is built in and nobody looks at it. |
| **WhoCrashed** or **WinDbg** | Reads minidumps and names the faulting driver. |
| **Event Viewer**, System log, filtered to Critical + Error | Kernel-Power event 41 means the machine lost power without a clean shutdown: PSU, overheating, or an unstable overclock. |
| **memtest86** | RAM. Run it before blaming anything else, especially with XMP/EXPO enabled. |
| **OCCT** or **Prime95** + **FurMark** | Load testing. A machine that is stable at idle and crashes under load is a power or thermal problem, not a Windows setting. |

:::tip[Rule out the obvious first]
Before tweaking anything for stability: run memtest, check your RAM is running at a
speed the CPU's memory controller actually supports, and confirm your CPU is not
thermal throttling. An unstable XMP profile presents as random application crashes
and gets blamed on Windows constantly.
:::
