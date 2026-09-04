---
title: Security
description: VBS, HVCI, Secure Boot and TPM — what each costs in performance, and what anti-cheat requires you to keep.
sidebar:
  order: 3
tags:
  - security
  - anti-cheat
  - bios
---

Most "gaming optimisation" advice about security features is a decade old and was
written before kernel-level anti-cheat existed. Turning these off today can cost
you the ability to launch the game you were optimising for.

## The four that anti-cheat cares about

| Feature | Keep it | Why |
| --- | --- | --- |
| **Secure Boot** | On | Riot Vanguard requires it on Windows 11. Others are moving the same way. |
| **TPM 2.0** | On | Same requirement, same direction of travel. |
| **Virtualisation (VT-x / AMD-V)** | On | Vanguard and several others require or strongly prefer virtualisation-based protections. Turning it off in firmware also disables VBS, WSL, Sandbox, Docker and Hyper-V. |
| **Driver signature enforcement** | On | Disabling it or enabling test signing is treated as tampering by every kernel anti-cheat there is. |

Anti-cheat is the practical argument. The security argument is the same one, and it
applies whether or not you play anything.

## VBS and HVCI — the one real trade

**VBS** (virtualisation-based security) runs part of the kernel inside a hypervisor
protected region. **HVCI** / Memory Integrity is the piece of it that verifies
drivers before they load.

This is the only item here with a measurable performance cost, and the honest
figure is *a few percent in some titles, nothing in most*. If you want to test it,
test HVCI specifically:

Windows Security → Device Security → Core Isolation → **Memory Integrity**.

That switch is reversible in two clicks, leaves virtualisation itself available,
and does not touch Secure Boot or the TPM. Measure it with
[frame-time captures](../benchmark/frame-times/)
before and after, three runs each. If you cannot see it, leave it on.

Turning off virtualisation in firmware to get the same few percent is the wrong
lever: it takes VBS, Credential Guard, WSL and your anti-cheat compatibility with
it.

## Where anti-cheat actually interacts with this collection

Nothing in the tweak list touches anti-cheat. Three things elsewhere do:

- **Driver installs.** A repacked NVIDIA driver breaks the signature Easy
  Anti-Cheat checks. NVCleanstall's EAC-compatible mode re-signs it — see
  [installing a driver cleanly](../nvidia-driver-install/).
- **Service disabling.** Anti-cheat services are installed as services. The
  wholesale "disable everything" service lists take them with them, which is one of
  several reasons [that page is short](../../tweaks/services/).
- **Firmware.** The four settings above, all on the [BIOS page](../bios/worth-changing/).

## What does not work

| Claim | Reality |
| --- | --- |
| "Disable Defender for FPS" | Real-time scanning costs I/O, not frames. Disabling it on a machine that downloads game mods is a bad trade in the other direction. |
| Blanket Defender exclusions for game folders | Reduces scanning of exactly the directory most likely to receive an untrusted file. If you exclude anything, exclude a shader cache, not a downloads path. |
| Disabling Secure Boot for compatibility | The compatibility problem it solves is usually an unsigned driver, which is the thing Secure Boot exists to stop. |
| Disabling SmartScreen, UAC and Windows Update together as "debloat" | None of the three has a measurable frame-time effect, and each removes a defence. |

The privacy settings in this collection are a separate question and are treated as
one: they change what leaves the machine, not what protects it. They are on the
[privacy page](../../tweaks/privacy/).
