# services.mdx — noverse cross-check

Page reviewed: `docs/src/content/docs/tweaks/services.mdx`
Primary noverse sources (all deep-read):

- Services/Drivers: https://noverse.dev/docs/win-config/system/disable-services-drivers/
- Disable Scheduled Tasks: https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/
- Disable Windows Search: https://noverse.dev/docs/win-config/system/disable-windows-search/
- Disable Printers: https://noverse.dev/docs/win-config/peripheral/disable-printers/
- Disable Bluetooth: https://noverse.dev/docs/win-config/peripheral/disable-bluetooth/
- ICS / Mobile Hotspot: https://noverse.dev/docs/win-config/network/disable-ics-mobile-hotspot/
- Disable Automatic Map Downloads: https://noverse.dev/docs/win-config/privacy/disable-automatic-map-downloads/
- Memory Compression: https://noverse.dev/docs/win-config/system/memory-compression/
- Service Splitting: https://noverse.dev/docs/win-config/system/service-splitting/
- Disable Autoruns: https://noverse.dev/docs/win-config/system/disable-autoruns/

Context on noverse's structure: his Services/Drivers page is the option reference for his WinConfig tool. His stated philosophy in the page intro: he recommends only the "main" option (telemetry/diagnostics/location); everything else is a suboption "for a specific reason" that "may cause broken functionalities", because "most other features won't start automatically anyway". That framing is essentially our page's thesis stated from the other side.

## Claim-by-claim verification

### Framing: bloat.services is a hardware/attack-surface/feature-usage decision, not an FPS tweak
- **Our claim:** The three services (RetailDemo, MapsBroker, Spooler) are not performance optimizations; disable for a reason, not to make a number go down.
- **noverse position — AGREES.** His services page opens by recommending against broad service disabling: most services never auto-start, and touching the rest only buys broken functionality. He frames every non-main option as a specific-reason decision, which is exactly our page's criterion.
- **Evidence:** intro of https://noverse.dev/docs/win-config/system/disable-services-drivers/

### RetailDemo = kiosk mode, never runs on a real PC
- **Our claim:** Retail Demo Service is store-display kiosk mode.
- **noverse position — AGREES.** Lists `RetailDemo` under a "Demo / Shared Device" category with the same description (controls device activity in retail demo mode), alongside `shpamsvc` (SharedPC profiles). Command line shown: `svchost.exe -k rdxgroup`.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Demo / Shared Device section). He also lists a related scheduled task `\Microsoft\Windows\RetailDemo\CleanupOfflineContent` on https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/.

### MapsBroker = offline maps for the Maps app
- **Our claim:** Downloaded Maps Manager is only used by the Maps app for offline maps.
- **noverse position — AGREES-WITH-NUANCE.** His description matches ("started on-demand by application accessing downloaded maps; disabling prevents apps from accessing maps") — note it is *any* app using the offline-maps API, not only the Maps app, matching our prior internal validation. He adds depth we lack: the maps stack also includes the `moshostcore` component (Downloaded Maps Manager Core) with persisted registry settings `AutoUpdateEnabled` and `UpdateOnlyOnWifi` (both default 1), two Maps policies (`AutoDownloadAndUpdateMapData`, `AllowUntriggeredNetworkTrafficOnSettingsPage` under `HKLM\Software\Policies\Microsoft\Windows\Maps`), and two scheduled tasks (`MapsUpdateTask`, `MapsToastTask`).
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Maps Manager), https://noverse.dev/docs/win-config/privacy/disable-automatic-map-downloads/, https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/

### Spooler = printing; disabling with a printer breaks printing outright
- **Our claim:** Disabling Print Spooler breaks printing; script skips it when a real printer exists.
- **noverse position — AGREES.** Same description ("you won't be able to print or see your printers"), and his Spooler row shows dependencies `RPCSS, http`. His Printer category is wider than ours: `PrintNotify`, `PrintWorkflowUserSvc`, `PrintScanBrokerService`, `PrintDeviceConfigurationService`, `McpManagementService` (Universal Print), and the `usbprint` kernel driver. His dedicated printers page also removes the context-menu Print verb and sets printing policies (`DisableHTTPPrinting`, `DisableWebPnPDownload` under `HKLM/HKCU\Software\Policies\Microsoft\Windows NT\Printers`).
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Printer), https://noverse.dev/docs/win-config/peripheral/disable-printers/
- The script's printer-enumeration check and state capture/restore are our implementation details — **NOT-COVERED** by noverse (his tool works differently).

### Print Spooler = PrintNightmare family, runs as SYSTEM, attack-surface removal
- **Our claim:** the spooler is the PrintNightmare component; disabling on a never-print machine removes the surface.
- **noverse position — NOT-COVERED.** He never mentions PrintNightmare or the security rationale; his printers page is purely functional (services, tasks, context menu, policies). No conflict — just absent.

### WSearch disabled → Start/Explorer search degrade badly
- **Our claim:** Start menu search and Explorer search stop working properly; extremely noticeable. (Implication: don't disable.)
- **noverse position — AGREES-WITH-NUANCE.** He confirms the breakage explicitly: disabling Windows Search "breaks the start menu", and CmdPal's File Search extension needs `WSearch`. But his remedy differs: he disables it anyway and replaces search with Everything (voidtools) + StartAllBack. Same mechanism, opposite conclusion — he accepts the breakage because he replaces the shell pieces.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-windows-search/ ; his services table also lists an "Everything" service entry, showing the replacement is part of his standard setup (https://noverse.dev/docs/win-config/system/disable-services-drivers/).

### SysMain: bad on spinning disks, close to free on NVMe, disabling doesn't help
- **Our claim:** Superfetch was genuinely bad on HDDs; on NVMe, disabling it does not help.
- **noverse position — AGREES-WITH-NUANCE, with important added depth.** He documents SysMain from Windows Internals: records app usage patterns, builds prefetch metadata (`layout.ini`), preloads to cut boot/app-start latency. Crucially, he documents a hidden cost of disabling it that we don't mention: **memory compression and page combining do not start when SysMain is disabled** — SysMain hosts the MMAgent config path (the CIM provider in `sysmain.dll` sets the admin bit in the `Superfetch` key and (re)starts SysMain; if SysMain can't run, `MemCompression` is never created). He also notes `EnableSuperfetch` becomes a no-op when the service is disabled, while `EnablePrefetcher` may still be read by the kernel. He offers a SysMain-off suboption for people who want to avoid the background activity, but explicitly warns it takes other beneficial MMAgent features with it, "which are beneficial on slow disks".
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (SysMain section), https://noverse.dev/docs/win-config/system/memory-compression/
- **Assessment:** No real conflict. His mechanism data *strengthens* our "don't bother disabling it" row: beyond "doesn't help", disabling actively costs you memory compression and page combining.

### wuauserv disabled → no security updates
- **Our claim:** disabling Windows Update service means no security updates.
- **noverse position — AGREES.** His wuauserv row carries the same Microsoft description (no Windows Update, no WUA API). His table also includes `UsoSvc` (Update Orchestrator) with the same consequence.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Windows Update section)

### WaaSMedicSvc is silently repaired and turned back on
- **Our claim:** Windows silently repairs WaaSMedicSvc and re-enables it; you achieve nothing but confusion.
- **noverse position — AGREES-WITH-NUANCE (partial).** His description of WaaSMedicSvc is the same ("repairs damaged Windows Update components so that the computer can keep getting updates"), but he does not document the launch-protection/self-repair mechanics. What he *does* provide is corroborating evidence of the self-healing ecosystem from the task side: `\Microsoft\Windows\WindowsUpdate\Scheduled Start` runs `sc.exe start wuauserv`, and `\Microsoft\Windows\Time Synchronization\SynchronizeTime` starts `w32time` the same way — Windows restarts these services from scheduled tasks even if you disable them.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Windows Update), https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/

### AudioEndpointBuilder disabled → audio devices stop being detected
- **Our claim:** audio device detection dies.
- **noverse position — NOT-COVERED.** AudioEndpointBuilder does not appear anywhere in his disable table — he offers no option to touch the audio service stack. His silence is consistent with our warning (he disables drivers/services only where there's a specific reason).

### BFE disabled → firewall/IPsec dead; can't restart without reboot
- **Our claim:** Windows Firewall and IPsec stop working; BFE cannot be started again without a reboot.
- **noverse position — AGREES (implicitly) + depth on the blast radius.** He never offers BFE for disabling. His dependency dumps quantify why killing BFE cascades far beyond the firewall: `XboxNetApiSvc` (deps: `BFE, mpssvc, IKEEXT, KeyIso`), `SharedAccess` (dep: `BFE`), `NcaSvc` (DirectAccess, deps: `BFE, dnscache, NSI, iphlpsvc`), and Defender's network inspection driver `WdNisDrv` (dep: `BFE`) all sit on top of it. The specific "cannot be started again without a reboot" sub-claim is **NOT-COVERED** by noverse (our prior validation found it overstatement-as-lore; that stands independently of him).
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Xbox, Mobile Hotspot / ICS, Network Profile & Connectivity UX, Windows Defender sections)

### Themes disabled → visual styles break, taskbar rendering on some builds
- **Our claim:** disabling Themes breaks visual styles and possibly taskbar rendering.
- **noverse position — AGREES-WITH-NUANCE (weak tension).** He lists `Themes` as an optional suboption ("Provides user experience theme management") without a warning, i.e. his tool lets you disable it. However, his own visibility section is full of tweaks that ride the theme stack (dark theme, accent color, visual effects), so the option only makes sense on a stripped fixed-purpose setup. He does not claim disabling Themes is safe on a normal desktop, so there is no direct factual conflict — see Conflicts below.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Themes section)

### "Every one of those appears as OK to disable in Microsoft's IoT guidance"
- **Our claim:** WSearch, SysMain, wuauserv, WaaSMedicSvc, AudioEndpointBuilder, BFE, Themes all appear as "OK to disable" in Microsoft's IoT services table.
- **noverse position — NOT-COVERED.** He never references Microsoft's IoT services guidance; his tables are generated from his own `dumpServicesDrivers.ps1` output. This claim therefore stands or falls on the Microsoft document alone — and our prior independent validation (`docs/local-tweaks-validation.md`, services.mdx section) already found it partially wrong against the current revision: SysMain, WaaSMedicSvc and BFE are marked **Don't disable** there. Noverse neither confirms nor refutes; flagged here so the fix isn't blocked on this cross-check.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (table provenance paragraph)

### Idle services cost approximately nothing; wins are elsewhere
- **Our claim:** an idle svchost at 0% CPU with a few MB paged out is not what slows a machine.
- **noverse position — AGREES.** His intro rationale is the same observation from the practitioner side: most services won't start automatically anyway, so disabling them buys nothing. He adds a mechanism we don't have: on systems with less than ~3.5 GB RAM, svchost service *splitting* is disabled by default anyway (`SvcHostSplitThresholdInKB` = 3670016 client default, read by SCM at startup and compared against physical memory), and he explicitly keeps the client default because grouping services back together only loses isolation.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (intro), https://noverse.dev/docs/win-config/system/service-splitting/

### The 14-service candidate list, all "OK to disable" per Microsoft, safe on machines that don't use them
- **Our claim:** bthserv/BthAvctpSvc, lfsvc, WalletService/SEMgrSvc, PhoneSvc/SmsRouter, icssvc, SharedAccess, WebClient, ScardSvr, WMPNetworkSvc, wisvc, PcaSvc — each is a hardware/feature decision; set Manual first.
- **noverse position — AGREES.** Every one of these appears in his table under the matching category, with descriptions that confirm our "what you lose" column:
  - Bluetooth (`bthserv`, `BthAvctpSvc`, plus the full BT driver stack `BthA2dp`/`BthEnum`/`BthHFEnum`/`BthLEEnum`/`BTHPORT`/`BTHUSB`/`RFCOMM` and per-user `BluetoothUserService`) — https://noverse.dev/docs/win-config/system/disable-services-drivers/ and https://noverse.dev/docs/win-config/peripheral/disable-bluetooth/
  - `lfsvc` (Location) — geolocation/geofence notifications lost. Same as ours.
  - `WalletService` (Miscellaneous), `SEMgrSvc` (NFC/Payments) — same descriptions as ours.
  - `PhoneSvc` (Telephony, with `TapiSrv`), `SmsRouter` (Miscellaneous) — same descriptions.
  - `icssvc`/`SharedAccess`/`ALG` (Mobile Hotspot / ICS) — AGREES, plus depth: ICS needs two or more network connections, and policy `NC_ShowSharedAccessUI` (`HKLM\Software\Policies\Microsoft\Windows\Network Connections`) removes the Sharing tab. https://noverse.dev/docs/win-config/network/disable-ics-mobile-hotspot/
  - `WebClient` (File/Printer Sharing) — AGREES on WebDAV redirector function; his row adds that it depends on the `MRxDAV` file-system driver. His exploit-history angle is **NOT-COVERED** (ours, citing SpecterOps/CIS, is better sourced here).
  - `ScardSvr` (Smart Card, with `ScDeviceEnum`, `SCPolicySvc`, `scfilter`) — AGREES.
  - `WMPNetworkSvc` (Media Sharing / Portable Devices) — AGREES on UPnP/DLNA sharing function. Our justification "from a player Windows no longer ships by default" is **NOT-COVERED** by him (and our prior validation found it inaccurate — WMP Legacy still ships as an optional feature).
  - `wisvc` (Windows Insider) — AGREES, identical description.
  - `PcaSvc` — AGREES on function; note he files it under his **Telemetry** category (with DiagTrack, dmwappushservice, InventorySvc, wuqisvc), reflecting that PCA feeds the compatibility-telemetry pipeline — a framing our page doesn't have.
- The "Set them to Manual first; a Manual service nothing asks for never starts" advice is **NOT-COVERED** explicitly by noverse (his tool sets disabled states directly), though his "most features won't start automatically anyway" is the same observation.

### RasMan trap: marked OK to disable, but VPN clients depend on it
- **Our claim:** RasMan reads as dial-up but backs the built-in VPN client and some third-party VPN clients; leave it alone.
- **noverse position — AGREES-WITH-NUANCE.** His VPN/RAS category treats the whole stack as disable-only-if-unused: `RasMan` (deps `SstpSvc, DnsCache`), `RasAuto`, `RemoteAccess` (deps `RpcSS, Bfe, RasMan, Http`), `SstpSvc`, and the WAN miniport drivers (PPTP/IKEv2/L2TP/SSTP). His RasMan description confirms it "manages dial-up and virtual private network (VPN) connections". He doesn't call it a trap, but his structure embodies the same advice: this is a category you touch only when you knowingly use no VPN.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-services-drivers/ (VPN/RAS Services)

### "What people turn back on" rows
- **BFE + mpssvc → firewall rules stop applying:** AGREES implicitly — see the BFE row above; his dependency data adds Xbox Live networking, ICS, DirectAccess and Defender NIS to the casualty list. https://noverse.dev/docs/win-config/system/disable-services-drivers/
- **appinfo → UAC elevation fails:** NOT-COVERED. His table has no appinfo entry; his UAC category contains only the `luafv` file-system driver.
- **AppXSvc → Store-packaged apps stop working:** AGREES, with a concrete extra data point: "Disabling breaks CmdPal and other store applications." He lists the full Store stack (`ClipSVC`, `InstallService`, `LicenseManager`, `PushToInstall`, plus `camsvc`). Also note his Autoplay row: disabling `ShellHWDetection` "causes CmdPal to not start directly after boot for whatever reason" — same class of modern-shell fallout. https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Microsoft Store, Autoplay)
- **pla/PerfHost/wmiApSrv → perfmon and WPR record nothing:** NOT-COVERED. None of the three appears in his table. (Our prior validation found the "WPR records nothing" half wrong — WPR is an ETW recorder; that correction stands independently.)
- **WlanSvc → no Wi-Fi:** AGREES. His Wi-Fi category includes `WlanSvc` plus `wcncsvc` (WPS), `WFDSConMgrSvc` (wireless display/docking), and drivers `vwififlt`, `NativeWifiP`, `Wificx`; the WlanSvc description explicitly warns all WLAN adapters become inaccessible from the Windows networking UI. He also has a dedicated disable-wi-fi option. https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Wi-Fi)
- **CapabilityAccessManagerSvc → camera/mic permission handling:** AGREES on function (his camsvc description matches ours), though he files it under his Microsoft Store category rather than flagging it as a breakage story. https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Microsoft Store)
- **Xbox services → Game Pass / cloud saves / overlay; IoT "Should be disabled" is backwards for gaming:** AGREES-WITH-NUANCE. His Xbox category lists the four services plus the `xboxgip` kernel driver, with descriptions confirming exactly our breakage claims (XblGameSave: "game save data will not upload to or download from Xbox Live"; XblAuthManager: "some applications may not operate correctly"). But he offers Xbox services as an ordinary suboption without a gamer warning — softer than our "exactly backwards for a gaming desktop". No factual conflict; a philosophy difference. His table does confirm the Xbox Live networking API service depends on BFE/mpssvc/IKEEXT/KeyIso, reinforcing the BFE warning. https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Xbox)
- **Anti-cheat services (Vanguard/EAC/BattlEye) block the game when disabled:** NOT-COVERED. His services table doesn't cover anti-cheat; his game tools are config generators, not service lists.

### "Services that look safe and are not" rows
- **Windows Biometric Service → Windows Hello:** AGREES. `WbioSrvc` listed under Biometrics with the same description. https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Biometrics)
- **Network Connection Broker → Store-app notifications:** AGREES, near-identical description (brokers connections that let packaged Store apps receive notifications from the internet); filed under his Broadcasts category with CDPSvc/CDPUserSvc and the PNRP/p2p services.
- **Connected Devices Platform → Phone Link / nearby sharing:** AGREES on function ("used for Connected Devices Platform scenarios"); his privacy section additionally documents CDP authz policy values (`RomeSdkChannelUserAuthzPolicy`, `CdpSessionUserAuthzPolicy`) for the cross-device toggle — depth we lack, though that belongs to the privacy page.
- **Geolocation Service:** AGREES (see candidate list).
- **Parental Controls → Family Safety:** AGREES. `WpcMonSvc` listed with the same consequence ("parental controls may not be enforced").
- **Radio Management Service → airplane mode:** AGREES. `RmSvc` listed under Radio Management ("Radio Management and Airplane Mode Service").
- **Program Compatibility Assistant:** AGREES on function (see candidate list).

### msconfig "hide all Microsoft services" is bad advice; use Autoruns instead
- **Our claim:** the checkbox can't tell vendor telemetry from driver services; msconfig keeps no record; audit with Sysinternals Autoruns instead.
- **noverse position — AGREES on the Autoruns half; msconfig critique NOT-COVERED.** His autoruns page is exactly our recommendation: download and run Sysinternals Autoruns, trim the Logon section (his examples: OneDrive, Spotify, Discord, Steam, LGHUB, SecurityHealth, Edge), and he points at the `Run` keys for a quick view. He doesn't discuss msconfig at all.
- **Evidence:** https://noverse.dev/docs/win-config/system/disable-autoruns/

## Improvements to adopt

1. **SysMain row: add the memory-compression coupling.** Disabling SysMain doesn't just forgo prefetch — memory compression and page combining never start, because SysMain hosts the MMAgent configuration path (the `Enable/Disable-MMAgent` CIM provider lives in `sysmain.dll` and (re)starts SysMain to apply state; without it, the MemCompression process is never created). Also: `EnableSuperfetch` is a no-op when the service is disabled; `EnablePrefetcher` may still be consumed by the kernel. This turns our "disabling doesn't help" into "disabling actively removes two memory-management features". Sources: https://noverse.dev/docs/win-config/system/disable-services-drivers/ (SysMain), https://noverse.dev/docs/win-config/system/memory-compression/
2. **BFE row: widen the blast radius with dependency facts.** Beyond firewall/IPsec: Xbox Live networking (`XboxNetApiSvc`), Internet Connection Sharing (`SharedAccess`), DirectAccess status (`NcaSvc`) and Defender's network inspection driver (`WdNisDrv`) all depend on BFE. Killing it also breaks the Xbox row two tables down. Source: https://noverse.dev/docs/win-config/system/disable-services-drivers/
3. **WaaSMedicSvc row: add the task-side self-healing evidence.** Even if you disable `wuauserv`, the scheduled task `\Microsoft\Windows\WindowsUpdate\Scheduled Start` runs `sc.exe start wuauserv`; `\Microsoft\Windows\Time Synchronization\SynchronizeTime` starts `w32time` the same way. The services come back because tasks and the medic service both restart them. Source: https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/
4. **Spooler section: name the rest of the print stack and the policy alternative.** A printerless machine can also drop `PrintNotify`, `PrintWorkflowUserSvc`, `PrintScanBrokerService`, `PrintDeviceConfigurationService`, `McpManagementService` and the `usbprint` driver; HTTP printing/driver download can be killed by policy (`DisableHTTPPrinting`, `DisableWebPnPDownload` under `...\Policies\Microsoft\Windows NT\Printers`) without touching the spooler. Spooler dependencies: RPCSS and HTTP. Sources: https://noverse.dev/docs/win-config/peripheral/disable-printers/, https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Printer)
5. **MapsBroker row: the service doesn't control map auto-downloads.** Automatic offline-map downloads/updates are governed separately: policies `AutoDownloadAndUpdateMapData` and `AllowUntriggeredNetworkTrafficOnSettingsPage` under `HKLM\Software\Policies\Microsoft\Windows\Maps`, persisted settings `AutoUpdateEnabled`/`UpdateOnlyOnWifi` (default on), and the `MapsUpdateTask`/`MapsToastTask` scheduled tasks. If the goal is killing map traffic, the service alone doesn't do it. Sources: https://noverse.dev/docs/win-config/privacy/disable-automatic-map-downloads/, https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/
6. **icssvc/SharedAccess row: add the policy and the two-adapter fact.** ICS only exists when two or more network connections are present, and policy `NC_ShowSharedAccessUI` (`HKLM\Software\Policies\Microsoft\Windows\Network Connections`) removes the Sharing tab without touching services. Source: https://noverse.dev/docs/win-config/network/disable-ics-mobile-hotspot/
7. **Bluetooth row: offer the radio-level policy as the gentler option.** The PolicyManager CSP `Connectivity\AllowBluetooth` = 0 greys out the Bluetooth toggle at the radio level — an alternative to disabling `bthserv` + the whole BT driver stack, and easier to reverse. Source: https://noverse.dev/docs/win-config/peripheral/disable-bluetooth/
8. **AppXSvc row: add the modern-shell casualty.** Disabling AppXSvc breaks CmdPal (PowerToys' launcher) in addition to Store apps; disabling `ShellHWDetection` (Autoplay) stops CmdPal starting at boot. Good concrete examples of "third-party things ship as Store apps now". Source: https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Microsoft Store, Autoplay)
9. **WSearch row: acknowledge the replacement path.** If someone genuinely wants indexing gone, the working recipe is a replacement, not bare removal: Everything (voidtools) for file search plus an alternative start menu — with the caveat that the stock start menu and CmdPal's File Search extension break without `WSearch`. Source: https://noverse.dev/docs/win-config/system/disable-windows-search/
10. **"Idle services cost nothing" section: add the svchost-splitting mechanism.** Service splitting into per-service svchost processes only happens at all when RAM ≥ ~3.5 GB (`SvcHostSplitThresholdInKB`, client default 3670016 KB, compared against physical memory at SCM startup); on small machines services stay grouped regardless. And merging them back (the "reduce svchost count" tweak) only trades away isolation. Source: https://noverse.dev/docs/win-config/system/service-splitting/
11. **PcaSvc row: note where noverse files it.** He groups PcaSvc with telemetry services (DiagTrack, InventorySvc, dmwappushservice, wuqisvc) — PCA feeds the compatibility-telemetry pipeline, which is a privacy angle our "harmless to keep" framing doesn't mention. Source: https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Telemetry)
12. **Independently of noverse (from prior validation, restated so it isn't lost):** fix "Every one of those appears as OK to disable in Microsoft's IoT guidance" — the current Microsoft table marks SysMain, WaaSMedicSvc and BFE **Don't disable**. Noverse has no position; the fix is against the Microsoft doc.

## Gaps noverse covers that we don't

- **Scheduled-task debloat as a category** — a full table of tasks with their action commands (CompatTelRunner/`InventorySvc`, `SilentCleanup`, `ScheduledDefrag`, Update Orchestrator `usoclient` tasks, `MapsUpdateTask`, `RegIdleBackup`, Defender maintenance tasks, RetailDemo cleanup). Our page is services-only; tasks are the other half of "what runs on my machine". https://noverse.dev/docs/win-config/system/disable-scheduled-tasks/
- **Service splitting internals** — `SvcHostSplitThresholdInKB` / `SvcHostSplitDisable` / `SvcHostDebug`, with WinDbg verification of `g_fSplitSvcHost`. https://noverse.dev/docs/win-config/system/service-splitting/
- **Kernel drivers as disable targets** — his table covers drivers alongside services: `bam` (background activity moderation), `Ndu` (network data usage; disabling breaks Task Manager's send/receive graph), `CimFS`/`wcifs` (container FS), `lltdio`/`rspndr`/`MsLldp` (link-layer discovery), WAN miniports, `scfilter`, `usbprint`. We never mention that service-list culture extends into drivers. https://noverse.dev/docs/win-config/system/disable-services-drivers/
- **Richer service introspection than services.msc** — his `dumpServicesDrivers.ps1` dumps triggers, failure actions, required privileges, thread/handle counts, KM/UM time (services.txt/drivers.txt in his repo). A "how to audit a service properly" note could cite this approach. https://noverse.dev/docs/win-config/system/disable-services-drivers/
- **Network Discovery stack** — `fdPHost`, `FDResPub`, `SSDPSRV`, `upnphost`, `lltdsvc`: a common "safe to disable" list entry we don't discuss at all. https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Network Discovery)
- **Remote Desktop / Recovery-Backup / Sensor service stacks** — `TermService`/`SessionEnv`/`UmRdpService` + RDP redirector drivers; `VSS`/`swprv`/`SDRSVC`/`wbengine`; `SensrSvc`/`SensorService`/`SensorDataService`. All plausible per-machine service decisions our candidate table doesn't mention. https://noverse.dev/docs/win-config/system/disable-services-drivers/
- **Telemetry-service set** — DiagTrack, dmwappushservice, InventorySvc, wuqisvc as a coherent group (this likely belongs to the privacy pages, which sibling agents cover; noted here because PcaSvc is filed with them). https://noverse.dev/docs/win-config/system/disable-services-drivers/ (Telemetry)
- **Whole-stack per-feature removal pages** — disable-printers (services + tasks + policies + context-menu verb), disable-bluetooth (CSP policy), disable-wi-fi, ICS/Mobile Hotspot with `NC_ShowSharedAccessUI`. His pattern is "kill the feature at every layer", where ours is "set the service Manual". https://noverse.dev/docs/win-config/peripheral/disable-printers/ , https://noverse.dev/docs/win-config/peripheral/disable-bluetooth/ , https://noverse.dev/docs/win-config/network/disable-wi-fi/ , https://noverse.dev/docs/win-config/network/disable-ics-mobile-hotspot/
- **Service-shutdown-timeout fact check** — his hung-screen page notes `WaitToKillServiceTimeout` defaults to 5000 on Windows 11 (not the 20000 that Windows Internals states), verified in win32kbase, and advises leaving timeouts alone. Relevant if our site ever covers shutdown-tweaks lore. https://noverse.dev/docs/win-config/system/disable-hung-screen/

## Conflicts needing a decision

1. **WSearch: warn vs replace.** We say disabling WSearch is one of the most noticeable regressions (implying: don't). Noverse agrees it breaks the start menu and CmdPal file search — and disables it anyway, replacing search with Everything + StartAllBack. The mechanisms agree; the conclusion differs because he replaces shell components and we don't. Decision needed: keep our pure warning, or add the "if you actually want it gone, here's the working replacement stack" path (improvement #9). Recommend keeping the warning as primary and mentioning the replacement as an opt-in path — our site doesn't endorse shell replacement elsewhere.
2. **Themes: unsafe vs offered-without-warning.** We warn disabling Themes breaks visual styles and possibly taskbar rendering (Microsoft documents losing theme management/accessibility themes; the taskbar part is community lore). Noverse's tool offers Themes as an ordinary suboption with no warning, though his own visibility tweaks depend on the theme stack. Neither source has hard evidence on the taskbar-rendering claim. Decision: our warning is the better-sourced side (Microsoft's own description backs the visual-styles half); keep it, optionally soften the unverifiable taskbar clause. No change forced by noverse.
3. **Xbox services: "exactly backwards for gaming" vs neutral suboption.** We call the IoT "Should be disabled" marking anti-guidance for gaming desktops; noverse lists Xbox services as an ordinary optional category. This is philosophy, not fact — his own row descriptions confirm everything we say breaks. No factual resolution needed; note that a respected practitioner is less categorical than we are. Our stronger stance is justified by our gaming audience.
4. **(Resolved independently, not a noverse conflict)** The "all OK to disable in Microsoft's IoT table" sentence: prior validation proved 3 of 7 rows wrong against the current Microsoft doc. Noverse doesn't use that table at all, so there's nothing to weigh — just fix it.
