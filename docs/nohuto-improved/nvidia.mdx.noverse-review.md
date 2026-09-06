# tweaks/nvidia.mdx — noverse cross-check

Sources deep-read (not just the source map):

- NVIDIA section raw source: https://raw.githubusercontent.com/nohuto/win-config/main/nvidia/desc.md
  (pages: bitmask-calculator, nvcpl-settings, debloated-driver, nvapi-cli, temporary-nvcpl,
  hide-tray-icon, disable-dlss-indicator, disable-logging, disable-scheduled-tasks,
  disable-telemetry, enable-developer-settings, nvlddmkm-hex-values, oc-uv-guide)
- nvlddmkm-hex-values rendered: https://noverse.dev/docs/win-config/nvidia/nvlddmkm-hex-values/
- PnP device values (MSI + interrupt keys): https://noverse.dev/docs/win-config/power/pnp-device-values/
- Interrupt affinities: https://noverse.dev/docs/win-config/affinities/interrupt-handling-affinities/
- His 964-entry NVIDIA RM value-name list: https://github.com/nohuto/bitmask-calc/blob/main/nvvalues.txt
- His converted official NVIDIA RM bitfield definitions (the JSON his bitmask tool downloads,
  `nvbitc.json` from github.com/nohuto/Files/releases) — queried directly for every RM* value
  on our page. All 20 value names on our page are present with NVIDIA's own field/comment data.

## Claim-by-claim verification

### 1. MSI explainer: line-based interrupts are shared/polled; MSI writes its own vector
- **Our claim:** line-based interrupts share physical IRQ lines forcing the OS to poll each
  device on the line; MSI lets the device write its own interrupt vector, no sharing/polling.
- **noverse position: AGREES (implicitly, mechanism-level).** He documents the exact same key
  (`...\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties`,
  `MSISupported` REG_DWORD, "set by many device INFs (device specific)") and adds
  `MessageNumberLimit` (cap on requested MSI messages) plus a `Range\<n>` subkey
  (`StartingMessage`/`EndingMessage`/`MessagesPerProcessor`). His affinities page notes
  `IrqPolicySpreadMessagesAcrossAllProcessors` requires MSI-X support on device and platform.
- Evidence: https://noverse.dev/docs/win-config/power/pnp-device-values/ ,
  https://noverse.dev/docs/win-config/affinities/interrupt-handling-affinities/

### 2. Most modern GPUs support MSI but ship line-based; NVIDIA driver installs reset it
- **Our claim:** support is common, enablement isn't; driver installs historically reset it.
- **noverse position: NOT-COVERED.** He never advises enabling MSI on the GPU and doesn't
  discuss NVIDIA INF defaults or reset-on-install. His only relevant statement is neutral:
  `MSISupported` is device-specific and INF-set — consistent with, but not confirming, our claim.
- Evidence: https://noverse.dev/docs/win-config/power/pnp-device-values/

### 3. The registry path `MSISupported = 1` + "re-check after every driver update" caution
- **Our claim:** set `MSISupported=1` under the device's Enum\PCI key; NVIDIA updates can reset it.
- **noverse position: AGREES on the mechanism** (identical path/value documented); the
  reset-after-update behavior is NOT-COVERED by him. No conflict.

### 4. Effect hedge: "may reduce interrupt/DPC overhead; not a guaranteed frame-time improvement"
- **Our claim:** plausible mechanism, unproven benefit.
- **noverse position: AGREES-WITH-NUANCE.** He makes no benefit claim either; instead he ships
  the measurement workflow we lack: capture `wpr -start CPU.light -start GPU.light`, open the
  ETL in WPA/MXA, and inspect per-core ISRs/DPCs per driver (his example is literally
  `nvlddmkm.sys` dragged into the MXA panel). This is the "how you'd actually verify it" material
  our page gestures at.
- Evidence: https://noverse.dev/docs/win-config/affinities/interrupt-handling-affinities/

### 5. Danger box: MSI can black-screen boot on rare hardware; revert via Safe Mode
- **noverse position: NOT-COVERED.** He doesn't warn about MSI boot failures anywhere.
  No conflict; our local validation already marked this MOSTLY TRUE via other sources.

### 6. DevicePriority=High: "no reproducible benefit and a real history of causing instability"
- **Our claim:** interrupt-priority raising is benefit-free and destabilizing; script skips it.
- **noverse position: AGREES-WITH-NUANCE.** He documents `DevicePriority` as a real REG_DWORD
  under `Interrupt Management\Affinity Policy` (default 0) and publishes the actual semantics
  from the WDK IRQ-priority table: High = elevated IRQL 12, Normal = IRQL 5–11, Low = 3–4.
  He neither recommends raising it nor repeats any instability story — so our "no reproducible
  benefit" stands unopposed, but "real history of causing instability" gets no support from him
  (consistent with our local validation calling it UNVERIFIABLE lore).
- Evidence: https://noverse.dev/docs/win-config/power/pnp-device-values/ ,
  https://noverse.dev/docs/win-config/affinities/interrupt-handling-affinities/

### 7. NVIDIA scheduled tasks: crash reporting, telemetry monitoring, update/profile polling, on timers and at logon
- **Our claim:** NVIDIA installs such tasks; our script matches NvTmRep*/NvTmMon*/NvDriverUpdate*/
  NVIDIA GeForce Experience*/NvProfileUpdater*/NvNodeLauncher*.
- **noverse position: AGREES.** His option disables the same family (his matcher:
  `NvTmRep_*`, `NvTmRepOnLogon*`, `NvTmMon_*`) and his per-task breakdown matches ours:
  NvTmRep.exe = crash and telemetry reporter; NvTmMon = sends at logon then hourly;
  NvTmRepOnLogon = at logon; NvTmRep = daily at 12:25. He doesn't cover the update/profile
  tasks (NvDriverUpdate*, NvProfileUpdater*, NvNodeLauncher*) — our pattern list is broader.
- Evidence: https://noverse.dev/docs/win-config/nvidia/disable-scheduled-tasks/

### 8. The hardcoded-GUID story and the NVIDIA App transition
- **Our claim:** old scripts disable tasks by full name incl. a hardcoded GUID; after the NVIDIA
  App replaced GeForce Experience in 2024 the task names changed and the calls fail silently
  (output to `nul`).
- **noverse position: AGREES on the key fact.** He writes (paraphrased): all 3 NvTm* tasks no
  longer seem to be created on recent drivers; he keeps the option anyway. That independently
  confirms the "the tasks stopped existing" endpoint. He says nothing about the GUID itself.
  (Note: our local validation separately proved the GUID is *not* per-machine — it's a constant
  NVIDIA embedded in GFE-era task names — and that the tasks ceased rather than "changed names".
  noverse supports the corrected version, not the page's current wording.)
- Evidence: https://noverse.dev/docs/win-config/nvidia/disable-scheduled-tasks/

### 9. Cost of disabling: no automatic driver-update notifications
- **noverse position: NOT-COVERED.** No conflict.

### 10. RM* block framing: "twenty-two undocumented values… copied from forum posts, not derived from anything"
- **Our claim:** the values are undocumented internal knobs whose bit meanings are unknown to
  everyone circulating them.
- **noverse position: CONTRADICTS the "undocumented/underivable" absolute.** His bitmask
  calculator ships a self-built JSON conversion of NVIDIA's *official* resource-manager registry
  definitions — 964/967 entries — and every one of the 20 RM* values on our page is in it with
  per-bit field names, option encodings, and NVIDIA's own comments. The bit meanings are
  therefore documented (internally) and now obtainable. **Nuance that saves our underlying
  point:** he labels his own presets "experimental… not recommendations, only possible
  presumptions", refuses to ship a preset at all for `RMBandwidthFeature`, and never claims any
  performance benefit for any of these. The definitions being readable doesn't validate the
  circulating magic numbers — but "nobody can say which bit corresponds to which engine" is no
  longer true as written (see claim 12).
- Evidence: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/ ,
  https://github.com/nohuto/bitmask-calc/blob/main/nvvalues.txt

### 11. HDCP block: RMHdcpKeyglobZero/RmDisableHdcp22/RMSkipHdcp22Init disable HDCP, break DRM playback, no perf gain
- **Our claim:** these kill the HDCP handshake; protected streams degrade/refuse; no performance
  mechanism.
- **noverse position: AGREES, with hard confirmation from NVIDIA's own definition text.** His
  converted definitions: `RMHdcpKeyglobZero` — 1 forces the HDCP keyglob to zero, intended for
  SKUs without fused HDCP keys (bring-up); `RmDisableHdcp22` — "Disables HDCP22 feature";
  `RMSkipHdcp22Init` — a WAR ("workaround") knob pending signed HDCP 2.2. He even demonstrates
  the effect in reverse: using the value to make a display report HDCP-unsupported in the NVCPL
  "View HDCP status" page. Nowhere does he attach any performance rationale.
- Evidence: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/ (definitions),
  https://noverse.dev/docs/win-config/nvidia/nvcpl-settings/ (HDCP status section)

### 12. Clock-gating block: ELCG/BLCG/SLCG/ELPG/FSPG are debug knobs; "nobody posting them can say which bit corresponds to which engine"
- **Our claim:** engine/block/second-level clock gating + engine power gating controls; magic
  patterns copied blindly, bit-to-engine mapping unknown.
- **noverse position: CONTRADICTS the "unknown bits" half, AGREES with the rest.** His data
  settles the names (ELCG = engine-level, BLCG = block-level, SLCG = second-level clock gating;
  ELPG = engine-level power gating; FSPG = floorsweep power gating) *and* the fields, e.g.
  RMElcg uses 2 bits per engine (GR bits 1:0, CE0 5:4, PDEC 7:6…) with 0=VBIOS default /
  1=disabled; RMBlcg uses 4 bits per engine with DISABLE/ENABLE/IDLE/STALL/QUIESCENT encodings;
  RMSlcg and RMElpg use 1 bit per engine. Decoded, the circulating values are just "disable
  every engine" masks: 0x55555555 = DISABLED in every 2-bit ELCG field, 0x11111111 = DISABLE in
  every BLCG field, 0xFFF = all twelve ELPG engines off — his own presets for these three are
  byte-for-byte the script values. **Two facts that strengthen our page's real point:** (a) per
  NVIDIA's comments, the *CG regkeys only take effect when the matching `RmPowerFeatures` field
  is set to per-engine override (value 2) — the short tweak scripts never set it, so the writes
  are likely inert, not dangerous; (b) script-to-script value drift (RMSlcg 0x3FFF3 vs 0x3FFFF;
  RMFspg 5 vs 15 — his presets are 0x3FFFF and 15, ours quote 0x3FFF3 and 5) is itself proof of
  blind copying.
- Evidence: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/ (+ nvbitc.json
  definitions for RMElcg/RMBlcg/RMSlcg/RMElpg/RMElpgStateOnInit/RMFspg)

### 13. Disabling clock gating costs heat/power and can lower achieved boost clocks
- **noverse position: NOT-COVERED editorially.** He provides definitions only and makes no
  power/thermal argument either way. No conflict; our mechanism reasoning stands on its own
  sources (NVIDIA GPU Boost is power/thermal-limited).

### 14. RMBandwidthFeature block: "1896072192 is 0x71007100", undocumented, no source, no measurement
- **Our claim:** a bit field for an undocumented internal feature; nothing known; value probably
  not even valid on current branches.
- **noverse position: CONTRADICTS "no source for what it does".** His definitions include both
  values: `RMBandwidthFeature` is a display-bandwidth feature override — its fields include
  scaler amortization (spreading the scaler's input fetch across a raster line to lower
  hubclk/dispclk requirements; NVIDIA's comment says the feature doesn't exist on chips before
  "Orin", i.e. Tegra-era text) and ISO_CRIT_ALWAYS; 16 fields total, many DEPRECATED.
  `RMBandwidthFeature2` overrides memory-pool compression and advanced-vs-legacy fetch metering
  (Ampere+ enables advanced fetch metering in hardware by default). Significantly, he ships **no
  preset** for it — his "Auto Config" is greyed out when there's no defensible value — which is
  the same bottom line as ours ("no reason to believe the value is valid") reached from the
  definitions themselves. Separately, the hex gloss is arithmetically wrong on our page:
  1896072192 = 0x7103C400, not 0x71007100 (already flagged by local validation; noverse doesn't
  address the number).
- Evidence: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/ (definition source),
  https://github.com/nohuto/bitmask-calc/blob/main/nvvalues.txt

### 15. ASPM/power block: intent legitimate, but the Windows power-plan PCIe ASPM setting does it documented and clean
- **Our claim:** stop the GPU's PCIe link sleeping via the documented power subsystem instead of
  nine driver-class-key values.
- **noverse position: AGREES-WITH-NUANCE.** He doesn't compare against powercfg, but NVIDIA's
  own comments in his data brand these as test knobs: `RMEnableASPMAtLoad` is "intended for
  testing purpose", for enabling ASPM on no-pstate/single-pstate VBIOSes;
  `RmOverrideSupportChipsetAspm` likewise "intended for testing purpose". And the values decode:
  `RMPcieLtrOverride` bits 1:0 = ALLOW_LTR with 0=default / 1=enable / **2=disable LTR messages**
  — so the scripts' `RMPcieLtrOverride = 2` is precisely "stop sending PCIe Latency Tolerance
  Reporting messages", the mechanism behind the stated intent. `RMDeepL1EntryLatencyUsec` is a
  boolean override of the DeepL1 entry delay (forcing 1 µs makes DeepL1 unenterable);
  `RmMIONoPowerOff` keeps MIOs (NVLink/multi-chip IO) powered. He also notes script polarity
  drift exists (his presets: RMEnableASPMDT=1, RMDisableGpuASPMFlags=3 — different from both our
  quoted block and QuakedK's).
- Evidence: nvbitc.json definitions via https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/

### 16. DisableDynamicPstate: pins the GPU out of low-power P-states → hot idle, less boost headroom
- **Our claim:** forces high clocks at idle; costs idle power/temperature.
- **noverse position: AGREES on function.** NVIDIA's definition in his data: 1 = disable dynamic
  P-State/adaptive clocking; 0 = leave it alone (default). He adds no thermal editorializing —
  our inference is unopposed and already sourced locally (AtlasOS/TechSpot).
- Evidence: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/

### 17. Write-to-both-keys problem (\0000 and \0001, CurrentControlSet vs ControlSet001)
- **Our claim:** blind dual-writes hit the wrong device or nothing; mixing control sets is sloppy.
- **noverse position: AGREES (he engineered around exactly this).** His tool never writes blind:
  "Reg Add"/"Open Key" enumerate the Display class GUID `{4d36e968-e325-11ce-bfc1-08002be10318}`
  subkeys and select the one whose `DriverDesc` matches `*NVIDIA*`. That's the correct
  auto-detection fix for the failure mode we describe, and worth citing as the pattern.
- Evidence: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/

### 18. The user-supplied GPU class GUID prompt (no validation, suppressed output, silent partial writes)
- **noverse position: AGREES implicitly** — same auto-detect mechanism as above exists precisely
  so no one has to type a GUID. No direct commentary. No conflict.

### 19. Do it at install time with NVCleanstall instead of registry edits
- **Our claim:** lean NVIDIA installs belong at install time; use NVCleanstall.
- **noverse position: AGREES-WITH-NUANCE.** Same philosophy, different tool: his `NVIDIA-Tool.ps1`
  optionally runs a DDU clean uninstall (safe-boot assisted) first, then strips the driver
  package to `Display.Driver`/`NVI2`/`setup.cfg`/`setup.exe` and edits telemetry, EULA and
  web-link entries out of the installer XML/CFG before running setup. He pulls the driver list
  from TechPowerUp (NVCleanstall's home). Adds two things we lack: DDU as the clean-slate step,
  and editing installer config files rather than only deselecting components.
- Evidence: https://noverse.dev/docs/win-config/nvidia/debloated-driver/

### 20. EnableGR535 = 0 restores Control Panel Image Sharpening
- **noverse position: NOT-COVERED.** He never mentions EnableGR535. No conflict. (Local
  validation's caveats stand: hidden since the 496 branch in 2021, not by the NVIDIA App; the
  key moved to `nvlddmkm\Parameters\FTS` on 566+; reliability degrading on newest drivers.)

## Improvements to adopt

1. **Reframe "undocumented" → "internal, now decoded".** Replace "twenty-two undocumented
   values… not derived from anything. Nobody posting them can say which bit corresponds to
   which engine" with: these are NVIDIA internal resource-manager parameters; NVIDIA's own
   definition files (converted to JSON by nohuto's bitmask calculator, 967 entries) document
   every field, and the circulating magic numbers decode as blanket "disable every engine"
   masks (0x55555555 = DISABLED in each 2-bit ELCG field, etc.). The critique that survives:
   script authors copy the masks without knowing this, values drift between scripts
   (RMSlcg 0x3FFF3 vs 0x3FFFF, RMFspg 5 vs 15), and no measurement exists.
   Cite: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/

2. **Add the RmPowerFeatures gating fact to the clock-gating block.** Per NVIDIA's definition
   comments, the ELCG/BLCG/SLCG/ELPG regkeys only take effect when the matching
   `RmPowerFeatures` field is set to per-engine override (2). The circulating blocks don't set
   it — so on most systems the writes are inert rather than harmful. This is a *stronger*
   debunk than "unknown bits" and is checkable.
   Cite: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/

3. **Decode the ASPM block's actual semantics.** `RMPcieLtrOverride = 2` = disable PCIe LTR
   (Latency Tolerance Reporting) messages — the scripts' real mechanism, now nameable.
   `RMEnableASPMAtLoad` and `RmOverrideSupportChipsetAspm` are flagged by NVIDIA's comments as
   test-purpose regkeys (the former for VBIOSes without proper P-states).
   `RMDeepL1EntryLatencyUsec` boolean-overrides the DeepL1 entry delay; `RmMIONoPowerOff` keeps
   MIOs powered. Cite: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/

4. **Give RMBandwidthFeature its real identity.** It's a display-bandwidth feature override
   (scaler amortization — spreading scaler input fetch to relax hubclk/dispclk — plus
   isochronous and fetch-metering controls; the definition text predates/disjoints from
   consumer GeForce, referencing pre-"Orin" chips). No preset value is defensible even from the
   definitions — which is exactly why the circulating decimal is folklore. Also fix the
   arithmetic: 1896072192 = 0x7103C400.
   Cite: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/

5. **Update the telemetry-tasks section with the endpoint nohuto confirms.** "All 3 tasks no
   longer seem to be created" on current drivers (NvTmMon, NvTmRepOnLogon, NvTmRep) — cite him
   alongside the NVIDIA App transition, and correct the page per local validation (the GUID was
   an NVIDIA constant; the tasks ceased rather than being renamed).
   Cite: https://noverse.dev/docs/win-config/nvidia/disable-scheduled-tasks/

6. **Add the telemetry-registry debunk (new material for us).** The widely copied "NVIDIA
   telemetry" values `HKLM\SOFTWARE\NVIDIA Corporation\Global\FTS\EnableRID44231/64640/66610`
   don't exist in current driver binaries (string-verified); the genuine NVCPL telemetry opt-out
   is `HKCU\Software\NVIDIA Corporation\NVControlPanel2\Client\OptInOrOutPreference`. His
   decompiled sequence shows the NVCPL telemetry event collects driver version, OS version,
   system type (desktop/laptop/Optimus) and GPU names. Also: a debloated driver is the first
   step. Cite: https://noverse.dev/docs/win-config/nvidia/disable-telemetry/

7. **Add a verification workflow to the MSI section.** How to check whether anything changed:
   WPR capture (`wpr -start CPU.light -start GPU.light`), open in WPA/MXA, inspect nvlddmkm.sys
   ISRs/DPCs per core. Turns our "plausible mechanism" into something the reader can test.
   Cite: https://noverse.dev/docs/win-config/affinities/interrupt-handling-affinities/

8. **Sharpen the DevicePriority paragraph.** Document what it actually does before dismissing
   it: it maps to the WDK IRQ-priority table (High = IRQL 12 vs Normal 5–11). Then keep the
   dismissal, but drop or hedge "a real history of causing instability" (lore, unsupported by
   either source). Cite: https://noverse.dev/docs/win-config/affinities/interrupt-handling-affinities/ ,
   https://noverse.dev/docs/win-config/power/pnp-device-values/

9. **Recommend auto-detection over GUID hunting in "What to do instead".** The correct pattern
   for touching the GPU class key: enumerate
   `HKLM\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}` and pick
   the subkey whose `DriverDesc` is *NVIDIA* — never write \0000 and \0001 blindly.
   Cite: https://noverse.dev/docs/win-config/nvidia/bitmask-calculator/

10. **Broaden the lean-install advice.** Alongside NVCleanstall: DDU (safe boot) for clean
    removal, and stripping the package to Display.Driver/NVI2/setup files with telemetry/EULA
    entries edited out of installer XML/CFG.
    Cite: https://noverse.dev/docs/win-config/nvidia/debloated-driver/

## Gaps noverse covers that we don't

- NVIDIA telemetry debunk: FTS `EnableRID*` values are dead; real opt-out `OptInOrOutPreference` — https://noverse.dev/docs/win-config/nvidia/disable-telemetry/
- Driver logging controls (`LogEventEntries`/`LogErrorEntries`/`LogWarningEntries`/`LogPagingEntries` under `nvlddmkm\Parameters`, retail default 512 entries each) — https://noverse.dev/docs/win-config/nvidia/disable-logging/
- DLSS on-screen indicator toggle (`HKLM\SOFTWARE\NVIDIA Corporation\Global\NGXCore\ShowDlssIndicator`, 1024=on/0=off) — https://noverse.dev/docs/win-config/nvidia/disable-dlss-indicator/
- Hidden NVCPL developer settings (`NvDevToolsVisible`, `RmProfilingAdminOnly`) — https://noverse.dev/docs/win-config/nvidia/enable-developer-settings/
- Tray icon / context-menu removal values (`HideXGpuTrayIcon`, CoProcManager `ShowTrayIcon`, NvCplApi `ContextUIPolicy`) — https://noverse.dev/docs/win-config/nvidia/hide-tray-icon/ , https://noverse.dev/docs/win-config/nvidia/remove-context-menu-entry/
- Temporary NVCPL (run NVDisplay.Container only while the panel is open) — https://noverse.dev/docs/win-config/nvidia/temporary-nvcpl/
- What NVCPL actually writes per setting (ProcMon traces: PhysX auto/GPU/CPU values, color/vibrance keys, video super-resolution) — https://noverse.dev/docs/win-config/nvidia/nvcpl-settings/
- `nvlddmkm\State` hive is the driver's persistent state store (DisplayDatabase, HDCP SRM, TDR records); the D3DOGL_* hex values read there — documented with an explicit "don't change these" — https://noverse.dev/docs/win-config/nvidia/nvlddmkm-hex-values/
- GPU interrupt affinity pinning (AssignmentSetOverride mask calculation; IrqPolicy table; MSI-X-only spreading policy) — https://noverse.dev/docs/win-config/affinities/interrupt-handling-affinities/
- GPU OC/UV workflow (Afterburner + HWiNFO, autostart profile via scheduled task) — https://noverse.dev/docs/win-config/nvidia/oc-uv-guide/
- NvAPI CLI (~400 NVAPI functions scriptable) — https://noverse.dev/docs/win-config/nvidia/nvapi-cli/
- Debloated-driver script incl. DDU step and TechPowerUp driver list — https://noverse.dev/docs/win-config/nvidia/debloated-driver/

## Conflicts needing a decision

1. **"Undocumented / nobody knows the bits" vs nohuto's official-definition conversion.** His
   JSON is verbatim NVIDIA RM definition text (internal field names like `CYA_L0S_ENABLE`,
   MODS/VBIOS commentary, Tegra-era chip references), consistent with NVIDIA's
   open-gpu-kernel-modules naming — the sourcing is strong. But "definitions exist" ≠ "the
   circulating values are sane": nohuto himself ships no preset for RMBandwidthFeature and marks
   his presets experimental/non-recommendations. Resolution: adopt his facts (definitions,
   field maps, RmPowerFeatures gating, LTR decode) while keeping — and strengthening — our
   anti-folklore verdict. The page's absolute wording must go; the warning stays.
2. **Which RMSlcg/RMFspg values to quote.** Our page quotes 0x3FFF3 and 5; nohuto's presets are
   0x3FFFF and 15; other scripts show further variants. Don't "correct" to his values — present
   the drift itself as the evidence of blind copying (both variants disable-subset masks).
3. **DevicePriority instability lore.** We say "real history of causing instability"; nohuto
   documents the value neutrally and local validation found no authoritative instability source.
   Decision needed: keep the advice (don't set it), soften the rationale to "no documented or
   measured benefit" and describe what it changes (IRQL 12).
4. **No conflict on the two local-validation errors** (0x71007100 arithmetic, per-machine GUID
   story) — noverse simply doesn't cover either; fixes for those come from the local validation,
   not this cross-check.
