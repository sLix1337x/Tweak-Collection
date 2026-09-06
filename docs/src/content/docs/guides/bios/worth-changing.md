---
title: Worth changing
description: "The firmware settings that earn their place: memory profile, training and idle states, TSME, BIOS updates, fTPM, Resizable BAR, unused devices."
sidebar:
  order: 1
tags:
  - bios
  - power
  - security
---

Everything on this page applies to **any board**. The settings that differ by platform are
on [AM4](../am4/) and [AM5](../am5/).

BIOS settings are not scriptable and nothing in the script reverts them. Record
every change. Most boards can save a profile beforehand, and photographing each page
before it is edited is worth the minute it costs.


### Enable the memory profile (XMP / EXPO / DOCP)

RAM runs at a JEDEC default speed until its profile is enabled. On Ryzen, memory speed
and Infinity Fabric clock have a larger measurable effect on frame times than anything
else in this collection, and are the most common reason a machine is slower than it
should be. Check it first; set it after installation
([when to do this](../before-windows/)).

:::caution[Then test it]
XMP and EXPO are factory overclocks, not guaranteed stable on every CPU/board/kit
combination. After enabling one, run memtest86 for a few passes. An unstable memory
profile presents as random application crashes and blue screens.
:::

### Memory training and idle: Memory Context Restore, Power Down

**Memory Context Restore** skips DRAM retraining at boot by reusing the saved training
state, recovering the 30–40 seconds AM5 boards can take to POST. On a marginal kit it
presents as boot-to-boot variance, failed POSTs and blue screens.

**Power Down Enable** lets the DRAM drop into a low-power state when idle, so the next
access waits for the exit before it is served. It ships as **Auto**, which resolves to
enabled on AM4 and AM5 alike — a board nobody has touched is running it.

**Both disabled** is the stable, low-latency configuration, at the cost of boot time.
Power Down is worth considering only as a stability crutch where Memory Context Restore
is kept on, and the two are usually set together: a report of Power Down disabled being
unstable is worth re-testing with Memory Context Restore off as well.

:::caution[Instability here arrives late]
Reports run both directions on this setting, and the crashes attributed to it turn up
after hours of uptime rather than in a benchmark run. Validate it the way a
[Curve Optimizer offset](../am4/#pbo-and-curve-optimizer) is validated — leave the
machine up and used, not stress tested.
:::

### Memory encryption: TSME

**Transparent Secure Memory Encryption** has the memory controller encrypt everything
written to DRAM and decrypt it on the way back, under an ephemeral AES key that the AMD
Secure Processor generates at each reset and never exposes to software. *Transparent* is
the part that matters: firmware enables it for all of memory, so no OS support is
involved and nothing in Windows asks for it or reports it. The entry sits under **AMD
CBS**, in *DF Common Options → Memory Addressing* or *NBIO Common Options* depending on
vendor and AGESA, sometimes labelled *Memory Guard* or *SMEE*.

**Disabled** is the lower-latency setting, because the AES engine sits in the DRAM path
and every access pays for it. The size is modest and workload-dependent: Cloudflare
measured an EPYC fleet with TSME on and off and found STREAM bandwidth down 2.6–4.2 %
(mean 3.7 %), with the average across all eleven data points at 0.699 %. Nobody has
published a frame-time comparison, so treat it as a small real cost of unknown size in a
game, and [measure](../../benchmark/frame-times/) if it matters whether it moved.

**What turning it off costs.** TSME defends DRAM against an attacker with physical
access — cold-boot recovery, a pulled DIMM, a bus interposer. It does nothing against
software or remote attack, and no anti-cheat reads it. On a desktop that never leaves the
room that threat model is thin. On a laptop, or any machine that can be carried off with
data on it, a fraction of a percent is the wrong thing to trade for it.

:::caution[The menu is not evidence that it is on]
AGESA 1.2.7.0 (April 2026) made the boot-loader flag `DfIsTsmeEnabled` return false on
non-PRO Ryzen regardless of the BIOS toggle, so consumer chips ran unencrypted while the
firmware still offered the switch. AMD reversed the change once it was found and
published; July 2026 firmware restores the option — ASUS from AGESA ComboAM5 PI 1.3.0.1b
Patch A — but the rollout is per vendor and per board. For most of 2026, "disable TSME"
on a consumer part was setting something that was already off.
:::

Read the state rather than the menu. `MSR_AMD64_SYSCFG` (`0xC0010010`) bit 23,
`MemEncryptionModeEn`, is 1 when the controller is encrypting. Under Linux that is
`rdmsr -f 23:23 0xC0010010`, or the `sme` flag in `/proc/cpuinfo`, which the kernel
clears when bit 23 is not set. TSME does **not** appear in the kernel's
`Memory Encryption Features active:` line — that reports the OS-driven SME and SEV
variants, and the CCP driver prints `psp: TSME enabled` separately. Windows publishes no
equivalent readout at all.

Tuning beyond the profile is socket-specific and lives on its own page: the fabric is the
variable on [AM4](../am4/), the memory controller ratio is the variable on
[AM5](../am5/). On an X3D part either way, the in-game difference between a good profile
and hand-tuned timings is far smaller than the synthetic difference, because the cache
absorbs much of the memory latency being tuned.

:::caution[`tREFI` at maximum is a thermal setting]
Raising the refresh interval to 65535 is a benchmark-padding trick that raises DRAM
temperature substantially. Where it is used, monitor memory temperature under a real
GPU heat soak rather than at idle.
:::

### Update the BIOS

AGESA and microcode updates fix real problems: memory compatibility, idle
instability, USB dropouts, and on 13th/14th gen Intel, the microcode fixes for the
voltage degradation issue are firmware-side only.

Update for a reason: a symptom, a known fix in the changelog, or new hardware. Never
update from a machine on unstable power.

On 13th/14th gen Intel, also select **Intel Default Settings** rather than the board's
"Extreme" or unlimited power profile. Board power delivery running past Intel's
guidance was a named contributor to the degradation problem, and the microcode fixes
measured with no notable gaming cost.

### fTPM stutter on AMD platforms

The firmware TPM performs extended SPI flash transactions that stall the system for
milliseconds at unpredictable intervals, presenting as random frame-time spikes and
audio crackle with no relationship to load.

AGESA 1.2.0.7 (2022) fixed most of it; reports persist on boards left on older
firmware. The fix arrives as an **fTPM firmware update carried by a newer AGESA**
(fTPM 3.\*.2.\* or later), and board vendors publish per-model charts naming the BIOS
that contains it. Update the BIOS, then re-measure.

**A discrete TPM module is not an upgrade here.** On a machine that plays on FACEIT it
is inverted: discrete modules are a documented source of TPM attestation failures, and
FACEIT's support documentation recommends switching *from* dTPM *to* fTPM when
attestation fails. On a patched board the module adds a failure mode. Keep fTPM
enabled, with Secure Boot and TPM 2.0 on.

If attestation still fails after the BIOS update, the documented recovery order is:
disable fTPM → re-enter the BIOS and flash the latest version → boot → `tpm.msc` →
Clear TPM → reinstall the anti-cheat.

**Back up BitLocker recovery keys before any of this.** Clearing or reconfiguring
the TPM on an encrypted drive means the machine asks for a recovery key at the next
boot, and without it the data is gone. TPM 2.0 is also mandatory on FACEIT, so
turning it off is not an available workaround there.

### Enable Resizable BAR

Lets the CPU address the whole GPU framebuffer at once instead of in 256 MB windows.
Small gains in some titles, occasional small losses in others. Must be enabled in both
the BIOS ("Above 4G Decoding" plus "Re-Size BAR Support") and the driver.

**CSM has to be off.** A board reporting "Resizable BAR: Enabled" with the
Compatibility Support Module still enabled is silently broken, and the feature reads as
disabled where it counts — confirm the live state in GPU-Z, not the firmware menu.

The gain is not universal: on a PCIe 3.0 link with an Ampere card, controlled testing
measured repeatable *regressions* in some titles (−2.5 % to −3.4 % in one, 0.1 % lows
nearly halved in a DX12 title) alongside gains up to ~12 % in others. CS2 prefers it
[off](../../../cs2/system/#the-composition-and-gpu-layer).

### Disable devices that are genuinely absent

Onboard audio on a machine using a USB interface, a second NIC that is never connected,
a SATA controller with nothing on it. Each is one less driver loading and one less
device in the interrupt tables. Minor.

## One thing that is not a BIOS setting

**Replace a non-certified DisplayPort cable.** Pin 20 of a DisplayPort connector is
`DP_PWR`, and the VESA specification says it must not be wired through between source
and sink. Non-compliant cables wire it, feeding 3.3 V from the monitor back into the
graphics card. Dell publishes a support article on this failure mode and removed the
wire from their own cables; VESA has stated that a batch of non-certified cables it
bought contained an alarming number improperly configured, some capable of damaging
hardware.

Symptoms: boot hangs, failure to detect the display, or a dead card. Cards made in the
last several years generally include protection. Buy a VESA-certified cable; to test a
suspect one, a strip of tape over pin 20 makes it behave as though the wire were
absent.

