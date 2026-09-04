---
title: Audio
description: Sample rate, exclusive mode, enhancements and the DPC latency that causes crackle — what to set and what it costs.
sidebar:
  order: 2
tags:
  - audio
  - latency
  - measurement
---

Audio problems on a desktop are usually one of two things: a format mismatch, or
DPC latency. Neither is fixed by the settings people reach for first.

## Crackle and dropouts are a DPC problem

If audio breaks up under load, the cause is almost always a driver holding the CPU
too long for the audio engine to refill its buffer in time. The audio stack is the
victim, not the cause.

Run [LatencyMon](../benchmark/dpc-latency/) and look at
the driver with the highest execution time. Reinstalling the audio driver when
`nvlddmkm.sys` or `ndis.sys` is the offender fixes nothing.

## Sample rate — match it, do not maximise it

Sound → device Properties → Advanced → Default Format.

Every source that is not in the shared format gets resampled. Set the default
format to what you actually play: **48 kHz** for games, video and Discord; 44.1 kHz
if most of what you listen to is CD-sourced music and you care about that path
being clean.

24-bit costs nothing on modern hardware and gives the mixer headroom. 96 kHz and
192 kHz do not improve anything for playback — they raise the data rate, and on a
USB interface, the interrupt rate with it.

## Exclusive mode

The two checkboxes under **Allow applications to take exclusive control** decide
whether a program can bypass the Windows mixer entirely.

- **Leave it allowed** if you use ASIO/WASAPI-exclusive playback for music or
  production. It removes the shared mixer from the path.
- **Turn it off** if a game or voice chat keeps losing the device to another
  application, which is what exclusive mode looks like when you did not want it.

For games it makes no meaningful latency difference: they use the shared engine
either way.

## Audio enhancements

Sound → device Properties → Advanced → **Enhance audio**, plus whatever your vendor
stacks on top (Nahimic, Sonic Studio, Realtek Audio Console effects).

Turn them off. Each effect is DSP inserted into the playback path, which adds its
own buffer, and vendor audio suites are a recurring source of DPC latency in their
own right. Positional accuracy in a competitive game is better served by no
processing at all than by a virtual surround profile.

Windows Sonic and Dolby Atmos for Headphones are the same trade, made honestly:
they are HRTF processing that helps positional cues and costs a little latency.
That one is a preference, not a bug.

## Onboard audio you do not use

If everything goes through a USB interface or a headset, disabling the onboard
codec in the BIOS is one less driver loading and one less device in the interrupt
tables. It is the one item from the original BIOS list on the
[BIOS page](../bios/worth-changing/) that survived review — and it is also the least significant
of them.

## What does not work

| Claim | Reality |
| --- | --- |
| Disabling **Windows Audio** or **AudioEndpointBuilder** | Kills audio entirely. Both are in [services that look safe and are not](../../tweaks/services/). |
| Raising the sample rate to reduce latency | The buffer size sets the latency, not the sample rate. |
| "Audio latency" registry bundles | Almost all of them write MMCSS values — the real ones are documented under [`latency.mmcss-games`](../../tweaks/latency/#latency.mmcss-games). |
| Disabling MMCSS for audio | MMCSS exists to protect audio threads. Removing it is how you cause the crackle you are trying to fix. |

## If you need genuinely low latency

For monitoring while recording, the buffer size in your DAW or interface control
panel is the only setting that matters, and it trades directly against dropouts.
ASIO on a dedicated interface will beat anything the Windows shared path can do,
and no registry value closes that gap.
