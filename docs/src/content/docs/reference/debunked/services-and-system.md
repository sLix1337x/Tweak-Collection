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

`msconfig` cannot tell a vendor telemetry uploader from the driver service your
GPU, audio interface or anti-cheat needs. Disabling that list wholesale produces a
machine that boots and where nothing works, with no record of what changed.

Use **Autoruns** from Sysinternals, which shows publisher, signature and the exact
key, and lets you re-enable individual entries.

## Disabling `WSearch` (Windows Search) — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Start menu search and Explorer search stop working properly. This is one of the most
noticeable degradations you can inflict on a Windows install, in exchange for an
idle service.

## Disabling `SysMain` (Superfetch) — Placebo on SSD/NVMe

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-placebo">Placebo on SSD/NVMe</span></p>

Genuinely helped on spinning disks, where it caused thrashing. On NVMe the
prefetching is cheap and the memory it uses is standby memory, which is released on
demand. Disabling it gains nothing measurable.

## Disabling `wuauserv` (Windows Update) — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

No security patches. If update timing is the problem, set active hours and metered
connections, or use `sc config wuauserv start= demand` — do not disable it.

## Disabling `WaaSMedicSvc` — Invalid

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-invalid">Invalid</span></p>

Windows repairs this service and re-enables it. You have achieved nothing except
confusion the next time you audit your service list.

## Registry "cleaners" and one-click debloat scripts — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

An orphaned registry key costs nothing to have. A registry cleaner deleting a key
something needed costs you an afternoon. Nothing in Windows performance is gated on
registry size.

One-click debloaters that remove Windows components — rather than disabling
features — leave a system that cannot take feature updates and that Microsoft will
not help you with. Use policy values, which are what this repo does.

## Disabling the page file — Harmful

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-harmful">Harmful</span></p>

Some applications commit more memory than they use and will fail to launch without a
page file regardless of how much RAM is installed. It also means no crash dumps, so
you lose the ability to diagnose a blue screen. Leave it system-managed.

## "Ultimate" third-party tweak utilities — Situational

<p class="tc-verdict-row"><span class="tc-verdict tc-verdict-situational">Situational</span></p>

Some are fine, most are opaque. The test: can it tell you what it is about to
change, and can it put it back? If not, do not run it on a machine you care about.

---
