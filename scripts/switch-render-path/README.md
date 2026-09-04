# DWM / MPO Switch — `Switch-RenderPath.ps1` v1.0.0

A single PowerShell script that switches **how Windows presents games and the desktop**.

Four independent axes, each with named states, plus options that sit outside every preset.
Nothing in it is tied to a particular machine — the states are defined by what they change,
not by what any PC looked like.

```
Switch-RenderPath.ps1    the tool (one file, no dependencies)
test-flag.ps1            self-check for the per-exe flag writer
LICENSE                  MIT
docs/                    full design + audit record (source tree only)
_backups/                created on first write; one folder per change
```

Backup folders are still named `render-path-*` — the script's name up to 1.0.0. The prefix
is deliberately frozen so restore points taken by an older copy stay visible to `[O]` and
`[X]`.

---

## The axes

| Axis | Registry | States | What actually changes |
|---|---|---|---|
| **Mpo** | `HKLM\...\Windows\Dwm\OverlayTestMode` | `On` (absent) / `Off` (5) | Whether the display engine may compose several planes in hardware. Off = one plane, so an overlay drawn over a game has to go through DWM instead |
| **Dwm** | 42 values in the same key | `Stock` (absent) / `Stripped` | Shadows, caching, effects, present-queue depth, advanced direct flip. Desktop composition — **not** the game's own frame path |
| **Fso** | `GameConfigStore\GameDVR_DXGIHonorFSEWindowsCompatible` | `On` / `Off` | On, "fullscreen" is quietly turned into flip-model borderless. Off, a game asking for exclusive fullscreen gets it |
| **WindowedOpt** | `DirectXUserGlobalSettings\SwapEffectUpgradeEnable` | `On` (absent or 1) / `Off` (0) | Whether windowed and borderless games are upgraded to the flip model |

> ⚠ **`WindowedOpt = Off` is normally a downgrade.** The flip upgrade is what puts a
> borderless game on the direct-flip path in the first place. Every preset leaves it `On`;
> the axis is exposed only for completeness, and the menu warns before switching it off.

### What `WindowedOpt` actually switches

A windowed or borderless game on the legacy **blit model** renders into its own buffer, and
DWM then *copies* that buffer into the desktop composition — an extra copy, at least a frame
of latency, no VRR, no independent flip.

`WindowedOpt = On` (the Windows default) makes Windows silently upgrade that swapchain to the
**flip model**: DWM references the game's buffer instead of copying it. That is what enables
lower latency, VRR/G-Sync/FreeSync in borderless, Auto HDR in windowed, and — when the window
covers the screen with nothing drawn over it — **independent flip**, where the display
controller scans out of the game's buffer and DWM leaves the path entirely.

So the name misleads: it is not an "optimization" you disable for performance. It is the thing
that makes borderless nearly as good as exclusive fullscreen. Turning it off forces the old
blit path back.

## Per-game FSO

The four axes above are global. Windows also has a **per-exe** version of the FSO switch: the
*Disable fullscreen optimizations* box on a program's Compatibility tab, stored as the flag
`DISABLEDXMAXIMIZEDWINDOWEDMODE` in
`HKCU\...\AppCompatFlags\Layers` under the exe's full path.

That flag **overrides the global `Fso` axis for that one game.** It is how you get exclusive
fullscreen (Legacy Flip) for a single title while every other game keeps the Windows default.

```powershell
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe' -GameFso Off   # exclusive fullscreen
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe' -GameFso On    # follow the global axis
.\Switch-RenderPath.ps1 -Game 'D:\Games\Some Game\game.exe'                # just report it
```

The value belongs to Windows and carries other flags for the same exe (`RUNASADMIN`,
`HIGHDPIAWARE`, …). It is edited **one word at a time**, so those survive; clearing the last
real flag removes the value rather than leaving an empty `~` behind. `test-flag.ps1` proves
both, against a scratch key of its own.

`Status` lists every exe that currently has the flag, in both hives. The all-users copy in
`HKLM` is **reported and never written** — it wins for that exe, so a per-user write would
look like it had no effect.

## Options

Not part of any preset, and never changed by applying one.

| Option | Registry | States | What it does |
|---|---|---|---|
| **GameDvr** | `Policies\...\GameDVR\AllowGameDVR` + `CurrentVersion\GameDVR\AppCaptureEnabled` + `GameConfigStore\GameDVR_Enabled` | `On` / `Off` | Xbox background recording and its capture hooks. `Off` sets the policy and disables capture |

Game DVR is a recording feature, not a render path. It is here because its capture hooks can
knock a game off the direct flip path — but that is a choice you make once, not a rider on
every preset.

All three values are written together on purpose. `GameDVR_Enabled` alone does not hold: it
is the `GameConfigStore` mirror of `AppCaptureEnabled`, and the Windows gaming stack
reconciles the pair at logon. Writing one side and not the other is how a verified write came
back changed after a reboot (`docs/DESIGN-AND-AUDIT.md` §15).

## Presets

```
[1] Windows default       Mpo=On   Dwm=Stock     Fso=On   WindowedOpt=On
[2] MPO off only          Mpo=Off  Dwm=Stock     Fso=On   WindowedOpt=On
[3] Exclusive fullscreen  Mpo=On   Dwm=Stock     Fso=Off  WindowedOpt=On
[4] Lean                  Mpo=Off  Dwm=Stock     Fso=Off  WindowedOpt=On
[5] Stripped              Mpo=Off  Dwm=Stripped  Fso=Off  WindowedOpt=On
```

`[2]` is the documented NVIDIA workaround for MPO flicker / black flashes on mixed-refresh
multi-monitor, and nothing else. `[4]` is the low-risk half: MPO and FSO off without touching
DWM internals.

## Install

Unzip anywhere. Files downloaded from the internet carry a Mark of the Web, which
PowerShell refuses to run, so unblock them once:

```powershell
Get-ChildItem .\*.ps1 | Unblock-File
```

If the machine's execution policy still blocks it, run the script through a scoped bypass
rather than changing the policy for the machine:

```powershell
powershell -ExecutionPolicy Bypass -File .\Switch-RenderPath.ps1
```

Verify the copy before trusting it with the registry:

```powershell
.\test-flag.ps1              # 13 assertions, own scratch key, writes nothing else
.\Switch-RenderPath.ps1 Status   # read-only report
```

## Usage

Needs an **elevated 64-bit** PowerShell (Windows PowerShell 5.1 or pwsh 7 both work).

```powershell
cd <where you unzipped it>
.\Switch-RenderPath.ps1                                   # interactive menu
.\Switch-RenderPath.ps1 Status                            # read-only report
.\Switch-RenderPath.ps1 -Preset Lean
.\Switch-RenderPath.ps1 -Mpo Off                          # one axis, nothing else touched
.\Switch-RenderPath.ps1 -Preset WindowsDefault -WhatIf    # shows everything, writes nothing
.\Switch-RenderPath.ps1 Backup                            # export the affected keys only
.\Switch-RenderPath.ps1 -GameDvr Off                      # an option; no axis touched
.\Switch-RenderPath.ps1 -RestartDwm                       # kill dwm.exe now (typed confirmation)
.\Switch-RenderPath.ps1 -Game 'D:\Games\g\g.exe' -GameFso Off   # one exe, not the global axis
.\Switch-RenderPath.ps1 -Measure g.exe -Seconds 15        # what present mode is it ACTUALLY using
```

Menu keys: `1`–`5` presets · `m` `d` `f` `w` cycle one axis · `g` toggle Game DVR · `p`
per-game FSO · `v` measure the present mode · `t` detail table · `b` backup now · `o` open the
backup folder in Explorer · `x` prune backups · `k` restart DWM · `q` quit.

The top block is **the live registry, read at that moment** — not a preset you have chosen.
Each row says in words whether it is at the Windows default or changed, and a marker on the
preset list shows which preset (if any) the machine currently is.

The menu takes over the terminal: every frame is drawn centred on a cleared screen
(scrollback included), so while the tool is running the window shows the tool and nothing
else, and quitting leaves a clean prompt. `Status`, `Backup` and the switch parameters stay
ordinary command output — they print where the cursor is and clear nothing.

Every change prints the full before/after diff and waits for `y`. A backup is taken first;
if it cannot be written, the change is **refused** rather than made without one.

Exit codes for scripted use: `0` success or nothing to do · `1` a change or backup was
refused or failed (non-interactive paths) · `2` the environment cannot run the script
safely (32-bit host, ConstrainedLanguage, not Windows).

### Managing backups

Every change writes one folder into `_backups/`, so they accumulate. Two menu keys:

- **`o`** opens `_backups/` in Explorer. Started from the elevated tool, the window still
  belongs to your own Explorer, so it is not an elevated file manager.
- **`x`** prunes them, keeping the **3 newest**. It lists every folder with its size, marks
  exactly which ones will go, and needs `DELETE` typed out — the same gate as restarting
  DWM. Deleting restore points cannot be undone.

Both only ever touch folders named `render-path-*`, so a `-BackupRoot` shared with
something else keeps its other contents.

### When changes take effect

| Axis | Applies |
|---|---|
| `Mpo`, `Dwm` | **Reboot** or sign-out — DWM reads them at session init |
| `Fso`, `WindowedOpt`, `GameFso` | Next game launch — read at process start |
| `GameDvr` | Sign out and back in, so the capture settings reload |

---

## What is verified, and what is not

**Verified** (measured, both PowerShell editions): a full preset round trip leaves all four
registry keys byte-identical; single-axis switching; menu cycling; token-wise editing of
`DirectXUserGlobalSettings` without disturbing sibling settings (AutoHDR, VRR); read-back
verification of every write; refusal without elevation, without a working backup location,
under 32-bit PowerShell, and under ConstrainedLanguage. Also: a per-exe `GameFso` round trip
on a live key that left `HIGHDPIAWARE` on the same exe untouched, and a PresentMon capture
that returned 280 frames of `Composed: Flip` for a windowed process.

**Not verified:** that a given mode produces the intended *rendering* effect. The tool is a
reliable switch; whether switch X moves the present mode the way you expect is still an open
question — but the tool now measures it for you instead of leaving it to a note.

### Expected vs measured present mode

`Status` and the menu print an **expected present mode**, derived from the live registry:

| Situation | Expected |
|---|---|
| `Fso = Off`, or the exe's own FSO flag set | `Hardware: Legacy Flip` |
| FSO on, `Mpo = On` | `Hardware Composed: Independent Flip` |
| FSO on, `Mpo = Off` | `Hardware: Independent Flip` |
| Borderless with `WindowedOpt = Off` | `Composed: Flip` — the blit path |

It is a **prediction**, not a measurement. The driver can decline the overlay plane, and
anything drawn over the game knocks it off independent flip.

To measure the real thing, with the game running:

```powershell
.\Switch-RenderPath.ps1 -Measure game.exe -Seconds 15     # or press [V] in the menu
```

That runs PresentMon against the process and reports the share of frames in each present
mode. Anything other than a `Hardware:` mode means DWM is in the path. **Frametime variance
is only comparable within the same present mode** — composition quantises presents to the
refresh interval, which compresses variance by construction while the experience gets worse.

PresentMon is not bundled. Put `presentmon.exe` on `PATH`, next to the script, or name it with
`-PresentMon`; `winget install Intel.PresentMon` is enough. The capture needs elevation, since
it reads ETW.

> One PresentMon trap the tool works around: `--timed` stops the *recording* but not the
> process. Without `--terminate_after_timed` a 3-second capture never returns, and a killed
> capture leaves its ETW session running — after which every later capture reports zero frames
> for no visible reason. The tool passes both that flag and `--stop_existing_session`.

## Honest note on `Dwm = Stripped`

`Dwm = Stock` is exact: stock Windows ships none of those 42 values, so `Stock` deletes them.
That side is identical on every Windows 10/11 machine.

`Dwm = Stripped` is **a set, not a standard.** There is no Microsoft-documented "DWM
stripped" configuration. These are the DWM feature switches as found on the system this was
built from. Values in the DWM key that the tool does not manage are listed under `Status` as
a note and are never written — so you can see when the definition is incomplete on a given
image.

## Absence matters

Stock Windows does not ship most of these values at all, so the stock state **deletes** them
rather than writing a zero. For `OverlayTestMode` this is documented behaviour: `5` disables
MPO, and the enable is the value's **absence**. Writing `0` is not the same thing and does
not re-enable it.

## Requirements

- Windows 10/11, 64-bit
- PowerShell 5.1 or 7+, **64-bit host**, FullLanguage mode
- Administrator (for `Mpo`, `Dwm`, `Fso`, the `GameDvr` policy value and any PresentMon
  capture; `WindowedOpt` and `GameFso` are per-user)
- PresentMon, only for `-Measure` / menu `[V]`. Everything else has no dependencies.

The script refuses to run in a 32-bit host: `HKLM\SOFTWARE` is redirected to `WOW6432Node`
there, so every value would read as absent — indistinguishable from "stock Windows" — and
every write would go to the wrong key.

## License

MIT. See `LICENSE`.

The registry values it writes belong to Windows; this tool only switches them and can put
them back. Every change is backed up first and refused if the backup cannot be written.
