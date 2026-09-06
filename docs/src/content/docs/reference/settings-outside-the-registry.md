---
title: Settings outside the registry
description: The Windows and firmware settings that live in a GUI or a powercfg call, what each one does, and which of them are worth changing.
sidebar:
  order: 3
tags:
  - power
  - services
  - measurement
---

Settings no script here writes, either because they need a GUI or because the correct
value depends on the hardware. Application order:
[fresh install order](../fresh-install-order/).

## Windows settings that are not registry values

| Setting | Where | Note |
| --- | --- | --- |
| **Hardware-accelerated GPU scheduling** | Settings → System → Display → Graphics → Change default graphics settings | Test both ways. Helps on some driver/GPU combinations and hurts on others. |
| **Optimisations for windowed games** | Same page | Leave **on**. Replaces the old "disable fullscreen optimisations" advice; gives borderless-windowed games a path close to exclusive fullscreen latency. |
| **Variable refresh rate** | Same page | On, where the monitor supports it. |
| **Core isolation / Memory integrity** | Windows Security → Device security | Costs a few percent in some titles, against a real security trade. Do **not** disable virtualisation in BIOS instead; see [BIOS settings](../../guides/bios/outdated-advice/#disable-cpu-virtualisation). |
| **Per-application power management** | NVIDIA Control Panel → Manage 3D settings → Program Settings | Set *Power management mode* to **Prefer maximum performance** for the applications that matter. Applying it to `explorer.exe` and `dwm.exe` does nothing — they are not GPU-bound. |
| **Storage Sense** | Settings → System → Storage | Off, where disk cleanup is handled manually. |

## Two powercfg commands

```powershell
powercfg /h off          # no hibernation, no hiberfil.sys, and no Fast Startup
powercfg /s scheme_current
```

Fast Startup *is* a hibernation file, so `/h off` removes it and returns the disk
space. Use on a machine that never hibernates.
[`system.fast-startup-off`](../../tweaks/power/#system.fast-startup-off) is the
narrower version: it clears `HiberbootEnabled` and leaves hibernation working.

`/s` is `setactive` and `scheme_current` aliases the active scheme, so the second
command re-applies the active plan to itself. As a power *setting* it is a no-op; its
effect is to make the power subsystem re-read the registry. Power values edited
directly in the registry do nothing until something reapplies the scheme.

```powershell
powercfg /getactivescheme   # the scheme actually in effect
```

## Power settings the GUI hides

Windows hides most per-scheme power settings from the advanced power plan dialog. Each
has an `Attributes` value: `1` hides it, `2` shows it. Setting it to `2` changes what
the dialog offers, not what the machine does.

The circulating one-liner has a broken regular expression:

```powershell
# Wrong. (\[0-9]|\b255)$ matches a literal "[", so it does not exclude anything.
(gci 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings' -Recurse).Name -notmatch '\bDefaultPowerSchemeValues|(\[0-9]|\b255)$' | % {sp $_.Replace('HKEY_LOCAL_MACHINE','HKLM:') -Name 'Attributes' -Value 2 -Force}
```

Under each setting's key are numbered subkeys (`\0`, `\1`, `\2` …) that define its
possible values. The filter is meant to skip those. It does not, and `-Force` then
creates a meaningless `Attributes` value inside each one. On this machine that is
417 keys written instead of 223.

```powershell
# Correct: skip DefaultPowerSchemeValues and any key whose last segment is a number
$root = 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings'
(Get-ChildItem $root -Recurse).Name -notmatch 'DefaultPowerSchemeValues|\\\d+$' |
  ForEach-Object {
    Set-ItemProperty ($_ -replace 'HKEY_LOCAL_MACHINE', 'HKLM:') -Name Attributes -Value 2 -Force
  }
```

`\\\d+$` is "a backslash, then digits, at the end", which is what a numbered subkey
path looks like. Another circulating fix, `\[0-9]$|\255$`, also excludes nothing: it
still matches a literal `[0-9]`, and `\255` is an octal escape in .NET.

Swap `-Value 2` for `-Value 1` to hide them again. This changes only which settings the
dialog exposes for editing.

:::caution[Unhiding exposes undocumented settings]
Several dozen settings with no documentation and no obvious safe range: processor idle
promote and demote thresholds, core parking granularity, latency tolerances. A wrong
value does not crash — it makes the machine behave slightly worse in a way that is hard
to attribute later. Change one thing at a time and record what it was.
:::

## Storage checks that are not tweaks

Worth checking on a new install; none need changing on a healthy one:

```powershell
fsutil behavior query DisableDeleteNotify   # TRIM. 0 = enabled, which is the default
winsat disk -drive c                        # sequential/random throughput and latency
Get-MMAgent                                 # prefetch, superfetch, memory compression state
```

TRIM has been on by default for years; `fsutil behavior set DisableDeleteNotify 0` only
matters if something turned it off. `Get-MMAgent` shows whether a tweak utility has
been through the machine — see
[debunked](../debunked/storage-and-memory/#disabling-memory-compression--situational).

Where a driver change produces shader corruption, `%LocalAppData%\NVIDIA\DXCache` and
`GLCache` are safe to delete as a repair, not as a tweak.

## Interrupt affinity

Pinning GPU, mouse, keyboard and audio interrupts to specific cores with the Interrupt
Affinity Policy Tool is a standard recommendation in latency guides.

It is a real technique and the most likely item here to make a machine worse: it
requires knowing which cores are least busy for *that specific* workload, and getting
it wrong pins a high-rate interrupt onto the core running the game's render thread.

Three rules:

- **Never CPU 0.** Windows concentrates its own housekeeping interrupts there, which
  makes the widely copied "pin everything to CPU 0" instruction backwards.
- **The GPU first, if anything.** It raises an interrupt per completed frame, making it
  the highest-frequency and highest-cost device; the NIC and USB controller are a
  distant second and third. Leave a NIC with healthy RSS alone — RSS already spreads
  receive processing across its own CPU set.
- **Verify it took effect.** Drivers read the policy at device start, so a registry
  write with no device restart does nothing. Per-CPU interrupt counters are the only
  proof the assignment is live.

Measure with LatencyMon first, change one device, measure again. There is no automated
revert, which is why it is not in the script.
