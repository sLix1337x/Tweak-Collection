---
title: Checking a tweak against the binary
description: How to tell a real registry value from a name someone made up, by dumping the value names out of the driver that would read them.
sidebar:
  order: 5
tags:
  - measurement
  - registry
  - latency
---

Most bad tweaks are wrong about the value existing at all, not about what it does.

Windows does not complain: `Set-ItemProperty` writes whatever name it is given, the key
appears in `regedit`, and nothing on the machine reads it. That failure is silent by
construction, which is why invalid tweaks survive for decades while harmful ones are
found in a week.

Worked example:
[MMCSS `GPU Priority`](../../reference/debunked/scheduler/#mmcss-gpu-priority-and-sfio-priority--invalid).

## The idea

A driver or kernel image stores the registry value names it queries as UTF-16LE
string literals. They are in the file, and they can be read out of it directly.

```powershell
$b = [IO.File]::ReadAllBytes('C:\Windows\System32\drivers\mmcss.sys')
$u = [Text.Encoding]::Unicode.GetString($b)
[regex]::Matches($u, '[\x20-\x7E]{3,}') | ForEach-Object { $_.Value } | Sort-Object -Unique
```

For a specific value, ask the direct question instead:

```powershell
'Scheduling Category', 'GPU Priority', 'SFIO Priority' | ForEach-Object {
    '{0,-20} {1}' -f $_, ($u.IndexOf($_, [StringComparison]::Ordinal) -ge 0)
}
```

Scan at byte offset 0 **and** offset 1 on large binaries. A UTF-16 string can start
on an odd offset relative to the start of the slice, and half the hits disappear when
only one is tried.

## The filter that makes it useful

**Most strings in a driver are not registry values.** They are ETW and WPP trace field
names, internal symbols and assertion text. `dxgkrnl.sys` yields hundreds of convincing
names (`YieldPriorityBand`, `PreemptionAttemptSuccess`, `SmallQuantumEnabled`) that are
event-log fields.

Two things separate a value name from noise:

**Path adjacency.** Value names cluster near the registry path string the code opens.
In `mmcss.sys` they sit in one contiguous run immediately before
`\Registry\Machine\Software\...\Multimedia\SystemProfile`.

**Known-anchor clustering.** Find names already confirmed as real, then look at what
shares their address neighbourhood. Same tight range, same string pool.

```powershell
$b = [IO.File]::ReadAllBytes('C:\Windows\System32\ntoskrnl.exe')
$u = [Text.Encoding]::Unicode.GetString($b)
foreach ($n in 'Win32PrioritySeparation', 'YourCandidate') {
    $i = $u.IndexOf($n, [StringComparison]::Ordinal)
    if ($i -ge 0) { '0x{0:X7}  {1}' -f ($i * 2), $n }
}
```

Anchors land within a few kilobytes of each other. Noise lands megabytes away.

## What it cannot establish

Semantics. A hit proves the name exists and roughly what area it touches, not the type,
valid range, default, key it is read from, or effect. A name that reads like a knob may
be a diagnostic counter.

The method rules things **out** cheaply, but only out of *that binary*. A miss proves
the name is not in the scanned file, not that nothing reads it. Values are routinely
read one layer up: `IoQueueDepth` and `NumberOfRequests` are in `storport.sys`, the
port driver, not in the `stornvme.sys` miniport whose key they are written under. Scan
the layer above before concluding a name is dead.

Ruling something *in* needs documentation or a measurement. A `[BINARY]`-only value is
a candidate to investigate, not a setting to apply. A **hit** means the name is read;
whether any particular value is an improvement is a separate question a string scan
cannot answer.

## Grading the results

Applicable without opening a binary.

| Grade | Meaning |
| --- | --- |
| **Measured** | Observed on a real system with a repeatable procedure |
| **Documented** | Stated by vendor documentation |
| **Binary** | The name provably exists in the shipping binary that would read it |
| **Mechanism** | Mechanism understood, effect not measured |
| **Folklore** | Widely repeated, no primary evidence |

*Documented* and *Binary* disagree often. Documentation goes stale in both directions:
it lists values the code no longer reads and omits values the code does read.
`GPU Priority` is documented and absent from the driver; `Priority When Yielded` is in
the driver and documented nowhere.

Per [how a tweak earns its place](../../start/method/), nothing below *Situational*
ships, and *Binary* alone is below it.

## Where to point it

| Binary | Area |
| --- | --- |
| `mmcss.sys` | MMCSS task profiles and the `SystemProfile` values |
| `ntoskrnl.exe` | Scheduler, DPC, timer and latency-tolerance values |
| `ndis.sys` | Network stack worker threads and receive throttling |
| `usbxhci.sys` | USB host controller, selective suspend, interrupt behaviour |
| `dxgkrnl.sys` | GPU scheduling. **Extremely noisy**, mostly trace fields |

Verify against the build in use (`(Get-Item $path).VersionInfo.FileVersion`) and
re-check after a feature update. Value names come and go between builds.

:::caution[Do not ship guessed values]
The scan surfaces undocumented names such as `CacheAwareScheduling`, `SchedulerPeriod`
and `Priority When Yielded`. Their existence is not knowledge of what to write into
them, and a wrong value does not crash — it makes the machine slightly worse in a way
that is hard to attribute later.
:::
