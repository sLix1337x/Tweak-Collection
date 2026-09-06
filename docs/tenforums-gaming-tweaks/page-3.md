# TenForums Gaming Tweaks — Page 3

Source: https://www.tenforums.com/gaming/117377-share-gaming-tweaks-chec-my-comprehensive-list-will-blow-your-mind-page3.html

**Fetch note:** the `-page3.html` URL form silently serves page 1 (canonical = thread root, "Results 1 to 10 of 50"). The URL that actually returns page 3 (posts #21–30, "Page 3 of 5") is:
`https://www.tenforums.com/gaming/117377-share-gaming-tweaks-chec-my-comprehensive-list-will-blow-your-mind-3.html`

Page 3 is mostly discussion/debate rather than new tweaks. It covers posts #21–30 (Dec 2020 – Jan 2022): an AMD-vs-Intel/Nvidia argument, one concrete registry correction to the OP's guide, and a long hardware/cooling post by CountMike.

## Registry tweaks

- **`DisablePagingExecutive` must be `1`, not `0`** — MaloK (#27, 09 Jan 2022) posts a correction to the guide's "SSD tweaks" section: "*DisablePagingExecutive must be set to 1 instead of 0 to prevent paging of kernel files.*" The post names only the value; the standard location of this value is `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management` (DWORD). Setting it to 1 keeps kernel/drivers in RAM instead of paging them out. (Note: this value is conventionally filed under memory-management tweaks, not SSD tweaks — the OP apparently had the wrong value in the guide.)

## Display/OS language tweak (anecdotal, disputed)

- **Windows display language "English (Philippines)" for lower input lag** — the OP (empleat) asked readers to test the claim that using English (Philippines) as the Windows 10 *display language* (not just input method) gives lower input lag than English (US), attributing it to overclock.net user X7007, with a screenshot link (`https://pbs.twimg.com/media/D90UqHmU...ng&name=medium`, truncated by the forum). RamenRider (#21) replied that *he* found the info on another forum and shared it to X7007 — an attribution spat, no data either way. Status: **unverified/anecdotal claim**, no mechanism or measurement given; treat as placebo-risk until tested.

## GPU / driver latency claims

- **Nvidia `nvlddmkm` DPC latency** — RamenRider (#21): the reason he uses AMD GPUs is that "*the Nvidia drivers nvlddmkm had always high DPC latency*."
- Counterpoint — empleat (#22): no DPC latency spikes on his RTX 2070 Super ("maybe 200 µs max sometimes, don't know what is causing it"); sound-production forums report not everyone gets high DPC latency on Nvidia. His summary: "*if you wanna go for a certainty: AMD GPU is the way to go! They have worse drivers tho.*" — cites an AMD driver bug where users were stuck at 60 Hz monitors, unfixed for a long time; and an Nvidia driver bug that "could destroy your GPU."
- **Practical driver rule from empleat:** "*I don't install new drivers and wait at least 2 weeks to see about issues.*"
- **DLSS** called a "game changer" by empleat; AMD's own deep-learning upscaling and Microsoft-ML (DirectML) mentioned as uncertain future alternatives.

## CPU / platform debate (AMD vs Intel, Dec 2020 era)

- RamenRider (#21): "AMD is better for both gaming and streaming"; claims Intel's historical lead came from bribing retailers — links the YouTube video "*Intel - Anti-Competitive, Anti-Consumer, Anti-Technology*".
- empleat (#22) caveats against AMD (second-hand, no first-hand testing):
  - AMD's USB chipset "is bad" — the **USB controller has a lower polling rate**; unsure if fixable via BIOS update or USB registry edits; says he read many complaints about input lag on AMD CPUs.
  - For competitive/older games that can't use many cores (e.g. CS:GO), Intel still wins on single-core performance; for streaming, AMD wins.
  - AMD X570 chipset fan: unknown quality, may die, and is blocked by the GPU on some boards (mini-ITX slot constraints).
  - Some AMD motherboards have 30 s+ boot times.
- CountMike (#23) corrections:
  - Chipset fan is only on **some X570** boards; **B550 has none**; fan quality varies by board maker, some are adjustable or can be turned off.
  - Microsoft patched Windows 10 for Ryzen in 2019; newer Ryzen assigns load to cores (CCX/CCD groups) via its own algorithms without OS help — "waiting for MS to do that would be futile."
  - Any 6+ core CPU drives top GPUs without a real bottleneck: **R5 5600X ≈ R7 5800X ≈ R9 in gaming; R5 3600X ≈ 3900X**.
- CountMike (#25): with Zen 3, Microsoft OS support is "a moot point"; notes Windows 10 Insider dev builds gave slightly better CPU benchmarks but had major 3D/GPU problems on the same machine with identical drivers.
- empleat (#22) hardware note: his i5-9600KF (bought ~$250) handles even an RTX 3080 without bottlenecks at stock, and works well in old single-threaded games.

## Hardware & cooling tweaks (CountMike, #30, 09 Jan 2022)

The most actionable post on the page — corrections plus thermal advice:

- **Typo fixes for the guide:** it's **XMP** (Extreme Memory Profile), not "XPM"; **RGB** (Red Green Blue), not "RBG" — readers searching the wrong terms would find nothing.
- **Case airflow:** many prebuilt and self-built PCs have terrible cooling; few cases have good airflow — glass fronts with minimal intake openings and internal obstacles interrupt fan flow. Route case airflow so it envelops the **GPU**, which is usually starved of fresh air.
- **CPU cooling:** OEM/factory coolers are only adequate near idle; an aftermarket cooler is required to let the CPU hold boost.
- **RAM thermals:** with AIO/water coolers RAM gets very little airflow (no downdraft from an air tower); newer RAM has its own temp sensors but BIOS often can't display them.
- **VRM cooling:** VRMs are usually rated 100 °C+ but throttle voltage output when overheated; cheap/small boards with weak 4+2 VRM stages can't supply clean power to 12–16-core CPUs — best case throttling, worst case the VRM "blows up or burns" and takes other components with it.
- **Why it matters (thermal throttling mechanics):** modern CPUs, GPUs and NVMe SSDs first cap boost clocks, then throttle base clocks, then shut down, governed by package/core temps. AMD Ryzen up to Zen 2+ is especially temperature-sensitive: full boost only up to 70 °C (65 °C on earlier models; 90 °C allowed on Zen 3/5000 series).
  - His measured example (R7 3700X): every +1 °C over 70 °C drops boost by 50–100 MHz from the 4.4 GHz max; at 75 °C it won't pass 4 GHz; 3.6 GHz at 85 °C; shutdown at 90 °C. Notes Intel Alder Lake behaves similarly.
- **RAM speed (Ryzen):** same RAM kit at **3600 MHz CL16 vs 2133 MHz CL14** gives **15–20%+ better CPU scores** on his 3700X — RAM frequency/latency strongly affects Ryzen CPU performance.
- **His result:** ~$80 spent on a 360 mm AIO + 3 case fans, plus enabling (slightly modified) **XMP**, gave "up to some 50% better overall system performance" vs OEM cooler + JEDEC RAM.

## Caveats & debunks (thread philosophy)

- TairikuOkami (#28): people don't post tweaks because they're "looking for magic — enable this, disable that and gain 100% performance boost. Tweaks are not meant to do that, they are designed to polish, to prevent lags, stuttering and such."
- solarstarshines (#29, replying to TairikuOkami): "*The best tweak is to use quality parts and keep everything within 2 gens of use*" — proper scaled RAM / proper CPU / proper BIOS use (RAM upclocking + power management); "*All the tweaking in the OS will lead to other issues; Windows 10 and 11 are already lite anyway if you choose to keep certain features off.*" I.e. a mild debunk of heavy OS-level tweaking in favor of hardware/BIOS-level setup.
- empleat (#24) AMD support caveat: AMD "always gets patches like a year later than Intel"; worried about future issues being deprioritized ("AMD will be boycotted").

## Chatter skipped

- empleat (#26, 06 Jan 2022) only laments "111k views and no one posted any suggestions" and points to the guide's ideas/questions section — no technical content.
