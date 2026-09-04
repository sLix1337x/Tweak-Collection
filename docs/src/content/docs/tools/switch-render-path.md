---
title: Switch-RenderPath.ps1
description: Switches how Windows presents games and the desktop — MPO, DWM internals, fullscreen optimizations and the flip-model upgrade — as four independent axes.
sidebar:
  order: 2
tags:
  - latency
  - registry
  - nvidia
---

A tool for the display-path settings that the
[tweak pages](../../tweaks/latency/) deliberately leave alone, because they are
worth switching back and forth rather than setting once.

Four independent axes, each with named states, plus presets. Nothing in it is tied
to a particular machine: the states are defined by what they change, not by what any
PC looked like on the day it was written.

```
scripts/switch-render-path/
  Switch-RenderPath.ps1    the tool, one file, no dependencies
  test-flag.ps1            self-check for the per-exe flag writer
  README.md                the full reference
```

## The axes

| Axis | What it actually changes |
| --- | --- |
| **Mpo** | Whether the display engine may compose several planes in hardware. Off means one plane, so an overlay drawn over a game has to go through DWM instead. |
| **Dwm** | 42 values covering shadows, caching, effects, present-queue depth and advanced direct flip. Desktop composition — **not** the game's own frame path. |
| **Fso** | Fullscreen optimizations. On, "fullscreen" is quietly turned into flip-model borderless. Off, a game asking for exclusive fullscreen gets it. |
| **WindowedOpt** | Whether windowed and borderless games are upgraded to the flip model. |

:::caution[WindowedOpt = Off is normally a downgrade]
The flip upgrade is what puts a borderless game on the direct-flip path in the first
place — it is what enables VRR in borderless, Auto HDR in windowed, and independent
flip when nothing is drawn over the window. Turning it off forces the old blit model
back, with an extra copy and at least a frame of latency.

Every preset leaves it `On`. The axis exists for completeness and the menu warns
before switching it off. The name misleads: it is not an "optimization" you disable
for performance.
:::

## Presets

```text
[1] Windows default       Mpo=On   Dwm=Stock     Fso=On   WindowedOpt=On
[2] MPO off only          Mpo=Off  Dwm=Stock     Fso=On   WindowedOpt=On
[3] Exclusive fullscreen  Mpo=On   Dwm=Stock     Fso=Off  WindowedOpt=On
[4] Lean                  Mpo=Off  Dwm=Stock     Fso=Off  WindowedOpt=On
[5] Stripped              Mpo=Off  Dwm=Stripped  Fso=Off  WindowedOpt=On
```

`[2]` is the documented NVIDIA workaround for MPO flicker and black flashes on
mixed-refresh multi-monitor setups, and nothing else — the same problem the
[driver install guide](../../guides/nvidia-driver-install/#multiplane-overlay-in-more-detail)
covers. `[4]` is the low-risk half: MPO and FSO off without touching DWM internals.

## Per-game fullscreen optimizations

The axes are global, but Windows also has a per-executable version of the FSO switch
— the *Disable fullscreen optimizations* box on a program's Compatibility tab. That
flag overrides the global axis for one game, which is how you get exclusive
fullscreen for a single title while everything else keeps the Windows default.

```powershell
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe' -GameFso Off
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe' -GameFso On
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe'   # just report it
```

That registry value belongs to Windows and carries other flags for the same
executable — `RUNASADMIN`, `HIGHDPIAWARE` and so on. It is edited one word at a time
so those survive, and clearing the last real flag removes the value rather than
leaving an empty separator behind. `test-flag.ps1` proves both against a scratch key
of its own, and runs in CI on every push.

## Using it

Needs an elevated 64-bit PowerShell; 5.1 and 7 both work.

```powershell
.\Switch-RenderPath.ps1                                  # interactive menu
.\Switch-RenderPath.ps1 Status                           # read-only report
.\Switch-RenderPath.ps1 -Preset Lean
.\Switch-RenderPath.ps1 -Mpo Off                         # one axis, nothing else
.\Switch-RenderPath.ps1 -Preset WindowsDefault -WhatIf   # shows everything, writes nothing
.\Switch-RenderPath.ps1 -Measure game.exe -Seconds 15    # what present mode is it really using
```

The top of the menu is the **live registry, read at that moment** — not the preset
you last chose. Every change prints a full before/after diff and waits for `y`, and a
backup is taken first: if the backup cannot be written, the change is refused rather
than made without one.

## When changes take effect

| Axis | Applies |
| --- | --- |
| `Mpo`, `Dwm` | Reboot or sign-out — DWM reads them at session init |
| `Fso`, `WindowedOpt`, `GameFso` | Next game launch |
| `GameDvr` | Sign out and back in |

## How this relates to the rest of the collection

Game DVR appears here as an *option* rather than an axis, and it overlaps with
[`latency.gamedvr-off`](../../tweaks/latency/#latency.gamedvr-off).
Use one or the other, not both at once — they write the same values, and only the
tweak script records the old ones for `-Revert`.

`Switch-RenderPath.ps1` writes its own backups to a `_backups/` folder next to
itself, one folder per change, rather than to the tweak script's backup file. The two
tools do not share state.

Full reference, including the exact registry paths and the verification notes, is in
the tool's own
[README](https://github.com/sLix1337x/Tweak-Collection/blob/main/scripts/switch-render-path/README.md).
