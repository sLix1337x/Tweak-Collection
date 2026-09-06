---
title: DPC latency
description: "LatencyMon: what it measures, what the numbers mean, and which driver names point where."
sidebar:
  order: 1
tags:
  - measurement
  - latency
---

[LatencyMon](https://www.resplendence.com/latencymon) measures how long deferred
procedure calls block the kernel. High DPC latency is what causes audio crackle,
frame-time spikes and stutter that no amount of GPU headroom fixes.

Run it for at least ten minutes while doing something representative, not on an
idle desktop.

**Check hard page faults first.** Memory pressure produces stutter that looks
identical to driver latency — a browser, Discord, a capture tool and RGB software on
a 16 GB machine is enough — and LatencyMon reports page-fault counts alongside DPC
times. A machine that is paging does not have a DPC problem to solve yet.

**What to look at:**

- **Highest measured interrupt to process latency**: under 500 µs is fine, over
  1000 µs means something is wrong.
- **The drivers tab, sorted by highest execution time.** This is the useful part.
  It names the file responsible.

**Common offenders and what they mean:**

| Driver | Usually means |
| --- | --- |
| `ndis.sys`, `e1d68x64.sys`, `rt640x64.sys` | Network stack or NIC driver. Try the [network tweaks](../../../tweaks/network/). |
| `storport.sys`, `storahci.sys`, `stornvme.sys` | Storage. Often PCIe ASPM; see [`power.pcie-aspm-off`](../../../tweaks/power/#power.pcie-aspm-off). |
| `nvlddmkm.sys` | NVIDIA display driver. Try [`nvidia.msi-mode`](../../../tweaks/nvidia/#nvidia.msi-mode), or a different driver branch. |
| `ACPI.sys`, `intelppm.sys` | CPU power management. Try the Ultimate Performance plan and check C-state settings in BIOS. |
| `Wdf01000.sys` | The Kernel-Mode Driver Framework runtime, shared by many drivers, so the cause is a KMDF driver rather than this file. Usually a peripheral. Unplug devices one at a time. |
| `dxgkrnl.sys` | Graphics kernel. Often a symptom of the display driver rather than the cause. |

:::note[LatencyMon reports symptoms, not causes]
A high number against `ndis.sys` does not mean NDIS is broken. It means something in
the network path is holding the CPU. The driver name narrows the search; it is not
the answer.
:::

