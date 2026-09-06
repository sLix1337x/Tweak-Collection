---
title: Installing an NVIDIA driver cleanly
description: DDU plus NVCleanstall, with the exact options to tick and why.
sidebar:
  order: 2
tags:
  - nvidia
  - drivers
  - anti-cheat
---

Installing a driver without the GeForce Experience components has more effect than any
registry value here.

## Tools

| Tool | What it is for |
| --- | --- |
| [DDU (Display Driver Uninstaller)](https://www.wagnardsoft.com/) | Completely removes an existing driver, including leftovers a normal uninstall misses. |
| [NVCleanstall](https://www.techpowerup.com/download/techpowerup-nvcleanstall/) | Repackages an official NVIDIA driver with only the selected components. |

Both are free. Use the links above rather than a mirror.

## When to use DDU

DDU is not required for a routine driver update; NVIDIA's installer with **Perform a
clean installation** ticked covers that. Use DDU when:

- switching between NVIDIA and AMD,
- rolling back several driver branches,
- investigating a specific driver-related fault: crashes, black screens, a display
  that will not wake, corrupt textures.

Run it from Safe Mode; DDU offers to reboot into it. Disconnect from the network first,
or Windows Update reinstalls a driver before the intended one is installed.

## NVCleanstall options

The **Installation Tweaks** page in NVCleanstall v1.19.0, upper half:

![NVCleanstall Installation Tweaks, upper half, showing the installer telemetry, clean install, MPO, Ansel and expert tweak options](../../../assets/nvcleanstall-tweaks-1.webp)

Lower half:

![NVCleanstall Installation Tweaks, lower half, showing the NVENC patch and the rebuild digital signature options](../../../assets/nvcleanstall-tweaks-2.webp)

Option by option:

| Option | Setting | Why |
| --- | --- | --- |
| **Disable Installer Telemetry & Advertising** | ✅ | Stops the installer itself phoning home and pushing promos. Nothing depends on it. |
| **Unattended Express Installation** | ✅ | No prompts during install. |
| **Allow automatic reboot, if needed** | ✅ | Driver installs want a reboot; let it. |
| **Perform a Clean Installation** | ✅ | Wipes existing driver settings first. Equivalent to the NVIDIA installer's own clean install option. |
| **Add Hardware Support** | ⬜ | Only needed when installing the driver package on a different GPU than the one detected. |
| **Enable DLSS Indicator** | ⬜ | Debug overlay showing DLSS version in-game. |
| **Disable Multiplane Overlay (MPO)** | ✅ | A Windows compositor feature with a long history of flickering, black flashes and stutter on multi-monitor and mixed-refresh-rate setups. |
| **Disable Ansel** | ✅ | In-game screenshot tool that injects into games. Overhead when unused. |
| **Show Expert Tweaks** | ✅ | Reveals the rest of this list. |
| **Disable Driver Telemetry** | ✅ | Removes the telemetry components rather than disabling them afterwards. Marked experimental by NVCleanstall. |
| **Disable NVIDIA Container** | ⬜ | **Leave off.** Breaks the NVIDIA Control Panel, required for per-application power management and V-Sync settings. |
| **Disable NVIDIA HD Audio device sleep timer** | ✅ | Stops the GPU's HDMI/DP audio output sleeping, which cuts off the first half-second of audio after a pause. |
| **Enable Message Signaled Interrupts** | ✅ | Equivalent to [`nvidia.msi-mode`](../../tweaks/nvidia/#nvidia.msi-mode), applied so it survives the install. |
| **Interrupt Policy / Priority** | Default | Raising interrupt priority has no documented or measured benefit on a desktop GPU. |
| **Disable HDCP** | ⬜ | **Leave off**, despite the screenshot. See below. |
| **Apply NVENC Video Encoding Session Limit Patch** | ⬜ | Lifts NVIDIA's limit on concurrent NVENC encode sessions. Relevant only for several simultaneous streams. |
| **Start external application** | ⬜ | Runs an arbitrary program after the install. |
| **Rebuild digital signature** | ✅ (forced) | Required once any tweak modifies the package. Enabled automatically. |
| **Use method compatible with Easy-Anti-Cheat** | ✅ | Signs the repacked driver in a way EAC accepts. Without it, EAC-protected games can refuse to launch on a modified driver. Causes a "driver unsigned" warning during installation. |
| **Automatically accept the "driver unsigned" warning** | ✅ | Clicks through the warning the option above causes. |

:::note[The anti-cheat option]
Any tweak on this page changes the driver package, invalidating NVIDIA's signature, so
NVCleanstall re-signs it. Easy Anti-Cheat checks that signature.

The EAC-compatible method keeps those games working, at the cost of a "driver unsigned"
prompt mid-install. On a machine that runs any EAC-protected game, tick both.
:::

:::caution[Do not disable HDCP]
The screenshot has **Disable HDCP** ticked. No performance is gained. It breaks the
copy protection handshake on the display output, so Netflix, Disney+, Amazon Prime
Video and other DRM-protected streams refuse to play or drop to 480p in a browser.

It appears in tweak guides on the theory that the HDCP handshake adds display latency.
No measurement supports that.
:::

## Multiplane Overlay, in more detail

MPO lets the GPU composite multiple display planes in hardware instead of the desktop
window manager doing it, saving power and a little latency. On multi-monitor systems,
particularly with mixed refresh rates or mixed HDR states, it has produced flickering,
brief black screens on the secondary display, and stutter in windowed games across
driver branches.

Leaving MPO on is fine on a single-monitor system with no symptoms. On a multi-monitor
setup, disabling it is the most reliable fix for a second monitor that flickers during
ordinary desktop use.

It can also be disabled after the fact:

```text
HKLM\SOFTWARE\Microsoft\Windows\Dwm
  OverlayTestMode = 5   (REG_DWORD)
  OverlayMinFPS   = 0   (REG_DWORD)  — required on 24H2 and later
```

Reboot afterwards. Delete both values to re-enable MPO.

:::caution[Why the single-value version stopped working]
`OverlayTestMode = 5` alone is NVIDIA's published workaround and was sufficient for
years. On Windows 11 **24H2 and later**, including 25H2, the desktop window manager
reads both values, and setting only `OverlayTestMode` often changes nothing. Guides and
`.reg` files written before that change are half a fix.

Cost: MPO is what lets a game keep an independent flip presentation when an overlay
(volume OSD, a notification) appears on top of it. With MPO off, those moments fall
back to composition. On a single monitor with no flicker, leaving it on is the default.
:::

## About driver versions

Driver rankings age out within months: engines update, and drivers pick up both
optimisations and regressions. Version recommendations carrying no date and no
comparison against a current build are not usable.

- Newer is usually better for a game that is actively patched, because NVIDIA ships
  game-specific optimisations in Game Ready drivers.
- Where a new driver makes a specific game worse, roll back one branch and check
  whether it is a known regression before assuming a machine fault.
- Studio drivers are not slower for gaming — the same code on a slower release cadence,
  validated longer. A reasonable default where stability matters more than day-one
  support for a new title.
