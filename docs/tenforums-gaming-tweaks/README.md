# TenForums Gaming Tweaks Thread — Extracted Notes

Extraction of the TenForums thread **"Share gaming tweaks, check my comprehensive list will blow your mind"** (started by empleat, Sep 2018; active through Aug 2023).

Source: <https://www.tenforums.com/gaming/117377-share-gaming-tweaks-chec-my-comprehensive-list-will-blow-your-mind.html>

The thread is 5 pages (50 posts). Each file below covers exactly one page. **Page 1 contains the bulk of the actual tweak guide** (empleat's massive OP) — the later pages are mostly discussion, corrections, and debunks.

## Files

| File | Posts | Content |
|---|---|---|
| [page-1.md](page-1.md) | #1–10 | The core guide: power plans (`powercfg` GUIDs), monitor/OSD advice, NVCP settings, BIOS tweaks (HPET, C-states), ~15 registry edits, timer tweaks (`bcdedit`), MSI/interrupt tooling, NIC/audio/mouse advice, large tool list (Process Lasso, ISLC, LatencyMon, DDU, CRU, …). Includes Faith's systematic debunks and danger flags (MSI mode brick risk, pagefile BSOD). |
| [page-2.md](page-2.md) | #11–20 | smirk24's registry/services dump (Win32PrioritySeparation, DisablePagingExecutive, LargeSystemCache, pagefile sizing) with empleat's point-by-point evaluation; ISLC freeze reports + alternatives; external guide links (Blur Busters, overclock.net). |
| [page-3.md](page-3.md) | #21–30 | Registry correction (DisablePagingExecutive must be **1**), Nvidia `nvlddmkm` DPC-latency discussion, CountMike's hardware/cooling/RAM-tuning post with measured data, AMD-vs-Intel debate, "tweaks are polish, not magic" pushback. |
| [page-4.md](page-4.md) | #31–40 | empleat's OS-latency tweak list (DWM/HID/ClearType, timer resolution, USB packet buffering); tools: NTLite, ReviOS, WLAN Optimizer, Hone Optimizer (flagged as likely scam); DWM-disable batch script risks; placebo debate. |
| [page-5.md](page-5.md) | #41–50 | trebleta's bcdedit set (`tscsyncpolicy Enhanced`, X2APIC/MSI block, `allowedinmemorysettings` with boot-loop warning), Intel SGX advice, HPET breakage report (XCOM), pagefile caution (Anno 1800), link to the DWM-disable batch script on Blur Busters. |

## Validation status

**This folder is source material, not guidance.** The thread is a Windows 10
document written between 2018 and 2023, and most of it does not survive a check
against Windows 11 24H2/25H2.

Read [VALIDATION.md](VALIDATION.md) before using anything here. It goes through the
claims with a verdict on each, lists the four items that can leave a machine
unbootable or damage hardware, and records what was published to the site as a
result (the `bcdedit` boot block, `IRQ#Priority`, and the DisplayPort pin-20 note).

Short version: of roughly 200 claims, about a dozen still hold up, and most of
those are already covered elsewhere on the site with better sourcing.

## Read this first — caveats

- Many claims in the thread are **anecdotal or disputed**, sometimes by the OP himself. Each page file has a caveats/debunks section — read it before applying anything.
- Several tweaks are flagged as **dangerous**: MSI mode on the wrong device can make a PC unbootable, `allowedinmemorysettings 0x0` can cause boot loops, disabling DWM breaks Windows functions.
- Some tweaks are marked **outdated** by the author (e.g. DWM disable on Windows 10+).
- Always create a restore point / backup before applying registry or bcdedit changes.

## Fetch note

The site's intuitive pagination URLs (`...-page2.html`) silently redirect to page 1. The correct page URLs use the `...-2.html` … `...-5.html` format. The site also 403-blocks non-browser user agents.
