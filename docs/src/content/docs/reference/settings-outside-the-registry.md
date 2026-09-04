---
title: Settings outside the registry
description: The Windows and firmware settings that live in a GUI or a powercfg call — what each one does, and which of them are worth changing.
sidebar:
  order: 3
tags:
  - power
  - services
  - measurement
---

Everything here is a real setting that no script in this collection writes, either
because it needs a GUI or because the right value depends on your hardware. The
order to apply them in is on [fresh install order](../fresh-install-order/).

## Windows settings that are not registry values

| Setting | Where | Note |
| --- | --- | --- |
| **Hardware-accelerated GPU scheduling** | Settings → System → Display → Graphics → Change default graphics settings | Test both ways. It helps on some driver/GPU combinations and hurts on others. Genuinely worth measuring rather than assuming. |
| **Optimisations for windowed games** | Same page | Leave **on**. This is the replacement for the old "disable fullscreen optimisations" advice — it gives borderless-windowed games a path close to exclusive fullscreen latency. |
| **Variable refresh rate** | Same page | On, if your monitor supports it. |
| **Core isolation / Memory integrity** | Windows Security → Device security | Costs a few percent in some titles. Turning it off is a real security trade — decide deliberately. Do **not** disable virtualisation in BIOS instead; see [BIOS settings](../../guides/bios/outdated-advice/#disable-cpu-virtualisation). |
| **Per-application power management** | NVIDIA Control Panel → Manage 3D settings → Program Settings | Set *Power management mode* to **Prefer maximum performance** for the applications that matter. The original notes suggested doing this for `explorer.exe` and `dwm.exe` as well, which does nothing useful — they are not GPU-bound. |
| **Storage Sense** | Settings → System → Storage | Off, if you would rather manage disk cleanup yourself. |

## Two powercfg commands worth knowing

```powershell
powercfg /h off          # no hibernation, no hiberfil.sys, and no Fast Startup
powercfg /s scheme_current
```

The first is the blunt way to turn Fast Startup off: Fast Startup *is* a
hibernation file, so removing hibernation removes it, and you get the disk space
back as well. Use it if you never hibernate. The script's
[`system.fast-startup-off`](../../tweaks/power/#system.fast-startup-off)
is the narrower version — it clears `HiberbootEnabled` and leaves hibernation
working.

The second is the one nobody explains. `/s` is `setactive`, and `scheme_current` is
an alias for whichever scheme is already active, so it re-applies the active plan to
itself. That sounds like a no-op, and as a power *setting* it is — its use is that
it makes the power subsystem re-read the registry. Edit power values directly in the
registry and nothing happens until something reapplies the scheme; this is that,
without a reboot.

```powershell
powercfg /getactivescheme   # what you are actually running
```

## Power settings the GUI hides

Windows hides most per-scheme power settings from the advanced power plan dialog.
Each one has an `Attributes` value: `1` hides it, `2` shows it. Setting it to `2` is
cosmetic and reversible — it changes what the dialog offers, not what the machine
does.

The one-liner that circulates for this has a broken regular expression:

```powershell
# Wrong. (\[0-9]|\b255)$ matches a literal "[", so it does not exclude anything.
(gci 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerSettings' -Recurse).Name -notmatch '\bDefaultPowerSchemeValues|(\[0-9]|\b255)$' | % {sp $_.Replace('HKEY_LOCAL_MACHINE','HKLM:') -Name 'Attributes' -Value 2 -Force}
```

Under each setting's key are numbered subkeys — `\0`, `\1`, `\2` … — that define its
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

`\\\d+$` is "a backslash, then digits, at the end" — which is exactly what a
numbered subkey path looks like. An earlier version of this page offered
`\[0-9]$|\255$` as the fix; that still matches a literal `[0-9]`, and `\255` is an
octal escape in .NET, so it excluded nothing either. Test a regex against a real
path before trusting it.

Swap `-Value 2` for `-Value 1` to hide them again. Nothing here changes a power
setting; it only decides which ones the dialog will let you change.

:::caution[Unhiding is the easy half]
It exposes several dozen settings with no documentation and no obvious safe range —
processor idle promote and demote thresholds, core parking granularity, latency
tolerances. A wrong value there is not a crash, it is a machine that behaves
slightly worse in a way you will not connect to this a month later. Unhide to look;
change one thing at a time, and write down what it was.
:::

## Storage checks that are not tweaks

Three things worth *checking* on a new install, none of which need changing on a
healthy one:

```powershell
fsutil behavior query DisableDeleteNotify   # TRIM. 0 = enabled, which is the default
winsat disk -drive c                        # sequential/random throughput and latency
Get-MMAgent                                 # prefetch, superfetch, memory compression state
```

TRIM has been on by default for years — `fsutil behavior set DisableDeleteNotify 0`
only matters if something turned it off. `Get-MMAgent` is the fast way to find out
whether a tweak utility has been through the machine already; see
[debunked](../debunked/storage-and-memory/#disabling-memory-compression--situational) for why the
answers there are usually best left alone.

If a driver change leaves you with shader corruption, `%LocalAppData%\NVIDIA\DXCache`
and `GLCache` are safe to delete — as a repair, not as a tweak.

## Interrupt affinity

Pinning GPU, mouse, keyboard and audio interrupts to specific cores with the
Interrupt Affinity Policy Tool is a standard recommendation in latency guides.

It is a genuine technique, and it is also the most likely thing on this whole site
to make a machine worse. It requires knowing which cores are least busy for
*your* workload, and getting it wrong means pinning a high-rate interrupt onto the
core your game's render thread is on.

If you want to try it: measure with LatencyMon first, change one device, measure
again. Treat it as an experiment, not a configuration step. There is no automated
revert, which is why it is not in the script.
