# TenForums Gaming Tweaks — Page 4

Source: https://www.tenforums.com/gaming/117377-share-gaming-tweaks-chec-my-comprehensive-list-will-blow-your-mind-4.html

Note: the `-page4.html` URL form redirects to page 1 on this site; page 4 actually lives at the `-4.html` URL above. Posts #31–#40, dated 09 Jan 2022 – 20 Feb 2022. This page contains **no registry keys, command lines, or config files** — it is discussion/debate about which OS-level tweaks matter, plus several tool recommendations and one batch script description.

## OS / latency tweaks (empleat's "biggest role" list, post #32)

empleat argues software tweaks matter even on top-tier hardware, because e.g. a fast mouse "hogged with hundreds of DPC latency... won't feel good by the nature of being inconsistent". Tweaks he says play the biggest role:

- Disable DWM (Desktop Window Manager) features, HID features, ClearType + "smooth edges of screen fonts", all visual effects, and AA (anti-aliased) fonts — claims some of these were performed by pro gamers.
- Use `Windows8DPIScalling` (Windows 8 DPI scaling mode).
- Reduce DPC latency ("also hogs kernel"): mainly affects consistency of mouse movement, especially important for 8 kHz polling mice; claims you can feel the difference between 50 µs and 250 µs because "it stacks over time".
- Remove redundant drivers that ship with Windows / come pre-installed for devices you don't own — they slow kernel response time and "can cause deadlocks".
- Chipset drivers, Intel drivers, sound drivers "cause huge lag" — Microsoft OEM drivers should be preferred.
- Timer resolution tweaking.
- USB mouse data packet buffering.
- Disable mouse smoothing.
- Disable dynamic tick.
- Disable software components and disable sleep states for devices in Device Manager (`devmgr`).
- .NET frameworks (trimming).
- Disable smoothing and GPU acceleration in Control Panel / internet settings.
- On thermal advice: "If you don't have thermal throttling, temperature is irrelevant." He planned to update the main guide for 2022 hardware with a thermal-throttling note.

## Tools

- **NTLite** (post #33, tairikuokami) — image-level Windows debloating/customization. Claimed result: "My ntlited Windows 7 was using only 80MB RAM." Caveat from same poster: requires a lot of attention — you have to reinstall Windows after every update and deal with breakage.
- **ReviOS** — custom pre-tweaked Windows ISO, https://www.revi.cc/about — mentioned as an alternative to NTLite (they credit TenForums' Brink). empleat (post #36) notes it has reduced security, "but better than Win7".
- **Hone Optimizer** — https://hone.gg — "boost your performance" tool. **Flagged as likely scam** by empleat (post #36): "(2x fps boost from average reviews) + mixed feelings from reddit! I don't like these programs: you don't even know what it does..."
- **WLAN Optimizer** — http://www.martin-majowski.de/ (post #35, callender, with two screenshots attached) — small utility that disables WLAN background scanning / tweaks wireless for lower latency. Caveat from empleat: "you don't want game over WIFI, if you can help it!" Callender's defense: useful for portable machines moved around the home.
- **duckyshine's CS:GO batch script** (post #40, not posted publicly — offered via DM). Described as doing:
  1. Disable ClearType and font smoothing
  2. Stop services (currently just `hidserv`)
  3. Kill background programs (currently `TextInputHost.exe` and `SettingSyncHost.exe`)
  4. Change Windows font to one without antialiasing
  5. Disable DWM

  Tested on Windows 10 21H1 and 21H2 with CS:GO. Ships with a Revert.bat because he only runs it while playing CS:GO. **Warning from author:** "Especially disabling DWM breaks a lot of functions in windows."

## CPU/RAM overclocking & BIOS discussion (posts #34, #36)

- CountMike (post #34): "Overclocking is pretty well dead now" — manufacturers implemented algorithms balancing performance and power, so OC no longer produces results like in the past; AMD Ryzen made OC almost impractical. But BIOSes still aren't smart enough to set everything optimally, so manual BIOS tweaking for best *practical* performance is still on the owner.
- Terminology note: whether XMP counts as overclocking is blurred — for DDR4, XMP raises RAM above the usual 2133 MHz base frequency. empleat (post #36) adds: Intel treats XMP as overclocking and "doesn't RMA CPU if you use XMP (but only if you tell them)".
- empleat (post #36): CPU overclocking still pays off in old/competitive **single-core-bound games** — CS:GO ("input lag is tied to FPS — something how its engine works") and Starcraft 2 ("gains FPS indefinitely with increasing CPU/RAM frequency — heavily single-core").
- empleat: most system processes run on core 0, so some people remove core 0 from their games' CPU affinity; he is "unsure if it is good thing to have interrupts being processed on other core than the one where your game is running" — i.e. unverified, possibly counterproductive.
- CountMike: HW and OS are equally important; tweaking only one doesn't give full results. What he posted "may or may not in full or partly work for other systems."

## Caveats & debunks

- **solarstarshines (posts #31, #38) — skeptic/placebo stance:** agrees with CountMike; says doing all the extra tweaks "really is a waste for general experience". Modern games are well optimized; at 200–300+ FPS on high-refresh 1080p competitive play, "the most visible lag would be internet connection". "You will not be able to see the gains or feel the gains — sometimes you need to just enjoy what you got."
- **empleat's rebuttal (post #39):** network latency and local input lag are separate things; local tweaks make you "click on things more precisely and faster". DWM cannot be turned off on Windows 10 (unlike Win7), and Win10's GUI is more resource-heavy. Consistency and small improvements matter in competitive play: "I couldn't play CS GO untweaked, I wouldn't hit anything..."
- **Hone Optimizer** flagged as probable scam (see Tools).
- **DWM disabling** acknowledged even by its practitioner (duckyshine) to break many Windows functions — use a revert script and only enable while gaming.
- **NTLite** acknowledged to be high-maintenance (reinstall after every Windows update).
- Typo corrections by CountMike (post #34): "XPM" should be **XMP** (Extreme Memory Profile); "RBG" should be **RGB**.
