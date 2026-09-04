---
title: Advice that no longer holds
description: SMT, virtualisation, C-states, the iGPU and Secure Boot — five firmware settings gaming guides get wrong.
sidebar:
  order: 4
tags:
  - bios
  - anti-cheat
---

### "Disable HyperThreading / SMT"

**Do not.** This advice is a decade old and dates from an era when a handful of
games scheduled badly across logical cores.

On a modern CPU — anything from a 5950X onwards — disabling SMT throws away 15–30%
of your CPU's throughput. Modern game engines use many threads. Windows' scheduler
understands the topology. The specific scenario this was supposed to fix does not
occur on current hardware and current Windows.

If you have a genuinely CPU-bound competitive title and you want to test it, test
it and measure. You will almost certainly measure a loss.

### "Disable CPU virtualisation"

**Do not.** This one has gone from useless to actively harmful.

- Windows 11 uses virtualisation-based security (VBS, HVCI, Credential Guard) as a
  core defence. Turning off VT-x/AMD-V disables it.
- Several anti-cheat systems — Riot Vanguard among them — require or strongly
  prefer virtualisation-based protections. Some will refuse to launch.
- WSL, Windows Sandbox, Docker, Hyper-V and Android emulators all stop working.

The performance claim behind the advice is that VBS costs a few percent. It can, in
some titles. If you specifically want to reclaim that, disable **Memory
Integrity/HVCI** in Windows Security → Device Security → Core Isolation, which is
reversible in two clicks and leaves virtualisation itself available. Turning off
virtualisation in firmware is the wrong lever, and it is a real security downgrade —
which is a decision to make deliberately, not because a tweak list said so.

### "Disable C-states"

**Situational, and rarely worth it.** Deep C-states add wake-up latency, which is
the actual concern. But disabling them entirely means the CPU never idles, which
raises temperature, which on a modern boost algorithm reduces the headroom your
single-core boost depends on. You can end up with lower peak clocks than you
started with.

If you are chasing DPC latency and LatencyMon points at `intelppm.sys` or
`ACPI.sys`, try disabling C-states deeper than C1 and measure. Otherwise leave them.

This is about *core* C-states. AM4's **DF C-states** are a separate setting covering
the Data Fabric, and are dealt with [above](../am4/).

The Windows-side equivalent — the Ultimate Performance power plan — gets most of
the benefit with none of the thermal cost, and is reversible.

### "Disable the iGPU"

**Only if it is causing a problem.** An idle integrated GPU costs essentially
nothing. Meanwhile it is genuinely useful: it can drive a secondary display, handle
video decode, and — most importantly — it is your only way to see a POST screen when
the discrete card fails.

Disable it if you have a specific conflict. Not as routine maintenance.

### "Disable Secure Boot"

**Do not.** Beyond the security implications, several anti-cheat systems now require
Secure Boot and TPM 2.0. Disabling them means not being able to play.


## The advice this replaces

The `#ManualTweak.txt` this repo started as listed, under BIOS:

```text
iGPU - off
HyperThreading - off
CPU Virtualization - off
C-states - off
Integrated Audio - off if not needed
```

Four of those five are covered above, and they either do nothing or cost you
something. "Integrated Audio off if not needed" is the one that holds up, and it is
the least significant item on the list.

That list dates from around 2023 and reflects Windows 10-era advice. It is kept here
only to show what the corrections above are answering, not as instructions.
