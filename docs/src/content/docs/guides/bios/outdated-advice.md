---
title: Advice that no longer holds
description: The five firmware settings gaming guides get wrong (SMT, virtualisation, C-states, the iGPU and Secure Boot).
sidebar:
  order: 5
tags:
  - bios
  - anti-cheat
---

### "Disable HyperThreading / SMT"

**Do not.** The advice dates from an era when a few games scheduled badly across
logical cores.

On a modern CPU (5950X onwards), disabling SMT discards 15–30 % of throughput. Modern
engines use many threads and the Windows scheduler understands the topology.

It can be tested on a genuinely CPU-bound competitive title. See the
[CS2 per-process alternative](../../../cs2/system/#cpu-scheduling), which confines the
game to physical cores without removing the threads from everything else.

### "Disable CPU virtualisation"

**Do not.**

- Windows 11 uses virtualisation-based security (VBS, HVCI, Credential Guard) as a
  core defence. Turning off VT-x/AMD-V disables it.
- Several anti-cheat systems, Riot Vanguard among them, require or strongly
  prefer virtualisation-based protections. Some will refuse to launch.
- WSL, Windows Sandbox, Docker, Hyper-V and Android emulators all stop working.

The performance claim is that VBS costs a few percent, which it can in some titles. To
reclaim that specifically, disable **Memory Integrity/HVCI** in Windows Security →
Device Security → Core Isolation: reversible in two clicks, and it leaves
virtualisation available. Disabling virtualisation in firmware is a security downgrade
for the same few percent.

### "Disable C-states"

**Situational.** Deep C-states add wake-up latency. Disabling them entirely means the
CPU never idles, raising temperature and reducing the headroom single-core boost
depends on, which can produce lower peak clocks than the machine started with.

Where LatencyMon points at `intelppm.sys` or `ACPI.sys`, disable C-states deeper than
C1 and measure. Otherwise leave them.

This covers *core* C-states. **DF C-states** are a separate setting covering the Data
Fabric, on both sockets — see [AM4](../am4/#fabric-and-link-power-states) or
[AM5](../am5/#fabric-and-link-power-states).

The Ultimate Performance power plan gets most of the benefit with none of the thermal
cost, and is reversible.

### "Disable the iGPU"

**Only for a specific conflict.** An idle integrated GPU costs essentially nothing, can
drive a secondary display, handles video decode, and is the only way to see a POST
screen when the discrete card fails.

### "Disable Secure Boot"

**Do not.** Several anti-cheat systems require Secure Boot and TPM 2.0.

## The advice this replaces

A representative Windows 10-era BIOS list:

```text
iGPU - off
HyperThreading - off
CPU Virtualization - off
C-states - off
Integrated Audio - off if not needed
```

Four of the five are corrected above. "Integrated Audio off if not needed" holds up and
is the least significant item on the list.
