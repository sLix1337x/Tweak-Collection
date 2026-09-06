---
title: Fresh install order
description: The order to put a machine together in. Which firmware settings have to be right before Windows goes on, and which belong on a system that already boots.
sidebar:
  order: 2
tags:
  - bios
  - drivers
---

The sequence for steps that need judgement, specific hardware or a GUI and so are not
in the script. The settings themselves are on
[settings outside the registry](../settings-outside-the-registry/).

## The order

Only four firmware settings have to be right *before* Windows goes on. The rest of the
BIOS is tuning, which belongs on a system that already boots — step 8.

1. **BIOS, only the settings that are painful to change later.** Boot mode UEFI,
   Secure Boot on, TPM on, SATA controller in AHCI. Windows installs against these;
   switching SATA mode or boot mode afterwards can leave a machine that will not boot
   until repaired. Leave memory profiles and Resizable BAR for now.
2. **Install Windows.** Skip the Microsoft account where the build still allows it,
   and decline every telemetry prompt during OOBE.
3. **Apply `privacy` before signing in to anything.**
   `DisableWindowsConsumerFeatures` is most useful before Windows starts pulling in
   promoted apps.
4. **Chipset drivers**, from the CPU or motherboard vendor, before any other driver.
5. **Everything else in Device Manager**, via
   [Snappy Driver Installer Origin](#snappy-driver-installer-origin).
6. **GPU driver.** See
   [installing an NVIDIA driver cleanly](../../guides/nvidia-driver-install/).
7. **Windows Update**, fully, including optional driver updates. Reboot until it is
   quiet.
8. **Back into the BIOS for tuning.** Enable XMP/EXPO and Resizable BAR now, and run
   memtest86 against a usable system if the profile turns out unstable.
9. **Baseline measurement.** LatencyMon for ten minutes and a frame-time capture in a
   familiar game, on the finished hardware configuration. See
   [measuring](../../guides/benchmark/dpc-latency/).
10. **Then** apply tweaks, one category at a time.

:::note[Why the BIOS tuning comes after the install]
XMP and EXPO are factory overclocks and not every kit is stable on every board.
Enabled during the install, an unstable profile presents as a Windows installation
that fails or corrupts itself, which says nothing about the cause. With Windows
already on the disk, the same instability can be memtested, backed off and retested.

The four settings in step 1 are exceptions because Windows bakes its assumptions about
them into the install.
:::

## Snappy Driver Installer Origin

[Snappy Driver Installer Origin](https://www.glenn.delahoy.com/snappy-driver-installer-origin/)
covers the long tail of devices: chipset sub-devices, card readers, odd NICs, the
yellow exclamation marks left in Device Manager after a clean install.

Unlike most "driver updater" software, it is open source, carries no bundleware or nag
screens, and works entirely offline from driverpacks downloaded once — useful on a
machine whose network card is the device missing a driver.

- **Review what it has selected before applying.** It offers newer or more generic
  drivers than the hardware vendor's own, which is not automatically better for a
  working device.
- **Take GPU and chipset drivers from the vendor.** NVIDIA or AMD for graphics; AMD,
  Intel or the board maker for chipset. Both change often and a driverpack is likely
  to carry an older build.

Create a restore point before a large driver run.

## Device Manager

**Disable absent or unused devices.** Cameras, unused Bluetooth radios, a second NIC,
onboard audio on a machine using a USB interface. Right-click → Disable device.

**Turn off power management per device.** For every USB Root Hub and network adapter:
Properties → Power Management → uncheck *Allow the computer to turn off this device to
save power*. [`net.adapter-powersave-off`](../../tweaks/network/#net.adapter-powersave-off)
and [`power.usb-suspend-off`](../../tweaks/power/#power.usb-suspend-off) cover the
network and USB cases; the checkbox is the manual equivalent for everything else.
