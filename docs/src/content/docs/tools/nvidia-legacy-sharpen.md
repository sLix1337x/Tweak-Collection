---
title: Legacy NVIDIA sharpening
description: Two .reg files that bring the driver-side Image Sharpening option back to NVIDIA Control Panel — the one that makes 4:3 stretched CS2 look sharp again.
sidebar:
  order: 5
tags:
  - nvidia
  - registry
  - anti-cheat
---

Not a performance tweak. This one is about how a stretched game looks, and it
needs re-applying after every clean driver install.

```text
scripts/nvidia-legacy-sharpen/
  Nvidia Legacy Sharpen.reg          writes the value, reboot afterwards
  Nvidia Legacy Sharpen (undo).reg   deletes it again
```

## The problem

At 4:3 stretched, CS2 renders at 1280×960 and the GPU scales that to the panel's
1920×1080, and scaling blurs — every edge gets smeared across the interpolated
pixels. For years the fix was NVIDIA Control Panel → *Manage 3D
settings* → **Image Sharpening**, which runs in the driver at the same stage as
the scaling, so it sharpens exactly the blur the scaling introduced.

With the NVIDIA App release (driver branch 566, late 2024) that option disappeared
from the Control Panel. Sharpening moved into the NVIDIA App's overlay filters,
which need the overlay running in the game and are a different, heavier thing.

## The fix

The driver still has the old code path. It is behind a feature toggle:

```text
HKLM\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters\FTS
  EnableGR535 = 0   (REG_DWORD)
```

`GR535` is NVIDIA's internal id for the change that removed the option; `0` turns
that change off. After a reboot **Image Sharpening** is back under *Manage 3D
settings*, exactly as it was.

Merge `Nvidia Legacy Sharpen.reg`, reboot, then in the Control Panel:

1. *Manage 3D settings* → *Program Settings* → pick `cs2.exe`, so the desktop stays
   unsharpened.
2. **Image Sharpening** → On. Start at the defaults, `0.50` sharpen and `0.17` film
   grain, and adjust to taste — higher values start to halo around edges.
3. Tick **GPU scaling**. This is the checkbox that matters for a stretched
   resolution: it is what routes the scaled image through the sharpening pass.

## Checked against the binary

The [usual check](../../guides/reading-the-binary/), because a toggle like this is
exactly the kind of value that stops being read one driver later and nobody
notices:

```powershell
$sys = Get-ChildItem "$env:SystemRoot\System32\DriverStore\FileRepository" -Recurse -Filter nvlddmkm.sys |
  Sort-Object LastWriteTime -Descending | Select-Object -First 1
$u = [Text.Encoding]::Unicode.GetString([IO.File]::ReadAllBytes($sys.FullName))
'EnableGR535', '\Parameters\FTS' | ForEach-Object {
  '{0,-18} {1}' -f $_, ($u.IndexOf($_, [StringComparison]::Ordinal) -ge 0)
}
```

On driver 610.88 (`nvlddmkm.sys` 32.0.16.1088) both names are present, so the
current driver still reads this value from this key.

**Why two keys in the file.** Drivers from the 566 branch onward moved their
registry parameters under `\Parameters`; older drivers read the key directly under
`nvlddmkm`. The `.reg` writes both so it works either side of that change. The
version of this file that circulates also writes `ControlSet001` separately, which
is redundant — `CurrentControlSet` *is* the active control set — so that line is
gone.

## What it costs

- **A reboot.** The driver reads the toggle at load.
- **Re-applying after a clean driver install.** A clean install wipes the driver's
  service key, and the value with it. A normal update keeps it.
- **Halos, if you overdo it.** Sharpening is edge-contrast boosting; past roughly
  `0.6` it starts drawing bright outlines around dark edges.

It is a driver-side post-process with no overlay and no injection into the game,
which is the reason to use this instead of the NVIDIA App filters: nothing runs
inside the game process, and the cost is a fraction of a millisecond in the display
pipeline rather than a filter pass in the frame.

## Undo

Merge `Nvidia Legacy Sharpen (undo).reg` and reboot. It deletes the value rather
than setting it to `1`, because the value did not exist before — the driver's
default is what you get when nothing is there. The Control Panel option disappears
again, and any per-program sharpening you set with it is ignored.

This is deliberately not in [`Tweaks.ps1`](../tweaks-script/): it is a preference
about how one game looks, not a change to how Windows behaves, and the undo is a
single deleted value.
