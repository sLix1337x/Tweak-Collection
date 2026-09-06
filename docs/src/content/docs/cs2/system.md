---
title: System & driver
description: The Windows and driver layer for CS2 — VBS, thread placement, shader cache, HAGS, ReBAR, and known update regressions.
sidebar:
  order: 5
tags:
  - cs2
  - latency
  - security
  - nvidia
  - anti-cheat
---

Windows and driver settings, ordered by effect on CS2 frame times.

## VBS and HVCI

The largest single software cost on a CPU-bound machine; enabled by default on a clean
install that meets the hardware requirements.

Measured: **~8 % average across games** on a 5800X3D in one controlled suite; **~10 %
average, over 20 % in CPU-sensitive titles** in earlier testing. Lows are hit harder
than averages; a faster GPU does not compensate.

CPUs without hardware GMET (pre-Zen 2) fall back to software emulation and lose more.
The older the CPU, the larger the recovery.

Check the actual state rather than the toggle; the two frequently disagree:

```powershell
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
  Select-Object VirtualizationBasedSecurityStatus, SecurityServicesRunning
```

### Disabling VBS, where the platform permits it

Two layers. Applying only one is a common reason the change appears to do nothing.

```text
Layer 1 — Memory Integrity only (recovers most of the loss, keeps the hypervisor)
  Windows Security → Device security → Core isolation → Memory integrity → Off
  Reboot.

Layer 2 — the VBS layer itself
  HKLM\SYSTEM\CurrentControlSet\Control\DeviceGuard
    EnableVirtualizationBasedSecurity  = 0
    HypervisorEnforcedCodeIntegrity    = 0
  bcdedit /set hypervisorlaunchtype off
  Reboot.
```

Revert: `bcdedit /set hypervisorlaunchtype auto`.

Layer 2 also disables WSL2, Docker Desktop, Windows Sandbox and Hyper-V. Cumulative
updates have been observed re-enabling Memory Integrity; re-check after each update.

### The FACEIT fork

FACEIT requires TPM 2.0 and Secure Boot from all players, and has rolled IOMMU and VBS
out to effectively the whole player base, with Memory Integrity required for specific
accounts and enforced by a hard block. VBS is how the anti-cheat trusts the IOMMU
state. Valve MM and Premier require none of it.

- **MM / Premier only:** both layers available.
- **FACEIT:** no change touching the hypervisor, Secure Boot, TPM or IOMMU applies.
  Applicable work: driver hygiene, the [frame cap](../frame-cap/), thermals, C-states,
  interrupt hygiene and thread placement.

Firmware consequences on FACEIT, because IOMMU must stay on: keep Above 4G Decoding and
ReBAR enabled, disable an unused iGPU where the board allows it (mixed iGPU + dGPU
configurations have known boot conflicts with IOMMU), and do not use chipset RAID on
the boot drive. Advice to disable AMD-Vi for latency does not apply.

Keep the BIOS current — AM4 still receives firmware updates. AGESA ComboAM4v2 1.2.0.F
(September 2025) updated fTPM for Vermeer (5900X/5950X) explicitly "to improve game
compatibility", and 2026 board releases update the Secure Boot keys (2023 KEK/DB/PK).
With FACEIT enforcing TPM 2.0 and Secure Boot attestation, an outdated BIOS can fail
the checks on otherwise working hardware.

Security background: [security guide](../../guides/security/).

### CPU mitigations

```text
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management
  FeatureSettingsOverride      = 3
  FeatureSettingsOverrideMask  = 3
```

State: `Get-SpeculationControlSettings`, or InSpectre.

The gain depends on CPU age. On AMD the switch is close to inert: Zen 3 runs always-on
STIBP that Windows-side tools cannot reach, and testing with mitigations disabled found
STIBP and IBRS still active. The cost is in silicon and already included in every
published Zen 3 benchmark.

Two operational notes: Memory Integrity re-imposes part of what this setting disables,
so it belongs on the VBS-off side of the fork; Windows Update ships microcode that
silently restores the cost.

## Driver and updates

Known bad updates by number. KB5066835 (October 2025) cut FPS in some games until
NVIDIA shipped driver 581.94; the fix was a driver, not a registry key. KB5074109 and
KB5077181 (2026) produced their own regressions, with uninstall confirmed to restore
performance.

Driver *versions* differ measurably even without a regression: a ten-driver sweep by
the scene's reference tester (March 2025) found 531.18 fastest in CS2 on both averages
and 1 % lows. Treat old-branch results as data points, not defaults — anything before
581.94 carries the KB5066835 regression, and the fix list matters more than the last
FPS.

When performance drops with no local change, check Windows Update and driver history
before the configuration. That is the purpose of
[the saved baseline](../measuring/#keep-the-baseline).

An August 2026 cumulative update blocked driver files resembling the generic
`inpoutx64` I/O family — shipped by several RGB and fan-control utilities — after
confirming they could hang or crash games. The side effect is that the RGB software
stops working. **Uninstall vendor RGB stacks rather than closing them** — their kernel
drivers remain in the DPC chain regardless of the tray icon.

Install cleanly: DDU in safe mode if the driver history is messy, then NVCleanstall
with only the components in use. Take the installer-telemetry option; **do not patch
driver telemetry** — it produces a modified driver package that some anti-cheats flag.
[Procedure](../../guides/nvidia-driver-install/).

### Shader cache

The shader cache is in the frame-time path, unlike the rest of storage.

A cache too small for a session's shader output loops compile → cap → evict →
recompile across reboots. Set **Shader Cache Size to 10 GB**; Unlimited is harmless but
unnecessary — the typical total across all games is under ~1 GB.

One stuttery session follows every driver update while the cache rebuilds; this is not
a driver regression. A small minority of systems stutter less with the cache disabled;
where hitching survives the rebuild session, test Disabled as a diagnostic.

Storage is otherwise not the constraint: CS2 loads a map and streams almost nothing.
The native NVMe driver's gains measured within run-to-run variance on consumer SSDs,
and DirectStorage is a streaming API CS2 does not use.

## The composition and GPU layer

| Setting | For CS2 | Notes |
| --- | --- | --- |
| **MPO** | Off **only if symptomatic** | Fixes G-Sync flicker, black flashes, alt-tab stutter; otherwise no benefit and a small latency cost when an overlay appears. Requires **both** `OverlayTestMode = 5` and `OverlayMinFPS = 0` on 24H2+ — [driver guide](../../guides/nvidia-driver-install/#multiplane-overlay-in-more-detail). |
| **HAGS** | Benchmark; mild lean to off on small-VRAM cards | A 2025 test including CS2: +0.3 % average, +1.6 % 1 % lows, 0 % 0.1 % lows. The practical argument is ~1 GB of VRAM freed on an 8 GB card. Required for DLSS Frame Generation, which a 3060 does not have. |
| **Resizable BAR** | **Benchmark it — CS2 may prefer off** | 2–4 % across a 22-game suite generally; CS2 is a documented exception, with controlled Dust2 testing finding similar averages but **~6 % better 1 % lows disabled**. Single-source. |
| **GSP firmware** | Default (off) | Split community testing — one tester measured a large drop in peak DPC latency with no FPS loss, another severe stutter in a DX11 title. Enabling changes the GPU UUID, forcing a shader-cache rebuild that resembles a regression. |
| **NVIDIA Smooth Motion** | **Off** | Interpolation without motion vectors: costs base frame rate, adds latency, produces artefacts on fast motion. Not available on RTX 30. |
| **Power management mode** | Prefer maximum performance | Removes clock-droop frame-time wobble. |
| **Threaded optimization** | Auto | No measurable effect; CS2 manages its own threading. |

Verify in GPU-Z that the card runs at **PCIe x16** under load. Riser cables and
shared-lane boards running at x8 or x4 are a documented cause of unexplained
frame-time problems.

## CPU scheduling

Each subsection applies to a specific CPU family; skip the ones that do not match.

### AMD dual-CCD X3D (7900X3D / 7950X3D / 9950X3D)

Games are pinned to the V-cache CCD while the frequency CCD parks — orchestrated by the
chipset driver's game detection **plus Xbox Game Bar's "this is a game" flag**.
Detection failure wakes the wrong cores.

- **Leave Game Bar and Game Mode on.** Both are load-bearing here, regardless of what
  debloat lists claim.
- **Reinstall the chipset driver cleanly** if CCD selection misbehaves; the toggles
  alone are frequently not enough. Keep it current: the 8.07.16.1035 release fixed
  Application Compatibility Database bugs (the component behind game detection), and
  8.08.12.551 is current as of August 2026.
- **Motherboard "Gaming Mode"** — disabling the non-cache CCD outright — has been
  reported to make CS2 *worse* by starving it of threads.
- Set CPPC to *Cached*, not a manual override.

Single-CCD parts (5600X through 9800X3D) do not need this section.

### AMD dual-CCD without V-cache (5900X / 5950X)

No cache asymmetry exists, so none of the parking machinery applies. What remains is
inter-CCD latency in the lows.

Send *background* processes to the second CCD with a wildcard rule in Process Lasso
(which has per-CCD selection built in) and leave the game free to spread across the
first. Hard-locking CS2 to one CCD so tightly that its workers cannot spread trades a
latency problem for a throughput one. Off FACEIT only.

### Other

**SMT.** CS2 is one of the rare titles where disabling SMT helps some machines — the
main thread does not share a physical core's execution resources well. The correct
implementation is **not** BIOS-disabling SMT: use a per-process affinity rule confining
`cs2.exe` to physical cores while background work keeps the full pool. Based on
community testing; a candidate, not a default.

**Core parking. Check before changing anything.** Instrumented testing found stock
Balanced Windows 11 parked **zero cores**, even at the most efficient power-mode
setting, because desktop defaults hold minimum-unparked-cores at 100 %. The failure
scenario appeared only when parking was *forced*: throughput collapsed 59 % while the
**worst frame time went 6.5 ms → 17.3 ms** and the median barely moved. Parking is a
tail-latency failure mode, not an average-speed tax.

Check Resource Monitor's CPU tab at idle for cores marked *Parked*, or
`powercfg /qh scheme_current sub_processor` and read `CPMINCORES` (`0x64` = 100 % =
parking already off).

## Power and throttling

The [power plan work](../../tweaks/power/) applies unchanged. Three additions.

**Per-app power throttling** — the targeted version of the registry-wide EcoQoS switch:

```powershell
powercfg /powerthrottling disable /path "C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\cs2.exe"
```

Expect steadier lows, not higher averages.

**Verify the plan applied.** Documented 24H2/25H2 bug: High Performance silently
reverts toward Balanced after sleep or reboot — the toggle reads High Performance while
the CPU idles at minimum clocks. Check the actual frequency in Task Manager after boot;
re-select the plan to fix.

Keep the choice in perspective: on a machine already holding its clocks, one tester's
three-plan CS2 benchmark (January 2025) found Power Saving, Balanced and High
Performance within ~2 % of each other. The plan matters when it is wrong (the silent
revert above, or a plan that drops clocks mid-session), not as a performance ladder.

**Thermals set the floor; an undervolt can lower it** — but only if it holds the same
sustained clock at lower voltage. One A/B test where sustained clocks sagged
(1.925 → 1.875 GHz) measured **0.1 % lows ~15 % worse** at equal averages and 60 W less
power. Validate with load *transitions*, not a flat stress loop, then in-game. AMD
implementation: negative Curve Optimizer offset, per CCD on dual-CCD parts.

**Boost policy is a short-burst setting.** Aggressive "Processor performance boost
mode" gained 3–7 % in CPU-sensitive games on a thermally constrained system; the
advantage disappeared after 10–15 minutes once sustained thermal limits took over.

## The background stack

**Defender.** Shader compilation is high-I/O work and real-time scanning intercepts it
synchronously. The targeted exclusions are `%LocalAppData%\NVIDIA\DXCache` and Steam's
*downloading* folder. Never exclude the game directory — it contains kernel-level
anti-cheat. Use path exclusions, not process exclusions. Verify with
`(Get-MpPreference).ExclusionPath`.

**Monitoring software has a cost.** HWiNFO sensor polling and Afterburner's power graph
are documented DPC and stutter sources on some platforms. Diagnose with them, close
them to play, and never leave them running under a benchmark.

**Memory.** On 16 GB, leave compression on. On 32 GB with few background apps,
disabling it is a legitimate Tier-3 A/B — but disabling `SysMain` disables compression
as a side effect, making "SysMain off, compression on" an incoherent state
([why](../../tweaks/services/#why-this-list-is-so-short)). Standby-list cleaners address
a diagnosed symptom: check Task Manager for actual memory pressure during a stutter
first.

**Custom ISOs.** AtlasOS, ReviOS and similar images cut idle CPU and ~1.5 GB of RAM in
use — background noise, not a frame-rate multiplier on a clean install, and the vendor
FPS numbers are vendor-published. Against that: they strip components anti-cheat
platforms depend on, in direct conflict with the
[FACEIT requirements](#the-faceit-fork), and updates can break the image. Windows 11
IoT Enterprise LTSC is the legitimate middle path — an official SKU — but 24H2-based
with murky consumer licensing.

**Xbox Full Screen Experience** is the supported version of what those ISOs promise:
the desktop shell replaced with a full-screen game launcher for the session. Measured
RAM in use 8.6 GB → 7.8 GB (~**9 %**), with Microsoft citing frame-rate gains up to
8.6 % from the reduced background workload. Controller-first, so it suits a session
mode rather than a replacement desktop. It changes the shell session, not the kernel,
so no anti-cheat conflict is expected — confirm rather than assume on FACEIT.
