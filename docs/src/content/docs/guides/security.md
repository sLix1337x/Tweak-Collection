---
title: Security
description: What VBS, HVCI, Secure Boot and TPM each cost in performance, and what anti-cheat requires to be kept.
sidebar:
  order: 3
tags:
  - security
  - anti-cheat
  - bios
---

Most "gaming optimisation" advice about security features predates kernel-level
anti-cheat. Disabling these can cost the ability to launch the game being optimised
for.

## The four that anti-cheat cares about

| Feature | Keep it | Why |
| --- | --- | --- |
| **Secure Boot** | On | Riot Vanguard requires it on Windows 11. Others are moving the same way. |
| **TPM 2.0** | On | Same requirement, same direction of travel. |
| **Virtualisation (VT-x / AMD-V)** | On | Vanguard and several others require or strongly prefer virtualisation-based protections. Turning it off in firmware also disables VBS, WSL, Sandbox, Docker and Hyper-V. |
| **Driver signature enforcement** | On | Disabling it or enabling test signing is treated as tampering by every kernel anti-cheat there is. |

AMD's **TSME** is a fifth firmware security feature with a performance cost, but no
anti-cheat reads it and it is a physical-access defence rather than a software one, so it
is weighed on the [BIOS page](../bios/worth-changing/#memory-encryption-tsme) instead.

## VBS and HVCI — the one real trade

The only item here with a measurable performance cost, and its size depends on whether
the title is CPU-bound. Independent testing puts it around **8–10 % on average across
games**, with percentile lows hit harder than averages and CPU-sensitive titles worse
than that; a GPU-bound game may show nothing. A faster GPU does not compensate.

CPUs with hardware MBEC (Intel Kaby Lake and newer) or GMET (AMD Zen 2 and newer) pay
much less, because Windows otherwise falls back to software emulation. The cost is
higher than the average figure on older CPUs.

Test HVCI specifically: Windows Security → Device Security → Core Isolation →
**Memory Integrity**. That switch is reversible in two clicks, leaves virtualisation
available, and does not touch Secure Boot or the TPM. Measure with
[frame-time captures](../benchmark/frame-times/) before and after, three runs each.

Disabling virtualisation in firmware for the same few percent takes VBS, Credential
Guard, WSL and anti-cheat compatibility with it.

:::caution[On a competitive machine the platform decides this]
FACEIT requires TPM 2.0 and Secure Boot from every player, has rolled IOMMU and VBS
requirements out to effectively its whole player base, and demands Memory Integrity
from some accounts. Valve matchmaking and Premier require none of it.

"Maximum performance" and "can play on FACEIT" are therefore two machine
configurations. The fork, with the registry and BCD state on each side, is on the
[CS2 system page](../../cs2/system/#vbs-and-hvci).
:::

## Where anti-cheat actually interacts with this collection

Nothing in the tweak list touches anti-cheat. Three things elsewhere do:

- **Driver installs.** A repacked NVIDIA driver breaks the signature Easy
  Anti-Cheat checks. NVCleanstall's EAC-compatible mode re-signs it. See
  [installing a driver cleanly](../nvidia-driver-install/).
- **Service disabling.** Anti-cheat installs as a service, and wholesale service lists
  disable it. See [services](../../tweaks/services/).
- **Firmware.** The four settings above, on the [BIOS page](../bios/worth-changing/).

## What does not work

| Claim | Reality |
| --- | --- |
| "Disable Defender for FPS" | Real-time scanning costs I/O, not frames. |
| Blanket Defender exclusions for game folders | Removes scanning from the directory most likely to receive an untrusted file. Where an exclusion is unavoidable, exclude a shader cache, not a downloads path. |
| Disabling Secure Boot for compatibility | The compatibility problem is usually an unsigned driver, which is what Secure Boot exists to stop. |
| Disabling SmartScreen, UAC and Windows Update as "debloat" | None has a measurable frame-time effect, and each removes a defence. |

Privacy settings change what leaves the machine rather than what protects it, and are
on the [privacy page](../../tweaks/privacy/).
