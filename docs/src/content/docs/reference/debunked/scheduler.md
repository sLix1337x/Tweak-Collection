---
title: Scheduler, timers and CPU power
description: Quantum tweaks, HPET and dynamic tick, the MMCSS values nothing reads, and input queue sizes.
sidebar:
  order: 1
tags:
  - debunked
  - latency
  - registry
  - power
---

## `Win32PrioritySeparation` — Unproven

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Unproven</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation
```

**This one is real and the kernel reads it.** The name is present in
`ntoskrnl.exe` on build 10.0.26100.8968, and the value genuinely changes three
things: how long a thread runs before it is pre-empted, whether that length is the
same for every thread or longer for the foreground one, and how much extra the
foreground process gets. Changing it changes scheduling. Anyone reporting that a
machine behaves differently afterwards is not imagining the mechanism.

What is missing is evidence that any *particular* non-default value is better for
games. No published measurement shows a consistent gain, and the two values in
widest circulation are both questionable for a different reason each:

`0x26` (38 decimal) is the value most often called "the gaming value". On a stock
client desktop it is the behaviour you already had — the stored default of `2`
leaves the two quantum fields on "OS default", which resolves to short and variable
on a client SKU, with the same 3:1 foreground boost that `0x26` spells out. It is
also exactly what *Adjust for best performance of: **Programs*** writes in System
Properties. Setting it is not harmful; it is just not a change.

`0x16` (22 decimal) is a **long** quantum, so threads run longer before being
pre-empted. That is a throughput bias rather than a latency one, which is the
opposite direction from what it is usually recommended for. It is a real change,
and the case for it being an improvement has never been made with numbers.

The [decoder page](../../win32priorityseparation/) has the full bit layout, so you
can work out what a recommended value actually asks for before writing it.

:::note[If it felt different, check what it changed from]
Going from `0x16` to `0x26`, or the reverse, moves between a long and a short
quantum. That is a genuine scheduler change and a plausible thing to notice on a
loaded machine. Going from the stock `2` to `0x26` is not — those two are the same
behaviour, so a difference there is worth being suspicious of.

On a high core count desktop, threads are competing for the same core far less
often than on the four-core machines this advice was written for, which is the main
reason the effect is hard to measure now.
:::

## `bcdedit /set disabledynamictick yes` — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Dynamic tick lets the kernel skip timer interrupts when idle. Disabling it forces a
constant tick.

On Windows 10 this was a common latency recommendation. On Windows 11 it is
counterproductive: it prevents the CPU entering deep idle states, which raises
temperature and reduces boost headroom, and Microsoft has spent several releases
improving the dynamic tick path specifically for latency.

:::note[The revert command usually given alongside it is wrong]
Guides give the revert as:

```text
bcdedit /deletevalue useplatformclock
```

That deletes a *different* setting. Following it leaves dynamic tick disabled while
looking like it was undone. The correct revert is:

```powershell
bcdedit /deletevalue disabledynamictick
```
:::

## `bcdedit /set useplatformclock true` — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Forces Windows to use HPET as its clock source instead of the CPU's invariant TSC.

HPET is slower to read and the calls go through more layers. On any CPU with an
invariant TSC — which is everything since roughly 2010 — forcing HPET measurably
*increases* DPC latency and can cost several percent of frame rate.

If you or a tweak utility ever set it, check and clear it:

```powershell
bcdedit /enum | Select-String useplatformclock
bcdedit /deletevalue useplatformclock
```

The related `useplatformtick` and `tscsyncpolicy` should also be left alone.

## MMCSS `GPU Priority` and `SFIO Priority` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

```text
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games
  GPU Priority  = 8
  SFIO Priority = "High"
```

The two headline values of every MMCSS tweak guide. Microsoft's own documentation
says *"this priority is not yet used"* of the first and *"this value is not used"* of
the second, which people read as deprecated-but-maybe. It is stronger than that:
**neither name exists anywhere in `mmcss.sys`**, the driver that reads this key.

Windows still ships the values in a stock `Tasks\Games` key, which is why they look
load-bearing. Nothing reads them. Check for yourself:

```powershell
$b = [IO.File]::ReadAllBytes('C:\Windows\System32\drivers\mmcss.sys')
$u = [Text.Encoding]::Unicode.GetString($b)
'Scheduling Category','Priority','GPU Priority','SFIO Priority' |
  ForEach-Object { '{0,-20} {1}' -f $_, ($u.IndexOf($_, [StringComparison]::Ordinal) -ge 0) }
```

The real value names sit in one tight cluster — on build 10.0.26100.8968, between
`0x011308` and `0x011530`: `Scheduling Category`, `Priority`, `Clock Rate`,
`Affinity`, `Background Only`, `BackgroundPriority`, `Latency Sensitive`,
`Priority When Yielded`, `NoLazyMode`, `SystemResponsiveness`,
`NetworkThrottlingIndex`, `SchedulerPeriod`. The two above are not among them.

See
[`latency.mmcss-games`](../../../tweaks/latency/#latency.mmcss-games),
which writes one value where the standard recipe writes four. The related claim that `GPU Priority`
maxes at 30 is wrong as well — the documented range is 0–31 — but the range is moot
when nothing reads it.

## MMCSS `Priority` under `Scheduling Category = High` — Placebo

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo</span></p>

Real value, real range of 1–8, and **ignored whenever the category is `High`**:
every task in the High category is treated as `2`, including the stock `Audio` and
`Pro Audio` tasks that ship with `Priority = 8`.

So the common recipe — set the category to `High` *and* raise `Priority` — is one
change and one no-op. `Priority` only means anything in `Medium` and `Low`.

## `SystemResponsiveness = 0` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

The value is rounded down to a multiple of 10, and anything below 10 or above 100 is
treated as **20**. `0` and `5` therefore both give you the default, while looking
like the most aggressive setting on the list. `100` disables MMCSS entirely.

`10` is the real floor, which is what
[`latency.system-responsiveness`](../../../tweaks/latency/#latency.system-responsiveness)
uses.

## Restarting the MMCSS service to apply changes — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Since Windows 10, MMCSS is a kernel driver rather than a svchost service, and it
caches task profiles at load — so its registry changes need a reboot and there is no
shortcut.

Trying to take the shortcut is worse than doing nothing. Registered threads hold
references to the driver, so the stop never completes: the service sits in
`STOP_PENDING`, the next start fails with `1056`, and **new MMCSS registrations fail
machine-wide until reboot — audio included.**

## `KeyboardDataQueueSize` / `MouseDataQueueSize` — Placebo

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters\KeyboardDataQueueSize
HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters\MouseDataQueueSize
```

These set the number of *buffer entries* the class driver allocates for input
packets, not a polling interval and not a delay. The default of 100 is already far
more than a queue that drains every packet needs; it is a capacity ceiling, not a
latency parameter.

Lowering it does not make input arrive sooner. Set it low enough and the queue
overflows under a burst, and you drop input. Guides recommending it tend to warn
that "setting the value too low can cause glitches", without noticing that this
makes dropped input the only observable effect the tweak has.

## Disabling core parking via `ParkControl` or registry — Superseded

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Superseded</span></p>

Not wrong, just redundant. The [Ultimate Performance power
plan](../../../tweaks/power/#power.ultimate) already
sets minimum unparked cores to 100%, through the documented power subsystem, and it
reverts cleanly.

---

## Processor idle promote and demote thresholds — Unmeasured

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Unmeasured</span></p>

```text
Processor idle demote threshold
Processor idle promote threshold
```

Hidden power settings, exposed by unhiding the
[power settings the GUI does not show](../../settings-outside-the-registry/#power-settings-the-gui-hides).
They control how readily the processor moves between idle states, and they are
frequently recommended at `100` alongside core parking advice.

They are real settings with a real mechanism. What is missing is any published
measurement showing a benefit over the plan default, and they are easy to leave in
a state that behaves slightly worse in a way nothing will connect back to them.
The [Ultimate Performance plan](../../../tweaks/power/#power.ultimate)
already covers the case these are usually reached for.
