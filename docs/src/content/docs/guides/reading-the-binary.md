---
title: Checking a tweak against the binary
description: How to tell a real registry value from a name someone made up — by dumping the value names out of the driver that would read them.
sidebar:
  order: 5
tags:
  - measurement
  - registry
  - latency
---

Most bad tweaks are not wrong about *what a value does*. They are wrong about the
value existing at all.

Windows never complains. `Set-ItemProperty` writes whatever name you give it, the key
appears in `regedit`, the guide looks correct, and nothing on the machine reads it.
That failure is silent by construction, which is why invalid tweaks survive for
decades while harmful ones get found out in a week.

There is a check for it that takes about thirty seconds, and it caught a value in
this project's own script — see [MMCSS `GPU Priority`](../../reference/debunked/scheduler/#mmcss-gpu-priority-and-sfio-priority--invalid).

## The idea

A driver or kernel image stores the registry value names it queries as UTF-16LE
string literals. They are in the file. You can read them.

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

Scan at byte offset 0 **and** offset 1 on large binaries — a UTF-16 string can start
on an odd offset relative to where your slice begins, and half your hits disappear if
you only try one.

## The filter that makes it useful

**Most strings in a driver are not registry values.** They are ETW and WPP trace field
names, internal symbols and assertion text. `dxgkrnl.sys` will hand you hundreds of
convincing names — `YieldPriorityBand`, `PreemptionAttemptSuccess`,
`SmallQuantumEnabled` — that are event-log fields. Publishing that list as a tweak
guide is precisely how folklore gets manufactured, and it has happened more than once.

Two things separate a value name from noise:

**Path adjacency.** Value names cluster near the registry path string the code opens.
In `mmcss.sys` they sit in one contiguous run immediately before
`\Registry\Machine\Software\...\Multimedia\SystemProfile`.

**Known-anchor clustering.** Find names you already know are real, then look at what
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

## What it cannot tell you

Semantics. A hit proves the name exists and roughly what area it touches. It does not
give you the type, the valid range, the default, the key it is read from, or the
effect — and a name that reads like a knob may well be a diagnostic counter.

So this method rules things **out** cheaply — but only out of *that binary*. A miss
proves the name is not in the file you scanned, not that nothing reads it. Values are
routinely read one layer up from where you would expect: `IoQueueDepth` and
`NumberOfRequests` are in `storport.sys`, the port driver, and not in the
`stornvme.sys` miniport whose key they are written under. Scan the layer above before
concluding a name is dead.

Ruling something *in* still needs documentation or a measurement. A `[BINARY]`-only
value is a candidate to investigate, never a setting to apply.

The mirror-image mistake is worth naming too, because it is the easier one to make:
a **hit** does not mean a tweak works. It means the name is read. Whether any
particular value is an improvement is a separate question that a string scan cannot
answer, and collapsing the two is how "real setting" turns into "recommended
setting".

## Grading what you find

Worth adopting even if you never open a binary. An ungraded tweak list is
indistinguishable from folklore, including your own from two years ago.

| Grade | Meaning |
| --- | --- |
| **Measured** | Observed on a real system with a repeatable procedure |
| **Documented** | Stated by vendor documentation |
| **Binary** | The name provably exists in the shipping binary that would read it |
| **Mechanism** | Mechanism understood, effect not measured |
| **Folklore** | Widely repeated, no primary evidence |

The interesting part is how often *Documented* and *Binary* disagree. Documentation
goes stale in both directions: it lists values the code no longer reads, and omits
values the code does read. `GPU Priority` is documented and absent from the driver.
`Priority When Yielded` is in the driver and documented nowhere.

This maps onto [how a tweak earns its place](../../start/method/) directly — nothing
below *Situational* ships, and *Binary* alone is below it.

## Where to point it

| Binary | Area |
| --- | --- |
| `mmcss.sys` | MMCSS task profiles and the `SystemProfile` values |
| `ntoskrnl.exe` | Scheduler, DPC, timer and latency-tolerance values |
| `ndis.sys` | Network stack worker threads and receive throttling |
| `usbxhci.sys` | USB host controller, selective suspend, interrupt behaviour |
| `dxgkrnl.sys` | GPU scheduling — **extremely noisy**, mostly trace fields |

Verify against the build you are running (`(Get-Item $path).VersionInfo.FileVersion`)
and re-check after a feature update. Value names come and go between builds, and the
binary is the only source that updates itself.

:::caution[Do not ship guessed values]
The scan surfaces plenty of tempting names with no documentation —
`CacheAwareScheduling`, `SchedulerPeriod`, `Priority When Yielded`. It is genuinely
interesting that they exist. That is not the same as knowing what to write into them,
and a wrong value here does not crash; it makes the machine slightly worse in a way
you will not connect back to this a month later.
:::
