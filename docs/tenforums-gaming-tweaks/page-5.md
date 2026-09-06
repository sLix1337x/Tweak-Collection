# TenForums Gaming Tweaks — Page 5

Source: https://www.tenforums.com/gaming/117377-share-gaming-tweaks-chec-my-comprehensive-list-will-blow-your-mind-5.html

Note: the site's real page-5 URL ends in `-5.html` (the `-page5.html` form silently serves page 1). Page 5 covers thread posts #41–#50 (Feb 2022 – Aug 2023). Most of the page is follow-up discussion; one post (#44, trebleta) contains nearly all of the new technical content, plus there is a working link to a DWM-disable batch script.

## bcdedit / boot-configuration tweaks (post #44, trebleta, quoting "melody")

All run from an elevated command prompt. trebleta attributes these to a poster named "melody" from elsewhere and says he uses them himself.

- Disable kernel memory mitigations:
  ```
  bcdedit /set allowedinmemorysettings 0x0
  bcdedit /set isolatedcontext No
  ```
  Why: turns off some kernel memory mitigations (Spectre-class protections) to reclaim performance. **Warning (quoted verbatim): "Causes boot crash/loops if Intel SGX is enforced and not set to 'Application Controlled' or 'Off' in your Firmware."** Gamers "don't use SGX under any possible circumstance." Poster advises noting the default value first ("make note of the default vault [sic] so you can revert if need be").

- TSC synchronization policy (replaces the older `useplatformtick` tweak):
  ```
  bcdedit /set tscsyncpolicy Enhanced
  ```
  Why: `useplatformtick` "has changed and can now be... `tscsyncpolicy Enhanced` and removing the tick" — i.e. use the Enhanced TSC sync policy instead of forcing the platform tick. Caveat: trebleta adds "yet not 100%", meaning he is not fully certain of the behavior.

- Enable X2APIC and PCI-E memory mapping:
  ```
  bcdedit /set x2apicpolicy Enable
  bcdedit /set configaccesspolicy Default
  bcdedit /set MSI Default
  bcdedit /set usephysicaldestination No
  bcdedit /set usefirmwarepcisettings No
  ```
  Why: "Enable X2Apic and enable Memory Mapping for PCI-E devices." For best results, additionally enable MSI (Message Signaled Interrupts) mode for all devices, either with the MSI utility or manually. Related note: the well-known **MSI utility is now at v3**.

## Platform/firmware settings (post #44, trebleta)

- **Intel SGX: disable in BIOS.** "System SGX can be disabled via bios as not needed in games." Ties into the warning above — SGX must be "Application Controlled" or "Off" in firmware before applying `allowedinmemorysettings 0x0`, or the machine may fail to boot.
- **HPET caveat (debunk of a common tweak):** trebleta reports that disabling HPET in Device Manager causes problems — "I get problems with 1-2 games turbo'ing, Xcom UFO being 1." So on his system the classic "disable HPET" tweak hurt specific games.
- **Pagefile caveat (debunk of a common tweak):** "On Pagefile I found just let system manage. Turning off cause errors also no error data and setting manual some games crash, like anno 1800." I.e. disabling the pagefile breaks error reporting and manually sizing it crashes some games (Anno 1800 named); leave it system-managed.

## Tools & scripts

- **DWM disable/enable batch script (Windows 10)** — post #47, duckyshine (14 Jun 2022) finally answers requests in posts #43/#45/#46 with a link:
  https://forums.blurbusters.com/viewtopic.php?f=10&t=10126 ("How to disable/enable DWM with batch script" — Blur Busters Forums).
  Context: earlier in the thread (quoted on this page) duckyshine described a batch script that (1) disables ClearType and font smoothing, (2) stops services (hidserv), (3) kills background programs (TextInputHost.exe, SettingSyncHost.exe), (4) changes the Windows font to one without antialiasing, and (5) disables DWM. It was tested on Windows 10 21H1/21H2 with CS:GO and ships with a Revert.bat because it is only used while playing CS:GO. **Warning from the author: "Especially disabling DWM breaks a lot of functions in windows."** SachsenPowl (post #46) confirms working DWM-disable scripts for Win10 are hard to find ("no one has a script that works").
- **Ghost Spectre OS** — post #41, sportster (20 Feb 2022): "I choose the easier way of installing ghost spectre OS customised for gaming." A pre-tweaked custom Windows ISO as an alternative to manual tweaking. No version or link given; treat unofficial ISOs as a security risk (not discussed in-thread).
- **MSI utility v3** — mentioned in post #44; the interrupt-utility used to enable MSI mode per device now has a v3 release.

## Performance claims & opinions (mostly from OP "empleat", post #42)

- SSD tweaks: OP believes there are few/none that do "more than none to little" — he is "now interested only into if there are any more SSD tweaks... but if you know some I can use it" — i.e. skeptical that SSD tweaking yields gains (placebo territory per the thread's own author).
- Web/site loading speed as a latency obsession: beyond "optimal DNS and using Ublock", OP says "there is not much you can do." He notes browser **hardware acceleration "can make it better/worse — didn't test it yet"**, and that he found no Chrome rendering-performance flags equivalent to Firefox's.

## Caveats & debunks summary

- Disabling DWM breaks many Windows functions — use a Revert.bat / only while gaming (duckyshine's script, discussed posts #42–#47).
- `allowedinmemorysettings 0x0` can cause boot crashes/loops unless Intel SGX is set to "Application Controlled" or "Off" in firmware (post #44).
- Disabling HPET caused stutter/"turbo'ing" problems in 1–2 games for trebleta (XCOM UFO named) — contradicts the generic "disable HPET" advice (post #44).
- Disabling or manually sizing the pagefile caused errors/crashes (Anno 1800 named); recommend leaving it system-managed (post #44).
- `tscsyncpolicy Enhanced` as a `useplatformtick` replacement is offered with explicit uncertainty ("yet not 100%").

## Chatter (no technical content, recorded for completeness)

- Post #43 (whatif) and #45 (SachsenPowl): asking duckyshine to share the batch file.
- Post #46 (SachsenPowl): "Sadly duckyshine didn't answer... no one has a script that works" (re disabling DWM on Win10).
- Post #48 (jonathah): "really cool".
- Post #49 (hektor314, Aug 2023): thanks Empleat — "was struggling with all this latency and now game is playable." (Anecdotal success report for the thread's tweaks.)
- Post #50 (User2468, Aug 2023): "Temple OS?" — joke reply.
