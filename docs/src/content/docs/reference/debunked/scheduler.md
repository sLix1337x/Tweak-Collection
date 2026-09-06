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

**The kernel reads this value.** The name is present in `ntoskrnl.exe` on build
10.0.26100.8968, and the value changes three things: how long a thread runs before
pre-emption, whether that length is uniform or longer for the foreground thread, and
how much extra the foreground process gets.

What is missing is evidence that any *particular* non-default value is better for
games. No published measurement shows a consistent gain, and the two most widely
circulated values are each questionable:

`0x26` (38 decimal), commonly called "the gaming value", is the behaviour already in
effect on a stock client desktop. The stored default of `2` leaves both quantum fields
on "OS default", resolving to short and variable on a client SKU with the same 3:1
foreground boost `0x26` spells out. It is also what *Adjust for best performance of:
**Programs*** writes in System Properties. Not harmful, but not a change.

`0x16` (22 decimal) is a **long** quantum: threads run longer before pre-emption. That
is a throughput bias, the opposite direction from what it is recommended for.

Full bit layout: [decoder page](../../win32priorityseparation/).

:::note[Interpreting a perceived difference]
`0x16` to `0x26` or the reverse moves between a long and a short quantum — a genuine
scheduler change. Stock `2` to `0x26` is the same behaviour on a client SKU.

On a high core count desktop, threads compete for the same core far less often than on
the four-core machines this advice was written for, which is why the effect is hard to
measure now.
:::

## `bcdedit /set disabledynamictick yes` — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Dynamic tick lets the kernel skip timer interrupts when idle. Disabling it forces a
constant tick.

A common Windows 10 latency recommendation. On Windows 11 it is counterproductive: it
prevents the CPU entering deep idle states, raising temperature and reducing boost
headroom, and Microsoft has improved the dynamic tick path for latency across several
releases.

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

## Disabling timer coalescing — Unmeasured

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Unmeasured</span></p>

Timer coalescing groups timer expirations that fall close together so the CPU wakes
once instead of several times. The control is real: a `TimerCoalescing` binary value
under `HKLM\SYSTEM\CurrentControlSet\Control\Power`, exactly 80 bytes, two blocks of
four DWORD tolerance values read by the graphics and kernel timer paths at
initialisation.

A timer firing at its exact deadline rather than within a tolerance window is only
useful if something was waiting on that deadline, and applications that care request
precision explicitly through the timer-resolution path. No published measurement
attaches a frame-time or input-latency change to this value, and a wrong length or
layout is silently ignored rather than rejected.

Documented because "disable timer coalescing" appears in tweak bundles, not as a
recommendation.

## Forcing a global timer resolution — Superseded

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Superseded</span></p>

The kernel's default tick is 15.625 ms, and a program that wants finer granularity
asks for it with `timeBeginPeriod` or `NtSetTimerResolution`. Timer tools exist to
force that request system-wide.

Since Windows 10 version 2004 the requests are **per-process**. A game asking for 1 ms
gets 1 ms regardless of what else did, and a background application can no longer drag
the whole system to 15.6 ms — the problem the tools were written for. Setting a timer
resolution *for* a game from outside it is therefore not possible.

The undocumented `GlobalTimerResolutionRequests` (DWORD `1`) under
`HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel` restores the old global
behaviour, and is the mechanism the remaining timer tools depend on. Without it, those
tools do not do what their interface says.

Forcing the resolution down is not free: the classic analysis documents higher power
draw and, in some conditions, a slower system, because everything wakes 2000 times a
second. Test by measuring the machine's sleep-delta curve and setting the resolution to
the measured optimum rather than the minimum.

## `bcdedit /set useplatformclock true` — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Forces Windows to use HPET as its clock source instead of the CPU's invariant TSC.

HPET is slower to read and the calls go through more layers. On any CPU with an
invariant TSC (which is everything since roughly 2010), forcing HPET measurably
*increases* DPC latency and can cost several percent of frame rate.

Where a tweak utility has set it, check and clear it:

```powershell
bcdedit /enum | Select-String useplatformclock
bcdedit /deletevalue useplatformclock
```

The related `useplatformtick` and `tscsyncpolicy` should also be left alone.

## The `bcdedit` boot block — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

Circulates as a block, presented as "enable X2APIC and PCIe memory mapping, and remove
kernel mitigations":

```text
bcdedit /set x2apicpolicy Enable
bcdedit /set configaccesspolicy Default
bcdedit /set MSI Default
bcdedit /set usephysicaldestination No
bcdedit /set usefirmwarepcisettings No
bcdedit /set tscsyncpolicy Enhanced
bcdedit /set allowedinmemorysettings 0x0
bcdedit /set isolatedcontext No
```

Against Microsoft's BCDEdit reference the block falls into three groups.

**Four write the value that is already there.**

| Command | What the documentation says |
| --- | --- |
| `MSI Default` | The element is `msi [Default \| ForceDisable]`. `Default` is the default. This does not enable MSI mode — that is a per-device registry setting, covered on [NVIDIA](../../../tweaks/nvidia/#nvidia.msi-mode). |
| `x2apicpolicy Enable` | "The system defaults to using extended APIC mode if it is available." Already on where supported; impossible where not. |
| `usephysicaldestination No` | The element *forces* the physical APIC. `No` is the not-forcing state. |
| `configaccesspolicy Default` | Not in Microsoft's reference at all — and `Default` is again the default. |

**Two are debugging flags Microsoft says not to use.** `tscsyncpolicy` carries the
line "This option should only be used for debugging", as `useplatformclock` and
`disabledynamictick` do. The claim that Enhanced trades FPS for input lag has no
documented mechanism, and on any CPU with an invariant TSC there is nothing left to
synchronise. `usefirmwarepcisettings No` is a real compatibility knob — it tells
Windows to re-enumerate PCI resources instead of trusting firmware — but nothing
connects it to latency.

**Two are undocumented security removals.** `allowedinmemorysettings 0x0` and
`isolatedcontext No` do not appear in Microsoft's reference. They travel in the same
packs as `vsmlaunchtype Off`, `hypervisorlaunchtype off` and `nx alwaysoff`.

:::danger[`allowedinmemorysettings 0x0` boot-loops with SGX enabled]
It causes a boot crash or boot loop if Intel SGX is enforced in firmware rather than
set to "Application Controlled" or "Off". The stock value is reported as `0x15000075`.

Export the BCD before changing it:

```powershell
bcdedit /export C:\bcdbackup
# and to undo, prefer deleting over writing a guessed "default"
bcdedit /deletevalue allowedinmemorysettings
bcdedit /deletevalue isolatedcontext
```
:::

## `IRQ#Priority` in `PriorityControl` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl
  IRQ8Priority  = 1     (the usual "CMOS first" version)
  IRQ16Priority = 2     (or whichever IRQ the GPU landed on)
```

The claimed effect is priority for one device's interrupts. The kernel does not read
the value: it does not appear in the kernel binaries, there is no Microsoft
documentation for it, and the trail runs back to Windows NT 3.x.

The premise is also wrong. IRQ 8 is the real-time clock, used for profiling that is
essentially never enabled. Windows orders interrupts by IRQL, a hardware and driver
property, not a registry value.

Two real alternatives: enabling
[MSI mode](../../../tweaks/nvidia/#nvidia.msi-mode) on a device that is still
line-based, and interrupt affinity policy for a diagnosed DPC problem — whose first
rule inverts the folklore: **keep device interrupts off CPU 0**, where Windows puts its
own housekeeping.

## MMCSS `GPU Priority` and `SFIO Priority` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

```text
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games
  GPU Priority  = 8
  SFIO Priority = "High"
```

The two headline values of every MMCSS tweak guide. Microsoft's documentation says
*"this priority is not yet used"* of the first and *"this value is not used"* of the
second. **Neither name exists anywhere in `mmcss.sys`**, the driver that reads this
key.

Windows ships the values in a stock `Tasks\Games` key, but nothing reads them. To
verify:

```powershell
$b = [IO.File]::ReadAllBytes('C:\Windows\System32\drivers\mmcss.sys')
$u = [Text.Encoding]::Unicode.GetString($b)
'Scheduling Category','Priority','GPU Priority','SFIO Priority' |
  ForEach-Object { '{0,-20} {1}' -f $_, ($u.IndexOf($_, [StringComparison]::Ordinal) -ge 0) }
```

The real value names sit in one tight cluster, on build 10.0.26100.8968, between
`0x011308` and `0x011530`: `Scheduling Category`, `Priority`, `Clock Rate`,
`Affinity`, `Background Only`, `BackgroundPriority`, `Latency Sensitive`,
`Priority When Yielded`, `NoLazyMode`, `SystemResponsiveness`,
`NetworkThrottlingIndex`, `SchedulerPeriod`. The two above are not among them.

See [`latency.mmcss-games`](../../../tweaks/latency/#latency.mmcss-games), which writes
one value where the standard recipe writes four. The related claim that `GPU Priority`
maxes at 30 is also wrong (documented range 0–31), though moot when nothing reads it.

## MMCSS `Priority` under `Scheduling Category = High` — Placebo

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo</span></p>

Real value, range 1–8, **ignored whenever the category is `High`**: every task in the
High category is treated as `2`, including the stock `Audio` and `Pro Audio` tasks that
ship with `Priority = 8`.

The common recipe — set the category to `High` *and* raise `Priority` — is one change
and one no-op. `Priority` applies only in `Medium` and `Low`.

## `SystemResponsiveness = 0` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

The value is rounded down to a multiple of 10, and anything below 10 or above 100 is
treated as **20**. `0` and `5` therefore both resolve to the default, while looking
like the most aggressive setting on the list. `100` disables MMCSS entirely.

`10` is the real floor, which is what
[`latency.system-responsiveness`](../../../tweaks/latency/#latency.system-responsiveness)
uses.

## Restarting the MMCSS service to apply changes — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Since Windows 10, MMCSS is a kernel driver rather than a svchost service and caches
task profiles at load, so registry changes require a reboot.

Registered threads hold references to the driver, so a stop never completes: the
service sits in `STOP_PENDING`, the next start fails with `1056`, and **new MMCSS
registrations fail machine-wide until reboot, audio included.**

## `KeyboardDataQueueSize` / `MouseDataQueueSize` — Placebo

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo</span></p>

```text
HKLM\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters\KeyboardDataQueueSize
HKLM\SYSTEM\CurrentControlSet\Services\mouclass\Parameters\MouseDataQueueSize
```

These set the number of *buffer entries* the class driver allocates for input packets —
a capacity ceiling, not a polling interval, delay or latency parameter. The default of
100 is already more than a queue that drains every packet needs.

Lowering it does not make input arrive sooner. Set low enough, the queue overflows under
a burst and input is dropped, which is the only observable effect.

## Disabling core parking via `ParkControl` or registry — Superseded

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Superseded</span></p>

Redundant rather than wrong. The
[Ultimate Performance power plan](../../../tweaks/power/#power.ultimate) already sets
minimum unparked cores to 100 % through the documented power subsystem, and reverts
cleanly.

---

## Processor idle promote and demote thresholds — Unmeasured

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Unmeasured</span></p>

```text
Processor idle demote threshold
Processor idle promote threshold
```

Hidden power settings, exposed by unhiding the
[power settings the GUI does not show](../../settings-outside-the-registry/#power-settings-the-gui-hides).
They control how readily the processor moves between idle states and are frequently
recommended at `100` alongside core parking advice.

Real settings with a real mechanism, but no published measurement shows a benefit over
the plan default, and a slightly worse state is hard to attribute back to them. The
[Ultimate Performance plan](../../../tweaks/power/#power.ultimate) covers the case they
are usually reached for.
