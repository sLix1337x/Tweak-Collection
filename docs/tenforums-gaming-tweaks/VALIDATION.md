# TenForums gaming-tweaks thread — validation against Windows 11 25H2

Validated **2026-09-06**. Source material: the five extracted pages in this folder,
covering the TenForums thread *"Share gaming tweaks, check my comprehensive list
will blow your mind"* (empleat, Sep 2018 – Aug 2023).

**Scope note.** The thread is a Windows 10 document written between 2018 and 2023,
mostly by one input-lag-focused author who repeatedly flags his own claims with
"test it yourself", "no idea if this is true" and "could be a habit". A large part
of it was already anecdotal when written. This pass separates what is still true
on Windows 11 24H2/25H2 from what has expired, what was never true, and what can
stop a machine booting.

Verdict vocabulary follows the site's
[debunked page](../src/content/docs/reference/debunked/index.mdx):
**Invalid** (does nothing), **Placebo** (real setting, no measurable effect),
**Harmful**, **Dangerous** (can prevent boot or damage hardware), **Situational**,
**Unproven**, **Superseded**, **Holds up**.

---

## 1. Headline verdict

Of roughly 200 distinct claims, **about a dozen still hold up on Windows 11**, and
most of those are already covered by this site with better sourcing. The bulk of
the thread fails for one of five reasons:

| Failure mode | Examples |
| --- | --- |
| **The mechanism was removed or replaced** | DWM disabling, Cortana policy, per-process timer resolution, `DefaultMediaCost` |
| **Microsoft explicitly labels it a debugging flag** | `useplatformclock`, `useplatformtick`, `disabledynamictick`, `tscsyncpolicy` |
| **The value sets its own default** | `bcdedit /set MSI Default`, `x2apicpolicy Enable` |
| **It was never read by anything** | `IRQ#Priority` |
| **It is anecdotal with no proposed mechanism** | English (Philippines) display language, "combine taskbar buttons never", "scroll inactive windows" |

Four things in the thread are **dangerous** and are listed separately in §6.

The thread also has a structural blind spot that matters more than any individual
error: **it predates VBS/HVCI being on by default, and predates anti-cheat
requiring TPM, Secure Boot and IOMMU.** Its entire security-off posture —
mitigations off, SGX off, `isolatedcontext No` — is now the single most likely way
to make a competitive machine unable to launch the game it was tuned for. See
[CS2 → System & driver](../src/content/docs/cs2/system.md) and
[Security](../src/content/docs/guides/security.md).

---

## 2. What changed under the thread since it was written

These platform changes each invalidate a block of the guide at once.

1. **Timer resolution became per-process in Windows 10 2004.** A process asking for
   1 ms gets 1 ms; it no longer drags the system. This removes the premise of the
   thread's flagship ISLC-forces-1 ms tweak and of "Chrome forces 0.5 ms on you".
   Global behaviour now requires the undocumented `GlobalTimerResolutionRequests`
   value, which the thread does not know about.
2. **DWM cannot be disabled on modern Windows.** The thread's own author marked his
   `.reg` OUTDATED and acknowledged it breaks on 1903+; three later posters still
   asked for the script. On Windows 11 the answer is simply no.
3. **VBS / Memory Integrity ship enabled** on clean installs meeting the hardware
   bar. Nothing in the thread accounts for the largest single software cost on a
   modern gaming machine.
4. **Anti-cheat now requires the things the thread turns off.** TPM 2.0 and Secure
   Boot are mandatory on FACEIT; IOMMU and VBS have rolled out to effectively the
   whole player base. "Disable Intel MEI", "disable SGX", `isolatedcontext No` are
   now platform-compatibility decisions, not latency decisions.
5. **Cortana was removed** (deprecated June 2023, app removed from Windows 11 builds
   during 2023). `AllowCortana` targets a product that is gone.
6. **`DefaultMediaCost` is reportedly no longer honoured**; metering now lives in
   the Data Usage Subscription Management service (`DusmSvc\Profiles\<GUID>\UserCost`)
   or the Settings toggle / Windows Connection Manager policy.
7. **Memory compression is enabled by default on Windows 11 client.** The thread
   asserts it "should be False" and that it is "disabled by default on 20H2" —
   wrong then, wrong now. It is off by default only on Server.
8. **MPO needs two values on 24H2+.** The thread predates `OverlayMinFPS`; so did
   this site until this week. See
   [the driver guide](../src/content/docs/guides/nvidia-driver-install.md).
9. **Sub-tick replaced the CS:GO netcode model.** Every CS:GO-era rate/interp
   reference in the thread is dead. See
   [CS2 → Game settings](../src/content/docs/cs2/game-settings.md).

---

## 3. Claim-by-claim — boot configuration (`bcdedit`)

The thread's page 5 set (trebleta, quoting "melody") is the most technical block in
it and the one that fails hardest. Checked against Microsoft's own
[BCDEdit /set reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/bcdedit--set).

| Claim | Verdict | Finding |
| --- | --- | --- |
| `bcdedit /set MSI Default` | **Invalid** | Microsoft documents `msi [Default \| ForceDisable]`. `Default` *is* the default. The command writes the stock value and changes nothing. It is in the list because it looks like it enables MSI mode; it does not — MSI mode is a per-device registry setting, which the thread separately (and correctly) describes. |
| `bcdedit /set x2apicpolicy Enable` | **Invalid / Placebo** | Documented: "The system defaults to using extended APIC mode if it is available." On hardware that supports x2APIC it is already on; on hardware that does not, the flag cannot conjure it. |
| `bcdedit /set usephysicaldestination No` | **Placebo** | Documented as "Forces the use of the physical APIC" — `No` is the non-forcing state, i.e. stock. |
| `bcdedit /set usefirmwarepcisettings No` | **Situational, historically a troubleshooting flag** | Documented: "Enables or disables the use of BIOS-configured PCI resources." Setting `No` tells Windows to re-enumerate rather than trust firmware assignment. It is a compatibility knob, not a latency one, and no source ties it to input lag. |
| `bcdedit /set configaccesspolicy Default` | **Invalid** | Not in Microsoft's reference. `Default` is again the default value; writing it is a no-op even if the element is real. |
| `bcdedit /set tscsyncpolicy Enhanced` | **Unproven, debugging-only** | Documented — and the documentation says in full: "Controls the times stamp counter synchronization policy. **This option should only be used for debugging.**" The circulating folklore ("Enhanced improves FPS but worsens input lag, Legacy the reverse") has no documented mechanism. On any CPU with invariant TSC — everything modern — expect nothing. The thread's own poster hedged it as "yet not 100%". |
| `bcdedit /set useplatformtick true` | **Harmful / debugging-only** | Documented: "Forces the clock to be backed by a platform source, no synthetic timers are allowed… This option should only be used for debugging." Extended community testing associates it with input lag. The thread recommends it *and* elsewhere warns it "can cause input lag — test it", which is the thread arguing with itself. |
| `useplatformclock` (HPET forcing) | **Harmful** | Same debugging-only note in Microsoft's docs. Forcing HPET as the system counter adds latency per timer read. The thread gets the *conclusion* right ("best to remove entirely and let Windows choose") while still listing it. Already on [debunked: scheduler](../src/content/docs/reference/debunked/scheduler.md). |
| `bcdedit /set disabledynamictick yes` — the author's flagship tweak | **Unproven / debugging-only** | Documented, with the same debugging-only caveat. Two independent problems with the claim: the stated mechanism ("dynamictick drops the timer to 15.6 ms and makes the mouse feel like it accelerates") conflates tickless idle with timer resolution, which are different things; and on thermally constrained systems the extra wake-ups reduce sustained clocks. There is also a real interaction the thread does not know about: on pre-24H2 builds, `disabledynamictick true` can break quantum expiration entirely, because with the clock stopped the kernel never sets `QuantumEnd`. 24H2 masks it with a servicing fix. |
| `bcdedit /set allowedinmemorysettings 0x0` | **Dangerous — see §6** | Not documented by Microsoft. Community reverse-engineering says the stock value is `0x15000075`. Boot-loops if Intel SGX is enforced in firmware, as the thread itself warns. |
| `bcdedit /set isolatedcontext No` | **Dangerous — see §6** | Not documented by Microsoft. Strips a loader hardening context. Bundled in the same tweak packs as `vsmlaunchtype Off`, `hypervisorlaunchtype off` and `nx alwaysoff` — i.e. it is part of a security-off bundle, not a performance setting. |

**Net:** of eleven BCD items, **four write their own default, four are labelled
debugging-only by Microsoft, and two are undocumented security removals.** None has
a published measurement behind it.

---

## 4. Claim-by-claim — registry and memory

| Claim | Verdict | Finding |
| --- | --- | --- |
| `IRQ#Priority` under `Control\PriorityControl` (author: "CMOS=1, GPU=2") | **Invalid** | The value is not read by the kernel. String analysis of the kernel binaries finds no such value; there is some evidence it did something in NT 3.x and it was dropped shortly after. The author's own report — "feels snappier but aim is trash" — is a description of noise. The documented mechanism for what he wanted is `DevicePriority` and interrupt affinity policy, which the thread also mentions. |
| `Win32PrioritySeparation` = `0x18` (smirk24) or `40` (empleat, "hex?") | **Unproven, and the units are guessed** | The author literally writes "(hex?)". `0x18` = decimal 24 = the value the Performance Options dialog writes for "Background services". `40` decimal = `0x28`, which is not a profile anyone recommends. The site has [a whole page](../src/content/docs/reference/win32priorityseparation.md) on this, including the decimal/hex trap that makes most advice about it backwards. |
| `DisablePagingExecutive = 1` (with MaloK's page-3 correction) | **Placebo → Harmful** | The correction is right about the *value* — 1 keeps the kernel resident — and wrong about it being desirable. It reduces memory available to games. Already on [debunked: storage and memory](../src/content/docs/reference/debunked/storage-and-memory.md). |
| `LargeSystemCache = 1` (smirk24) | **Harmful** | Server-oriented; fills standby with file cache instead of game assets. empleat disputes it in-thread for the wrong reason ("wears down your SSD"), but lands on the right answer. |
| `EnablePrefetcher = 0` + disable SysMain | **Harmful on Windows 11** | smirk24 partially recants in-thread. The decisive fact neither poster had: **disabling SysMain also disables memory compression and page combining**, because SysMain hosts the MMAgent configuration path. Covered on [services](../src/content/docs/tweaks/services.mdx). |
| "Memory compression should be False / disabled by default on 20H2" | **Wrong** | Enabled by default on Windows 11 client; disabled by default only on Server. Check with `Get-MMAgent`. |
| ISLC to force 1 ms timer resolution | **Superseded** | Timer resolution has been per-process since Windows 10 2004. A global forcing tool does nothing unless `GlobalTimerResolutionRequests` is set, which the thread never mentions. Its second function — standby-list purging — is a diagnosed-symptom tool, and the thread's own reports of it *causing freezes on every purge* are consistent with purging the whole list at once. |
| `MouseDataQueueSize = 25` | **Invalid** | A buffer depth in packets, not a polling interval and not a delay. Already on [debunked: scheduler](../src/content/docs/reference/debunked/scheduler.md) and [input](../src/content/docs/guides/input.md). |
| Delete `SmoothMouseXCurve` / `SmoothMouseYCurve` | **Contradicted in-thread, correctly** | Rezler catches it on page 1: the guide says delete the curves *and* recommends the MarkC fix, which works by editing those same curves. Both cannot be right. |
| `LanmanServer\Parameters\Size = 3` | **Placebo for gaming** | A file-sharing throughput hint. Irrelevant to a client that is not serving SMB. |
| `AllowCortana = 0` | **Invalid** | Cortana was deprecated in June 2023 and removed from Windows 11 builds during 2023. The policy targets a product that is not installed. |
| `DefaultMediaCost` Ethernet = 2 to defer updates | **Invalid on current builds** | Reportedly no longer honoured; metering moved to `DusmSvc` profiles, the Settings toggle, or the Windows Connection Manager policy. |
| `ExcludeWUDriversInQualityUpdate = 1`, `SearchOrderConfig = 0`, `DenyUnspecified`, `DisableCoInstallers` | **Holds up, partially** | The first is still a supported policy on Pro and above (Home is not listed as supported), documented in the Update Policy CSP. Caveat the thread does not give: it excludes drivers from *quality updates* and does not stop every path — vendor utilities, device setup and optional driver updates still install. Some OEM machines ship with it already enabled. |
| `Auditpol /set /category:* /Success:disable` | **Placebo** | Real command, real effect on the event log. No path to frame times or input latency. |
| `UserPreferencesMask` all zeros | **Situational, cosmetic** | Real value; disables leftover animation/visual behaviours. It is a preference, and the author himself notes some bits no longer apply on newer builds. |
| `Win8DpiScaling = 1` ("should help a lot", marked major) | **Placebo, with a real cost** | The value is real: it is the Windows 8.1 "let me choose one scaling level for all my displays" checkbox, paired with `LogPixels`. What it does is force *legacy system-wide* DPI scaling instead of per-monitor. That greys out Scale & Layout in Settings and bitmap-stretches non-DPI-aware apps — the classic blurry-text symptom. There is no latency mechanism, and the modern equivalent lives in `PerMonitorSettings\<display>\DpiValue`. |
| System Restore off via `DisableConfig` / `DisableSR` | **Situational, and a bad trade here** | Real policy. But this thread recommends BCD edits that can boot-loop a machine; turning off the recovery mechanism first is the wrong order of operations. |

---

## 5. Claim-by-claim — hardware, drivers and the rest

### Genuinely correct, and worth keeping

| Claim | Note |
| --- | --- |
| **Bad DisplayPort cables can damage a GPU** | The thread's most surprising claim is **true**. Pin 20 is DP_PWR; the VESA spec says it must not be wired source-to-sink. Non-compliant cables feed 3.3 V back into the GPU, which Dell documents as a cause of graphics-card failure and which VESA confirmed after buying non-certified cables and finding an alarming number improperly configured. Modern cards mostly include protection, and the issue is largely historical after ~2017, but the mechanism is documented and the advice ("buy a certified cable") is correct. |
| **MSI mode on the wrong device can make a PC unbootable** | Correct, and correctly flagged. The site says the same on [NVIDIA](../src/content/docs/tweaks/nvidia.mdx). |
| **Don't use `msconfig` for services; use Autoruns** | Correct, and matches [services](../src/content/docs/tweaks/services.mdx). |
| **Don't use CCleaner for registry cleaning** | Correct. |
| **Disable NIC power management** | Correct; [net.adapter-powersave-off](../src/content/docs/tweaks/network.mdx). |
| **Mouse: 6/11 pointer speed, Enhance pointer precision off** | Correct; [input](../src/content/docs/guides/input.md). |
| **Rear USB ports, no hubs** | Correct; same page. |
| **Ultimate Performance plan, USB selective suspend off, PCIe ASPM off** | Correct; [power](../src/content/docs/tweaks/power.mdx) covers all three with the mechanism. |
| **`powercfg -h off` disables Fast Startup** | Correct, but a heavier hammer than needed — `HiberbootEnabled = 0` is the targeted version, and `/h off` also takes hybrid sleep. |
| **Wait two weeks before installing a new driver** (empleat, page 3) | Good practice, and the 2025–2026 regression record supports it. Now stated on [CS2 → Measuring](../src/content/docs/cs2/measuring.md). |
| **CountMike's thermal post (page 3)** | The best technical content in the whole thread and the only part with measured numbers: boost clock falling 50–100 MHz per °C above 70 °C on a 3700X, VRM throttling, RAM airflow under an AIO, and 3600 CL16 vs 2133 CL14 being worth 15–20 % on Ryzen. This is consistent with everything on [CS2 → System](../src/content/docs/cs2/system.md) about thermals setting the frametime floor. |
| **"Tweaks are polish, not magic"** (TairikuOkami, page 3) | The thread's own best summary, and it argues against most of the thread. |

### Wrong, and worth stating why

| Claim | Verdict | Finding |
| --- | --- | --- |
| "Do not install Intel Chipset INF drivers — huge input lag, can't be uninstalled without reinstalling Windows" | **Harmful advice** | Chipset INFs are identification packages that tell Windows what the platform devices are. Skipping them leaves devices on generic drivers or unenumerated. The author concedes in the same paragraph that *not* updating the PCIe controller also caused him lag — which is the actual answer. |
| "Do not install Intel SATA drivers — 2006 Microsoft drivers benchmark at full speed" | **Harmful** | Storage driver choice affects AHCI link power management and NVMe behaviour. "Benchmarks at full speed" is a throughput claim used to justify a latency decision. |
| "Disable Intel MEI (spy engine), causes lag" | **Harmful / now a compatibility problem** | MEI underpins firmware TPM on Intel platforms. On a machine that needs TPM 2.0 for anti-cheat, this is not a free choice. |
| "Disable USB 3 entirely — causes huge lag"; "PS/2 has lower lag" | **Harmful, and stale** | The USB 3 claim is attributed to a forum personality with no measurement. PS/2 vs USB was a real argument at 125 Hz polling; at 1000 Hz the difference is inside the noise, and the modern input-latency limit for CS2 is the game's own [lock contention per raw-input read](../src/content/docs/cs2/game-settings.md#input). |
| "Interrupt affinity: everything on core 0 felt best" | **Backwards** | Windows concentrates its own housekeeping interrupts on CPU 0. Steering device interrupts *onto* it is the documented wrong direction; the guidance is to keep IRQs off the cores the game uses and off CPU 0. |
| "Setting affinity on disks can damage your PC" | **Invalid** | Interrupt affinity is a scheduling hint. It cannot damage hardware. |
| "Never use V-Sync" | **Inverted for VRR** | With G-Sync or FreeSync active, control-panel V-Sync is the range ceiling guard, not a pacing mechanism. Turning it off is the popular mistake. See [CS2 → The frame cap](../src/content/docs/cs2/frame-cap.md). |
| "In-engine FPS limiter is best; RTSS nearly lagless" | **Half right, and the wrong half matters** | Measured comparison at an identical cap puts RTSS Async ahead of the in-game limiter on 0.1 % lows and well ahead of the driver limiter, at ~0.1 ms more latency. "Nearly lagless" is right; "in-engine best" is not, for the metric this thread claims to care about. |
| "Disable all C-States" | **Inverted on AM5 X3D** | The documented fix for micro-stutter there is setting Global C-State Control explicitly to **Enabled**, because "Auto" silently means Disabled on many boards. Blanket-disabling also kills turbo on locked CPUs. |
| "Disable Hyper-Threading in BIOS" | **Right idea, wrong implementation** | CS2 is a genuine case where excluding SMT siblings helps some machines — but as a per-process affinity rule, not a BIOS switch that removes the threads for everything else. |
| "Turn off disk after = 0, otherwise damages SSD" | **Right setting, invented reason** | `0` means *never* turn the disk off, which is correct for latency. It does not protect the SSD from anything; the reasoning is backwards from the setting. |
| "Set audio to 16-bit 44100 Hz — higher sampling adds input lag" | **Placebo** | Disputed in-thread by Rezler and correctly. Sample rate is not latency; buffer size is. The site's [audio guide](../src/content/docs/guides/audio.md) says match the source rather than maximise or minimise it. |
| "Ultra Low Latency is counterproductive below 99 % GPU load" | **Holds up** | This one is right and better-reasoned than most of the thread: Reflex and low-latency modes drain a render queue, and a CPU-bound game has no queue to drain. |
| "Windows display language English (Philippines) lowers input lag" | **Placebo** | No mechanism proposed, no measurement, and the page-3 discussion is an attribution argument between two forum users about who found it first. |
| "Correctly synchronised time reduces input lag" | **Placebo** | The author flags his own uncertainty; smirk24's reaction in-thread is "??? LOL". |
| "Combine taskbar buttons = never seems to reduce input lag"; "keep scroll-inactive-windows enabled or the mouse feels heavy"; "killing explorer.exe helps" | **Placebo** | All three are stated as feel, all three are contradicted by the author elsewhere on the same page. |
| "Disable the HID service — HID = huge lag" | **Harmful** | Breaks media and special keys, and on some configurations input device enumeration. Already on [input → what does not work](../src/content/docs/guides/input.md). |
| "NVIDIA GPU scaling gave +50 FPS average" | **Unverifiable** | Display-versus-GPU scaling changes where the scaler runs. It does not produce 50 frames. No capture accompanies the claim. |
| "Hone Optimizer is likely a scam" (empleat's own flag) | **Reasonable caution, correctly reasoned** | "2× FPS boost from average reviews" is the tell, and the site's position on unverifiable one-click optimisers is the same. |
| Custom ISOs — ReviOS, Ghost Spectre, NTLite | **Situational, now with an anti-cheat conflict** | The thread's own caveats (reduced security, reinstall after every update) are correct as far as they go. What has changed: stripped images break the components anti-cheat platforms check. |

---

## 6. The dangerous four

These are the items that can leave a machine unbootable or a component damaged.
They are called out here because the thread mixes them in with cosmetic tweaks.

1. **`bcdedit /set allowedinmemorysettings 0x0`** — the thread's own warning is
   accurate: boot crash or boot loop if Intel SGX is enforced in firmware rather
   than "Application Controlled" or "Off". Undocumented by Microsoft, stock value
   reported as `0x15000075`. If you have already applied it and the machine boots,
   the way back is `bcdedit /deletevalue allowedinmemorysettings`. **Take a BCD
   export first** (`bcdedit /export C:\bcdbackup`) — this thread recommends
   disabling System Restore in the same document.
2. **MSI mode on the wrong device** — correctly flagged by the thread. Enabling it
   on a storage or chipset device that does not support it can prevent boot, and
   the recovery is Safe Mode. The site's version is on
   [NVIDIA](../src/content/docs/tweaks/nvidia.mdx).
3. **Disabling drivers at boot via Autoruns** — the thread flags it and then
   recommends it anyway, alongside a report of someone disabling a storage driver
   and losing the system. Same class of failure, no Safe Mode guarantee if the
   driver is the storage stack.
4. **Non-compliant DisplayPort cables** — the one *hardware* danger in the thread,
   and the one it is right about. Pin 20 backfeed is documented by Dell and
   acknowledged by VESA.

A fifth, softer one: **disabling DWM.** It cannot be done on current Windows, the
scripts that claim to do it break shell functionality, and the thread's own
practitioner ships a `Revert.bat` because of it.

---

## 7. What, if anything, should reach the site

Almost nothing new. The thread's correct material is already covered here with
better sourcing, and its novel material is either anecdotal or expired. Three
candidates, in descending order of value:

1. **The `bcdedit` debunk block is worth publishing.** The site's
   [debunked: scheduler](../src/content/docs/reference/debunked/scheduler.md) page
   covers HPET and dynamic tick, but not the newer BCD bundle now circulating in
   tweak packs — `MSI Default`, `x2apicpolicy Enable`, `configaccesspolicy Default`,
   `usephysicaldestination No`, `tscsyncpolicy Enhanced`, `allowedinmemorysettings 0x0`,
   `isolatedcontext No`. The finding that **four of them write their own documented
   default and four are labelled debugging-only by Microsoft** is a clean, checkable
   debunk of a whole genre, and the SGX boot-loop interaction is a real safety note.
   This is the strongest reason to have read the thread.
2. **`IRQ#Priority`** deserves a one-line entry: it is still copied around, and
   "the kernel does not read this value" is exactly the kind of verdict this site
   exists to record.
3. **The DisplayPort pin-20 note** fits the BIOS/hardware pages as a
   two-sentence aside — it is the rare tweak-forum claim that turns out to be a real
   documented hardware fault mode.

Not worth adopting: everything in §5's "wrong" table is already contradicted by
existing pages, and adding rebuttals to claims nobody is repeating in 2026 would
grow the debunked list without helping a reader.

---

## 8. Sources consulted for this pass

- [BCDEdit /set reference](https://learn.microsoft.com/en-us/windows-hardware/drivers/devtest/bcdedit--set) — Microsoft. Authoritative for `msi`, `x2apicpolicy`, `usephysicaldestination`, `usefirmwarepcisettings`, `tscsyncpolicy`, `useplatformclock`, `useplatformtick`, `disabledynamictick`, including the "debugging only" notes.
- [Elements in the bcdedit](https://answers.microsoft.com/en-us/windows/forum/all/elements-in-the-bcdedit/d48287af-7980-4c13-aa06-372729870d2d) — Microsoft Q&A, for the undocumented `allowedinmemorysettings` / `isolatedcontext` pair.
- [tscsyncpolicy discussion](https://forums.blurbusters.com/viewtopic.php?t=8890) — Blur Busters, for the circulating Enhanced/Legacy folklore.
- [IRQ Priority Tweak =FAKE= WARNING](https://forums.guru3d.com/threads/irq-priority-tweak-for-agp-card.137634/) — Guru3D, and [Increase priority of Select Hardware using IRQs](https://notes.ponderworthy.com/Increase+priority+of+Select+Hardware+in+Windows+using+IRQs+and+Registry+Edits), for the `IRQ#Priority` string analysis.
- [The 20th Pin is Not Wired on Dell DisplayPort Cables](https://www.dell.com/support/kbdoc/en-us/000132935/the-20th-pin-is-not-wired-on-dell-displayport-cables) — Dell, and [DisplayPort Pin 20 Issue](https://www.cablewholesale.com/blog/index.php/2021/12/29/displayport-pin-20-issue-avoid-graphics-card-damage/), for the pin-20 failure mode and VESA's cable findings.
- [DPI-related APIs and registry settings](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/dpi-related-apis-and-registry-settings?view=windows-11) — Microsoft, for `Win8DpiScaling` / `LogPixels` / `PerMonitorSettings`.
- [Enable or Disable Memory Compression in Windows 10 and Windows 11](https://www.elevenforum.com/t/enable-or-disable-memory-compression-in-windows-10-and-windows-11.3555/), for the client-versus-server default.
- [Microsoft is deprecating Cortana on Windows 11](https://www.windowscentral.com/software-apps/microsoft-kills-cortana-with-update-though-you-still-have-some-time-left-with-the-assistant) and [Microsoft officially removes Cortana for Windows 11 Insiders](https://www.bleepingcomputer.com/news/microsoft/microsoft-officially-removes-cortana-for-windows-11-insiders/), for the Cortana timeline.
- [Configure GPO to turn off metered network connection on Ethernet](https://learn.microsoft.com/en-us/answers/questions/262724/configure-gpo-to-trun-off-metered-network-connecti) and [Metered connections in Windows](https://support.microsoft.com/en-us/windows/experience/connectivity-networking/metered-connections-in-windows), for `DefaultMediaCost` no longer being honoured.
- [Does ExcludeWUDriversInQualityUpdate come enabled by default on Windows 11 Pro?](https://learn.microsoft.com/en-us/answers/questions/5615022/does-the-group-policy-excludewudriversinqualityupd) and [Enable or Disable Include Drivers with Windows Updates in Windows 11](https://www.elevenforum.com/t/enable-or-disable-include-drivers-with-windows-updates-in-windows-11.2232/), for the driver-update policy's current status and limits.
- Internal: `docs/research/CS2_Windows11_25H2_Deep_Optimization_Research.md`, `docs/nohuto-improved/*`, and the site's existing debunked pages.
