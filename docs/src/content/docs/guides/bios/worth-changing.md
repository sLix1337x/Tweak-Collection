---
title: Worth changing
description: "The four firmware settings that earn their place: memory profile, BIOS updates, Resizable BAR, unused devices."
sidebar:
  order: 1
tags:
  - bios
  - power
---

BIOS settings are not scriptable and nothing in the script reverts them. Write down
what you change. Most boards let you save a profile before you start, and it is
worth photographing every page you touch before you touch it.


### Enable your memory profile (XMP / EXPO / DOCP)

Your RAM runs at a JEDEC default speed until you enable its profile. On Ryzen in
particular, memory speed and Infinity Fabric clock have a large, measurable effect
on frame times — considerably larger than anything else on this site.

It is the single most common reason a machine is slower than it should be, so it is
the first thing to check. Not the first thing to *set*, though: see
[when to do this](../before-windows/).

:::caution[Then test it]
XMP and EXPO are factory overclocks. They are not guaranteed stable on every
CPU/board/kit combination. After enabling one, run memtest86 for a few passes. An
unstable memory profile presents as random application crashes and blue screens
that get blamed on Windows for months.
:::

### Update the BIOS

AGESA and microcode updates fix real problems: memory compatibility, idle
instability, USB dropouts, and on 13th/14th gen Intel, the microcode fixes for the
voltage degradation issue are firmware-side only.

Update when you have a reason — a symptom, a known fix in the changelog, or new
hardware. Do not update for its own sake, and never update from a machine on
unstable power.

### Enable Resizable BAR

Lets the CPU address the whole GPU framebuffer at once instead of in 256 MB
windows. Small but real gains in some titles, occasionally a small loss in others.
Requires it to be on in both the BIOS (often called "Above 4G Decoding" plus
"Re-Size BAR Support") and in the driver.

### Disable devices you genuinely do not have

Onboard audio when you use a USB interface, a second NIC you never plug in, a SATA
controller with nothing on it. Each one is one less driver loading and one less
device in the interrupt tables.

This is minor. Do it while you are in there, not as a special trip.

