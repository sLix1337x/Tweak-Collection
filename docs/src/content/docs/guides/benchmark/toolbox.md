---
title: The toolbox
description: Every measurement tool this collection uses, and what each one is for.
sidebar:
  order: 3
tags:
  - measurement
---

| Tool | What it is for |
| --- | --- |
| [CapFrameX](https://www.capframex.com/) | Frame-time capture, percentiles and before/after comparison. The default choice for testing a tweak. |
| [PresentMon](https://github.com/GameTechDev/PresentMon) | The capture engine underneath it, plus an overlay. Use it directly when you want the raw CSV or a scripted run. |
| [LatencyMon](https://www.resplendence.com/latencymon) | DPC and ISR latency, attributed to a driver file. The tool for stutter that is not GPU-bound. |
| [HWiNFO64](https://www.hwinfo.com/) | Sensors: clocks, power, temperatures, throttling reasons. Rules out thermal or power limits before you blame a registry value. |
| [RTSS](https://www.guru3d.com/download/rtss-rivatuner-statistics-server-download/) (with MSI Afterburner) | Frame limiter and overlay. The frame cap itself matters more for latency than most tweaks on this site. |
| [NVIDIA FrameView](https://www.nvidia.com/en-us/geforce/technologies/frameview/) | PresentMon-based capture that also logs board power, and PC latency where Reflex is supported. |
| [xperf / WPA](https://learn.microsoft.com/windows-hardware/test/wpt/) (Windows Performance Toolkit) | The heavy option. When you need to know *which* code path caused a spike rather than which driver file was on the stack. |

Do not run half of these while capturing. An overlay, a sensor poller and a capture
tool all sampling at once is itself a source of frame-time spikes.

