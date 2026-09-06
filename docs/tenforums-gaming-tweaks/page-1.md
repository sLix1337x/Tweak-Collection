# TenForums Gaming Tweaks — Page 1

Source: https://www.tenforums.com/gaming/117377-share-gaming-tweaks-chec-my-comprehensive-list-will-blow-your-mind.html

Page 1 contains the massive original post by **empleat** (started 06 Sep 2018, heavily edited through 2022) — a comprehensive input-lag/latency-focused tweak guide — plus 9 replies, including notable pushback from **Faith** and **Rezler**. The guide's own legend: `[major, minor]` = effectiveness; the author is input-lag obsessed (claims ability to discern ~6 ms differences). Almost everything below is from empleat unless noted. Many claims are anecdotal ("feels better"); treat accordingly.

## Power plans & power-management commands

- **Enable the "Ultimate Performance" power plan** (elevated cmd): `powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61`. Claimed lowest input lag; check CPU temps first.
- **Expose "Processor idle disable" (idle saver) setting**: `powercfg -attributes SUB_PROCESSOR 5d76a2ca-e8c0-402f-a133-2158492d58ad -ATTRIB_HIDE` (use `+ATTRIB_HIDE` to re-hide). Setting "Processor idle disable" keeps the CPU in C0 at 100% — only with good cooling; verify with perfmon (C1 time and idle time = 0).
- **Expose DIPM/HIPM disk setting**: `powercfg -attributes SUB_DISK 0b2d69d7-a2a1-449c-9680-f91c70521c60 -ATTRIB_HIDE`, then set to "active" to prevent disk power-saving. HIPM/DIPM (AHCI link power management) *can cause stutter* — enable per-power-plan only (see https://www.tenforums.com/tutorials/72971).
- Power plan details: under Ultimate Performance disable USB selective suspend; set "turn off disk after" to 0 ("otherwise damages SSD" per author); PCI Express link-state power management to Off; WiFi to maximum performance.
- **Disable hibernation / fast startup**: `powercfg -h off` (elevated) — removes hiberfil.sys and disables fast startup.
- For power *saving* (author's later 2022 focus): Balanced plan with Minimum Processor State 5%, PCI-E link speed to Auto in BIOS, cap FPS with RTSS/MSI Afterburner (claims 158 W → 78 W GPU draw in single-player games), undervolt GPU via Afterburner curve, Intel Speed Shift on (Speed Step off), SVID "best case", lowest LLC, hardware-accelerated GPU scheduling on, Resizable BAR on Intel 10th gen+.
- Warning: do NOT set "Prefer maximum performance" globally in NVCP if you want GPU to downclock at desktop.
- Tool: **PowerSettingsExplorer** (guru3d thread, "Windows power plan settings explorer utility", https://forums.guru3d.com/threads/windows-power-plan-settings-explorer-utility.416058/) — edit hidden power-plan settings.
- Tool: **Process Lasso** (bitsum.com) — dynamic power-plan switching (game vs desktop), ProBalance, CPU affinity for services, "induce performance mode" per app, memory priorities (author notes memory priority 0 is broken, use 1); **ParkControl** (bitsum.com/parkcontrol) — per-plan CPU core parking (set everything 100%/disabled for gaming plan).

## Monitor / display

- **Do not use the DisplayPort cable shipped with the monitor** — author claims bad bundled DP cables "can destroy GPU"; buy any certified DP cable from displayport.org-certified makers.
- OSD settings: sharpness 0% ("adds tons of lag"), disable DDC/CI, set scaling to "none/normal" (no monitor-side scaling).
- "1 ms GtG" marketing is meaningless; check input-lag (signal processing) tests at tftcentral.co.uk. Recommendations of the era: ≥144 Hz, ≤4–6 ms pixel response; ASUS VG248QE as budget pick. Author trashes AOC (claims review samples lacked overdrive → ghosting).
- G-SYNC: cap FPS below refresh (in-engine or RTSS/CPU limiter, not driver V-Sync) because G-SYNC disengages at refresh rate; G-SYNC-compatible monitors tested (1000 fps camera) to have *lower* lag with G-SYNC on. Freesync has no chip → can ghost (author's opinion).
- Port claims: prefers DisplayPort (needed for G-SYNC), avoids HDMI; says DVI "seems faster" but read DP is ~1 ms faster — **disputed by Faith** (see Debunks: DP/DVI/HDMI are the same digital encoding; latency differs only in frame buffering/panel/cable length).
- **CRU (Custom Resolution Utility)** (monitortests.com) — fix refresh rates that sit at e.g. 139.96 Hz, or overclock monitors; worst case is a black screen, escapable via hotkey. Alternative: NVCP custom resolutions.
- Strobelight (blur busters) for ULMB on VG248QE/BenQ — reduces motion blur but *adds input lag*.
- Windows Color Management [major claim]: default ICC profile "worst input lag"; try sRGB WCS profile, monitor-vendor profile, or "sRGB_v4_ICC_preference.icc" from color.org; or check the box to use *no* color profile. Author claims BlurBusters staff confirmed some profiles add lag; all feel/CPU-mouse-feel changes are anecdotal.

## NVIDIA Control Panel & drivers

- **Low Latency Mode**: use "On" (= 1 pre-rendered frame). **Never "Off"** (3–4 frames queue = big lag). **Ultra Low Latency is counterproductive if GPU is not at 99% load** — tested with 1000 fps camera (linked YouTube 7CKnJ5ujL_Q); Ultra is a PR answer to AMD Anti-Lag; use NVIDIA **Reflex** where the game implements it, and don't combine Reflex with Ultra.
- **Adjust desktop size and position**: never use "fullscreen" scaling mode; author switched from *Display scaling to GPU scaling* and claims it fixed frame times and gave "+50 FPS average" — also check "override scaling set by applications".
- Global Antialiasing – Mode "off" lowers input lag for the whole desktop, but author doesn't recommend it ("makes mouse heavy").
- PhysX: set to CPU if CPU is decent (frees GPU); most modern games don't use GPU PhysX so can skip installing it. **Faith disputes**: NVCP only affects rare GPU-accelerated PhysX, and forcing it to CPU is a bad move because those tasks were written heavy-for-GPU.
- Disable NVIDIA Ansel if unused: run `C:\Program Files\NVIDIA Corporation\Ansel\NvCameraConfiguration.exe`, check Disable, save.
- Disable NVIDIA HD Audio (sound control panel or Device Manager) if unused; don't install it at all.
- NVIDIA Container/telemetry service: author claims disabling reduces input lag with V-Sync off, but an NVIDIA mod warned application profiles may stop working — author unsure.
- Driver hygiene: install Windows **offline** so Windows Update doesn't install OEM NVIDIA drivers first; otherwise clean with **DDU (Wagnardsoft)** — only for serious problems, verify download with `Get-FileHash`. Don't uninstall GPU drivers via Device Manager (use Programs and Features). Don't delete the Installer2 folder. Use **NVCleanstall** (techpowerup) to repack the NVIDIA installer with only needed components; skip GeForce Experience.
- NVIDIA driver 461.09+ introduced MPO (multiplane overlay) — "borderless" window can bypass DWM with low lag; known issue: desktop apps may flicker/stutter when resizing (NVIDIA support articles a_id 5157/5159).
- **NVIDIA Profile Inspector** (github.com/Orbmu2k/nvidiaProfileInspector) — per-game "frame rate limiter mode" (helped PUBG input lag), set single-display performance mode even with multi-monitor, shader cache off helps some games.

## BIOS tweaks

- Update BIOS only if you have high DPC latency or specific problems (never mid-outage; most modern boards can recover). **Faith pushes back**: never update without knowing what the update does.
- Disable: all C-States, EIST/SpeedStep, thermal throttling (for OC), Hyper-Threading (helps old single-core games like SC2), spread spectrum (if no EMI issues), HPET (if the option exists — can greatly reduce latency on some boards; don't force off via cmd; can disable in Device Manager), Legacy USB support, EHCI/XHCI handoff, unused USB ports, **USB 3 entirely** ("causes huge lag" — author's claim).
- Enable: Intel TPM (security, no noticed lag), Intel Speed Shift (faster C-state transitions), IOAPIC 24-119 entries + Above 4G decoding if using Resizable BAR (gave him lag on gen-9 without BAR).
- Keep BCLK as close to 100 MHz as possible; ±0.1–0.3 MHz spikes normal, ~1 MHz = problem.
- RAM: downclock RAM + tighten timings for latency (XMP off made 2133 MHz RAM feel much lower latency — anecdotal); 2133→3200 MHz is 10–20 FPS on modern CPUs. Changing timings *can* cause instability; author claims he once corrupted a cheap RAM stick. AIDA64 Extreme for RAM latency benchmarking; AMD DRAM calculator exists but "don't trust blindly".
- Voltage sanity: VCCIO/VCCSA start ~1.1 V, don't exceed ~1.2 V (BIOS often overvolts these); RAM standard 1.35 V — some boards (called out: ASRock) overvolt RAM/CPU while reporting lower values. ASUS boards have >1 ms DPC latency even at $500+ and crackling sound; Gigabyte recommended. (All author's opinions.)
- BIOS mods for locked CPUs: bios-mods.com; scan with VirusTotal, demand SHA hashes, don't trust low-rep posters.
- Disable Intel MEI where possible ("spy engine", causes lag) — can't be fully disabled or PC won't boot. AMD equivalent: "AMD Secure Technology" can be disabled in BIOS.

## Windows installation & debloating

- Install Windows with Ethernet unplugged; use offline account; untick everything.
- **Sledgehammer** or **WUTM** (tenforums threads) to take manual control of Windows Update and stop automatic driver updates ("tweaks reset after major updates — keep .reg/scripts list"). One commenter warned update-blockers "cause bugs"; author says WUTM (manual-only) is safe.
- Set connection to metered via registry: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\DefaultMediaCost`, set "Ethernet"=2 and "Default"=2 — defers automatic updates. Also check askwoody.com MS-DEFCON before updating.
- Uninstall Appx packages (tenforums tutorial 4689), remove everything except the Store; also clean Store apps and "optional features" (Win+i → Apps). In "Turn Windows features on or off" disable everything unneeded except .NET Framework (author says disabling .NET 4.8 gives lowest latency but almost everything needs it — not recommended).
- Edge: don't force-uninstall (contains core components); instead deny all NTFS permissions for your user/SYSTEM on it, disable its background running + HW acceleration; keep its updater for security fixes.
- **Do not use CCleaner for registry cleaning** — registry is designed to be bloated; CCleaner was once hacked to distribute malware. Windows Disk Cleanup is fine. RevoUninstaller Pro for traced uninstalls (do a backup/restore point first).
- Uninstall Adobe Flash via KB4577586 (catalog.update.microsoft.com) — "causes so much input lag", EOL security risk.
- Settings: disable Focus Assist + automatic rules, background apps (Privacy), notifications.
- **O&O ShutUp10 (OOSU10)** — disable everything except entries marked "no"/"limited" (reference config: tweakhound.com 03dec2020 post); make a restore point.
- Disable virtual desktops / Task View via registry:
  ```
  [HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MultitaskingView\AllUpView]
  "AllUpView"=dword:00000000
  "Remove TaskView"=dword:00000001
  ```
  Author believes virtual desktops cause "tremendous input lag" (unverified).
- Disable IE add-ons via gpedit: Computer Configuration → Administrative Templates → Windows Components → Internet Explorer → Security Features → Add-on Management → "Deny all add-ons unless specifically allowed".
- Disable startup delay (tenforums tutorial 69693); audit startup with **Autoruns** and **Process Explorer** (Sysinternals — can submit hashes to VirusTotal); services via services.msc (blackviper.com for safe-disable references), not msconfig.
- Task Scheduler: author warns manual edits "caused weird lag" only fixed by reinstall; follow the tenforums "Project: Which Scheduled Tasks can be Disabled WITHOUT Drastic Impact" thread instead.
- Win+i → Devices → Mouse: keep **"Scroll inactive windows when I hover over them" enabled** — disabling it causes "heavy mouse movement".
- Audit successful events off [minor]: `Auditpol /set /category:* /Success:disable` (doesn't cover security events).

## Memory, pagefile & SSD registry tweaks

- Pagefile sizing (MS docs): min = RAM/8, max = RAM × 1–1.5; system-managed has small overhead; can disable entirely with 16 GB+ RAM but not recommended. Author uses fixed 4096 MB with 16 GB. Put pagefile on NVME/SSD (non-system disk for SATA SSDs). Monitor usage in perfmon (Paging File → % Usage Total).
- **Pagefile encryption caveat**: enabling `ClearPageFileAtShutdown`=1 or pagefile encryption at `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management` — **changing pagefile size while encryption is on caused BSODs** (disable encryption first, resize, re-enable).
- Memory Compression: check `Get-MMAgent` (elevated PS) — compression should be False; Task Manager RAM shows "(compressed 0)". Claims memory-compression bug (The Division reddit thread) crashes games when standby memory fills RAM. Disabled by default on 20H2.
- `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management` → DWORD `DisablePagingExecutive=1` (keep kernel in RAM; "100% safe, needs 8 GB+").
- `...\Memory Management\PrefetchParameters` → DWORD `EnablePrefetcher=0`, and `EnableBootTrace=0` (faster boot; re-enable for boot debugging).
- Disable service **SysMain** (Superfetch) in services.msc.
- Install all programs on NVME/SSD to minimize hard-pagefault cost. HDDs are for storage, not modern games; defrag HDDs and run error checks occasionally; keep disk count low to cut interrupts/DPC latency; NVME needs a heatsink or it throttles.

## Sound

- Set speakers to **16-bit 44100 Hz**, disable all enhancements/virtual audio, configure full-range left/right. Author claims higher sampling "adds input lag" — **disputed by Rezler** (see Debunks).
- Don't use USB sound cards/headsets ("huge DPC latency"); onboard audio has lower lag than NVIDIA HD Audio (which is also limited to ≥24-bit/48 kHz).
- Don't install Realtek audio drivers unless you have sound-related stutter/FPS drops (old CS:GO issue); default Windows audio drivers have lower input lag (empleat's answer to lolnothankyou). Newer 2020 Microsoft Realtek drivers exist for some cards.

## Timers & timer resolution

- `bcdedit /set disabledynamictick yes` (undo: `bcdedit /deletevalue disabledynamictick`) — dynamictick drops the timer to 15.6 ms and makes the mouse feel like it accelerates; disabling keeps movement consistent. [Author's flagship tweak]
- `bcdedit /set useplatformtick true` (undo: `bcdedit /deletevalue useplatformtick`) — disables synthetic timers; improves mouse accuracy *but can cause input lag — test it*.
- `useplatformclock` (HPET forcing): best to remove entirely (`bcdedit /deletevalue useplatformclock`) and let Windows choose; disable HPET in BIOS if desired, not via cmd. Check current values with `bcdedit /enum`. Timer benchmark: TimerBench (matthias.zronek.at/projects/timerbench) or the overclockers.at "HPET bug" tool.
- **Timer resolution**: author uses **ISLC (Intelligent Standby List Cleaner, by Wagnardsoft)** to force 1 ms (says 0.5 ms adds inconsistency at 500 Hz mouse polling); claims drastically lower input lag, slightly better CPU usage and DPC latency, plus standby-memory cleaning. Notes Chrome forces 0.5 ms on its own; dynamic 15.6↔0.5 ms switching would be ideal for power saving.

## Windows visuals, DWM & services

- "Adjust the appearance and performance of Windows": disable everything except "smooth edges of screen fonts". **ClearType Switch** (small utility) to toggle ClearType for gaming sessions. Disabling the Themes service may stabilize mouse polling but can break visual-effects settings.
- Registry: `HKEY_CURRENT_USER\Control Panel\Desktop` — `UserPreferencesMask` set to all zeros (delete all data bytes) disables leftover visual features; use **UPMCalc** (softpedia) to decode the mask. Author notes some bits no longer apply on newer Win10.
- Same key: `Win8DpiScaling=1` — "should help a lot" [author's major tweak, 03/2021].
- Taskbar: set "combine taskbar buttons" to **never** — "seems it caused a little bit of input lag".
- Killing explorer.exe in-game reduces input lag (fine on Win7) but makes mouse inaccurate on Win10; changing explorer's core affinity also feels wrong.
- Old tweak to disable forced AA in Windows (Microsoft Answers thread) — possible font rendering glitches in some apps (crossed W, slashes in Google Docs).
- DWM: author's old "disable DWM" .reg is marked **OUTDATED** by himself — can cause errors/freezes; DWM can't really be disabled on 1903+. Safer 2021+ approach: BlurBusters threads t=7168 and f=5&t=4512 (DWM tweak downloads, "google what they do"). Set DWM memory priority to 1 (very low) in Process Lasso.
- Services causing literal lag per author: HID and DWM; disabling explorer while gaming helps; **do NOT disable Windows Firewall service** (used by IPSec etc.). Disable "Host for setting synchronization" (SettingSyncHost) and "Text input app" (linked superuser/howtogeek articles); don't edit DCOM permissions (easy to break security).
- Time sync: Windows clock drifts (~0.7 s/day, found 7 s off) and unsynced time "can cause input lag" [major claim]; sync periodically (batch file every 30 min while no game running) — dedicated sync services cause more lag than they fix.
- **Tweak 1 [Major]**: Internet Properties → Advanced → check "Use software rendering instead of GPU rendering"; uncheck "Use smooth scrolling".
- **Tweak 2 [Major]**: switch Windows display language to **English (Philippines)** — claimed lower input lag than English US (credited to x7007/RamenRider on overclock.net). Highly anecdotal.
- Disable SmartScreen (App & browser control) [minor]; disable **hardware acceleration everywhere** — browsers, Spotify, game clients ("worst evil... immense input lag"). Firefox-specific: `browser.cache.disk.enable=false`, `media.peerconnection.enabled=false` (WebRTC off), disable OpenH264 plugins, install without the background update service; verify installer hash: `(Get-FileHash "...\Firefox Setup 83.0.exe" -Algorithm SHA512).Hash` vs ftp.mozilla.org listing.
- Author's uploaded "kill unresponsive programs" batch utility on Google Drive (drive.google.com/drive/folders/1HJTTT0DSWsrf-9cDhD43VBX9N14QDyUM) + Task Manager "Always on top" to survive game freezes without hard resets.
- Internet browser pick: Opera GX (can limit CPU/RAM), or tab suspending in Chrome/Firefox. "Chrome is spyware" (author's opinion).

## Drivers, DPC latency, interrupts & MSI

- Diagnostics: `dxdiag`, `msinfo32`; **LatencyMon** (resplendence.com/latencymon) — measure DPC/ISR latency; default mode (interrupt-to-user-process latency), check all CPUs in options, test ≥30 min, disable power saving/turbo while testing, BCLK at 100. Update drivers only if a new one doesn't add ~10k+ interrupts or higher execution times. Windows ADK also good for DPC analysis.
- Mouse polling testers: MouseTester (overclock.net thread, v1.2 fine; someone flagged 1.53 as virus but source is released), zowie.benq.com mouse-rate-checker.
- **MSI utility v2 (Msi_util2)** (guru3d "Windows: Line-Based vs Message Signaled-Based Interrupts" thread) — switch GPU, NIC, audio, USB, SATA/NVMe controllers, Intel MEI to MSI mode. **WARNING: enabling MSI on the wrong device can make the PC unbootable** — know your device IDs (cross-check IRQs in Device Manager → View → Resources by connection); author had 2 audio controllers and picking the wrong one would kill boot. Most devices are MSI by default already.
- Interrupt affinity: **Interrupt Affinity Policy Tool** (Microsoft) — author tested extensively; **everything on core 0 felt best**; setting affinity on *disks* "can damage your PC". Consensus: one device's interrupts shouldn't span multiple cores (cache misses). LatencyMon support told him registry interrupt affinity can be ignored at driver/hardware level anyway.
- Interrupt priority via registry: `HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl` → DWORD `IRQ#Priority` (# = device IRQ, 1 = highest … 16 = lowest). Some users liked CMOS=1, GPU=2, USB controller=2/3. Author's results mixed ("feels snappier but aim is trash"); default mostly best. Find IRQs via Msi_util2 or by disabling USB controllers with a PS/2 mouse attached.
- Driver install order: chipset first, then sound/network/GPU — **but don't install Intel Chipset INF drivers** ("huge input lag", can't be uninstalled without reinstalling Windows; they only expose devices to the OS — though he concedes *not* updating some (PCIe controller) also caused lag). Do not install Intel SATA drivers ("tremendous input lag"; 2006 MS SATA drivers benchmark at full speed). Intel Management Engine (MEI) drivers = lag (some people have issues without them — test). Mouse drivers are often badly coded (Logitech OK; **never install Razer Synapse** — input lag can persist after uninstall, Razer Insider thread); default Windows mouse drivers usually best.
- Stop auto driver updates via registry:
  ```
  HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate — DWORD ExcludeWUDriversInQualityUpdate=1
  HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching — DWORD SearchOrderConfig=0
  HKLM\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Restrictions — DWORD DenyUnspecified=1
  HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer — DWORD DisableCoInstallers=1
  ```
- List installed drivers: msinfo32, or the howtogeek driver-list guide; **DriverStore Explorer** (github.com/lostindark/DriverStoreExplorer) to remove old driver packages; Autoruns can stop drivers loading at boot (**risky — can make PC unbootable; backup first**). Never uninstall *hidden/disconnected* devices (causes "clown mouse feel"); in Device Manager prefer Disable over Uninstall for system devices ("NEVER UNINSTALL DEVICES IN DEVMGR, WINDOWS BUGS OUT AND CAN CAUSE LAG").
- PCI-E add-in cards (NIC/sound) = "tremendous input lag" (NVMe on PCI-E gen3 x4 is fine). USB ground/EMI issues can make the mouse jitter — try a UPS or surge-protected outlet.
- **InSpectre (grc.com/inspectre.htm)** — check/disable Spectre/Meltdown mitigations for some performance back ("causes input lag on my old PC"; security risk trade-off — author's caveat: don't take his word).
- Overclock.net "Gaming and mouse response BIOS optimization guide" post #4306 — guide to disabling useless Windows-installed drivers; warning quoted: someone disabled an Intel/RAID driver and the system wouldn't start.

## Network tweaks

- NIC: disable power management ("allow the computer to turn off this device"), configure Advanced tab per speedguide.net guides (LAN tweaks articles 5819/3449/5812 + their TCP Optimizer program).
- Author's exception to speedguide defaults: **Interrupt Moderation = Enabled, Interrupt Moderation Rate = Medium** — made mouse more consistent via lower DPC latency (BlurBusters thread ref). Optionally reduce receive/transmit buffers to 258/258.
- Disable unused WAN miniports in Device Manager (show hidden devices); keep SSTP if you use VPN.
- Disable DHCP by setting static IP/gateway (subnet auto-fills).
- Security: disable **NetBIOS** (NIC properties → TCP/IPv4 → Advanced → WINS → disable LMHOSTS lookup + NetBIOS over TCP/IP; also NetBIOS and UPnP services in services.msc); uncheck all NIC bindings except IPv4 (or IPv6); QoS binding not useful (handle QoS in router). Routers: pfSense or Turris Omnia; "ISP routers are full of security holes". DNS-over-TLS preferred over DoH but slower; **dnsbench** to find fastest DNS.
- WiFi tweaks: martin-majowski.de (tweak credited to Callender).
- **Myth-bust by author**: DNS does not affect ping — at most initial connection speed. (Reply from **tom9928** nonetheless suggests 1.1.1.1 DNS; empleat questions its relevance to gaming.)

## In-game settings & fullscreen optimizations

- Never use V-Sync (adds ~1 frame of lag, e.g. 16.67 ms at 60 FPS); use Fast Sync or FPS caps instead. Cap FPS below refresh with G-SYNC. **Faith disputes**: V-Sync is preference; many games use an extra frame buffer to avoid framepacing issues.
- Resolution scaling 99% (barely degrades quality, lowers input lag per author); disable motion blur (sometimes via console/cfg); lowest AA, ambient occlusion, shadows, film grain, chromatic aberration.
- **Disable Fullscreen Optimizations (FSO)** per-game .exe (Compatibility tab) — requires registry to fully work:
  ```
  [HKEY_CURRENT_USER\System\GameConfigStore]
  "GameDVR_DXGIHonorFSEWindowsCompatible"=dword:00000001
  "GameDVR_FSEBehavior"=dword:00000002
  "GameDVR_FSEBehaviorMode"=dword:00000002
  "GameDVR_HonorUserFSEBehaviorMode"=dword:00000001
  ```
  Only affects DX9/DX11 (DX12/Vulkan have no fullscreen-exclusive). Verify FSO is off by pressing volume/media keys in fullscreen — if an overlay pops up, FSO is still on. With NVIDIA 460.09+ MPO, borderless can reach "independent flip" — check with **PresentMon** (github.com/GameTechDev/PresentMon).
- Same Compatibility tab: "Override high DPI scaling behavior → Application" — can fix blur/input lag, not always better.
- FPS capping methods benchmarked per API (reddit r/allbenchmarks "Comprehensive benchmarking of Nvidia's FPS limiters") — in-engine limiter best; RTSS nearly lagless.
- **win32priorityseparation** tweak: value **40** (hex?) "gives least input lag" per author; can cause FPS drops though he measured more FPS in one benchmark; from the linked Google Docs DPC/interrupt guide (docs.google.com/document/d/1c2-lUJq74wuYK1WrA_bIvgb89dUN0sj8-hO3vqmrau4).

## Mouse tweaks

- Windows: pointer speed slider exactly 6/11 (default = 1.0); uncheck "Enhance pointer precision". Verify in registry `HKEY_CURRENT_USER\Control Panel\Mouse`: MouseSensitivity=10, MouseSpeed=0, MouseThreshold1=0, MouseThreshold2=0.
- **Delete smoothing curves** [author's major]: `HKCU\Control Panel\Mouse` → `SmoothMouseXCurve` and `SmoothMouseYCurve` — delete all bytes so they show as zero-length binary values (legacy from 400-DPI IntelliMouse era; today only induces lag). Defaults restorable from `HKEY_USERS\.DEFAULT\...` same path. **Rezler calls this contradictory** (see Debunks) since the MarkC fix edits these same values.
- **MarkC Windows 8+7 MouseAccelFix** — for old games (CS 1.6, Brood War) that force Windows acceleration; edits the same smoothing curves to cancel acceleration; adds lag per author; includes restore-to-default reg.
- **MouseDataQueueSize=25** (registry, via linked YouTube) — author had good experience; lower = inconsistent.
- Windows USB bug: keyboard entries must be ordered above mouse in Device Manager (overclock.net "2 Windows USB bugs affecting most people" thread); connect keyboard first, delete greyed-out HID entries; a BlurBusters fix thread (t=7618) especially for 8 kHz mice.
- Polling/DPI advice: 800 DPI on 1080p, in-game sensitivity = 1.00 (avoid interpolation/pixel skipping); 500 Hz polling more consistent, 1000 Hz quicker; pair 500 Hz with 1 ms timer resolution (0.5 ms adds inconsistency); 8 kHz mice need <76 µs DPC latency on the XHCI (wdf01000.sys in LatencyMon) and can't currently sustain 8 kHz. Use raw input per-game (some games couple it with smoothing).
- Buying: optical sensor only (never laser — built-in acceleration), check click latency (DeathAdder cited ~8 ms), low LOD, sensor.fyi for sensor lists; Zowie praised (no drivers); ideal weight 90–105 g; ceramic/glass mouse feet (Pulsar Superglides, Hotline Games/hyperglides).
- Disable Logitech driver smoothing; skip mouse calibration ("feels weird, adds lag"). Use top USB 2.0 ports for mouse/keyboard; never use USB hubs; PS/2 has lower lag at ≤500 Hz. USB 3 "worse architecture for latency" (attributed to r0ach).

## Benchmarking & measurement tools

- **MSI Afterburner + RivaTuner (RTSS)** — FPS cap (nearly zero added lag), frame times, OSD. (Download beta, release had a bug.)
- **NVIDIA FrameView** — frame-time/power logging to CSV; read 99th-percentile frame times.
- **PresentMon** (GameTechDev GitHub) — verify independent flip / MPO engagement.
- **3DMark** — expected-performance sanity checks, stress testing, bottleneck testing while underclocking CPU.
- **LatencyMon**, **Windows ADK**, **TimerBench**, **MouseTester**, zowie rate checker (above).
- **Intel Power Gadget** (CPU power draw), **GPU-Z** (GPU power/throttling), **HWiNFO** (monitoring; don't leave monitors running — cause FPS drops/stutters), **prime95** for stress tests, **AIDA64 Extreme** for RAM latency, **Input Lag A/B test** on BlurBusters forums, guru3d "system latency device" thread (LDAT-like hardware, US-only at the time).

## Hardware buying notes (author's opinions, 2018–2022 era)

- Mobo: price largely irrelevant above junk tier; Gigabyte preferred; avoid ASUS (>1 ms DPC, crackling audio) and ASRock (overvolts while misreporting); want Intel NIC, no RGB/WiFi/BT (or disable-able), HPET disable option, EMI shielding; Anandtech publishes mobo DPC latency tests; vi-control.net "PC specs for lowest possible latency" thread.
- CPU: Intel better single-core/USB polling interval (128 µs); AMD X570 had USB dropout issues (GamersNexus HW News 2021) and VR incompatibilities; Ryzen 5000 competitive. (**CountMike** and **Lugh** counter: Ryzen R9 3950x etc. made AMD the better value — plain CPU-fan discussion, no tweaks.)
- RAM: Samsung B-die, G.Skill 3200 CL16 sweet spot; 2133→3200 ≈ 20 FPS; check QVL; avoid RGB.
- PSU: wattage calculators are a scam; 500–600 W enough for single-GPU high-end rigs (PSUs exceed rating 10–20%); aim Gold+; Corsair RM650x 2018 praised, Seasonic declined, check Amazon reviews (Cooler Master unit with bad OVP killed a PC).
- Case: big towers for airflow/cable management; ≥49 CFM low-RPM quiet fans. GPU: 60/70-series cost-efficiency; avoid vertical mounts (author's GPU ran x2 from a dust particle). NVMe needs heatsink. 7200 rpm HDDs noisy/vibrate — 5400 for storage. WD HDDs have a data vulnerability (his claim).

## Caveats & debunks (replies on this page)

- **Faith (post 1454671)** — systematic pushback: (1) DP/DVI/HDMI share the same digital encoding; latency comes from frame buffering/panel/cable length, not the connector — author's "DVI vs DP feels different" claim is unfounded. (2) V-Sync is preference; added latency is a non-issue for many; modern games use an extra frame buffer against framepacing/stutter. (3) The NVCP PhysX setting only affects the rare GPU-accelerated PhysX path; forcing GPU-PhysX workloads onto the CPU is counterproductive. (4) BIOS updates should never be done without knowing what they fix.
- **Rezler (post 1713511)** — challenges the >44100 Hz sampling = input lag claim ("pretty useless but not that much impact") and points out a contradiction: the guide says delete SmoothMouseX/YCurve values, yet also recommends the MarkC fix which works by *editing those same values*.
- **empleat self-corrections**: the disable-DWM registry file is marked **OUTDATED/dangerous** (errors/freezes; DWM can't be disabled on 1903+); the "kill explorer.exe" trick feels wrong on Win10; USB-MSI switching on old PCs "did nothing"; his earlier AOC monitor recommendation was retracted ("never buy AOC"); Interrupt Moderation should be *enabled/medium*, contra speedguide's max-performance defaults; author repeatedly flags his own claims with "test it yourself", "no idea if this is true", "could be a habit".
- **lolnothankyou / tom9928 / CountMike / Lugh** — Q&A and chatter: use default Windows audio drivers instead of Realtek (empleat); 1.1.1.1 DNS suggestion (empleat skeptical); "just buy a beast PC" rebutted (DWM/HID services lag regardless); AMD value discussion.

## External resources linked (tweakers & guides to follow)

- Tweakers named: RamenRider, R0ach, x7007, FR33THY, Adamx, mbk1969, HAGGARD, Calypto, LowSpecChaos, Melody, djdallmann, Timecard, Chief Blur Buster.
- Guides: BlurBusters "most epic tweakguide" (f=10&t=7168), overclock.net "Gaming and mouse response BIOS optimization guide" (1433882) and "USB polling precision" (1550666), the Google-Docs interrupt/DPC guide (1c2-lUJq74wuYK1WrA_bIvgb89dUN0sj8-hO3vqmrau4), melodystweaks sites.google.com, github.com/BoringBoredom/PC-Optimization-Hub, github.com/PrincessAkira/Use-Gaming-Tweaks (Chef Koch; notes mousesync.com is likely a scam), overclock.net MMCSS research thread (1774590), github.com/djdallmann/GamingPCSetup, AMD red-team input-lag thread (2020), r/ShadowPC input-lag guide, speedguide.net articles, tweakhound.com timer-tweaks benchmark, PCGamingWiki NVCP tweakguide, blackviper.com service configs, tftcentral.co.uk input-lag testing.
