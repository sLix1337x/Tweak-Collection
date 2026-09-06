---
title: Switch-RenderPath.ps1
description: Switches how Windows presents games and the desktop as four independent axes (MPO, DWM internals, fullscreen optimizations and the flip-model upgrade).
sidebar:
  order: 2
tags:
  - latency
  - registry
  - nvidia
---

Display-path settings that the [tweak pages](../../tweaks/latency/) leave alone because
they are worth switching back and forth rather than setting once.

Four independent axes, each with named states, plus presets. States are defined by what
they change rather than by any particular machine's configuration.

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
| **Dwm** | 42 values covering shadows, caching, effects, present-queue depth and advanced direct flip. Desktop composition, **not** the game's own frame path. |
| **Fso** | Fullscreen optimizations. On, "fullscreen" is quietly turned into flip-model borderless. Off, a game asking for exclusive fullscreen gets it. |
| **WindowedOpt** | Whether windowed and borderless games are upgraded to the flip model. |

:::caution[WindowedOpt = Off is normally a downgrade]
The flip upgrade is what puts a borderless game on the direct-flip path in the first
place: it is what enables VRR in borderless, Auto HDR in windowed, and independent
flip when nothing is drawn over the window. Turning it off forces the old blit model
back, with an extra copy and at least a frame of latency.

Every preset leaves it `On`. The axis exists for completeness and the menu warns before
switching it off.
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
mixed-refresh multi-monitor setups, covered on the
[driver install guide](../../guides/nvidia-driver-install/#multiplane-overlay-in-more-detail).
`[4]` is the low-risk half: MPO and FSO off without touching DWM internals.

The `Mpo` axis writes **two** values, `OverlayTestMode = 5` and `OverlayMinFPS = 0`. On
Windows 11 24H2 and later the desktop window manager reads both, and `OverlayTestMode`
alone frequently changes nothing. Both are cleared when the axis returns to `On`.

Where a previous `.reg` file set only `OverlayTestMode`, the script reports the axis as
`MIXED` rather than `Off`. Apply the axis to complete it.

## Per-game fullscreen optimizations

Windows has a per-executable version of the FSO switch: the *Disable fullscreen
optimizations* box on a program's Compatibility tab. It overrides the global axis for
one game, giving a single title exclusive fullscreen while everything else keeps the
Windows default.

```powershell
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe' -GameFso Off
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe' -GameFso On
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe'   # just report it
```

That registry value carries other flags for the same executable — `RUNASADMIN`,
`HIGHDPIAWARE` and so on. It is edited one word at a time so those survive, and
clearing the last real flag removes the value rather than leaving an empty separator.
`test-flag.ps1` covers both against its own scratch key and runs in CI on every push.

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

The top of the menu shows the **live registry, read at that moment**, not the
last-selected preset. Every change prints a before/after diff and waits for `y`, and a
backup is taken first: if the backup cannot be written, the change is refused.

## When changes take effect

| Axis | Applies |
| --- | --- |
| `Mpo`, `Dwm` | Reboot or sign-out: DWM reads them at session init |
| `Fso`, `WindowedOpt`, `GameFso` | Next game launch |
| `GameDvr` | Sign out and back in |

## Relationship to the rest of the collection

Game DVR appears here as an *option* rather than an axis and overlaps with
[`latency.gamedvr-off`](../../tweaks/latency/#latency.gamedvr-off). Use one or the
other: they write the same values, and only the tweak script records the old ones for
`-Revert`.

`Switch-RenderPath.ps1` writes its own backups to a `_backups/` folder next to itself,
one folder per change. The two tools do not share state.

Full reference, including registry paths and verification notes:
[README](https://github.com/sLix1337x/Tweak-Collection/blob/main/scripts/switch-render-path/README.md).
