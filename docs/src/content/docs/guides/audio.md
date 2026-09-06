---
title: Audio
description: Per-device sample rate and bit depth, where Windows stores them, exclusive mode, enhancements, spatial gates, ducking, and the DPC latency that causes crackle.
sidebar:
  order: 2
tags:
  - audio
  - latency
  - measurement
  - registry
---

Desktop audio problems are usually a format mismatch or DPC latency.

## Crackle and dropouts are a DPC problem

Audio breaking up under load is almost always a driver holding the CPU too long for
the audio engine to refill its buffer. The audio stack is the victim, not the cause.

Run [LatencyMon](../benchmark/dpc-latency/) and read the driver with the highest
execution time. Reinstalling the audio driver does nothing when `nvlddmkm.sys` or
`ndis.sys` is the offender.

## Sample rate and bit depth are per endpoint

An endpoint is one direction of one device, and each is configured separately: a
headset's playback, the same headset's microphone, a monitor over HDMI and the
onboard line-out are four independent settings, each with a driver-supplied format
list.

```text
Playback:  Settings → System → Sound → <device> → Format
           mmsys.cpl → Playback → <device> → Properties → Advanced → Default Format
Recording: mmsys.cpl → Recording → <device> → Properties → Advanced → Default Format
```

**There is no per-application sample rate.** In shared mode the audio engine mixes
every stream into one endpoint format, resampling whatever does not match, so the
endpoint's Default Format is what every application ends up at. The only way an
application gets its own format is [exclusive mode](#exclusive-mode), which hands it
the whole endpoint for as long as it holds it.

Format: **48 kHz** for games, video and voice chat, matching the source material;
44.1 kHz where most listening is CD-sourced. 24-bit costs nothing on modern hardware
and gives the mixer headroom. 96 and 192 kHz do not improve playback — they raise the
data rate, and on a USB interface the interrupt rate with it.

Set the **capture** endpoint too: a microphone at 44.1 kHz feeding a 48 kHz engine
adds a resample on the voice path. A Bluetooth headset changes its own format when
the microphone opens — the handsfree profile drops to narrowband mono — which is a
device limitation, not a setting.

### Where Windows stores the format

Each endpoint keeps its format as a property blob under:

```text
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render\{endpoint}
HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Capture\{endpoint}
```

`Render` is playback, `Capture` is recording. Changing the Default Format in the UI
writes several values under `Properties`:

| Value | Meaning |
| --- | --- |
| `{f19f064d-082c-4e27-bc73-6882a1bb8e4c},0` | `PKEY_AudioEngine_DeviceFormat` — the shared-mode format the engine uses between itself and the device. |
| `{e4870e26-3cc5-4cd2-ba46-ca0a9a70ed04},0` | Sits under the `PKEY_AudioEngine_OEMFormat` GUID; the driver-supplied default. |
| `{3d6e1656-2e50-4c4c-8d85-d0acae3c6c68},3`, `{624f56de-fd24-473e-814a-de40aacaed16},3`, `{3d6e1656-2e50-4c4c-8d85-d0acae3c6c68},2` | Written alongside the two above when the format changes. |

Each is a 48-byte serialised `PROPVARIANT`: an 8-byte header, then a 40-byte
`WAVEFORMATEXTENSIBLE` starting at offset `0x08`. Sample rate is a little-endian
DWORD at `0x0C` (48000 = `80 BB 00 00`), bit depth a WORD at `0x16`.

:::caution[Read these, do not write them]
Microsoft documents endpoint properties as values clients may read but should not
set, and the blob has internal consistency requirements:

```text
nBlockAlign     = nChannels × wBitsPerSample / 8
nAvgBytesPerSec = nSamplesPerSec × nBlockAlign
```

Writing a rate without recomputing the byte rate and block alignment produces a
device that **reports the new format in the UI and outputs silence**, with no error
message, because the UI, the endpoint builder, the engine, the driver and the effect
chain no longer describe the same thing. Change formats through Settings or
`mmsys.cpl`; treat the registry as read-only here.
:::

[`dumpAudioFormats.ps1`](https://github.com/nohuto/win-config/blob/main/peripheral/assets/dumpAudioFormats.ps1)
walks both trees and decodes each blob, including the derived fields. The supported
programmatic route is Core Audio: `IAudioClient::GetMixFormat` for the current shared
format, `IAudioClient::IsFormatSupported` to test a format before selecting it.

## Exclusive mode

The two checkboxes under **Allow applications to take exclusive control** decide
whether a program can bypass the Windows mixer. Per endpoint, stored next to the
format:

| Value | Setting |
| --- | --- |
| `\Properties\{b3f8fa53-0004-438e-9003-51a46e139bfc},3` | Allow applications to take exclusive control |
| `\Properties\{b3f8fa53-0004-438e-9003-51a46e139bfc},4` | Give exclusive mode applications priority |

- **Allowed** for ASIO/WASAPI-exclusive playback in music or production work. It
  removes the shared mixer from the path and is the only way an application runs the
  endpoint at its own format.
- **Off** where a game or voice chat keeps losing the device to another application.

No meaningful latency difference for games — they use the shared engine either way.

## Audio enhancements

Sound → device Properties → Advanced → **Enhance audio**, plus vendor stacks
(Nahimic, Sonic Studio, Realtek Audio Console effects).

Turn them off. Each effect is an audio processing object inserted into the playback
path with its own buffer, and vendor audio suites are a recurring DPC latency source.
Positional accuracy is better served by no processing than by a virtual surround
profile.

The checkbox writes one property per endpoint:

```text
…\MMDevices\Audio\Render\{endpoint}\FxProperties
  {1da5d803-d492-4edd-8c23-e0c0ffee7f0e},5 = 1     PKEY_AudioEndpoint_Disable_SysFx
```

`1` disables system effects for that endpoint, passing the stream through the
processing chain unmodified. A machine-wide switch also exists —
`GlobalDisableThirdPartyEnhancements` under
`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio` — which skips third-party
driver effect-pack configuration, relevant when a vendor suite keeps reinstating its
processing. The per-endpoint checkbox is the supported control.

Windows Sonic and Dolby Atmos for Headphones are HRTF processing: they help
positional cues and cost a little latency. A preference, not a defect.

### Spatial sound, and a registry trap

The spatial gates under `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio`
(`DisableSpatialAudioGlobal`, `DisableSpatialAudioPerEndpoint`,
`SpatialAudioHrtfOnByDefault`, `DisableSpatialOnComboEndpoints`) are read by the audio
service but are not an off switch: they grey the spatial option out in device
properties without disabling the feature. Use **Spatial sound: Off** on the endpoint.

## Communications ducking

Controls attenuation of other streams when a communications stream opens. Sound
control panel → **Communications** tab, or the value the policy manager reads:

```text
HKCU\Software\Microsoft\Multimedia\Audio
  UserDuckingPreference = 3      0 = −96 dB, 1 = −18 dB (default), 2 = −6 dB, 3 = no ducking
```

`3` stops Windows attenuating game audio when a voice application marks itself as a
communications stream. Values above 3 fall back to the default.

`AccessibilityMonoMixState` sits under the same key. `1` folds both channels into
one, destroying left/right positional information. Leave at `0` unless required.

## The audio engine's own knobs

`audiodg.exe` and the audio service read a long list of values under
`HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio`, recovered from decompiled
pseudocode rather than documentation. A representative few:

| Value | What it controls | Default |
| --- | --- | --- |
| `RTOperatingMode` | How the realtime work queues are structured — one shared queue, a queue per processing object, or a mix. | `3` |
| `CpuManagementThresholdHns` | CPU-management threshold in 100 ns units. | `50000` (5 ms) |
| `AudioDGCPUPercentMax` | Share of an audio period the pump may spend processing, range 10–90. | `40` |
| `SkipRTHeap` | Whether the engine allocates from the realtime heap or the normal one. | — |
| `AudioDGInactiveTimeout` | Seconds of inactivity before `audiodg` is terminated. | `300` |

Documented here because "audio latency" bundles write them, not as a recommendation.
None has a published measurement, the defaults are chosen against the whole audio
stack rather than one workload, and a wrong value presents as glitching under load
rather than an error. None is applied by this collection — see
[how a tweak earns its place](../../start/method/).

## Endpoint hygiene

Every enabled endpoint is another device in the interrupt tables and another entry
the engine enumerates:

- **Disable endpoints that are never used** in `mmsys.cpl` — the HDMI outputs of a
  monitor with no speakers, a webcam microphone, a second onboard line-out.
- **Where all audio goes through a USB interface or headset**, disabling the onboard
  codec in the BIOS removes the driver entirely. See the
  [BIOS page](../bios/worth-changing/).
- **USB audio prefers a rear port on its own controller.** Sharing a hub with a
  streaming webcam is a documented source of dropouts. Disable USB selective suspend
  on the audio device —
  [`power.usb-suspend-off`](../../tweaks/power/#power.usb-suspend-off) and
  [USB-LatencySuite](../../tools/usb-latency-suite/).

## What does not work

| Claim | Reality |
| --- | --- |
| Disabling **Windows Audio** or **AudioEndpointBuilder** | Kills audio entirely. Both are in [services that look safe and are not](../../tweaks/services/). |
| Raising the sample rate to reduce latency | The buffer size sets the latency, not the sample rate. A higher rate raises throughput and interrupt load. |
| Editing the format blob in the registry to reach a rate the UI does not offer | The list in the UI is what the driver reports as supported. A blob the driver cannot honour produces a silent endpoint, not a new capability. |
| "Audio latency" registry bundles | Almost all of them write MMCSS values. The real ones are documented under [`latency.mmcss-games`](../../tweaks/latency/#latency.mmcss-games). |
| Disabling MMCSS for audio | MMCSS exists to protect audio threads. Removing it causes the crackle it is supposed to fix. |
| Killing or renicing `audiodg.exe` | It is the engine that mixes and applies effects. Terminating it drops every stream and it restarts on demand. |
| Spatial registry gates as an off switch | They grey the UI option out without disabling the feature. Use the endpoint setting. |

## Genuinely low latency

For monitoring while recording, the buffer size in the DAW or interface control panel
is the only relevant setting, and it trades directly against dropouts. ASIO on a
dedicated interface beats the Windows shared path; no registry value closes that gap.

## Sources

- [PKEY_AudioEngine_DeviceFormat](https://learn.microsoft.com/en-us/windows/win32/coreaudio/pkey-audioengine-deviceformat) and [PKEY_AudioEndpoint_Disable_SysFx](https://learn.microsoft.com/en-us/windows/win32/coreaudio/pkey-audioendpoint-disable-sysfx) — property definitions.
- [IAudioClient::GetMixFormat](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclient-getmixformat) and [IAudioClient::IsFormatSupported](https://learn.microsoft.com/en-us/windows/win32/api/audioclient/nf-audioclient-iaudioclient-isformatsupported) — supported way to read and test formats.
- [WAVEFORMATEXTENSIBLE](https://learn.microsoft.com/en-us/windows/win32/api/mmreg/ns-mmreg-waveformatextensible) — the structure inside the blob, including field consistency rules.
- [noverse — Sample Rate](https://noverse.dev/docs/win-config/peripheral/sample-rate/), [Audio Values](https://noverse.dev/docs/win-config/peripheral/audio-values/), [Disable Audio Enhancements](https://noverse.dev/docs/win-config/peripheral/disable-audio-enhancements/) — endpoint property inventory, blob layout, `audiodg`/`audiosrv` values.
- [Spatial sound for developers](https://learn.microsoft.com/en-us/windows/win32/coreaudio/spatial-sound) — the spatial platform.
