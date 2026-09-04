---
title: Win32PrioritySeparation, decoded
description: What every bit of the scheduler's quantum and foreground-boost value means, and why the most recommended "gaming value" is the default written out longhand.
sidebar:
  order: 4
tags:
  - latency
  - registry
  - debunked
---

A decoder, because every list that recommends a value for this gives the value
without saying what it means, and the most popular recommendation turns out to be
the default written out longhand.

This value is genuinely read by the kernel and genuinely changes scheduling. The
point of the page is not that it does nothing — it is that you should know which of
the three fields a recommended value is actually changing before writing it.

```text
HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation
```

Only the low six bits are used, as three independent 2-bit fields:

| Bits | Field | `0` | `1` | `2` |
| --- | --- | --- | --- | --- |
| 5-4 | Quantum length | OS default | Long | Short |
| 3-2 | Quantum type | OS default | Variable | Fixed |
| 1-0 | Foreground boost | None (1:1) | Medium (2:1) | High (3:1) |

The two quantum fields treat `0` as "use whatever the OS default is", which is why
the stored default of `2` is a valid value rather than an unset one: the same `2`
gives short and variable on a client SKU and long and fixed on a server one. The
foreground boost field is different — there `0` is a literal "no boost", which is
what the *Background services* radio writes. Every combination worth naming:

| Hex | Dec | Quantum | Type | Foreground boost |
| --- | --- | --- | --- | --- |
| `0x2A` | 42 | Short | Fixed | High |
| `0x29` | 41 | Short | Fixed | Medium |
| `0x28` | 40 | Short | Fixed | None |
| `0x26` | 38 | Short | Variable | High |
| `0x25` | 37 | Short | Variable | Medium |
| `0x24` | 36 | Short | Variable | None |
| `0x1A` | 26 | Long | Fixed | High |
| `0x19` | 25 | Long | Fixed | Medium |
| `0x18` | 24 | Long | Fixed | None |
| `0x16` | 22 | Long | Variable | High |
| `0x15` | 21 | Long | Variable | Medium |
| `0x14` | 20 | Long | Variable | None |

### What the values you will be recommended actually are

**The stored default on client Windows is `2`** — all three fields on "OS default",
which on a desktop SKU resolves to short quantum, variable, 3:1 foreground boost.

`0x26` is that same combination written out explicitly. It is what System Properties
→ Advanced → Performance → Advanced → *Adjust for best performance of: **Programs***
writes, and **it changes nothing on a stock desktop install** — it spells out the
behaviour you already had. Every guide calling `0x26` the number one gaming value is
recommending the default.

`0x18` is the *Background services* radio on that same dialog: long, fixed, no
foreground boost. That is the one thing on this page a desktop user has an obvious
reason not to want.

`0x16` (22 decimal) is the value most often recommended for "smoothest gameplay".
It is a **long** quantum — threads run longer before being pre-empted, which is a
throughput bias rather than a latency one, and so the opposite direction from what
it is usually recommended for. It is a real change to scheduling; what has never
been shown is that it is an improvement. See
[debunked: scheduler](../debunked/scheduler/#win32priorityseparation--unproven).

:::note[Reading yours]
```powershell
'{0} (0x{0:X})' -f (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl').Win32PrioritySeparation
```
If it says `2`, nobody has touched it. If it says `38`, someone selected *Programs*
in that dialog — which, again, is the same behaviour.
:::
