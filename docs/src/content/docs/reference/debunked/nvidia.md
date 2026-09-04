---
title: NVIDIA
description: The RM* registry values that circulate in GPU tweak scripts, and what each one actually does.
sidebar:
  order: 3
tags:
  - debunked
  - nvidia
  - registry
---

These arrive as a block, usually as a `.bat` that writes twenty-odd values into the
display driver's class key at once. The full breakdown, value by value, is on the
[NVIDIA page](../../../tweaks/nvidia/#the-rm-block-in-full).

| Value | Verdict |
| --- | --- |
| `RMBandwidthFeature` / `RMBandwidthFeature2` | Placebo — undocumented bit field, no measurement, no source |
| `RMHdcpKeyglobZero`, `RmDisableHdcp22`, `RMSkipHdcp22Init` | Harmful — breaks DRM-protected video playback |
| `RMElcg`, `RMBlcg`, `RMSlcg`, `RMFspg`, `RMElpg`, `RMElpgStateOnInit` | Harmful — disables clock gating, adds heat, costs boost headroom |
| `DisableDynamicPstate` | Harmful — pins the GPU out of low-power states at idle |
| `EnableMClkSlowdown = 0` | Placebo/Harmful — same category |
| `RMEnableASPMAtLoad`, `RMDisableGpuASPMFlags`, `RmOverrideSupportChipsetAspm` | Superseded — [`power.pcie-aspm-off`](../../../tweaks/power/#power.pcie-aspm-off) does this properly |
| `RMPcieLtrOverride`, `RMDeepL1EntryLatencyUsec`, `RmMIONoPowerOff` | Placebo — undocumented, unmeasured |
| `EnableTiledDisplay = 0` | Placebo on anything that is not a tiled 4K/8K display |
| Hardcoded `NvTmRep_..._{B2FE1952-...}` task GUIDs | Invalid — that GUID belonged to a GeForce Experience install that no longer exists |
| GPU interrupt `DevicePriority = High` | Harmful — no reproducible gain, known instability |

---
