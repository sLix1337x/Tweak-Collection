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

These arrive as a block, usually a `.bat` writing twenty-odd values into the display
driver's class key at once. Value-by-value breakdown:
[NVIDIA page](../../../tweaks/nvidia/#the-rm-block-in-full).

| Value | Verdict |
| --- | --- |
| `RMBandwidthFeature` / `RMBandwidthFeature2` | Placebo: display bandwidth overrides, not frame rate; no measurement published |
| `RMHdcpKeyglobZero`, `RmDisableHdcp22`, `RMSkipHdcp22Init` | Harmful: breaks DRM-protected video playback |
| `RMElcg`, `RMBlcg`, `RMSlcg`, `RMFspg`, `RMElpg`, `RMElpgStateOnInit` | Harmful: disables clock gating, adds heat, costs boost headroom. Likely inert without `RmPowerFeatures = 2` |
| `DisableDynamicPstate` | Harmful: pins the GPU out of low-power states at idle |
| `EnableMClkSlowdown = 0` | Placebo/Harmful: same category |
| `RMEnableASPMAtLoad`, `RMDisableGpuASPMFlags`, `RmOverrideSupportChipsetAspm` | Superseded: [`power.pcie-aspm-off`](../../../tweaks/power/#power.pcie-aspm-off) does this through the documented power subsystem |
| `RMPcieLtrOverride`, `RMDeepL1EntryLatencyUsec`, `RmMIONoPowerOff` | Placebo: test-bench overrides, unmeasured |
| `EnableTiledDisplay = 0` | Placebo on anything that is not a tiled 4K/8K display |
| Hardcoded `NvTmRep_..._{B2FE1952-...}` task GUIDs | Invalid: a constant from GeForce Experience-era task names; recent drivers do not create the tasks |
| GPU interrupt `DevicePriority = High` | Placebo: no documented or measured benefit on a desktop GPU |

---
