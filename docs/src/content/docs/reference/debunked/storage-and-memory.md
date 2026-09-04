---
title: Storage and memory
description: Queue depths, pool limits, the prefetcher and memory compression — the section where a failed tweak produces no visible error.
sidebar:
  order: 4
tags:
  - debunked
  - registry
---

The category where a wrong tweak survives longest, because none of it produces a
visible error when it fails.

## `DeviceQueueDepth` under `stornvme` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device
  DeviceQueueDepth = 8
```

Passed around as "1 = lowest latency, 8 = best for gaming, 32 = the default". All
three numbers are made up, because **no Windows storage driver reads a registry
value by that name.**

`DeviceQueueDepth` exists as a *driver API* —
[`StorPortSetDeviceQueueDepth`](https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/storport/nf-storport-storportsetdevicequeuedepth)
— which is where the name leaked from. The registry entry StorPort documents is
[`NumberOfRequests`](https://learn.microsoft.com/en-us/windows-hardware/drivers/storage/registry-entries-for-storport-miniport-drivers):
default 1000, clamped to 16–255 when set. `IoQueueDepth` is the other real one.

Both of those names live in `storport.sys`, which is the port driver the miniports
run under — not in `stornvme.sys` or `storahci.sys` themselves. `DeviceQueueDepth`
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

The intent is wrong even if you write to the key that works. An NVMe drive gets its
throughput from having many commands in flight at once; a queue depth of 1
serialises every request. That is not low latency, it is a drive pretending to be a
hard disk.

## `IoPageLockLimit` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management
  IoPageLockLimit = 0x400000
```

A Windows 2000-era knob for the maximum bytes that could be locked for I/O. It has
been reported non-functional since XP, no current Microsoft documentation references
it, and it is absent from a stock install rather than merely set to a default.

Guides recommending it routinely disagree with themselves, giving `0x400000` and
`67108864` as the same number. `0x400000` is 4,194,304. 67,108,864 is `0x4000000`.
Copied wrong, then copied again from the copy.

## `NonPagedPoolQuota` — Unproven

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Unproven</span></p>

A per-process cap on non-paged pool, in megabytes, from the era when pool was a
fixed and scarce address-space allocation.

The kernel still reads it: both `NonPagedPoolQuota` and `PagedPoolQuota` are present
in `ntoskrnl.exe` on build 10.0.26100.8968. So this is not a dead name, and calling
it invalid — as an earlier version of this page did — was wrong.

What has no basis is the recommendation. On 64-bit Windows the pool is sized
dynamically against available memory, so a per-process cap is solving a problem that
the address space stopped having. The value everyone passes around, `0x8f` for
143 MB, has no more justification than any other number, and nobody circulating it
says what pressure it is meant to relieve. Leave it absent.

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
SysMain service is what controls that behaviour — and disabling SysMain is its own
placebo, below.

## `LargeSystemCache = 0` — Placebo

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo</span></p>

Already the default on every client edition of Windows — it is what "favour
applications over the file cache" means, and the desktop SKU picks it for you. The
tweak writes the value that is already there. The one place it means something is a
file server, where you might want `1`.

## `DisablePagingExecutive = 1` — Unproven

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Unproven</span></p>

Real, and read by the memory manager: it keeps kernel and driver code resident
rather than allowing it to be paged out. On a machine with RAM to spare that code
is not under pressure to be paged out in the first place, so there is usually
nothing to win — but "usually" is doing work in that sentence, and nobody has
published a measurement either way. Harmless, and unlikely to be worth the trouble.

## Disabling memory compression — Situational

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Situational</span></p>

```powershell
Disable-MMAgent -mc
```

A real, supported cmdlet, and the trade is genuine: compression spends a little CPU
to avoid writing pages to disk. Turn it off and a machine that never fills its RAM
notices nothing, while a machine that does fill its RAM pages to the SSD instead —
which costs far more than the compression did.

So it is not harmful on 32 GB. It is also not an improvement on 32 GB. Check where a
tweak list left you:

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

Real paths, and clearing them is a legitimate *troubleshooting* step for shader
corruption after a driver change. It is not a performance tweak: the cache exists to
avoid recompiling shaders, so deleting it guarantees a session of compilation
stutter rebuilding exactly what you threw away.
