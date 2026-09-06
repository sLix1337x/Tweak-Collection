# Noverse (nohuto) source map

- **Source:** https://github.com/nohuto/win-config (repo, AGPL-3.0) → rendered docs at https://noverse.dev/docs/win-config (Starlight site). Accessed **2026-09-06**. All `/docs/...` links below are relative to `https://noverse.dev`.
- **License note:** AGPL-3.0. Use as research reference only; facts rewritten in our own words. Do NOT copy text/tables/scripts verbatim. Short factual fragments (registry paths, value names, GUIDs) are fine. Each section below cites its page URL.
- **Structure:** One large markdown file per category in the repo (`system/desc.md` 633 KB, `power` 173 KB, `privacy` 134 KB, `peripheral` 122 KB, `network` 114 KB, `security` 100 KB, `visibility` 92 KB, `nvidia` 80 KB, `misc` 38 KB, plus `affinities/`, `policies/`, `home.md`). Each `# Heading` = one page at `/docs/win-config/<category>/<slug>/`. Raw: `https://raw.githubusercontent.com/nohuto/win-config/main/<category>/desc.md`.
- **What it is:** docs for his paid (9.99 EUR lifetime) "WinConfig" tweaking tool, but the documentation itself is free and extremely deep — much of it is original reverse-engineering: decompiled kernel/driver pseudocode (ntoskrnl, mmcss, dxgkrnl, ndis, usbhub, storport, win32k) across builds 23H2→25H2, WinDbg captures, and ProcMon traces of what each Settings UI toggle actually writes. Sister doc sections on the same site (separate repos): `windbg-notes`, `regkit` (registry editor + records of values read at boot), `app-guides` (Mullvad, Brave, Discord, Steam, Spotify...).
- **Notable extras:** https://noverse.dev/diff (pseudocode diff viewer between Windows builds), https://noverse.dev/policies (ADMX policy browser), `cleanup/desc.md` exists in repo but is **not published** on the site (404).

---

# System section (/docs/win-config/system/)

## Priority Separation — /docs/win-config/system/priority-separation/
- Deep dive on `HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl\Win32PrioritySeparation` (2 hex digits: quantum table index / fixed-vs-variable / long-vs-short). Observed writes: `24` (0x18) and `38` (0x26) from the Performance Options dialog.
- Client default = variable + short quantums ("Programs"); server = fixed + long ("Background services"). 24H2 quantum tables: variable-short index 2 = 36 QU (~31.25 ms), fixed-short = 18 QU (~15.625 ms) for all indices; QU ≈ 0.868 ms on 24H2 vs 5.208 ms on 23H2.
- **Key finding:** `bcdedit /set disabledynamictick true` can break quantum expiration — with per-CPU clock-tick scheduling on, the stopped clock timer never calls `KiUpdateRunTime`, so `KPRCB.QuantumEnd` is never set. 24H2+ has `Feature_Servicing_Kernel_ClockTickIdleEstimateFix` which re-arms the timer and masks the bug. FG priority boost capped at priority 15, applies below RT range.
- On 24H2+, "Variable" quantums get overridden by `BamQosLevel` unless ≥ 8. He links his bitmask calculator for encoding values.

## MMCSS Values — /docs/win-config/system/mmcss-values/
- All values under `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile` (REG_DWORD), verified against mmcss.sys pseudocode: `SystemResponsiveness` (default 20; clamp 10–100; **100 disables MMCSS**), `NetworkThrottlingIndex` (default 10; 0xFFFFFFFF disables the throttle override; caps NBLs per receive DPC — NDIS hardcodes 64 max per processor), `NoLazyMode` (0), `IdleDetectionCycles` (2, range 1–31), `LazyModeTimeout` (1000000), `SchedulerTimerResolution` (10000, capped), `SchedulerPeriod` (100000, range 50000–1000000), `MaxThreadsPerProcess` (32, 8–128), `MaxThreadsTotal` (256, 64–65535). MMCSS scheduler thread runs at priority 27.

## Timer Expiration — /docs/win-config/system/timer-expiration/
- Kernel values `SerializeTimerExpiration` (default 1; forced on Modern Standby clients so CPU 0 is always clock owner; 2 = per-CPU tables) and `EnablePerCpuClockTickScheduling` (default 0, W11+). On 25H2 the two are decoupled. Explains why "server-style" timer tweaks do little on clients.

## DWM Values — /docs/win-config/system/dwm-values/
- Documents values read by dwm.exe from `HKLM\SOFTWARE\Microsoft\Windows\Dwm` (+ `...\Dwm\Scene`, `GpuAccelInkTiming`, `HKLM\SOFTWARE\Microsoft\Avalon.Graphics`), e.g. `ColorizationGlassAttribute`, `AnimationAttributionEnabled`/`HashingEnabled`. Mostly informational reverse-engineering, not tweak advice.

## Kernel Values — /docs/win-config/system/kernel-values/
- Catalog of the kernel's `CmControlVector` table: every registry value ntoskrnl reads at boot from `HKLM\SYSTEM\CurrentControlSet\Control\...` (Power, Session Manager\Power/Memory Management/Kernel incl. RNG subkey, ProductOptions). Cross-refs WER and WPBT values. Reference page for "which kernel values actually exist".

## Game Mode — /docs/win-config/system/game-mode/
- Mechanism: Resource Manager feature; registration gated by `HKCU\Software\Microsoft\GameBar\AutoGameModeEnabled` (nonzero/missing = on) and `HKLM\Software\Policies\Microsoft\Windows\GameDVR`. HKCU fallback GPU budget values: yield 2 / game mem 50 / DWM mem 30 (`GpuYieldPercentage`, `GpuGameMemoryBudgetPercentage`, `GpuDwmMemoryBudgetPercentage`).
- **Contrarian verdict:** Game Mode prevents the Win32PrioritySeparation FG boost, forces games out of `REALTIME_PRIORITY_CLASS` down to `NORMAL`, CPU Sets never observed applied, and its power-profile switch does nothing if the active scheme is already `GUID_MIN_POWER_SAVINGS` (High performance). Says FPS testing is the wrong way to evaluate it; check registration/effects via WPR/SI instead.

## DXG Kernel Values — /docs/win-config/system/dxg-kernel-values/
- Values read by dxgkrnl.sys/dxgmms2.sys from `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers` and subkeys (`Scheduler`, `MemoryManager`, `Paravirtualization`, `Power`, `BasicDisplay`, `Mdm`, `Smm`, `DMM`, `Validation`, `MonitorDataStore`). Reference material from pseudocode, 23H2 vs 25H2 differences noted.

## HAGS — /docs/win-config/system/hags/
- `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Scheduler\HwSchMode` (0 = OS default, 1 = off, 2 = on; ≥3 treated as 0), `HwQueuePacketCap` (1–14), `HwSchOverrideBlockList` (default 1), `HwSchTreatExperimentalAsStable` (default 0). Support is driver-reported via `DXGK_FEATURE_SUPPORT_*`; registry values are only overrides.

## Heap Type — /docs/win-config/system/heap-type/
- Segment Heap vs NT heap. Per-exe override via IFEO: `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<exe>\FrontEndHeapDebugOptions` (values 4 / 8 shown); global `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Segment Heap`.

## Memory Compression — /docs/win-config/system/memory-compression/
- `Enable/Disable-MMAgent -MemoryCompression` → CIM provider in sysmain.dll flips an admin bit in `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Superfetch` and (re)starts SysMain. Verify with `Get-MMAgent`. Neutral explanation, no "always disable" claim.

## Page Combining — /docs/win-config/system/page-combining/
- `DisablePageCombining` = 1 in `HKLM\System\CurrentControlSet\Control\Session Manager\Memory Management`; also MMAgent/Superfetch admin-bit path. Explains copy-on-write tradeoff.

## Disable Services/Drivers — /docs/win-config/system/disable-services-drivers/
- Big service/driver table with start types and binary paths. **Recommends only the "main" option** (telemetry/diagnostics/location-related), arguing most other services don't auto-start anyway. Examples: `PNRPAutoReg` (svchost -k LocalServicePeerNet), `CimFS`.

## Disable Scheduled Tasks — /docs/win-config/system/disable-scheduled-tasks/
- Task table w/ actions, e.g. `Microsoft Compatibility Appraiser` (`sc.exe start InventorySvc`), `DiskCleanup\SilentCleanup` (`cleanmgr.exe /autocleanstoragesense`), `SynchronizeTime` (starts w32time), `WindowsUpdate\Scheduled Start` (starts wuauserv), Chkdsk tasks. Parser script `ScheduledTasksList.ps1` in repo assets.

## BCD Edits — /docs/win-config/system/bcd-edits/
- BCD = hive `HKLM\BCD00000000\Objects\{GUID}\Elements\XXXXXXXX` (UEFI file `\EFI\Microsoft\Boot\BCD`); inspect with `bcdedit /enum all /v`. Documents element IDs per object ({current}, {bootmgr}, {resume}, {memdiag}, {badmemory}). Notes some popular BCD tweaks (e.g. `HalpTscSyncPolicy`) are no longer used on recent Windows.

## Page File — /docs/win-config/system/page-file/
- Marked "will be updated soon". Currently: clear-pagefile-at-shutdown security option (longer shutdowns vs offline data exposure).

## Disable Notifications — /docs/win-config/system/disable-notifications/
- `WnsEndpoint` (REG_SZ) for push notifications; per-app `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings`; Storage Sense reminder values; `HKCU\Software\Microsoft\Windows\MiracastDiscovery\DisableNotification`; notification duration under `HKCU\Control Panel\Accessibility`.

## Minimal Window Snapping — /docs/win-config/system/minimal-window-snapping/
- Keeps snapping, kills extras: `HKCU\...\Explorer\Advanced` `SnapAssist`, `EnableSnapAssistFlyout`, `EnableSnapBar`, `EnableTaskGroups`, `DisallowShaking`; `HKCU\Control Panel\Desktop\WindowArrangementActive`; policy `NoWindowMinimizingShortcuts`.

## File System Values — /docs/win-config/system/file-system-values/
- `HKLM\System\CurrentControlSet\Control\FileSystem`: `NtfsDisableSpotCorruptionHandling`, `LongPathsEnabled`, more; full boot-read value list in his regkit `records/FileSystem.txt`.

## Disable Hyper-V — /docs/win-config/system/disable-hyper-v/
- Explains type-1 hypervisor; disabling removes VBS/HVCI basis (cross-ref security section).

## Service Splitting — /docs/win-config/system/service-splitting/
- `SvcHostSplitDisable` under `HKLM\SYSTEM\CurrentControlSet\Control`; per-service `HKLM\...\Services\<svc>` split config. **He keeps the client default** — grouping reduces svchost count but loses isolation; notes <3.5 GB RAM systems don't split anyway. Check count: `(Get-Process svchost).Count`.

## Disable Storage Sense — /docs/win-config/system/disable-storage-sense/
- `HKCU\...\StorageSense\Parameters\StoragePolicy\<01,04,08,32,256,512,2048>` flags + `HKLM\Software\Policies\Microsoft\Windows\StorageSense` policies (`AllowStorageSenseGlobal`, thresholds).

## Disable Accessibility Features — /docs/win-config/system/disable-accessibility-features/
- Disables Narrator/Magnifier/OSK/Voice Access/Live Captions; per-feature sub-options. Uses `HKCU\Control Panel\Desktop\UserPreferencesMask` bitmask variants, `DynamicScrollbars`, `WindowMetrics\MinAnimate`, `EnableTransparency`.

## Disable Windows Search — /docs/win-config/system/disable-windows-search/
- Replaces with Everything (voidtools) + StartAllBack. Policies under `HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search`: `DisableSearch`, `DisableWebSearch`, `ConnectedSearchUseWeb`, `PreventRemoteQueries`, `PreventIndexOnBattery`; `HKCU\...\SearchSettings\IsDynamicSearchBoxEnabled` = 0.

## Enable FSO — /docs/win-config/system/enable-fso/
- "Disable fullscreen optimizations" compat checkbox writes `~ DISABLEDXMAXIMIZEDWINDOWEDMODE` into `HKCU|HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers\<exe>`. Notes `GameDVR_DSEBehavior` strings in ResourcePolicyServer.dll. Page marked as pending update.

- **Time Zone** — /docs/win-config/system/time-zone/ — `Get-TimeZone -ListAvailable`.
- **Display Scaling** — /docs/win-config/system/display-scaling/ — per-monitor `DpiValue` in `GraphicsDrivers\ScaleFactors\<MONITORID>` and `HKCU\Control Panel\Desktop\PerMonitorSettings`.
- **Detailed Status Messages** — /docs/win-config/system/detailed-status-messages/ — `VerboseStatus` policy.
- **Disable Autoruns** — /docs/win-config/system/disable-autoruns/ — Sysinternals Autoruns workflow; Run keys; app-offloading (`EnableAppOffloading`) + `AllowAutomaticAppArchiving` policy.
- **Export Explorer/Taskbar Pins** — /docs/win-config/system/export-explorer-taskbar-pins/ — pins in `f01b4d95cf55d32a.automaticDestinations-ms`; taskbar pins in `HKCU\...\Explorer\Taskband` ("Favorites").

## Disable Hung Screen — /docs/win-config/system/disable-hung-screen/ — auto-terminates hung apps; **notes `WaitToKillServiceTimeout` actually defaults to 5000 on W11** (Windows Internals says 20000), win32kbase confirms 5000; advises leaving timeouts at default.

---

# Network section (/docs/win-config/network/)

## Encrypted DNS — /docs/win-config/network/encrypted-dns/ — DoH per-interface: `Dnscache\InterfaceSpecificParameters\{NetID}\DohInterfaceSettings\Doh\<ip>\DohTemplate` + `DohFlags` (REG_QWORD), `Tcpip\Parameters\Interfaces\{NetID}\NameServer`. Provider templates: Mullvad, Quad9, AdGuard, Cloudflare.
## Enable Network Offloads — /docs/win-config/network/enable-network-offloads/ — keeps task offloads on (checksum, LSO, IPsec) but **disables PM (power management) protocol offloads**; keys `TCPIP\Parameters`, `Ipsec`, NIC class key `{4D36E972-...}\00XX`; inspect via `!ndiskd.netadapter`.
## SMB — /docs/win-config/network/smb/ — SMBv1 stays disabled (`LanmanServer\Parameters\SMB1`=0, `Disable-WindowsOptionalFeature SMB1Protocol`); client via `Set-SmbClientConfiguration`, server via `Set-SmbServerConfiguration`.
## Disable Network Discovery — /docs/win-config/network/disable-network-discovery/ — LLTDIO/Responder (LLTD) protocol drivers.
## NDIS Poll Mode — /docs/win-config/network/ndis-poll-mode/ — NDIS 6.85+ DPC-replacement polling model; INF keyword `*NdisPoll` (default 1); NVIDIA WinOF-2 (mlx5) `RecvCompletionMethod` ranges noted.
## Congestion Provider — /docs/win-config/network/congestion-provider/ — `Get-NetTCPSetting`; templates Internet/Datacenter/Compat/Custom; providers: Default = **CUBIC**, CTCP (loss+delay), DCTCP (ECN). Explains when each matters.
## Speed & Duplex — /docs/win-config/network/speed-duplex/ — always full-duplex; `*SpeedDuplex` under NIC class key `Ndi\Params`.
## Disable Wi-Fi — /docs/win-config/network/disable-wi-fi/ — Wi-Fi services/drivers/tasks off.
## Static IP — /docs/win-config/network/static-ip/ — reads `netsh int ip show config`, applies via registry; requires manual DNS.
## Disable Active Probing — /docs/win-config/network/disable-active-probing/ — NCSI probes to `www.msftconnecttest.com/connecttest.txt`; policies `NoActiveProbe`, `DisablePassivePolling`.
## Disable VPNs — /docs/win-config/network/disable-vpns/ — `Get-VpnConnection`/`Remove-VpnConnection`.
## Disable NetBIOS/mDNS/LLMNR — /docs/win-config/network/disable-netbios-mdns-llmnr/ — `NetBT\Parameters\Interfaces\Tcpip_<guid>\NetbiosOptions`=2; DNSClient policies `EnableMDNS`=0, `EnableMulticast`=0 (LLMNR), `EnableNetbios`, `DisableSmartNameResolution`.
## Disable IPv6 — /docs/win-config/network/disable-ipv6/ — **warns `DisabledComponents=0xFFFFFFFF` breaks needed interfaces and adds ~5s boot delay**; use proper 0xFF-style bitmask per MS guidance.
## Disable Wi-Fi Sense — /docs/win-config/network/disable-wi-fi-sense/ — dead since W10 1803; historical only.
## Disable WoL — /docs/win-config/network/disable-wol/ — `powercfg /devicequery wake_programmable|wake_armed`; NIC class key wake settings.
## Network Buffers — /docs/win-config/network/network-buffers/ — Intel TX/RX buffer sizes are per-adapter (INF min/max differ); does **not** blindly apply max.
## Interrupt Moderation — /docs/win-config/network/interrupt-moderation/ — CPU-vs-latency tradeoff; per-adapter levels/coalescing params.
## Enable RSS — /docs/win-config/network/enable-rss/ — Receive-Side Scaling across queues/CPUs.
## Disable ICS / Mobile Hotspot — /docs/win-config/network/disable-ics-mobile-hotspot/ — ICS NAT/DHCP service; policy `NC_ShowSharedAccessUI`.
## Disable LLSE — /docs/win-config/network/disable-llse/ — link-state event logging off.
## Disable Flow Control — /docs/win-config/network/disable-flow-control/ — 802.3x pause frames; needs link-partner support.
## Enable Jumbo Packets — /docs/win-config/network/enable-jumbo-packets/ — "**you won't use this feature**"; only if every device on path supports the same frame size.
## Disable VMQ — /docs/win-config/network/disable-vmq/ — Hyper-V switch scaling; irrelevant without VMs.
## Disable SR-IOV — /docs/win-config/network/disable-sr-iov/ — PCIe virtualization, Hyper-V only.
## Disable FEC — /docs/win-config/network/disable-fec/ — forward error correction adds latency, improves stability.
## Disable File/Printer Sharing — /docs/win-config/network/disable-file-printer-sharing/ — firewall group `@FirewallAPI.dll,-28502`, `ms_server` binding.
## Disable Microsoft Client/Multiplexor — /docs/win-config/network/disable-microsoft-client-multiplexor/ — unbinds `ms_msclient` (SMB client) and `ms_implat` (NIC teaming).
## QoS Policy — /docs/win-config/network/qos-policy/ — policy QoS via `HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS\<name>` (app, protocol, ports, DSCP, throttle); Fortnite example.
## Enable Legacy Switch Compatibility Mode — /docs/win-config/network/enable-legacy-switch-compatibility-mode/ — undocumented NIC setting for old-switch negotiation issues.

---

# NVIDIA section (/docs/win-config/nvidia/)

## Bitmask Calculator — /docs/win-config/nvidia/bitmask-calculator/ — his tool (https://noverse.dev/#bitmask) that decodes NVIDIA DWORD bitfields using official definitions and can `reg add` them, e.g. `RMElcg` = 1431655765 into GPU class key `{4d36e968-...}\000X`.
## NVCPL Settings — /docs/win-config/nvidia/nvcpl-settings/ — "Minimal" (G-SYNC/AA/sharpening/AO/NIS/Ansel off) vs "Compatible" profiles; ProcMon captures of what NVCPL writes: `nvlddmkm\Global\NVTweak` (`NvCplPhysxAuto`, `RmProfilingAdminOnly`), `nvlddmkm\NVAPI\physxGpuId`, per-display color/range values under class key `0000` (`_User_*` values), `HKCU\Software\NVIDIA Corporation\Global\NVTweak\Devices\<id>\Color`.
## Debloated Driver — /docs/win-config/nvidia/debloated-driver/ — his `NVIDIA-Tool.ps1`: option 1 debloats driver (optional DDU clean uninstall), option 2 installs directly; pulls driver list from TechPowerUp.
## NvAPI CLI — /docs/win-config/nvidia/nvapi-cli/ — his CLI wrapping NVIDIA NVAPI (~400 functions) for GPU/display/driver query & control; separate docs at /docs/nvapi-cli/.
## Temporary NVCPL — /docs/win-config/nvidia/temporary-nvcpl/ — `nvcpl.ps1` starts `NVDisplay.Container.exe` + nvcpl, kills them on close (no persistent container).
## Hide Tray Icon — /docs/win-config/nvidia/hide-tray-icon/ — values in `nvlddmkm\Global\NVTweak` + `HKCU\...\NvCplApi\Policies`; only first value used.
## Disable DLSS Indicator — /docs/win-config/nvidia/disable-dlss-indicator/ — `HKLM\SOFTWARE\NVIDIA Corporation\Global\NGXCore` value: 1024 = on, 0 = off.
## Disable Logging — /docs/win-config/nvidia/disable-logging/ — driver logging off.
## Disable Scheduled Tasks — /docs/win-config/nvidia/disable-scheduled-tasks/ — `NvTmMon` (hourly), `NvTmRepOnLogon`, `NvTmRep` (daily 12:25) crash/telemetry reporter tasks; notes they're no longer created on recent drivers.
## Disable Telemetry — /docs/win-config/nvidia/disable-telemetry/ — debloated driver first; **debunks the commonly copied "NVIDIA telemetry" registry values (`HKLM\SOFTWARE\NVIDIA Corporation\Global\FTS`, HKCU opt-in/out) as outdated/nonexistent** — verified against driver binaries.
## Enable Developer Settings — /docs/win-config/nvidia/enable-developer-settings/ — exposes hidden NVCPL developer section.
## Remove Context Menu Entry — /docs/win-config/nvidia/remove-context-menu-entry/ — desktop context menu toggle.
## NVLDDMKM Hex Values — /docs/win-config/nvidia/nvlddmkm-hex-values/ — documents `nvlddmkm\State` hive and `D3DOGL_*` workstation-setting DWORDs (bitfields/samples attributes); **advises not to change them — informational only**.
## OC/UV Guide — /docs/win-config/nvidia/oc-uv-guide/ — MSI Afterburner OC/UV workflow + HWiNFO monitoring; autostart profile via `schtasks /create /sc ONSTART ... MSIAfterburner.exe /profile1`; VBIOS part omitted.

---

# Peripheral section (/docs/win-config/peripheral/)

## Mouse Values — /docs/win-config/peripheral/mouse-values/ — **raw-input throttling**: `RawMouseThrottleDuration` = 8 (≈125 Hz cap for background raw listeners), `RawMouseThrottleForced` = 0 by default. Acceleration off via `HKCU\Control Panel\Mouse\MouseThreshold1/2` = 0, `MouseSpeed` = 0 (defaults 6/10/1); `MouseSensitivity` reapplies pointer speed.
## Sample Rate — /docs/win-config/peripheral/sample-rate/ — per-endpoint default format under `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\{Render|Capture}\{Endpoint}`.
## Sound Mode — /docs/win-config/peripheral/sound-mode/ — spatial sound config `HKLM\Software\Microsoft\Windows\CurrentVersion\Audio\Policy\Spatial`; mono mix `HKCU\Software\Microsoft\Multimedia\Audio\AccessibilityMonoMixState`.
## Disable Audio Enhancements — /docs/win-config/peripheral/disable-audio-enhancements/ — per-endpoint APO/property-store toggles under MMDevices.
## USBFlags Values — /docs/win-config/peripheral/usbflags-values/ — per-device `HKLM\SYSTEM\CurrentControlSet\Control\usbflags\<vvvvpppprrrr>` names resolved from usbhub3 pseudocode; also `Control\usb\UsbLtm`, `AutomaticSurpriseRemoval`, `HardwareVerifier`.
## USB Values — /docs/win-config/peripheral/usb-values/ — usbhub.sys-read values, e.g. `Control\usb\Usb20HardwareLpm` (LPM off direction); nonzero = bool semantics noted.
## USBHUB Values — /docs/win-config/peripheral/usbhub-values/ — `Services\USBHUB\hubg` global key, `uxd_control\{policy,devices,pnp}` subkeys.
## Keyboard Values — /docs/win-config/peripheral/keyboard-values/ — disables language-switch hotkeys: `HKCU\Keyboard Layout\Toggle\{Language Hotkey,Hotkey,Layout Hotkey}` = 3.
## Audio Values — /docs/win-config/peripheral/audio-values/ — audiosrv/audiodg values: `...\CurrentVersion\Audio\Parameters`, `Policy`, `Spatial`, Atmos license debug, HoloSI.
## StorNVMe Values — /docs/win-config/peripheral/stornvme-values/ — `Services\stornvme\Parameters[\Device]`; many values matched per device-id `VEN_vvvv&DEV_dddd`; author flags some applied data as speculative.
## StorPort Values — /docs/win-config/peripheral/storport-values/ — full storport.sys value list: `Control\StorPort[\Verifier]`, `Control\Storage\StorageTelemetry`.
## Audio Ducking — /docs/win-config/peripheral/audio-ducking/ — `HKCU\Software\Microsoft\Multimedia\Audio\UserDuckingPreference` (0–3).
## Disable AutoPlay/Autorun — /docs/win-config/peripheral/disable-autoplay-autorun/ — `AutoplayHandlers\DisableAutoplay`=1 + per-event `MSTakeNoAction` defaults.
## Disable Touch & Tablet — /docs/win-config/peripheral/disable-touch-tablet/ — `pnputil /disable-device` for HID touch screen; `Wisp\Touch`, `PrecisionTouchPad`, TabletPC policies.
- Simple toggle pages (slug = kebab-case title): Disable Bluetooth, Device Manager, Disable Wake on Input, Disable Dynamic Lighting, Disable System Sounds, Disable Printers, Monitor Settings.

---

# Power section (/docs/win-config/power/)

## xHCI IMOD — /docs/win-config/power/xhci-imod/ — xHCI Interrupter Moderation register (IMODI/IMODC): min time between USB controller interrupts; register-level documentation.
## Power Plan — /docs/win-config/power/power-plan/ — his plan = **clone of `SCHEME_MIN` (High performance) with ~60 changes**: disables core parking, USB selective suspend, (deep) sleep, battery features, display dimming, disk power savings, slideshow/PAPB; keeps processor idle enabled ("shouldn't be changed"). Every setting documented with PowerCfg alias + GUID in `power/assets/power-settings/*.md` (~100 files, incl. full core-parking CP* and hetero-scheduling parameter docs). Desktop-oriented.
## Disable Timer Coalescing — /docs/win-config/power/disable-timer-coalescing/ — `TimerCoalescing` REG_BINARY (80 bytes = 20 DWORDs = two 4-entry tolerance blocks) under `HKLM\SYSTEM\CurrentControlSet\Control\Power`; from win32kfull `InitTimerCoalescing`.
## PnP Device Values — /docs/win-config/power/pnp-device-values/ — per-device `HKLM\SYSTEM\CurrentControlSet\Enum\<enum>\<devID>\<instID>\Device Parameters` (+ Wdf, Ceip, `Interrupt Management\MessageSignaledInterruptProperties` MSI config); applied for USB enumerator: kills selective suspend/idle/LP features.
## Power Values — /docs/win-config/power/power-values/ — `Control\Power` values: `HibernateEnabled`, `ForceHibernateDisabled`, `HiberFileBucket`, `ModernSleep`, `PowerThrottling`, `Control\Storage`; **author explicitly warns some applied data is speculation**; power-symbols.txt reference.
## USB Audio Idle — /docs/win-config/power/usb-audio-idle/ — audio class `{4d36e96c-...}\00xx\PowerSettings` idle-timeout (D0→D3) values.
## Disable NIC Power Savings — /docs/win-config/power/disable-nic-power-savings/ — NIC class key `{4D36E972-...}\00XX` power values; per-adapter INF defaults; Intel NIC assets in repo.
## Disable Hibernation — /docs/win-config/power/disable-hibernation/ — `powercfg /hibernate off` also kills Fast Startup + hybrid sleep; `HibernateEnabled`, `Session Manager\Power`, hiberfile types (`powercfg /h /type full|reduced`).
## Remove Power Options — /docs/win-config/power/remove-power-options/ — hides Hibernate/Lock/Sleep from menus: `Explorer\FlyoutMenuSettings\ShowLockOption` etc., `PolicyManager\default\Start\Hide*`, policies `ShowSleepOption`/`ShowHibernateOption`.
## Disable Energy Estimation — /docs/win-config/power/disable-energy-estimation/ — per-process energy tracking off; partmgr `IdleStatesN...` caveats.

---

# Privacy section (/docs/win-config/privacy/) — 43 pages, mostly policy-key documentation

- **App Configuration** — /privacy/app-configuration/ → links to app-guides repo.
- **Disable General Telemetry** — /privacy/disable-general-telemetry/ — DiagTrack service values, `HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\DataCollection`, CEIP, inking/typing personalization, app-launch tracking.
- **Disable WER** — /privacy/disable-wer/ — WER internals incl. `TimeStampEnabled`/`TimeStampInterval` (Reliability keys; policy key uses seconds, non-policy minutes).
- **Troubleshooter Preference** — /privacy/troubleshooter-preference/ — `HKLM\SOFTWARE\Microsoft\WindowsMitigation\UserPreference` (1/2/3).
- **Disable Suggestions/Tips/Tricks** — /privacy/disable-suggestions-tips-tricks/ — `SubscribedContent-*` values (only `338389` exists by default — he reverse-searched the rest); CloudContent policies.
- **Disable Automatic Map Downloads** — /privacy/disable-automatic-map-downloads/ — Maps policies `AutoDownloadAndUpdateMapData`, metered-connection values, moshostcore.
- **Disable Time Sync** — /privacy/disable-time-sync/ — w32time/NtpClient policy; warns about clock drift/cert issues.
- **Disable Cross-Device Experiences** — /privacy/disable-cross-device-experiences/ — `HKCU\...\CDP\RomeSdkChannelUserAuthzPolicy`, `CdpSessionUserAuthzPolicy`.
- **Disable Phone Linking** — /privacy/disable-phone-linking/ — `CrossDeviceResume\Configuration\IsResumeAllowed`; policy `EnableMmx`.
- **Hide Last Logged-In User** — /privacy/hide-last-logged-in-user/ — `DontDisplayLastUserName`/`DontDisplayUserName`; warns passwordless users must type username.
- **Disable Background Apps** — /privacy/disable-background-apps/ — AppPrivacy `LetAppsRunInBackground`; warns it breaks notifications/sync for UWP.
- **Disable Apps for Websites** — /privacy/disable-apps-for-websites/ — web-to-app linking off; `HttpAcceptLanguageOptOut`.
- **Disable Clipboard** — /privacy/disable-clipboard/ — `AllowClipboardHistory`, `AllowCrossDeviceClipboard`, TS `fDisableClip` policies.
- **Disable Auto Maintenance** — /privacy/disable-auto-maintenance/ — **says there's no real reason to disable it** (runs only at idle); documents anyway.
- **Disable Microsoft Copilot** — /privacy/disable-microsoft-copilot/ — `HKCU\SOFTWARE\Microsoft\Windows\Shell\Copilot` values, `CopilotDisabledReason`.
- **Disable Recall** — /privacy/disable-recall/ — WindowsAI policies `DisableAIDataAnalysis`, `AllowRecallEnablement`, `DisableClickToDo`.
- **Disable Xbox Game Bar** — /privacy/disable-xbox-game-bar/ · **Location Access** — /privacy/disable-location-access/ · **Sensors** — /privacy/disable-sensors/ · **Biometrics** — /privacy/disable-biometrics/ · **Camera** — /privacy/disable-camera/ · **Cortana** — /privacy/disable-cortana/ · **Find My Device** — /privacy/disable-find-my-device/ · **Activity History** — /privacy/disable-activity-history/ · **File History** — /privacy/disable-file-history/ · **Clipboard/Sync** — /privacy/disable-synchronization/ — standard policy/value toggles.
- **Disable PowerShell & .NET Telemetry** — /privacy/disable-powershell-net-telemetry/ — env vars `POWERSHELL_TELEMETRY_OPTOUT`, `DOTNET_CLI_TELEMETRY_OPTOUT` etc.
- Remaining pages (each documents exact keys/policies; deep-read individually, slug = kebab-case title): Disable Xbox Game Bar, Disable Location Access, Disable Sensors, Disable Biometrics, Disable Camera, Disable Cortana, Disable Find My Device, Disable Activity History, Disable File History, Disable Synchronization, Disable Remote Desktop, Deny App Access (CapabilityAccessManager per-permission denies), Disable Startup ETS, Disable Text Input Hosts, Disable MDM Enrollment, Disable DRM Internet Access, Disable Sleep Study, Disable CSC (Offline Files), Disable Cloud Content Search, Microsoft Accounts, Disable Font Providers, Disable Thumbnail Caching, Disable Application Compatibility, Disable OneSettings Download, Disable F1 Help Key, Disable WMPlayer Telemetry.

---

# Security section (/docs/win-config/security/) — 23 pages

- **Increase TDR** — /security/increase-tdr/ — TDR (Timeout Detection & Recovery) values under `HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers`; **recommends keeping TDR enabled** (contradicts "disable TDR" tweak lore) — option only raises the timeout.
- **Process Mitigations** — /security/process-mitigations/ — `Session Manager\kernel\MitigationOptions`/`MitigationAuditOptions` (REG_BINARY, 24 bytes); full mitigation tables; warns anti-cheat/overlays/old games can break.
- **Disable WPBT** — /security/disable-wpbt/ — `DisableWpbtExecution` in `Session Manager` (smss.exe); blocks vendor ACPI WPBT auto-run binaries (ASUS etc.).
- **DMA Remapping** — /security/dma-remapping/ — IOMMU/Kernel DMA Protection explainer.
- **Disable VBS (HVCI)** — /security/disable-vbs-hvci/ — VBS needs Hyper-V; HVCI/Device Guard/Credential Guard relationships; `Set-VMSecurity -VirtualizationBasedSecurityOptOut`.
- **Windows Firewall** — /security/windows-firewall/ — WFP-based; `SharedAccess\Parameters\FirewallPolicy\{profile}` (`EnableFirewall`, `DefaultInboundAction`, `DoNotAllowExceptions`).
- **Windows Defender** — /security/windows-defender/ — `Get-MpComputerStatus` AMRunningMode; SmartScreen policies (`EnableSmartScreen`, `EnabledV9`).
- **Windows Update** — /security/windows-update/ — driver search order, device metadata, root-cert auto-update policies.
- Simple single-topic pages (slug = kebab-case title): UAC, PS Execution Policy, Sudo (W11), Password Age, Enable Dynamic Lock, Enable Camera OSD Indicator, Administrator Account, Guest Account, defaultuser0 Account.
- **Disable Bitlocker & EFS** — /security/disable-bitlocker-efs/ — `Disable-BitLocker`, `fsutil behavior set disableencryption 1`.
- **Disable P2P Updates** — /security/disable-p2p-updates/ — Delivery Optimization `DODownloadMode`; default is LAN.
- **Disable System Restore** — /security/disable-system-restore/ — `Disable-ComputerRestore`, `RPSessionInterval`=0, `DisableConfig` policy.
- **Disable Downloads Blocking** — /security/disable-downloads-blocking/ — Zone.Identifier/MotW ADS; `SaveZoneInformation` policy.
- **Disable Password Reveal** — /security/disable-password-reveal/ — CredUI `DisablePasswordReveal`.
- **Enable USB Write Protection** — /security/enable-usb-write-protection/ — RemovableStorage `Deny_Write` policy / diskpart readonly.

---

# Visibility section (/docs/win-config/visibility/) — 25 pages, cosmetic, low gaming relevance

Slug = kebab-case title under `/docs/win-config/visibility/`: Explorer Options, Desktop Wallpaper, Pointer Style, Disable Rounded Corners, Night Light, Minimal Visual Effects (`UserPreferencesMask`), Enable Dark Theme, Disable Transparency, Disable Animations, Taskbar Settings, Accent Color, Account Picture, System Fonts, Mouse Hover Time, Disable Audio/Video Preview, Classic Context Menu (W11→W10), Hide Shortcut Icon, Desktop Icon Spacing, Detailed File Transfer, Alt-Tab App Tabs, Hide Lock Screen, PowerShell Colors, Classic Control Panel, OEM Information, Settings Page Visibility.

---

# Misc / Policies / Affinities

## RegKit — /docs/win-config/misc/regkit/ — his registry editor (github.com/nohuto/regkit) + boot-activity value records; docs at /docs/regkit/ (ProcMon + WPR/WPA tracing guides).
## NVFetch — /docs/win-config/misc/nvfetch/ — his neofetch/fastfetch replacement; Get-CimInstance + nvidia-smi.
## Explorer Blur — /docs/win-config/misc/explorer-blur/ — installs ExplorerBlurMica + config.ini.
## StartAllBack Config — /docs/win-config/misc/startallback-config/ — his StartAllBackCfg settings + every `HKCU\Software\StartIsBack` value SAB reads.
## System Informer — /docs/win-config/misc/system-informer/ — replace Task Manager; SI uses clock-cycle counters vs TM's interval timer (shows short-burst threads TM misses).
## 7-Zip Settings — /docs/win-config/misc/7-zip-settings/ — minimal context menu via `HKCU\Software\7-Zip\Options` (`CascadedMenu`, `ElimDupExtract`, `MenuIcons`); suggests NanaZip.
## Disable VS Telemetry — /docs/win-config/misc/disable-vs-telemetry/ — VSCommon SQM keys, Feedback policies, DiagnosticsHub, license cleanup.
## Disable MS Office Telemetry — /docs/win-config/misc/disable-ms-office-telemetry/ — Office 16.0 OSM `preventedapplications`/`preventedsolutiontypes`, CEIP opt-out, telemetry agent tasks.
## OneDrive — /docs/win-config/misc/onedrive/ — `OneDriveSetup.exe /uninstall` + leftover/Run-key cleanup + policies.
## Hash Generator — /docs/win-config/misc/hash-generator/ — Get-FileHash wrapper (MD5/SHA1/256/384/512).

## Windows Policies — /docs/win-config/policies/ — output of his **admx-parser** (PolicyDefinitions → JSON/YAML); powers the https://noverse.dev/policies browser linked throughout all pages.

## Interrupt Handling & Affinities — /docs/win-config/affinities/interrupt-handling-affinities/
- IRQ affinity policy table (`IrqPolicyMachineDefault` … `IrqPolicySpecifiedProcessors`, `IrqPolicySpreadMessagesAcrossAllProcessors` needs MSI-X); pin device interrupts via affinity mask in `AssignmentSetOverride` (mask calc example: CPUs 8+9 → 0x300); IRQ priorities; validation workflow with WPR (`wpr -start CPU.light -start GPU.light`) + MXA, dragging e.g. `nvlddmkm.sys` ISRs/DPCs per core. Marked "to be extended".

## Cleanup (REPO ONLY — not on site) — https://github.com/nohuto/win-config/blob/main/cleanup/desc.md
- 26 cleanup topics: WinSxS, Windows.old, SRUM data, DirectX shader cache, shadow copies, quick-access lists, MUI cache, font cache, delivery optimization files, temp files, clipboard history, DNS cache, WER files, Defender scans, event logs, WU cache, thumbnail cache, prefetch, BSoD dumps, product key, system logs. Deep-read raw file if needed.

---

# noverse.dev/projects & /product (tools he ships)

From https://noverse.dev/projects and https://noverse.dev/product (accessed 2026-09-06):
- **WinConfig** (product, 9.99 EUR lifetime): GUI tool applying everything documented in win-config; transparent logs (value name/data/type per change, recursive-change counts, shown PowerShell); per-section templates; strict dynamic state detection (option shows "disabled" unless all expected values match); settings via `HKCU\Software\Noverse` (search filters, `SearchDelayMs`, theme/accent). Hardware-bound license (SMBIOS UUID + baseboard serial + CPU ID); Discord-role delivery.
- **RegKit** — registry editor with extra features + boot/registry-activity records. **Bitmask Calculator** — NVIDIA bitfield decoder/applier. **NvAPI CLI** — ~400-function NVAPI command line. **NVFetch** — HW/OS info CLI.
- **Component Manager** (comp-mgr) — manage Windows packages/optional features/capabilities. **Blocklist Manager** (blocklist-mgr) — hosts/URL blocklist picker GUI. **ADMX Parser** — PolicyDefinitions → JSON/YAML. **App Guides / Game Tools** — per-app privacy configs (Mullvad, Brave, Discord, Steam, Spotify, SteelSeries, LGHUB, VSC) and auto game-config tools (VALORANT, Fortnite, Marvel Rivals, CS2, Overwatch).
- **DISM WSIM** guide — custom automated Windows install images. **PBO2 UV Guide**, **GPU OC/UV Guide**. **Decompiled Pseudocode / Type Layouts / Globals** — the RE data repos powering the docs. **PowerShell Minifier / Void Obfuscation / reg2bat / PS12bat / strings2 TUI** — smaller utilities.

---

# Topic index

- **Win32PrioritySeparation / quantum / scheduling** → system/priority-separation; system/timer-expiration; windbg-notes threads section
- **MMCSS** → system/mmcss-values (SystemResponsiveness/NetworkThrottlingIndex verified limits); NDIS NBL cap also there
- **Timers / dynamic tick** → system/timer-expiration; system/priority-separation (disabledynamictick bug + 24H2 ClockTickIdleEstimateFix); power/disable-timer-coalescing
- **Game Mode / FSO / GameDVR** → system/game-mode (contrarian verdict); system/enable-fso; privacy/disable-xbox-game-bar
- **HAGS / GPU scheduling / DXG kernel** → system/hags; system/dxg-kernel-values; security/increase-tdr (TDR)
- **DWM / compositing / animations** → system/dwm-values; visibility (rounded corners, transparency, animations, visual effects)
- **NVIDIA driver/NVCPL/registry** → nvidia/* (debloated-driver, nvcpl-settings, bitmask-calculator, nvapi-cli, nvlddmkm-hex-values, telemetry-debunk, oc-uv-guide)
- **Memory (compression/combining/pagefile/heap)** → system/memory-compression; system/page-combining; system/page-file; system/heap-type
- **Services & scheduled tasks (debloat)** → system/disable-services-drivers; system/disable-scheduled-tasks; nvidia/disable-scheduled-tasks; peripheral/disable-* (bluetooth/printers/touch)
- **BCD / boot** → system/bcd-edits; system/disable-hyper-v
- **Power plan / CPU parking / PPM** → power/power-plan (+ ~100 per-setting files under power/assets/power-settings/); power/power-values; power/disable-hibernation; power/disable-energy-estimation
- **USB / xHCI / input latency** → power/xhci-imod; power/pnp-device-values; peripheral/usb-values, usbflags-values, usbhub-values; peripheral/mouse-values (RawMouseThrottle*); peripheral/keyboard-values
- **Storage (NVMe/StorPort)** → peripheral/stornvme-values; peripheral/storport-values; system/file-system-values
- **Audio** → peripheral/sample-rate, sound-mode, disable-audio-enhancements, audio-values, audio-ducking; power/usb-audio-idle; system/mmcss-values
- **Network (latency/offloads/TCP)** → network/ndis-poll-mode, congestion-provider (CUBIC/CTCP/DCTCP), interrupt-moderation, network-buffers, enable-rss, disable-flow-control, enable-network-offloads, speed-duplex, disable-fec; network/disable-ipv6 (0xFFFFFFFF boot-delay warning); encrypted-dns; smb; qos-policy; disable-netbios-mdns-llmnr
- **Interrupt affinity / MSI-X** → affinities/interrupt-handling-affinities; power/pnp-device-values (MessageSignaledInterruptProperties)
- **Privacy / telemetry / debloat** → privacy/disable-general-telemetry (DiagTrack/DataCollection), disable-wer, disable-suggestions-tips-tricks (SubscribedContent), disable-microsoft-copilot, disable-recall, disable-background-apps; misc/onedrive, disable-vs-telemetry, disable-ms-office-telemetry; nvidia/disable-telemetry (debunks fake NVIDIA telemetry values)
- **Security/VBS/Defender** → security/disable-vbs-hvci, windows-defender, process-mitigations, disable-wpbt, windows-firewall
- **BIOS/firmware-adjacent** → security/disable-wpbt (vendor ACPI auto-exec), security/dma-remapping; projects → PBO2 UV Guide; no dedicated BIOS page
- **Search/Start/shell replacement** → system/disable-windows-search (Everything + StartAllBack); misc/startallback-config, explorer-blur, system-informer
- **Cleanup/disk** → repo-only cleanup/desc.md (26 topics)
- **Policies reference** → policies page + noverse.dev/policies (admx-parser output); cross-linked from nearly every page
- **Tools** → projects page: WinConfig (paid GUI), RegKit, Bitmask Calculator, NvAPI CLI, NVFetch, Component Manager, Blocklist Manager, ADMX Parser, Game Tools, DISM WSIM guide
