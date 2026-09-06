---
title: Game settings
description: Launch options, the video cost map, the two network cvars that still exist, audio, and the input facts specific to CS2.
sidebar:
  order: 4
tags:
  - cs2
  - latency
  - input
  - audio
  - network
---

Most CS2 config lists are recycled CS:GO material. The engine and network model
changed, and many circulating commands address controls the game no longer honours.
This page covers what survives.

## Launch options

| Option | Verdict |
| --- | --- |
| `-fullscreen` | **Keep.** Forces the presentation mode regardless of config drift. |
| `-threads N` | **A/B it.** See below. |
| `-mainthreadpriority 2` | **Try it.** Raises the main thread's priority within the process. Benchmark-oriented sources credit it with smoother 1 % lows; revert if an older CPU stutters. |
| `-noreflex` | **Situational.** For players capping externally who do not want Reflex's queue management interfering. See [the frame cap](../frame-cap/#reflex). |
| `-vulkan` | **No, on Windows.** Controlled comparisons put DX11 ~14 % ahead on averages with better lows. Vulkan is a Linux and Steam Deck path. |
| `-high` | **No.** Source 1-era flag. CS2 manages its own priority; the documented side effect is instability. |
| `-tickrate 128` | **Dead.** CS2 is sub-tick. Never made a server 128-tick. |
| `-d3d9ex` / `-nod3d9ex` | **Dead.** Source 1 relics. |
| `-novid` | **Dead.** CS2 has no intro video; the flag is a no-op. |

### The `-threads` revision

`-threads <physical cores + 1>` was valid advice in CS2's first year and remains the
advice in most guides. Testing since finds the engine manages its own threading well
enough that the flag is at best a no-op and at worst a constraint. Both positions come
from real testing at different engine versions, so **benchmark it rather than inherit
it** — default threading as baseline, `-threads` as candidate. Note that the scene's
reference tester runs `-threads 9` on his 8-core machine in his published benchmark
configs, so the flag is not inherently harmful — it is unproven, not dangerous.

The engine's actual state is self-verifiable: `sys_info` in the console prints the
thread-pool size and the process priority, so `-threads` and priority claims can be
checked in seconds rather than inherited.

**Never set `cs2.exe` to Realtime priority.** It starves system and driver threads and
produces exactly the stutter it was meant to remove. High or Above Normal is the
ceiling, and even that has a cost.

## Video settings

CS2 is CPU-bound at competitive settings, so most sliders move a GPU cost that is not
being paid. "Everything on lowest = maximum FPS" does not hold here, and some of the
settings commonly lowered remove information.

The per-setting percentages below come from a full every-setting sweep (ThourCS2,
August 2025: 9800X3D / RTX 5070, 1280×960, Dust2 benchmark map). Percentages shrink on
slower GPUs and grow where the GPU is actually the limit, but the ordering holds.

| Setting | Where to put it | Measured cost / why |
| --- | --- | --- |
| **Shader Detail** | Low | High measured −5.4 % average. No competitive information. First thing to cut. |
| **Particle Detail** | Low | Very High −10 %, High −4.8 % average. The sweep found no visible difference between levels in smoke/molotov tests, so Low loses nothing. |
| **Dynamic Shadows** | **All** | All measured −2 % average, **+4.7 % on 1 % lows**. Renders the enemy shadows that reveal players around corners and overhead. Non-negotiable. |
| **Global Shadow Quality** | Medium | The *cost* lever, separate from Dynamic Shadows — see below. Medium −8 %, High −12.9 %, Very High −22 % average against Low. |
| **Ambient Occlusion** | Off | Medium/High −4.5–4.8 % average; the sweep found the added contact shadow hard to notice in fast play. |
| **MSAA** | CMAA2 or 2× | The steepest scaler in the menu: 2× −10 %, 4× −12.2 %, 8× −18 % average. CMAA2 costs only −3.8 % and fixes most of the shimmering that None leaves on distant models. |
| **HDR** | Quality | Performance mode adds a film-grain filter that costs clarity; Quality measured −2.7 % average, **+3.3 % on 1 % lows**. |
| **FidelityFX / upscaling** | Disabled | Reduces GPU load that is not the limit. Only consider at genuine 99 % GPU utilisation. |
| **Model / Texture Detail** | Low | Medium measured −8.1 % average in the sweep, with no visible difference found in its comparison shots. The counter-claim (Low makes blood and decals harder to read) comes from settings guides without measurements — benchmark the trade before paying 8 % for it. |
| **Texture Filtering** | 16× | Effectively free: 16× measured −1 % average, **+5 % on 1 % lows**. |
| **Texture Streaming** | On for 8 GB VRAM and below | |
| **Boost Player Contrast** | On | Measured −2.1 % average but **+5.8 % on 1 % lows** — a lows-positive visibility setting. |

Plus `fps_max_ui 60`, so the menu stops rendering at full rate. (`fps_max_menu` was
removed from the engine; current builds use `fps_max_ui`, default 0 = unlimited.)
`engine_no_focus_sleep 0` keeps the game rendering at full rate when unfocused —
relevant when alt-tabbing during benchmarking; the default throttles an unfocused
game to 20 FPS.

### The shadow setting commonly set backwards

The usual advice — Global Shadow Quality **High** "so enemy shadows still render" —
targets the wrong control. Shadows render at every quality level; whether *player*
shadows are drawn at all is decided by **Dynamic Shadows**. Global Shadow Quality only
sets how expensively they render.

Set Dynamic Shadows All, Quality Medium. Current professional configs agree — all run
Dynamic Shadows All while splitting across Medium to Very High on quality.

The other half of the CPU side is outside the game's settings: a hardware-accelerated
browser playing video, a Discord stream and overlay software are the most common cause
of unexplained drops. Measured: closing Discord entirely improved 1 % lows by ~6.6 %
on the Dust2 benchmark (~3 % elsewhere) in one tester's capture — averages were
unchanged, which is why this cause hides from most monitoring.

## Fullscreen optimisations

Usually dismissed as a Windows 10 relic; the condition is specific. Whether FSO's
optimised borderless mode costs anything depends on whether presentation stays on the
independent-flip path or falls back to desktop composition. A tester using FrameView
measured **PC latency roughly halving** (≈8–9 ms to ≈3–4 ms) with FSO disabled **at a
custom or upscaled resolution**, with improved 1 % lows — shrinking to margin of error
at native supported resolutions.

At a stretched resolution (1280×960 and similar), test FSO-disabled with a
latency-capable capture. At native resolution on a current build, expect a no-op.

Global version of the switch, and the DWM axes around it:
[Switch-RenderPath](../../tools/switch-render-path/).

## Network

Sub-tick invalidated the CS:GO netcode canon. The modern client config is two settings,
plus one convenience cvar.

```text
rate 1000000                  # console ceiling; the Settings UI caps at 786432, the engine default is 80000
cl_net_buffer_ticks 0         # 0 stable wired · 1 if telemetry shows jitter/loss · 2 as a crutch
mm_dedicated_search_maxping 60  # caps matchmaking server search ping; default 150, archived
```

`rate` is archived, so one autoexec entry persists it. The three values are distinct
and widely confused: the engine default (80000), the UI slider maximum (786432), and
the console maximum (1000000). On any modern broadband connection, set 1000000.

`cl_net_buffer_ticks` is the "Buffering to smooth over packet loss" slider. Each
buffered tick costs ~15.6 ms of *displayed-state* delay at 64 Hz server intervals —
displayed state, not raw mouse latency — in both directions, snapshots and outgoing
commands. Enable **Settings → Game → Telemetry** network warnings and change the value
when the graph shows jitter, not on the impression left by a death.

The current build also exposes `cl_net_buffer_ticks_use_interp` (default false), which
switches the smoothing mechanism between clock-synchronization buffering and
interp-style delayed processing. Effect unverified; leave at default.

**Remove from any autoexec:** `cl_interp`, `cl_interp_ratio`, `cl_cmdrate`,
`cl_updaterate`. The first two still parse in current builds but are engine-managed
vestiges; the last two are removed entirely.

Windows and NIC layer: [network tweak page](../../tweaks/network/). Two CS2-specific
cautions:

- **`TcpAckFrequency` / `TCPNoDelay` cannot affect CS2.** TCP settings; gameplay
  traffic is UDP. [More](../../tweaks/network/#net.nagle).
- **`NetworkThrottlingIndex` is not a ping setting.** A
  [multimedia-scheduling packet cap](../../tweaks/latency/#latency.network-throttling-off)
  with no path to server latency.

Where a connection is inconsistent, test bufferbloat before touching Windows. No
registry value fixes an oversubscribed uplink.

## Audio

The CS:GO-era audio cvar block is mostly dead in current builds. Current engine dumps
flag `snd_headphone_pan_exponent`, `snd_front_headphone_position` and
`snd_rear_headphone_position` as development-only, and they no longer appear in cvar
trackers — verify in the console whether a value sticks before relying on it.
`snd_mixahead` still exists and is archived, but its dumped default is already ~0, so
the classic "lower it to 0.05" advice is obsolete; only touch it if artefacts appear
after an engine change.

The Windows layer is where the remaining latency lives: match the device sample rate
to the game's output (24-bit/48 kHz), disable spatial sound and "enhancements" on the
CS2 output device, and remove unused audio endpoints — every enabled device is another
driver in the DPC chain. [Audio guide](../../guides/audio/).

## Input

**Raw input is forced on in CS2.** There is no toggle, so Windows' pointer-speed slider
and "Enhance pointer precision" cannot reach it — any guide prescribing "disable mouse
acceleration in Windows for CS2" describes a dead control path. (Still worth disabling
for everything else: [input guide](../../guides/input/).)

**High polling rates cost frames in CS2 specifically.** The underlying SDL issue —
`GetRawInputData` acquiring a lock per call
([SDL #8756](https://github.com/libsdl-org/SDL/issues/8756)) — was fixed on SDL's side
in early 2024, but community captures still measure the cost in CS2: on a mid-range
CPU, 4000 Hz cost ~20 % of frame rate against 1000 Hz, 8000 Hz ~33 %, in a scene that
was GPU-bound to begin with. Sensor-side limitation: 800 DPI cannot generate enough
counts to fill 8000 reports per second, so the popular "8 kHz plus 400 DPI" pairing is
self-defeating.

**Run 1000–2000 Hz** on a rear motherboard port; higher only if a frame-time capture
proves it free on the machine.
[Reasoning](../../guides/input/#polling-rate--higher-is-not-automatically-better).

## Disabled engine cvars

Source 2 contains `engine_low_latency_sleep_after_client_tick` and
`r_experimental_lag_limiter`, both associated with early-CS2 low-latency experiments.
Current state per the live engine dump:

- `engine_low_latency_sleep_after_client_tick` (default false) now carries a plain
  release flag — no cheat or development-only restriction. Whether it still functions
  is unverified; test directly with a latency-capable capture rather than trusting old
  guides in either direction.
- `r_experimental_lag_limiter` remains development-only and is not usable in normal
  play.

Older guides describe a `gameinfo_branchspecific.gi` override to force these. That
modifies a game file, breaks matchmaking integrity, and is an anti-cheat risk — and is
no longer the only way to set the first cvar.
