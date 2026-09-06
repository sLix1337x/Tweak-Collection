# TenForums Gaming Tweaks — Page 2

Source: https://www.tenforums.com/gaming/117377-share-gaming-tweaks-chec-my-comprehensive-list-will-blow-your-mind-2.html

(Note: the `...-page2.html` URL form silently redirects to page 1; this is the real page 2, containing posts #11–20, dated 23 Nov 2019 – 05 Nov 2020.)

This page contains one substantial community tweak dump — smirk24's registry/services/page-file list (26 Jul 2020) — plus a long commentary reply from the OP "empleat" evaluating each item and adding caveats, and a page-file/standby-memory discussion. The rest is lighter hardware chatter and meta-discussion about the guide itself.

---

## Registry tweaks (from smirk24, 26 Jul 2020)

Full .reg content posted verbatim by smirk24:

```
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\PriorityControl]
"Win32PrioritySeparation"=dword:00000018

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Session Manager\Memory Management]
"DisablePagingExecutive"=dword:00000001
"LargeSystemCache"=dword:00000001

[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Services\LanmanServer\Parameters]
"Size"=dword:00000003

; Misc
[HKEY_LOCAL_MACHINE\SYSTEM\ControlSet001\Control\Session Manager\Memory Management\PrefetchParameters]
"EnablePrefetcher"=dword:00000000
```

- **Win32PrioritySeparation = 0x18 (hex)** — foreground/background thread scheduling quantum bias; gaming-tweak staple. smirk24 later refines: leave at **2 for weak CPUs, 0x18 for powerful CPUs** (in a follow-up he writes "2 ... and 18", i.e. decimal 2 vs hex 18). empleat says he sets the equivalent via Control Panel ("foreground programs" in Performance Options → Advanced).
- **DisablePagingExecutive = 1** — keeps kernel/drivers in RAM instead of paging out. empleat endorses: "Paging executive i have on 1!"
- **LargeSystemCache = 1** — favors system file cache over working sets. **empleat disputes it:** "Largesystem cache is useless, if you have ssd! It just wears it down."
- **LanmanServer\Parameters "Size" = 3** — server service sizing (maximize throughput for file sharing; marginal for gaming).
- **EnablePrefetcher = 0** — empleat agrees ("Yep prefetcher 0"; on SSDs it "only wears down ssd", benchmarked only ~3 MB/s gain). **smirk24 later partially recants:** with Prefetcher = 1 **and** SysMain set to Automatic/running, programs launch faster/smoother — "believe it or not prefetcher improves program launch on hdd, ssd and m.2".

### Disable System Restore (smirk24 prefers gpedit; reg equivalent)

```
Windows Registry Editor Version 5.00
[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows NT\SystemRestore]
"DisableConfig"=dword:00000001
"DisableSR"=dword:00000001
```

empleat also disables System Restore but re-enables it when uninstalling programs; he doubts the registry values are needed (gpedit suffices).

### Disable Cortana

```
Windows Registry Editor Version 5.00
[HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\Windows Search]
"AllowCortana"=dword:00000000
```

**empleat's caveat:** "Cortana cannot be disabled, or you lose start menu, but windows suspends it, so it shouldn't consume any cpu cycles most of the time."

## Windows services

smirk24's disabled list (all normally Automatic+running by default):
- Connected User Experiences and Telemetry
- Diagnostic Policy Service
- Geo Location (lfsvc)
- Payments and NFC/SE Manager
- SysMain (Superfetch)
- Windows Font Cache Service
- Windows Search

Set to Automatic instead: Program Compatibility Assistant, Human Interface Device Service, Windows Time.

empleat's commentary:
- Disables the same list **except** Payments and NFC/SE Manager, and Diagnostic Policy Service ("should be harmless to disable it, but i am very careful these days").
- **HID service: "Hid = huge lag"** — but disabling it kills keyboard special/media keys (he doesn't care).
- **Windows Time: "??? LOL"** — skeptical of the input-lag correlation claim he himself heard ("Correctly synchronized time was even correlated to input lag (not sure about that)").
- Additional suggestions: disable **scheduled defrag**; disable **automatic maintenance** (it slows restarts, though it only runs when idle); disable **auditing of successful events** (command not given here — on page-1-content it is `Auditpol /set /category:* /Success:disable`).
- "You can disable explorer when gaming and clear type."

## Memory / page file / standby memory

- **smirk24's page-file setting: min 1500 MB / max 5000 MB** (or system managed).
- **smirk24's finding (anecdotal): disabling the page file is pointless** — after months with it disabled, re-enabling produced a notification about "overwriting my page file": Windows apparently creates a pagefile even when disabled. empleat disagrees: "Weird, i never had created page file, after disabling it."
- **Standby-memory / memory-compression discussion (empleat):** with 16 GB RAM, RAM slowly fills with standby memory; when it runs out, Windows tries to compress memory and programs crash with "out of memory" — supposedly the real cause behind the "memory leak" reports. **ISLC causes freezes each time it clears standby memory**; "you need at least 32 GB ram probably to use that effectively." Process Lasso's trim doesn't work either.
  - **TairikuOkami's suggested alternatives: "Reduce Memory" or "CleanMem"** (standby/memory cleaners). empleat asks whether they delete standby memory (if so they'd freeze the same way) — unresolved in-thread.
- **Page file security:** passwords can be left in the pagefile, and it is **not encrypted by default**. TairikuOkami links the two TenForums tutorials:
  - "Clear Virtual Memory Pagefile at Shutdown in Windows 10" (tenforums.com/tutorials/77773-...)
  - "Enable or Disable Virtual Memory Pagefile Encryption in Windows 10" (tenforums.com/tutorials/77782-...)
  empleat uses clear-on-shutdown (`ClearPageFileAtShutdown`) since his NVMe is rated for 1000 TBW; unsure whether the password risk only matters with physical disk access. empleat's own page-file history: 800–3200 MB fixed, now system managed because of the memory-compression behavior.

## Linked external guides / threads / videos

- **Blur Busters: "I'M SO CLOSE TO FINISHING MY INPUT LAG!"** — https://forums.blurbusters.com/viewtopic.php?t=7168 — about disabling DWM. **empleat's warning: "Possible to disable dwm, risky and can break your pc. Or after next update it won't work and break your pc... So backup is needed."** Thread also contains "useful tweaks from hardware specialist".
- **Overclock.net "USB polling precision" thread** — https://www.overclock.net/threads/usb-polling-precision.1550666/page-63 — empleat: "(page 81), you can disable usb interrupt moderation, shouldn't be needed on intel and is very risky, you need to be 200% sure, you can ask there ucode." (Link targets page 63; his text says page 81.)
- **Reddit r/ShadowPC: "Guide to reducing input lag while gaming"** — https://www.reddit.com/r/ShadowPC/comments/fs4f8f/guide_to_reducing_input_lag_while_gaming/ — "Also this thread very good!"
- **Steam guide: "Windows 10 Optimization And Tweak Guide For GAMING"** — https://steamcommunity.com/sharedfiles/filedetails/?id=476760198 — "very detailed".
- **YouTube: "Timers Timer Resolution HPET"** — https://www.youtube.com/watch?v=EG4g9XlKw5w — one YouTuber's timer/HPET coverage. Same video also linked for demonstrating **backing up individual registry keys/subkeys** before editing ("Should backup registry always, unless you are 100% sure").
- **sygnus21's own guide (SevenForums): "Tips for Troubleshooting Game Issues"** — https://www.sevenforums.com/gaming/77293-tips-troubleshooting-game-issues.html — troubleshooting-focused rather than latency-focused.

## Hardware / platform chatter

- **empleat (23 Nov 2019):** Ryzen good for streaming/multi-threaded work, "but intel is still better in games usually" (late-2019 context). CS:GO is still DirectX 9, got more demanding after the Panorama update, uses only 1–2 cores — so **CPU frequency and high-speed RAM matter more than core count** in such games. An RTX 2080 should beat a GTX 1080 in SC2; "2000 series card and high speed ram" good deals for games that can't use multicore. Rumor: new NVIDIA GPUs may get cheaper due to AMD threat.
- **empleat reiterates (28 Nov 2019):** Ultra Low Latency Mode = Ultra **increases** latency when GPU isn't at 99% usage; "1 pre-rendered frame, which is now called on" is better in that case (repeat of his page-1 NVCP point, aimed at sygnus21).

## Meta / criticism of the guide itself

- **sygnus21 (28 Nov 2019):** "Good god... that post is so unwieldy it's basically become ineffective." empleat concedes he's a "vehement writer" and promises to reformat, but insists the tweaks are "really powerful... not some placebo, or garbage."
- **empleat (23 Nov 2019):** laments that despite 70k views nobody shared hidden tweaks; the thread was meant to crowd-source unlisted tweaks.

## Tools mentioned on this page

| Tool | Purpose | Note |
|---|---|---|
| ISLC (Intelligent Standby List Cleaner) | timer resolution + standby memory purge | **empleat: causes freezes on each standby purge; needs 32 GB+ RAM to be effective** |
| Reduce Memory | standby/RAM cleaner | suggested by TairikuOkami as ISLC alternative (freeze behavior unconfirmed) |
| CleanMem | standby/RAM cleaner | same as above |
| Process Lasso | RAM trim etc. | empleat: trim "doesn't work" for the standby-memory problem |
