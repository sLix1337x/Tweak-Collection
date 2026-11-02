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

The value is read by the kernel and changes scheduling. A recommended value should be
decoded into its three fields before being written.

```text
HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation
```

Only the low six bits are used, as three independent 2-bit fields:

| Bits | Field | `0` | `1` | `2` |
| --- | --- | --- | --- | --- |
| 5-4 | Quantum length | OS default | Long | Short |
| 3-2 | Quantum type | OS default | Variable | Fixed |
| 1-0 | Foreground boost | None | Medium (+1 priority) | High (+2 priority) |

The foreground field adds 0/1/2 to a foreground thread's priority after a wait (capped
at 15) and selects the foreground entry of the quantum table. Only the *Variable* table
differs per entry (2× / 3× the background quantum before 24H2); the *Fixed* table's
three entries are equal. `3` is treated as `2`.

Both quantum fields treat `0` as "use the OS default", which is why the stored default
of `2` is a valid value rather than an unset one: the same `2` gives short and variable
on a client SKU and long and fixed on a server one. In the foreground boost field `0`
is a literal "no boost", which the *Background services* radio writes.

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

:::note[24H2 and later]
The 1:2:3 quantum ratios are pre-24H2. 24H2 makes the quantum unit six times smaller
(`ShortThreadQuantum`), and with *Variable* most threads take their quantum from their
QoS level (`BamQosLevel`) instead of this table; *Fixed* still uses it.
:::

### The commonly recommended values

**The stored default on client Windows is `2`**: both quantum fields on "OS default"
and the foreground field at `2` (High), resolving on a desktop SKU to short, variable,
High.

`0x26` is the same combination written out explicitly. It is what System Properties →
Advanced → Performance → Advanced → *Adjust for best performance of: **Programs***
writes, and **changes nothing on a stock desktop install**.

`0x18` is the *Background services* radio on that dialog: long, fixed, no foreground
boost.

`0x16` (22 decimal) is the value most often recommended for "smoothest gameplay". It is
a **long** quantum — threads run longer before pre-emption, a throughput bias rather
than a latency one, and the opposite direction from what it is recommended for. A real
scheduling change; no evidence it is an improvement. See
[debunked: scheduler](../debunked/scheduler/#win32priorityseparation--unproven).

:::note[Reading the current value]
```powershell
'{0} (0x{0:X})' -f (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl').Win32PrioritySeparation
```
`2` means untouched. `38` means *Programs* was selected in that dialog — the same
behaviour.
:::
