---
title: Storage and memory
description: Queue depths, pool limits, the prefetcher and memory compression. The section where a failed tweak produces no visible error.
sidebar:
  order: 4
tags:
  - debunked
  - registry
---

None of these produce a visible error when they fail.

## `DeviceQueueDepth` under `stornvme` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device
  DeviceQueueDepth = 8
```

Circulated as "1 = lowest latency, 8 = best for gaming, 32 = the default". **No Windows
storage driver reads a registry value by that name.**

`DeviceQueueDepth` exists as a *driver API*,
[`StorPortSetDeviceQueueDepth`](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/storport/nf-storport-storportsetdevicequeuedepth),
which is where the name leaked from. The registry entry StorPort documents is
[`NumberOfRequests`](https://learn.microsoft.com/en-us/windows-hardware/drivers/storage/registry-entries-for-storport-miniport-drivers):
default 1000, clamped to 16–255 when set. `IoQueueDepth` is the other real one.

Both of those names live in `storport.sys`, which is the port driver the miniports
run under, not in `stornvme.sys` or `storahci.sys` themselves. `DeviceQueueDepth`
is in none of the three. On build 10.0.26100.8968:

```powershell
foreach ($f in 'stornvme.sys', 'storahci.sys', 'storport.sys') {
    $u = [Text.Encoding]::Unicode.GetString(
        [IO.File]::ReadAllBytes("$env:SystemRoot\System32\drivers\$f"))
    foreach ($n in 'DeviceQueueDepth', 'NumberOfRequests', 'IoQueueDepth') {
        '{0,-14} {1,-18} {2}' -f $f, $n, ($u.IndexOf($n, [StringComparison]::Ordinal) -ge 0)
    }
}
```

The intent is also wrong when written to a key that works. NVMe throughput comes from
many commands in flight; a queue depth of 1 serialises every request.

## `IoPageLockLimit` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management
  IoPageLockLimit = 0x400000
```

A Windows 2000-era knob for the maximum bytes lockable for I/O. Reported
non-functional since XP, referenced by no current Microsoft documentation, and absent
from a stock install rather than set to a default.

Guides give `0x400000` and `67108864` as the same number. `0x400000` is 4,194,304;
67,108,864 is `0x4000000`.

## `NonPagedPoolQuota` — Unproven

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Unproven</span></p>

A per-process cap on non-paged pool, in megabytes, from the era when pool was a
fixed and scarce address-space allocation.

The kernel reads it: both `NonPagedPoolQuota` and `PagedPoolQuota` are present in
`ntoskrnl.exe` on build 10.0.26100.8968.

The recommendation has no basis. On 64-bit Windows the pool is sized dynamically
against available memory, so a per-process cap addresses a problem the address space
stopped having. The circulated value `0x8f` (143 MB) has no stated justification.
Leave it absent.

## `EnablePrefetcher = 0` — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters
  EnablePrefetcher = 0
```

The prefetcher reads the file access pattern of a previous launch so the next one
can be issued as sequential I/O. Disabling it frees nothing meaningful and makes
cold application starts slower.

`EnableSuperfetch` alongside it is a Windows 7-era value. On Windows 10 and 11 the
SysMain service controls that behaviour.

## `LargeSystemCache = 0` — Placebo

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo</span></p>

Already the default on every client edition — it is what "favour applications over the
file cache" means. The tweak writes the value that is already there. `1` can be
appropriate on a file server.

## `DisablePagingExecutive = 1` — Unproven

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Unproven</span></p>

Read by the memory manager: it keeps kernel and driver code resident rather than
pageable. On a machine with RAM to spare that code is not under pressure to be paged
out, so there is usually nothing to gain. No measurement published either way.
Harmless.

## Disabling memory compression — Situational

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Situational</span></p>

```powershell
Disable-MMAgent -mc
```

A supported cmdlet with a real trade: compression spends CPU to avoid writing pages to
disk. Disabled, a machine that never fills its RAM notices nothing; a machine that does
pages to the SSD instead, which costs more than the compression did.

Neither harmful nor an improvement on 32 GB. Check the state a tweak list left behind:

```powershell
Get-MMAgent
Enable-MMAgent -mc   # put it back
```

## Deleting the NVIDIA shader cache as a performance tweak — Situational

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Situational</span></p>

```text
%LocalAppData%\NVIDIA\DXCache
%LocalAppData%\NVIDIA\GLCache
```

Real paths. Clearing them is a legitimate *troubleshooting* step for shader corruption
after a driver change, not a performance tweak: deleting the cache guarantees a session
of compilation stutter rebuilding what was discarded.
