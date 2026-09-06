---
title: Services and system
description: Service-disabling lists, registry cleaners, one-click debloaters and the page file.
sidebar:
  order: 5
tags:
  - debunked
  - services
---

## `msconfig` → "Disable all non-Microsoft services" — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

`msconfig` cannot distinguish a vendor telemetry uploader from the driver service a
GPU, audio interface or anti-cheat depends on, and keeps no record of what changed.

Use **Autoruns** from Sysinternals: it shows publisher, signature and the exact key,
and allows individual entries to be re-enabled.

## Disabling `WSearch` (Windows Search) — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Start menu search and Explorer search stop working properly, in exchange for an idle
service.

## Disabling `SysMain` (Superfetch) — Placebo on SSD/NVMe

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo on SSD/NVMe</span></p>

Genuinely helped on spinning disks, where it caused thrashing. On NVMe the
prefetching is cheap and the memory it uses is standby memory, which is released on
demand. Disabling it gains nothing measurable.

## Disabling `wuauserv` (Windows Update) — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

No security patches. If update timing is the problem, set active hours and metered
connections, or use `sc config wuauserv start= demand`. Do not disable it.

## Disabling `WaaSMedicSvc` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

Windows repairs this service and re-enables it.

## Registry "cleaners" and one-click debloat scripts — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

An orphaned registry key costs nothing. Nothing in Windows performance is gated on
registry size, and a cleaner deleting a key something needed is a real failure mode.

One-click debloaters that remove Windows components rather than disabling features
leave a system that cannot take feature updates and that Microsoft will not support.
Use policy values.

## Disabling the page file — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Some applications commit more memory than they use and fail to launch without a page
file regardless of installed RAM. It also removes crash dumps, and with them any way to
diagnose a blue screen. Leave it system-managed.

## "Ultimate" third-party tweak utilities — Situational

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Situational</span></p>

The test: does it state what it is about to change, and can it revert it?

---
