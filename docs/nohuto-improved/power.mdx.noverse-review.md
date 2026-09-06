# power.mdx — noverse cross-check

Scope: every tweak/info item on `docs/src/content/docs/tweaks/power.mdx` (intro framing, power.ultimate, power.pcie-aspm-off, power.usb-suspend-off, system.fast-startup-off), checked against nohuto's win-config docs (power section + relevant asset files), deep-read 2026-09-06 via raw.githubusercontent.com. Prior local validation (`docs/local-tweaks-validation.md` lines 735–947) used as context.

## Claim-by-claim verification

### 1. Intro framing: "power management is the single biggest source of avoidable latency on a desktop"

- **Our claim:** Windows power management is the biggest source of avoidable desktop latency; the settings trade watts for responsiveness — right trade on a plugged-in desktop, wrong one on battery.
- **noverse position:** NOT-COVERED as a ranking. He never frames power management as the "#1 latency source"; he just ships a desktop plan ("Noverse Performance") that strips power saving and a laptop plan ("Noverse Balanced") that keeps it "to prevent overheating" — which matches our desktop-vs-battery framing in spirit. https://noverse.dev/docs/win-config/power/power-plan/
- **Evidence:** No statement ranking latency sources anywhere in `power/desc.md`. The desktop/battery split in his two plans is the closest thing and aligns with ours.

### 2. Ultimate Performance plan: hidden scheme, GUID e9a42b02…, made visible by duplicating, then /setactive

- **Our claim:** Windows ships a hidden Ultimate Performance scheme (`e9a42b02-d5df-448d-aa00-03f14749eb61`); on consumer SKUs it's made visible via `powercfg /duplicatescheme` + `/setactive`.
- **noverse position:** NOT-COVERED. The string "Ultimate Performance" and the GUID appear nowhere in his repo's docs (checked `power/desc.md`, `system/desc.md`, `misc/desc.md`, `home.md`, `peripheral/desc.md`). His entire approach is different: he clones **SCHEME_MIN (High performance, `8c5e7fda-…`)** and applies ~60 documented changes (parking off, selective suspend off, sleep/deep-sleep off, display dimming off, disk power savings off) rather than touching Ultimate Performance. https://noverse.dev/docs/win-config/power/power-plan/
- **Evidence:** `power/desc.md` "Power Plan" section; default-scheme GUID list in his "Suboptions" section (SCHEME_BALANCED/SCHEME_MIN/SCHEME_MAX only — no e9a42b02). Not a contradiction: he implicitly treats a customized High performance as the better-documented path.

### 3. Ultimate Performance behavior: "biases toward high processor performance and less parking"; cost = higher idle draw, cores never park so no wake-up ramp

- **Our claim:** the scheme favors high processor performance and less core parking; cost is tens of watts at idle on a 16-core part; unparked cores mean no wake-up ramp.
- **noverse position:** AGREES-WITH-NUANCE (on the mechanism, not on this specific plan). His power-settings docs (Microsoft Learn backups annotated via the PowrProf API) confirm the knobs: `CPMINCORES` at 100% is what disables the core-parking algorithm; `PROCTHROTTLEMIN` is a 0–100% floor on requested performance. Notably, his own desktop plan disables parking and selective suspend but **keeps processor idle enabled — "which shouldn't be changed"** — i.e. he unparks cores but deliberately does not touch C-state idle (`IDLEDISABLE`), the dangerous version of this tweak. That supports the local-validation nuance that unparked ≠ C-state-disabled.
- **Evidence:** https://noverse.dev/docs/win-config/power/power-plan/ ("keeps processor idle enabled, which shouldn't be changed"); CPMinCores doc ("The Core Parking algorithm is disabled if the value of this setting is 100%") at https://github.com/nohuto/win-config/blob/main/power/assets/power-settings/options-for-core-parking-cpmincores.md; MinPerformance doc at https://github.com/nohuto/win-config/blob/main/power/assets/power-settings/options-for-perf-state-engine-minperformance.md. He offers no idle-wattage measurements, so our "tens of watts" stays sourced to the local validation's community measurements, not noverse.

### 4. Ultimate Performance limitations: no overclocking, no peak-FPS gain GPU-bound, benefit is burst/ramp only, prove with frame times

- **Our claim:** does not overclock; no peak framerate gain in GPU-bound games; benefit limited to burst/ramp; demand frame-time captures.
- **noverse position:** NOT-COVERED. He makes no FPS claims about power plans anywhere in the power section.
- **Evidence:** absence across `power/desc.md`. Our conservative framing stands on the local validation's sources.

### 5. Laptop note: don't run Ultimate on battery; High Performance while plugged in

- **Our claim:** laptops should skip this plan; High Performance on AC, leave battery profile alone.
- **noverse position:** AGREES-WITH-NUANCE. He likewise gates his aggressive plan to desktops ("This can be used by desktop users") and ships a separate laptop plan that keeps power savings "to prevent overheating". Same direction; his laptop answer is a trimmed Balanced clone rather than stock High Performance.
- **Evidence:** https://noverse.dev/docs/win-config/power/power-plan/ (Noverse Performance vs Noverse Balanced paragraphs).

### 6. Worked variation: min processor state back to 5%, narrower boost band, USB suspend off, display never off, exported as .pow

- **Our claim:** a variation on the plan with PROCTHROTTLEMIN back at 5% so idle cores clock down, etc., exported as `CS2 Zen3 Frametime.pow`.
- **noverse position:** AGREES (methodologically). His plan is exactly this pattern — a stock-scheme clone with individually documented changes — and his docs confirm the setting semantics (PROCTHROTTLEMIN 0–100%, percent units; PERFBOOSTMODE exists as a separate documented setting for the boost-band part). He even ships a context-menu "Import" handler for `.pow` files.
- **Evidence:** https://noverse.dev/docs/win-config/power/power-plan/ (plan description + Context Menu Import); PROCTHROTTLEMIN/PERFBOOSTMODE docs linked from the same page's setting list.

### 7. PCIe ASPM: link drops to low-power state between transfers; wake adds device/platform-dependent delay; `SUB_PCIEXPRESS ASPM 0` disables; costs a few watts

- **Our claim:** ASPM parks the PCIe link; wake-up adds a small device- and platform-dependent delay; disable via `powercfg /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0`; cost a few watts at idle.
- **noverse position:** AGREES. His Link State Power Management doc confirms the setting's identity and semantics: PowerCfg alias `ASPM`, GUID `ee12f906-d277-404b-b6da-e5fa1a576df5`, hidden setting, index 0 = Off ("turn off ASPM for all links"), 1 = Moderate = attempt L0s, 2 = Maximum = attempt L1. His desktop plan strips this class of power saving as part of the ~60 changes.
- **Evidence:** https://noverse.dev/docs/win-config/power/power-plan/ and the per-setting doc https://github.com/nohuto/win-config/blob/main/power/assets/power-settings/pci-express-settings-link-state-power-management.md (canonical MS source: learn.microsoft.com/windows-hardware/customize/power-settings/pci-express-settings-link-state-power-management). Extra depth he has that we lack: per-device `ASPMOptOut` / `ASPMOptIn` DWORDs under `HKLM\SYSTEM\CurrentControlSet\Enum\<enum>\<devID>\<instID>\Device Parameters` (PCI driver reads them; opt-out needs PCIe base ≥ 1.1) — https://noverse.dev/docs/win-config/power/pnp-device-values/. No wattage data from him either; our "few watts" remains locally sourced.

### 8. ASPM caveat: LatencyMon attribution alone doesn't prove disabling ASPM is the fix

- **Our claim:** ASPM-off can fix a specific DPC/link-wake problem, but a LatencyMon driver listing alone doesn't establish causation.
- **noverse position:** NOT-COVERED. He doesn't discuss LatencyMon on the power pages. (His validation tooling elsewhere is WPR/WPA + WinDbg, e.g. the affinities page — consistent with our "A/B the setting" advice, but not a statement about LatencyMon.)
- **Evidence:** absence in `power/desc.md`; methodology context at https://noverse.dev/docs/win-config/affinities/interrupt-handling-affinities/.

### 9. USB selective suspend: Windows suspends idle ports; invisible on mouse/keyboard; clicks/dropouts/vanishing on audio interfaces, DACs, capture devices

- **Our claim:** selective suspend is invisible on HID but shows up as clicks, dropouts, or disappearing devices on audio/capture gear; the power-plan value is the global switch (script sets subgroup `2a737441-…` / setting `48e6b7a6-…` to 0).
- **noverse position:** AGREES, with extra mechanism depth. His docs confirm the global setting (GUID `48e6b7a6-50f5-4782-a5d4-53bb8f07e226`, index 0 = Disabled; correctly notes it has **no** powercfg alias — which is why GUID-based scripting is required) and his desktop plan disables selective suspend. He adds two layers we don't cover:
  1. A separate global **Hub Selective Suspend Timeout** setting (`0853a681-27c8-4100-a2fd-82013e970683`, milliseconds, max 100,000) that sets the idle timeout for all USB hubs.
  2. The per-device registry layer the checkbox maps to: under `Enum\<enumerator>\<deviceID>\<instanceID>\Device Parameters` — `SelectiveSuspendEnabled`, `DeviceIdleEnabled` ("whether the device is capable of being powered down when idle"), `DefaultIdleState`, `SelectiveSuspendTimeout` (5000 ms), `SystemWakeEnabled` (gates the "allow this device to wake" checkbox), `UserSetDeviceIdleEnabled` (gates the user-visible idle checkbox).
  3. On the audio symptom specifically: USBAUDIO.sys has its **own** idle detection (`PoRegisterDeviceForIdleDetection`) with defaults `PerformanceIdleTime = 0` on AC (i.e. a USB audio device on wall power never idles out of D0 via this path) and `ConservationIdleTime = 30` s on battery; 24H2+ adds `CSConservationIdleTime`/`CSPerformanceIdleTime` gated by `GUID_LOW_POWER_EPOCH`. So on a desktop, audio dropouts trace to selective suspend / hub power-off, not the class driver's idle timer — which sharpens rather than contradicts our claim.
- **Evidence:** USB settings docs at https://github.com/nohuto/win-config/blob/main/power/assets/power-settings/configure-power-settings.md (Hub Selective Suspend Timeout, USB selective suspend setting); https://noverse.dev/docs/win-config/power/pnp-device-values/ (per-device values); https://noverse.dev/docs/win-config/power/usb-audio-idle/ (USBAUDIO idle detection, build differences 23H2 vs 24H2).

### 10. USB tweak location: per-hub Device Manager "Allow the computer to turn off this device" checkbox; power-plan value is the global switch

- **Our claim:** the checkbox exists per USB Root Hub in Device Manager; the power-plan value is the global switch and is what the script changes.
- **noverse position:** AGREES-WITH-NUANCE. Same two-layer model, expressed in registry terms: he documents the global power-plan setting and separately the per-instance `Device Parameters` values, noting that values like `SystemWakeEnabled` and `UserSetDeviceIdleEnabled` are precisely what make the Device Manager checkboxes appear. His tool applies the per-device registry values for the USB enumerator directly ("kills selective suspend/idle/LP features") rather than only the plan value — a stronger version of the same tweak.
- **Evidence:** https://noverse.dev/docs/win-config/power/pnp-device-values/ (Device Parameters value list with the W10-source comments on checkbox semantics); plan-level disable at https://noverse.dev/docs/win-config/power/power-plan/.

### 11. Fast Startup mechanism: Shut down hibernates the kernel session to hiberfil.sys; driver/service/kernel state carries over; Restart is a full boot, Shut down is not

- **Our claim:** with Fast Startup on, shutdown logs you off and hibernates the kernel session; that's why Restart fixes what shutdown+power-on doesn't.
- **noverse position:** AGREES, fully. "Fast Startup (also called hiberboot/hybrid shutdown)… logs off the interactive user sessions first, then hibernates the kernel session and loaded kernel mode drivers… Restart doesn't use Fast Startup, it performs a full boot cycle." He adds the command-line nuance (`shutdown /s /t 0` = full shutdown even with Fast Startup on; `/s /hybrid` forces hybrid) and the boot-side plumbing (Boot Manager uses the `resume`/`resumeobject`/`hiberboot`/`filepath`/`filedevice` BCD elements to find Winresume and the hiberfile).
- **Evidence:** https://noverse.dev/docs/win-config/power/disable-hibernation/ ("Disable Hiberboot" section, quoting Microsoft's System power states doc); BCD elements cross-ref to https://noverse.dev/docs/win-config/system/bcd-edits/.

### 12. Fast Startup registry: `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Power\HiberbootEnabled = 0`

- **Our claim:** the script writes `HiberbootEnabled = 0` under `Session Manager\Power`; reboot required.
- **noverse position:** AGREES, with one real addition. He confirms the value (REG_DWORD, range 0–1) and shows decompiled `PopReadHiberbootPolicy` reading it via `PopOpenPowerKey` → `Control\Session Manager\Power`. His addition: the value **also** exists under `Control\Power` (`PopHiberbootEnabledReg`), and a **group policy** `HKLM\Software\Policies\Microsoft\Windows\System\HiberbootEnabled` ("Require use of fast startup") is checked *before* the Session Manager value — a nonzero policy wins. On a policy-managed machine our write could be overridden. He also flags sibling values in the same key that are merely counters (`HybridBootAnimationTime`, `HiberIoCpuTime`, `ResumeCompleteTimestamp`) — changing them does nothing.
- **Evidence:** https://noverse.dev/docs/win-config/power/disable-hibernation/ (registry values + PopReadHiberbootPolicy pseudocode, linked to github.com/nohuto/decompiled-pseudocode 11-23H2 ntoskrnl); policy row linking to noverse.dev/policies (WinInit Hiberboot).

### 13. Fast Startup cost: boot a few seconds longer, barely perceptible on NVMe

- **Our claim:** boot takes a few seconds longer; barely perceptible on NVMe.
- **noverse position:** NOT-COVERED. He gives no boot-time deltas; he only notes the mechanism (hibernation write at shutdown, resume via Winresume) and hiberfile sizing (see claim 14).
- **Evidence:** absence in the disable-hibernation page. Our cost figure remains sourced from the local validation (Microsoft/HP).

### 14. What HiberbootEnabled=0 keeps: hibernate and sleep still work; `powercfg /h off` is the heavier hammer

- **Our claim:** our tweak kills only hybrid shutdown; `powercfg /h off` throws away hibernate entirely plus the hiberfil.sys disk space.
- **noverse position:** AGREES, with sizing depth. "`powercfg /hibernate off` disables normal hibernation, hybrid sleep, and Fast Startup as a consequence" — he notes it also kills **hybrid sleep**, which our page doesn't mention. He documents the hiberfile type system: full (default 40% of RAM; supports hibernate, hybrid sleep, fast startup) vs reduced (20%; fast startup only), switchable via `powercfg /h /type full|reduced` (a middle option between our tweak and `/h off`), and the registry underneath (`HibernateEnabled` = the value `/h off` flips; `HiberFileType`, `HiberFileSizePercent`, the `HiberFileBucket` per-RAM-size percentages). He also documents `ForceHibernateDisabled\{GuardedHost,Policy}` (forced-off paths) and a `DisableIdleStatesAtBoot` suboption.
- **Evidence:** https://noverse.dev/docs/win-config/power/disable-hibernation/ (Reduced HiberFile section + PowerCFG captures + registry values); related `Control\Power` catalog at https://noverse.dev/docs/win-config/power/power-values/.

## Improvements to adopt

(In our own words; ready to merge later.)

1. **Fast Startup: add the policy-precedence caveat.** A domain/local policy "Require use of fast startup" (`HKLM\Software\Policies\Microsoft\Windows\System\HiberbootEnabled`) is evaluated before the `Session Manager\Power` value, and a nonzero policy wins — so on policy-managed machines the script's write can be overridden. One sentence suffices. Source: https://noverse.dev/docs/win-config/power/disable-hibernation/
2. **Fast Startup: mention the middle option and the hybrid-sleep casualty.** `powercfg /h /type reduced` shrinks the hiberfile to ~20% of RAM for a fast-startup-only file (full is ~40% and also backs hibernate + hybrid sleep); and `powercfg /h off` kills hybrid sleep too, not just hibernate + Fast Startup. Strengthens our "heavier hammer" paragraph with specifics. Source: https://noverse.dev/docs/win-config/power/disable-hibernation/
3. **USB selective suspend: name the second global knob and the per-device layer.** Besides the plan setting (`48e6b7a6-…`, no powercfg alias — GUID scripting is required), there is a global Hub Selective Suspend Timeout (`0853a681-…`, ms) and the per-device layer lives under `Enum\<enum>\<devID>\<instID>\Device Parameters` (`SelectiveSuspendEnabled`, `DeviceIdleEnabled`, `SelectiveSuspendTimeout` = 5000 ms default; `SystemWakeEnabled`/`UserSetDeviceIdleEnabled` control which Device Manager checkboxes exist). Sources: https://noverse.dev/docs/win-config/power/power-plan/ , https://noverse.dev/docs/win-config/power/pnp-device-values/
4. **USB audio dropout claim: sharpen the mechanism.** USBAUDIO.sys registers its own idle detection, but its AC default (`PerformanceIdleTime = 0`) means a USB audio device on wall power never self-idles into D3 — the 30-second timer only applies on battery (24H2 adds separate Modern-Standby `CS*` timers). So desktop audio clicks/dropouts come from selective suspend / hub power-off, exactly the switch our tweak flips; worth one clause to preempt "but my interface has its own idle timer" confusion. Source: https://noverse.dev/docs/win-config/power/usb-audio-idle/
5. **ASPM: spell out the index semantics.** 0 = Off (all links), 1 = Moderate (L0s), 2 = Maximum (L0s + L1); Balanced's AC default is Moderate, so many desktops only hit L1-class wake penalties after an OEM or user selects Maximum. Optionally: per-device `ASPMOptOut` under the device's `Device Parameters` can exempt one device without touching the plan. Sources: https://github.com/nohuto/win-config/blob/main/power/assets/power-settings/pci-express-settings-link-state-power-management.md , https://noverse.dev/docs/win-config/power/pnp-device-values/
6. **Power plan section: add the "unparked ≠ idle-disabled" distinction with the concrete knobs.** Parking is governed by `CPMINCORES` (100% disables the parking algorithm); forcing `IDLEDISABLE` (C-states) is the aggressive variant that a careful reference implementation explicitly refuses to apply ("shouldn't be changed"). This backs our existing "cores never park" wording with the exact mechanism and warns readers off the heavier version. Sources: https://noverse.dev/docs/win-config/power/power-plan/ , https://github.com/nohuto/win-config/blob/main/power/assets/power-settings/options-for-core-parking-cpmincores.md

## Gaps noverse covers that we don't

- **Disable Timer Coalescing** — `TimerCoalescing` REG_BINARY (exactly 80 bytes = two 4-DWORD tolerance blocks, validated by win32kfull `InitTimerCoalescing`) under `HKLM\SYSTEM\CurrentControlSet\Control\Power`. Latency-adjacent power tweak we don't mention on any page. https://noverse.dev/docs/win-config/power/disable-timer-coalescing/
- **xHCI IMOD** — USB controller interrupt moderation: Windows writes IMODI = 200 ticks = 50 µs on every build from W10 1507 through W11 26H1; his verdict is to *keep the default* (counter is usually already zero at the next 1 ms/125 µs service chance) and instead spread devices across xHCI controllers so they don't share an interrupter. Not covered in our docs (usb-latency-suite.md only covers driver-level interrupt threshold). https://noverse.dev/docs/win-config/power/xhci-imod/
- **USB Audio Idle values** — per-device-class `{4d36e96c-…}\00xx\PowerSettings` idle timeouts (see improvement #4). https://noverse.dev/docs/win-config/power/usb-audio-idle/
- **Power Values catalog** — the full `Control\Power` boot-read list (`PowerThrottlingOff` QoS gate, `EnergyEstimationEnabled`, `HibernateEnabled`, `ModernSleep`, `HiberFileBucket`…). Author himself warns "the applied data is sometimes pure speculation" — mine it for facts, not for tweak recipes. https://noverse.dev/docs/win-config/power/power-values/
- **Disable Energy Estimation** — per-process energy tracking switch (with partmgr idle-state caveats). https://noverse.dev/docs/win-config/power/disable-energy-estimation/
- **Remove Power Options** — hiding Sleep/Hibernate/Lock from Start/logoff menus (`Explorer\FlyoutMenuSettings`, PolicyManager `Hide*`, policies). Cosmetic but adjacent to our Fast Startup entry. https://noverse.dev/docs/win-config/power/remove-power-options/
- **~100 documented power settings** (core-parking CP* family, hetero-scheduling HETERO* family, NVMe idle/NOPPME, AHCI HIPM/DIPM) — reference material if we ever expand the worked-variation `.pow` documentation. https://noverse.dev/docs/win-config/power/power-plan/
- **Disable NIC Power Savings** — per-adapter power values under the NIC class key. Our network.mdx covers NIC power at the cmdlet level (sibling agent's page); cross-link candidate only. https://noverse.dev/docs/win-config/power/disable-nic-power-savings/

## Conflicts needing a decision

- **No factual contradictions found.** noverse agrees with (or doesn't cover) every mechanism on our page. Two philosophical divergences worth an editorial note, not a rewrite:
  1. **Ultimate Performance vs custom High-performance clone.** Our page leads with the hidden Ultimate plan; noverse ignores that plan entirely and builds his desktop plan as a documented ~60-change clone of High performance, explicitly keeping processor idle enabled. Neither is wrong — ours is one command with a honest cost/limitations section; his is more controlled. If we ever expand the power-plan section, presenting the "clone + documented changes" approach as the advanced option (it already is, embryonically, via our `CS2 Zen3 Frametime.pow` worked variation) reconciles both.
  2. **Fast Startup recommendation level.** We call disabling it "the single most useful entry in the collection"; noverse offers the same disable neutrally (his tool, his docs) without endorsing or warning. Microsoft's support line ("Disabling Fast Startup is not recommended", KB 3211190, flagged in the local validation) remains the only source actually opposing our recommendation — a documented opinion gap, not a noverse conflict.
- **Caution flag on his Power Values page:** he states the applied data there "is sometimes pure speculation." Treat individual value semantics from that page as leads to verify (his pseudocode links help), not as authoritative — relevant if we adopt gap items from it.
