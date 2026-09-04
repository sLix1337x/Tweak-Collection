---
title: Fresh install order
description: The order to put a machine together in — which firmware settings have to be right before Windows goes on, and which belong on a system that already boots.
sidebar:
  order: 2
tags:
  - bios
  - drivers
---

Things that need judgement, specific hardware or a GUI, and so are not in the
script. This page is the sequence; the settings themselves are on
[settings outside the registry](../settings-outside-the-registry/).

## The order

Only a handful of firmware settings genuinely have to be right *before* Windows goes
on. Everything else in the BIOS is tuning, and tuning belongs on a system that
already boots — so it comes back around at step 8.

1. **BIOS, but only the settings that are painful to change later.** Boot mode set to
   UEFI, Secure Boot on, TPM on, and the SATA controller in AHCI. Windows installs
   itself against these; switching SATA mode or boot mode afterwards can leave a
   machine that will not boot until you repair it. Leave memory profiles and
   Resizable BAR alone for now.
2. **Install Windows.** Skip the Microsoft account if you can, and decline every
   telemetry prompt during OOBE.
3. **Apply `privacy` before signing in to anything.**
   `DisableWindowsConsumerFeatures` is most useful before Windows starts pulling in
   promoted apps.
4. **Chipset drivers**, from the CPU or motherboard vendor, before any other driver.
5. **Everything else in Device Manager.** This is where
   [Snappy Driver Installer Origin](#snappy-driver-installer-origin) earns its keep.
6. **GPU driver** — see
   [installing an NVIDIA driver cleanly](../../guides/nvidia-driver-install/).
7. **Windows Update**, fully, including optional driver updates. Reboot until it is
   quiet.
8. **Back into the BIOS for the tuning.** Enable XMP/EXPO now, then run memtest86
   against a system you can actually use if it turns out unstable. Resizable BAR
   too. Doing this second means an unstable memory profile shows up as a machine you
   can debug, rather than an installer that fails halfway with no explanation.
9. **Baseline measurement.** LatencyMon for ten minutes and a frame-time capture in a
   game you know, on the finished hardware configuration. See
   [measuring](../../guides/benchmark/dpc-latency/).
10. **Then** apply tweaks, one category at a time.

:::note[Why not do all the BIOS work up front?]
Because step 8 is the part most likely to go wrong. XMP and EXPO are factory
overclocks and not every kit is stable on every board. Enabled during the install,
an unstable profile shows up as a Windows installation that fails or corrupts
itself, which tells you nothing about the cause. With Windows already on the disk,
the same instability shows up as something you can memtest, back off, and retest.

The exceptions are the four settings in step 1, because Windows bakes its
assumptions about them into the install.
:::

## Snappy Driver Installer Origin

For the long tail of devices — chipset sub-devices, card readers, odd NICs, the
yellow exclamation marks left in Device Manager after a clean install —
[Snappy Driver Installer Origin](https://www.glenn.delahoy.com/snappy-driver-installer-origin/)
is the tool for the job.

It is worth separating from the category it superficially belongs to. Most
"driver updater" software is adware with a scan button: it manufactures urgency,
bundles junk, and asks for money to install files you could have downloaded. SDIO is
none of that — it is open source, it carries no bundleware or nag screens, and it
works entirely offline from driverpacks you download once, which makes it genuinely
useful on a machine whose network card is the thing missing a driver.

Two habits worth keeping anyway:

- **Review what it has selected before applying it.** It will happily offer a newer
  or more generic driver than the one your hardware vendor ships. Newer is not
  automatically better for a device that is already working.
- **Still take the GPU and chipset drivers from the vendor.** NVIDIA and AMD for
  graphics, AMD or Intel or your board maker for chipset. Those two matter most,
  change most often, and are the ones a driverpack is most likely to have an older
  build of.

Create a restore point before a big driver run. It is the one operation on this page
that can take out a working machine in a single click.

## Device Manager

**Disable devices you do not have.** Cameras, unused Bluetooth radios, a second NIC,
onboard audio when you use a USB interface. Right-click → Disable device.

**Turn off power management per device.** For every USB Root Hub and network
adapter: Properties → Power Management → uncheck *Allow the computer to turn off
this device to save power*. [`net.adapter-powersave-off`](../../tweaks/network/#net.adapter-powersave-off)
and [`power.usb-suspend-off`](../../tweaks/power/#power.usb-suspend-off)
cover the network and USB cases; the per-device checkbox is the manual equivalent
for everything else.
