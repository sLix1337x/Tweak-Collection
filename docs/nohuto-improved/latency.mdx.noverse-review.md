# latency.mdx — noverse cross-check

Sources deep-read (not just the source map):
- https://noverse.dev/docs/win-config/system/mmcss-values/ (full page incl. Tasks section, read from raw `system/desc.md` lines 1150–1988)
- https://noverse.dev/docs/win-config/system/game-mode/
- https://noverse.dev/docs/win-config/privacy/disable-xbox-game-bar/

Noverse's MMCSS material is decompiled mmcss.sys pseudocode (11–23H2) plus WinDbg reads of the live globals (`CiSystemResponsiveness`, `CiNetworkThrottlingIndex`, …). That is the same evidence class as our page's binary-strings verification, but stronger (disassembly + live memory, not just string presence).

## Claim-by-claim verification

### Game DVR — rolling background encode, on by default, GPU encoder, frame-time spikes
- **Our claim:** background recording keeps a rolling encode so "record last 30 s" works; on by default; uses the GPU encoder; cost shows as periodic frame-time spikes.
- **Noverse position:** **NOT-COVERED.** His Game Bar page (https://noverse.dev/docs/win-config/privacy/disable-xbox-game-bar/) is a privacy/values inventory — it lists every `HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR` value the capture settings APIs read (`AppCaptureEnabled`, `HistoricalCaptureEnabled`, buffer length, bitrate modes, hotkey VK codes…) but makes no performance/overhead claim. His Game Mode page touches Game DVR only as a policy/registration gate.
- **Evidence + URLs:** no overhead measurement anywhere in noverse. Our local validation already flagged "on by default" as outdated for Windows 11 (background recording off by default; capture capability on). Noverse neither confirms nor refutes.

### Game DVR registry values — GameDVR_Enabled (HKCU) + AllowGameDVR policy (HKLM)
- **Our claim:** `HKCU\System\GameConfigStore\GameDVR_Enabled = 0` (per-user) and `HKLM\SOFTWARE\Policies\Microsoft\Windows\GameDVR\AllowGameDVR = 0` (machine-wide); HKCU half must be applied per account.
- **Noverse position:** **AGREES.** His Game Bar page documents exactly the same policy: `HKLM\Software\Policies\Microsoft\Windows\GameDVR` / `AllowGameDVR` ("Enables or disables Windows Game Recording and Broadcasting"). URL: https://noverse.dev/docs/win-config/privacy/disable-xbox-game-bar/
- **Nuance:** for the per-user half he documents `HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR\AppCaptureEnabled` (bool) rather than `GameConfigStore\GameDVR_Enabled`. Both values are real; they are written/read by different components (Settings/Game Bar vs. the capture settings API). No conflict, but his inventory shows the surface is wider than one value.
- **Related fact (game-mode page):** the same HKLM GameDVR policy key also carries `AllowAutoGameMode`, which gates **Game Mode** registration (missing/nonzero = allowed; 0 hides the Game Mode settings page). Our `AllowGameDVR = 0` does not touch it. URL: https://noverse.dev/docs/win-config/system/game-mode/

### "Disables capture, not the overlay" (Shift+G note)
- **Our claim:** Game Bar overlay still opens; "Shift+G" opens it.
- **Noverse position:** **AGREES** on substance — his page treats recording/broadcast policy and the Game Bar app as separate things and even lists the Game Bar hotkey values (`VKToggleGameBar` etc.) as independent settings. URL: https://noverse.dev/docs/win-config/privacy/disable-xbox-game-bar/
- The "Shift+G" vs "Win+G" error was already caught by the local validation; noverse's listed default hotkey virtual-key values are consistent with Win+G but he doesn't spell the chord out.

### Network throttling — mechanism and trigger
- **Our claim:** Windows throttles non-multimedia network packet processing to ~10 packets/ms "whenever any multimedia application is running"; documented in "KB 2483177"; doesn't lower ping, no reason to help ordinary UDP games.
- **Noverse position:** **AGREES-WITH-NUANCE** — same default (10), same disable sentinel (0xFFFFFFFF), but his driver-level mechanism corrects two of our phrasings. URL: https://noverse.dev/docs/win-config/system/mmcss-values/
  - The value is the maximum number of received `NET_BUFFER_LIST` structures a miniport may indicate **per receive DPC** — not "packets per millisecond". (Russinovich's 2007 blog says ~10 packets/ms; the driver reality is a per-indication NBL cap. Both describe the same throttle at different abstraction levels.)
  - The throttle is applied only while at least one MMCSS thread with **Scheduling Category Medium or High** is scheduled (`CiScheduledThreadCount` 0→1 sends the cap, 1→0 sends `0xFFFFFFFF`). "Any multimedia application running" is too loose — it must be MMCSS-registered with a Medium/High task.
  - It only works when the miniport supports NDIS Receive Side Throttle (RST, mandatory for NDIS 6.20+); NDIS's own per-processor table caps at 64 NBLs, so the MMCSS value of 10 clamps the RST ladder (1,2,4,8,10,10,…).
  - Clamp behavior from `CiConfigInitialize`: 0 is rewritten to 1, 1–70 pass through, 71–0xFFFFFFFE become 70, 0xFFFFFFFF removes the MMCSS maximum (`NDIS_INDICATE_ALL_NBLS`).
  - Measured caveat matching our "cost" framing: with 0xFFFFFFFF the miniport callback can run inside `ndisInterruptDpc` itself, so ndis.sys DPC execution times go **up** — independently observed by djdallmann (cited in our local validation).
  - Ping/UDP games: nothing in his mechanism would lower server ping; AGREES implicitly.
  - He cites Microsoft's "Receive Side Throttle in NDIS 6.20" doc and `NDIS_RECEIVE_THROTTLE_PARAMETERS`, **not** a KB. (Local validation already found our "KB 2483177" is a wrong citation — correct retired KB is 948066.)

### NetworkThrottlingIndex value — 0xFFFFFFFF disables, default 10
- **Our claim:** `NetworkThrottlingIndex = 0xFFFFFFFF` (disabled; default 10), reboot required.
- **Noverse position:** **AGREES**, verified against mmcss.sys pseudocode and live WinDbg reads (`CiNetworkThrottlingIndex` = 0xA default; 0xFFFFFFFF means the `\Device\Ndis` handle is never even opened). URL: https://noverse.dev/docs/win-config/system/mmcss-values/
- Extra depth worth adopting: valid range is 1–70 (71+ clamps to 70); 0 means 1. Our page states only default and the disable sentinel.

### Cost of disabling — audio glitch on CPU-starved systems
- **Our claim:** on a CPU-starved system under heavy network load, expect audio crackle; revert if heard.
- **Noverse position:** **AGREES.** His explanation of why the throttle exists is the same: receive DPCs run at DISPATCH_LEVEL and long DPCs block threads, harming multimedia playback. He additionally shows *why* DPC time rises with the cap removed (callback folded into the interrupt DPC). URL: https://noverse.dev/docs/win-config/system/mmcss-values/

### SystemResponsiveness — semantics, default 20, we set 10
- **Our claim:** percentage of CPU guaranteed to non-multimedia background work; default 20; script sets 10.
- **Noverse position:** **AGREES**, with the precise mechanism: it splits each `SchedulerPeriod` (default 100000 = 10 ms) into boosted and exhausted slices — exhausted = period × SR/100, boosted = the remainder. During the exhausted slice, MMCSS threads drop to priority 1–7. This matches the Windows Internals "80/20 of 10 ms" description (which he quotes). URL: https://noverse.dev/docs/win-config/system/mmcss-values/

### SystemResponsiveness rounding — multiple of 10, out-of-range → 20, 100 disables MMCSS
- **Our claim:** value rounded down to a multiple of 10; below 10 or above 100 treated as 20; 100 disables MMCSS outright with `STATUS_SERVER_DISABLED`.
- **Noverse position:** **AGREES — exact match, independently derived from pseudocode.** `CiConfigInitialize`: fallback-if-missing is 100; if (value − 10) > 90 unsigned → 20; else `10 * (value/10)`; == 100 → return `STATUS_SERVER_DISABLED` (`-1073741696`) before the Tasks key is even read. This is the strongest possible cross-confirmation of our page's signature claim. URL: https://noverse.dev/docs/win-config/system/mmcss-values/

### MMCSS Games task — Scheduling Category Medium → High
- **Our claim:** raising `Tasks\Games\Scheduling Category` to "High" moves registered threads from the Medium category into High.
- **Noverse position:** **AGREES.** Category priority ranges: Low 8–15, Medium 16–22, High 23–26 (exhausted 1–7); for High, the boosted base is forced to 24 regardless of `Priority`. URL: https://noverse.dev/docs/win-config/system/mmcss-values/
- **Nuance he adds:** the MS-doc line "for High, Priority is always treated as 2" refers only to the *boosted* priority; exhausted priority still derives from `Priority − 1` (clamped to 1). Our page says "ignored whenever Scheduling Category is High, where every task is treated as 2" — correct in effect for the boosted path, slightly overbroad as written.

### GPU Priority / SFIO Priority are inert — not in the binary
- **Our claim:** on build 10.0.26100.8968, `GPU Priority` and `SFIO Priority` strings are absent from mmcss.sys; MS docs say "not yet used"/"not used".
- **Noverse position:** **AGREES, and sharpens it:** he quotes the same MS doc table, then notes that "not used" understates it — the mmcss driver *does not read these values at all*. Same conclusion by the same kind of evidence (driver disassembly vs our string dump). URL: https://noverse.dev/docs/win-config/system/mmcss-values/
- Bonus facts from his task-value notes: `Background Only` is also unused; `Latency Sensitive` (REG_SZ) exists and appears in logging but he found no consumer; `Clock Rate` range 5000–10000 is dead since Win7; `Priority When Yielded` range 1–19, default 16.

### MMCSS is opt-in — many engines never register with "Games"
- **Our claim:** MMCSS reaches only processes calling `AvSetMmThreadCharacteristics` with the "Games" task; many modern engines never do; page ships a PowerShell string check on the game exe.
- **Noverse position:** **AGREES, with a stronger empirical data point:** via `Thread_SetChars`/`Thread_Join` ETW events he reports *"I didn't see any app registering with other tasks than Audio/Pro Audio yet"* — i.e., in his testing nothing registered with the `Games` task at all. He lists the 8 default task profiles (Audio, Capture, Distribution, Games, Playback, Pro Audio, Window Manager, DisplayPostProcessing). URL: https://noverse.dev/docs/win-config/system/mmcss-values/

### Never restart the MMCSS service — kernel driver, profiles cached at load, STOP_PENDING/1056
- **Our claim:** since Win10 MMCSS is a kernel driver; task profiles cached at load; changes need reboot; stopping the service hangs in STOP_PENDING, next start fails 1056, new registrations fail machine-wide until reboot.
- **Noverse position:** **AGREES-WITH-NUANCE / partially NOT-COVERED.** He confirms task keys are read once in `CiConfigInitialize` at driver config init (and skipped entirely when SystemResponsiveness == 100), which is consistent with reboot-required. He does not discuss the service-stop failure mode (STOP_PENDING / error 1056) anywhere — that part remains our original contribution, unverified by noverse but uncontradicted.

### "What is left out" pointers (DataQueueSize, HPET/dynamic tick, long quantum, Win32PrioritySeparation)
- **Our claim:** these are debunked / covered elsewhere on our site.
- **Noverse position:** not a tweak claim, but relevant cross-checks exist: his timer-expiration and priority-separation pages document why "server-style" timer tweaks do little on clients and that `disabledynamictick` can break quantum expiration on pre-24H2 — consistent with our debunking posture. URLs: https://noverse.dev/docs/win-config/system/timer-expiration/, https://noverse.dev/docs/win-config/system/priority-separation/

## Improvements to adopt

1. **Fix the network-throttling trigger wording.** Replace "whenever any multimedia application is running" with: the cap is applied by MMCSS only while at least one registered MMCSS thread in a Medium or High scheduling category is active, and lifted when the count returns to zero. Source: https://noverse.dev/docs/win-config/system/mmcss-values/
2. **State the unit correctly and add the clamp table.** `NetworkThrottlingIndex` caps received `NET_BUFFER_LIST` structures per receive DPC (default 10); valid range is 1–70 (higher values clamp to 70, 0 becomes 1), and 0xFFFFFFFF removes the cap entirely. The effect also requires the NIC's miniport driver to support NDIS Receive Side Throttle. Source: https://noverse.dev/docs/win-config/system/mmcss-values/
3. **Fix the citation.** Drop "KB 2483177" (a Media Foundation codec hotfix — wrong). Cite Microsoft's "Receive Side Throttle in NDIS 6.20" documentation / `NDIS_RECEIVE_THROTTLE_PARAMETERS` as noverse does, and/or the retired KB 948066 via archive. Sources: https://noverse.dev/docs/win-config/system/mmcss-values/ + local validation findings.
4. **Add the DPC-cost mechanism to the "What it costs" note:** with the cap removed, the miniport's receive callback can run inline inside `ndisInterruptDpc`, so ndis.sys DPC execution time rises — this is the mechanism behind both the audio-crackle risk and independent measurements showing higher NDIS DPC latency after disabling. Source: https://noverse.dev/docs/win-config/system/mmcss-values/
5. **Enrich the SystemResponsiveness section with the period math:** the value splits each scheduler period (default 10 ms) into a boosted slice and an exhausted slice (exhausted = period × value/100; during it, MMCSS threads fall to priority 1–7). Setting 10 = 1 ms exhausted / 9 ms boosted per 10 ms period. Also note: at 100, mmcss returns `STATUS_SERVER_DISABLED` before even reading the Tasks key — so `Tasks\Games` edits are doubly inert on such a system. Source: https://noverse.dev/docs/win-config/system/mmcss-values/
6. **Tighten the "Priority treated as 2" sentence:** that rule applies to the boosted priority only; the exhausted priority still derives from `Priority` (stored as value − 1, clamped to 1). For High category the boosted base is forced to 24 (range 23–26 with relative priority). Source: https://noverse.dev/docs/win-config/system/mmcss-values/
7. **Strengthen the opt-in caveat with noverse's observation:** in his ETW tracing he never saw any application register with tasks other than Audio/Pro Audio — no observed `Games`-task registrant at all. Good supporting evidence for our exe-string check. Source: https://noverse.dev/docs/win-config/system/mmcss-values/
8. **Consider documenting the extra per-user capture value** `HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR\AppCaptureEnabled` alongside `GameDVR_Enabled` (his inventory shows the capture stack reads both hives). Source: https://noverse.dev/docs/win-config/privacy/disable-xbox-game-bar/
9. **Add a cross-link to Game Mode side-effects** near the Game DVR section: same policy key family; Game Mode registration is gated by `AllowAutoGameMode` / `AutoGameModeEnabled`, and Game Mode itself has measurable downsides (blocks the foreground priority boost on 23H2, forces games out of REALTIME_PRIORITY_CLASS to NORMAL, power profile is a no-op when the active scheme is already High performance). Source: https://noverse.dev/docs/win-config/system/game-mode/

## Gaps noverse covers that we don't

- Other real MMCSS `SystemProfile` values with verified ranges: `NoLazyMode`, `IdleDetectionCycles` (1–31), `LazyModeTimeout`, `SchedulerTimerResolution` (capped at 10000), `SchedulerPeriod` (50000–1000000), `MaxThreadsPerProcess` (8–128), `MaxThreadsTotal` (64–65535); MMCSS scheduler thread runs at priority 27. https://noverse.dev/docs/win-config/system/mmcss-values/
- MMCSS lazy-mode / idle-detection machinery (`CiProcessorIdleHistoryBits`, sleep reasons Realtime/SleepResponsiveness/IdleDetection/DeepSleep) — explains why MMCSS cost is near-zero when idle. https://noverse.dev/docs/win-config/system/mmcss-values/
- Task-value dead knobs beyond GPU/SFIO Priority: `Background Only` unused, `Latency Sensitive` unread, `Clock Rate` dead since Win7, `Priority When Yielded` (1–19). https://noverse.dev/docs/win-config/system/mmcss-values/
- Full Game DVR / Game Bar value inventory (bitrate/resolution/framerate modes, historical buffer length, mic/system gain, hotkey VK codes). https://noverse.dev/docs/win-config/privacy/disable-xbox-game-bar/
- Game Mode end-to-end reverse engineering (registration via twinui.pcshell BroadcastDVRComponent, WNF_RM_GAME_MODE_ACTIVE state, CPU-set policy never observed applying, GPU yield/budget defaults 2/50/30, WNF_SEB_GAME_MODE power profile). https://noverse.dev/docs/win-config/system/game-mode/
- Timer-expiration kernel values (`SerializeTimerExpiration`, `EnablePerCpuClockTickScheduling`, 25H2 decoupling) — background for our debunked-timers page. https://noverse.dev/docs/win-config/system/timer-expiration/
- `disabledynamictick` quantum-expiration bug + 24H2 ClockTickIdleEstimateFix — background for our debunked page. https://noverse.dev/docs/win-config/system/priority-separation/

## Conflicts needing a decision

- **"Packets per millisecond" vs "NBLs per receive DPC":** Russinovich (2007) says the throttle is ~10 packets/ms; noverse's mmcss.sys pseudocode says the value is a max-NBLs-per-receive-indication cap with no time unit (Period is set to −1). These are reconcilable (Russinovich describes the observed effect at Vista-era DPC cadence; the driver implements a per-DPC count cap), but our page currently states the Russinovich framing as the mechanism. Recommend adopting noverse's driver-level description and citing Russinovich only as historical context. Not a true factual conflict — an abstraction-level fix.
- **KB citation:** our page cites KB 2483177; local validation proved that KB is an unrelated H.264 codec fix, and noverse conspicuously cites no KB at all (he uses current MS NDIS docs). Correct KB is the retired 948066. Decision: replace citation; no conflict on the technical facts.
- **"Whenever any multimedia application is running"** (ours) vs "only while MMCSS Medium/High threads are scheduled" (noverse, from `CiScheduledThreadCount` logic, corroborated by live WinDbg captures showing the throttle inactive with zero scheduled threads). Noverse's evidence is disassembly + live kernel state; ours is uncited loose phrasing. Recommend adopting noverse's version.
- No disagreements found on SystemResponsiveness rounding/disable behavior, the inert GPU/SFIO Priority values, or the Games task category mechanics — noverse independently confirms all three.
