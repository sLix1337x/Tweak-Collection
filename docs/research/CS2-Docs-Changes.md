# CS2 performance work — what changed in Tweak-Collection

A record of every change made to the collection in the CS2 sessions: what was
corrected, what was added, and where each item lives. The last section distils it
into an action list for a Ryzen 9 5950X / RTX 3060 Ti / 16 GB DDR4 machine, which is
the hardware the research file targets.

Source for all of it: `docs/research/CS2_Windows11_25H2_Deep_Optimization_Research.md`
(Parts I–V) plus the noverse/nohuto cross-check reviews in `docs/nohuto-improved/`.

---

## 1. Corrections — things the docs had wrong

These are the ones that matter most, because following the old text made the machine
worse or wasted the effort.

| Item | Was | Now | Page |
| --- | --- | --- | --- |
| **fTPM stutter fix** | "Fit a discrete TPM module — it is the definitive fix." | Inverted for FACEIT machines. dTPM modules are a documented source of TPM attestation failures and FACEIT recommends switching dTPM → fTPM. The real fix is the fTPM firmware (3.\*.2.\*+) carried by a newer AGESA. | `guides/bios/worth-changing.md` |
| **CS2 shadow settings** | "Global Shadow Quality High, deliberately kept, because CS2 renders enemy shadows." | Wrong lever. Shadows render at every quality level; the setting that draws player shadows is **Dynamic Shadows = All**. Quality is a pure cost slider — High costs ~15–25 FPS over Medium for information that is already there. | `cs2/game-settings.md` |
| **MSI mode** | Presented as a tweak to apply (`MSISupported = 1`). | Already the driver default on RTX 30/40. Line-based survives mainly on Maxwell/Pascal/Turing. On current cards: verify, do not write. Forcing it on badly routed boards has been reported to make interrupt conflicts worse. | `tweaks/nvidia.mdx`, `cs2/myths.md` |
| **`-threads` launch option** | Recommended as `physical cores + 1`. | Engine threading matured; the flag is at best a no-op, at worst a constraint. A/B it, do not inherit it. | `cs2/game-settings.md` |
| **FACEIT frame cap** | — | The research contradicts itself (§8 says cap slightly *above* refresh, §27 says 3 *below*). Docs use the −3 VRR rule, which is the one with the display-research work behind it. | `cs2/frame-cap.md` |

---

## 2. Added — CS2-specific

### Security and platform policy

- **VBS / HVCI fork.** The decision that comes before every other tweak: MM/Premier
  players can turn both layers off (~8–10 % average, more on the lows); FACEIT
  players cannot, because TPM 2.0, Secure Boot, IOMMU and VBS are mandatory and
  Memory Integrity is demanded from specific accounts. Two permanently different
  machines. → `cs2/system.md`, `cs2/index.mdx`
- **CPU mitigations (Spectre/Meltdown).** `FeatureSettingsOverride` / `Mask = 3`.
  Worth a real few percent only on Intel 8th gen or older / pre-Zen 2 (6700K: 98 →
  93 → 88 FPS with microcode). Noise on modern silicon; possibly negative on the
  newest. → `cs2/system.md`
- **AMD-specific: the switch is nearly inert.** Zen 3 runs always-on STIBP as part
  of Spectre v2 handling and Windows-side tools cannot disable it — the cost is in
  silicon and already inside every published benchmark. Zenbleed's fix cost up to
  15 % in specific non-gaming workloads, nothing in games. → `cs2/system.md`

### Firmware (AM4 / Zen 3)

- **FCLK 1:1 and the WHEA-19 audit.** "Highest stable FCLK" is still the Zen 3 rule
  (unlike AM5). Most Vermeer chips wall at **1866–1900 MHz**; dual-CCD parts fare
  worse because they are binned for core quality, not I/O die. Corrected errors are
  silent — one documented case logged 4,000 in an hour while memtest-clean — and each
  one costs fabric latency that lands in the frame times. Includes a `Get-WinEvent`
  one-liner for the audit. → `guides/bios/am4.md`
- **AGESA is a tuning variable.** On identical RAM at an identical FCLK, AGESA
  1.1.9.0 alone took AIDA64 memory latency from 65.8 ns to ~56.5 ns — more than the
  last fabric step is worth. → `guides/bios/am4.md`
- **PBO / Curve Optimizer.** Capping **EDC at 150 A** beat the board's unlimited
  profile: ~5,030 MHz single-core, ~4,600 MHz all-core, R23 temperature 86–87 °C →
  74 °C, +600 points. Per-core offsets (best cores tolerate least). Instability shows
  up at **idle**, not under load. Disabling Global C-States costs 100–150 MHz of
  boost. → `guides/bios/am4.md`
- **Memory training (AM5).** Memory Context Restore off and Power Down Enable off is
  the fast, stable pair; `tREFI 65535` is a thermal stressor, not a free win.
  → `guides/bios/worth-changing.md`
- **ReBAR verification.** "Enabled" in the BIOS with CSM still on is a silently
  broken configuration — confirm in GPU-Z. On a PCIe 3.0 Ampere card ReBAR showed
  repeatable regressions in some titles. CS2 specifically prefers it **off**
  (~6 % better 1 % lows). → `guides/bios/worth-changing.md`, `cs2/system.md`

### Scheduling and CPU

- **Core parking, measured.** An instrumented 14900F test found stock Windows 11
  desktops never park at all. Where parking is forced, throughput fell 59 % and the
  worst frame time went 6.5 → 17.3 ms while the median barely moved: it is a
  tail-latency failure mode, not an average-speed tax. Check `resmon` /
  `CPMINCORES` before touching anything. → `cs2/system.md`
- **Dual-CCD without V-cache (5900X / 5950X).** Previously fell between the X3D and
  single-CCD sections. The working pattern: background processes pinned to CCD1 via
  a Process Lasso wildcard rule, game left free to spread on CCD0; never hard-lock
  the game to one CCD. → `cs2/system.md`
- **Intel APO** as the sanctioned hybrid answer (CS2 is on Intel's official list),
  with the requirement to remove manual affinity and `-threads` first.
  → `cs2/system.md`

### GPU, driver and display

- **Shader cache 10 GB**, plus the two corollaries: one stuttery session after every
  driver update is the cache rebuilding, and a minority of systems stutter *less*
  with it disabled. → `cs2/system.md`
- **Update regressions by KB number** — KB5066835 (fixed by driver 581.94),
  KB5074109, KB5077181, and the August 2026 `inpoutx64` driver block that means RGB
  suites should be uninstalled rather than closed. → `cs2/system.md`
- **Undervolt caveat.** An undervolt that lets sustained clocks sag measured **0.1 %
  lows about 15 % worse** at equal averages. Target the same clock at lower voltage,
  validate on load transitions. → `cs2/system.md`
- **G-Sync recipe** — G-Sync on, control-panel V-Sync **on**, cap 3 below refresh,
  and never lower the monitor's refresh to match a cap. → `cs2/frame-cap.md`
- **Limiter comparison table** (CapFrameX, 120 FPS cap): RTSS Async and Special K
  hold ~101–106 1 % low against the driver limiter's 92.3, at ~1 ms more latency.
  RTSS off FACEIT, NVCP on it. → `cs2/frame-cap.md`

### Game settings

- **MSAA 8× costs up to 18 % of average FPS** — the single most expensive setting in
  the menu. 2× is the landing spot, CMAA2 if shimmering distracts. → `cs2/game-settings.md`
- **Dynamic Shadows All + Shadow Quality Medium** (see correction above).
- **Model/Texture Detail Medium**, Texture Filtering 4× — Low saves almost nothing on
  an 8 GB card and costs readability. → `cs2/game-settings.md`

### Windows layer

- **Xbox Full Screen Experience** — the supported version of what debloat ISOs
  promise: RAM in use 8.6 → 7.8 GB (about 9 %), Microsoft citing up to 8.6 % FPS from
  the reduced background workload, without stripping anything an anti-cheat checks.
  → `cs2/system.md`
- **Timer resolution is per-process since Windows 10 2004** — a timer tool cannot
  grant a game a finer timer from outside; the undocumented
  `GlobalTimerResolutionRequests` is what the remaining tools depend on.
  → `reference/debunked/scheduler.md`
- **Timer coalescing** — real value (`TimerCoalescing`, 80 bytes under
  `Control\Power`), no measurement attached. Documented, not recommended.
  → `reference/debunked/scheduler.md`
- **`TaskOffload` → checksum → RSS dependency** — disabling offloads globally
  silently kills RSS, so the NIC falls back to single-core interrupt handling while
  still reporting RSS as enabled. → `guides/network-adapter-settings.md`
- **RSS tuning depth** — `*RssBaseProcNumber` to move receive work off the low cores,
  `*RssProfile`, RSSv2; the sane alternative to manual IRQ pinning.
  → `guides/network-adapter-settings.md`
- **Interrupt affinity rules** — never CPU 0 (Windows puts its own housekeeping
  interrupts there, so the popular advice is backwards), GPU first if anything, leave
  a healthy RSS NIC alone, verify with per-CPU counters after a device restart.
  → `reference/settings-outside-the-registry.md`
- **DPC triage: check hard page faults first** — memory pressure produces stutter
  identical to driver latency. → `guides/benchmark/dpc-latency.md`
- **IPv6 `DisabledComponents = 0xFFFFFFFF` is harmful** — sets undefined bits, breaks
  loopback/tunnel components, adds ~5 s to boot. `0x20` (prefer IPv4) is the middle
  ground, `0xFF` the correct full disable. → `reference/debunked/network.md`
- **xHCI interrupt moderation (IMOD)** — ~50 µs batching, irrelevant at 1000 Hz,
  meaningful at 8 kHz, and changeable only by writing an MMIO register with
  RWEverything at every boot. Documented as the argument *for* 1000–2000 Hz.
  → `guides/input.md`
- **`nvlddmkm\State` is a state store, not a settings key** (display database, HDCP
  revocation, TDR records); `\Parameters` holds only diagnostic log-size knobs.
  → `tweaks/nvidia.mdx`

### Audio (rebuilt page)

- **Sample rate and bit depth are per endpoint** — every playback and every recording
  device separately; there is no per-application sample rate in shared mode, only
  exclusive mode. Backing store is
  `MMDevices\Audio\Render|Capture\{endpoint}\Properties`, `{f19f064d-…},0` holding a
  48-byte `PROPVARIANT` with the `WAVEFORMATEXTENSIBLE` at offset `0x08`. Read it,
  never write it: an inconsistent blob gives a device that shows the new format in
  the UI and outputs silence.
- Exclusive-mode flags, `PKEY_AudioEndpoint_Disable_SysFx`, the spatial registry
  gates that only grey the UI out, communications ducking
  (`UserDuckingPreference = 3` stops game audio being attenuated by voice apps), the
  `audiodg` engine knobs listed as documented-but-unmeasured, and endpoint hygiene.
  → `guides/audio.md`

---

## 3. Structural changes

- **Counter-Strike 2 sidebar group moved below Misc** (above Debunked & rejected).
- **Whole docs site rewritten in impersonal technical-documentation voice** — 45
  files, ~454 second-person instances removed, three headings renamed with their
  inbound links updated. The blog post keeps its first-person voice deliberately.
- **Research file** renamed back over its tracked path after the Part V update.
- **Deploy gotcha worth remembering:** the `Deploy docs` workflow is path-filtered on
  `docs/**`, and a force-push (which this repo uses for its single-commit history)
  leaves GitHub unable to diff against the replaced commit, so the filter matches
  nothing and the deploy silently never runs. After every push:
  `gh workflow run "Deploy docs" --ref main`.

---

## 4. Action list for a 5950X / RTX 3060 Ti / 16 GB rig

In order. Everything here is reversible and benchmarkable.

**Firmware first**

1. Update to the board's latest AGESA — it carries the FCLK improvements, the
   FACEIT-compliant fTPM firmware and Curve Optimizer maturity in one flash.
2. DOCP/XMP on. Target DDR4-3600 CL16 or 3800 CL14–16, FCLK 1:1 at 1800 (1900 only
   if a week of use logs zero WHEA-19).
3. Audit Event Viewer for WHEA event 19 after any memory change. Zero errors beats a
   faster profile that logs them.
4. Global C-State Control **Enabled** (explicitly, not Auto). Disabling costs
   100–150 MHz of boost.
5. fTPM on, Secure Boot on, TPM 2.0 on, IOMMU on. No discrete TPM module.
6. Above 4G Decoding on, CSM **off**, then A/B ReBAR — CS2 prefers it off. Verify the
   live state in GPU-Z, not in the firmware menu.
7. Curve Optimizer per core (start −10 on the best cores, −20 on the rest),
   PPT 200 / TDC 200 / **EDC 150**. Validate at idle over hours, not with Cinebench.

**Windows layer**

8. Decide the VBS question by platform. FACEIT: leave everything on and skip to 10.
   MM/Premier only: Memory Integrity off, optionally the whole VBS layer.
9. Skip the Spectre/Meltdown registry tweak — on Zen 3 it cannot reach the always-on
   STIBP that carries the cost.
10. Ultimate Performance plan; verify it actually applied after each boot (there is a
    24H2/25H2 bug where it silently reverts toward Balanced).
11. `powercfg /powerthrottling disable /path …\cs2.exe`.
12. Uninstall RGB/fan-control suites rather than closing them.
13. Optional: test Xbox Full Screen Experience as a session mode — about 800 MB of
    RAM back on a 16 GB machine.

**Driver**

14. Latest Game Ready branch, NVCleanstall with installer telemetry off and the
    driver-telemetry expert tweak **off** (anti-cheat safety). DDU first if history
    is messy.
15. NVCP: Prefer maximum performance, Shader Cache Size 10 GB. Expect one stuttery
    session afterwards while the cache rebuilds.
16. Verify `MSISupported` is already 1 — do not force it on an Ampere card.
17. Confirm the card runs at PCIe x16 under load in GPU-Z.

**Game**

18. Launch options: `-fullscreen`, plus `-mainthreadpriority 2` as a candidate. A/B
    `-threads`; never `-high`, never `-vulkan` on Windows (DX11 is ~14 % ahead).
19. Video: Dynamic Shadows **All**, Global Shadow Quality Medium, Shader and Particle
    Low, AO off, MSAA 2×, Model/Texture Medium, Texture Filtering 4×, FSR off, Boost
    Player Contrast on, `fps_max_menu 60`.
20. Frame cap: RTSS Async off FACEIT, the driver limiter with Low Latency Ultra on
    it. With VRR: G-Sync on, control-panel V-Sync on, cap 3 below refresh.
21. Network: `rate 786432`, `cl_net_buffer_ticks 0` (raise only on telemetry
    evidence). NIC: interrupt moderation and EEE off, `TaskOffload` left **enabled**
    globally.
22. Audio: match the endpoint format to 48 kHz / 24-bit on both playback and capture,
    enhancements off, `snd_mixahead 0.05` stepped down to the first artefact-free
    value.
23. Mouse: 1000–2000 Hz on a rear motherboard port. 8 kHz costs measured frame rate
    and CS2 is worse than most because its input path takes a lock per read.

**Discipline**

24. Save a CapFrameX baseline on the Dust2 benchmark map after every configuration
    that is kept. AAABBBAAA runs, one variable at a time, read the 1 % and 0.1 %
    lows.
25. Delay non-security Windows updates one to two weeks; never run
    `DISM … /ResetBase`, which removes the uninstall path.
26. After every Patch Tuesday: re-run the baseline, then re-verify VBS state, power
    plan, Game Bar and mitigation state.
27. When FPS collapses mid-match, `disconnect` then `retry` before touching the
    config — that pattern is a known engine-side bug.

---

## 5. What was deliberately left out

- The claim "16 → 32 GB is worth +17–18 % average and 1 % lows" appears only in the
  research checklist, with no supporting section or citation anywhere in the file.
- Privacy items from the noverse review (Windows Error Reporting pipeline,
  OneSettings, Copilot/Recall policies, endpoint blocklists): the privacy pages
  document what the script applies, so entries with no script behind them would
  misrepresent the page.
- Scheduled-task debloat as a category: a real gap, but it is a new page plus script
  surface rather than an edit.
- Niche network items with no gaming relevance: FEC on 25G NICs, encrypted DNS,
  policy-based QoS marking.
