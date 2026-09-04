# Discord Debloat Suite

Strips a Discord Stable install down to a minimal, fast-starting client while keeping
voice, Krisp, input capture and the tray icon working.

**607.5 MB → 314.6 MB** on a stock install — 1074 files down to 194.

Single PowerShell file, no installer, no dependencies. Runs on Windows PowerShell 5.1
and PowerShell 7.

---

## Run it

Double-click **`Launch DiscordDebloat.cmd`**. It requests administrator rights and
opens the window.

Windows may warn that the file came from the internet — it is an unsigned script, which
is normal for a tool distributed this way. If you want to be sure you got the file
intact, compare the checksum in the `.sha256.txt` next to the archive:

```powershell
Get-FileHash .\DiscordDebloat-v1.1.0-2026-08-23.7z -Algorithm SHA256
```

The tool finds your Discord by itself: a running client first, then the standard
per-user folders, then the installer's registry entry.

**Start on the Overview page.** It scans and shows exactly what would be removed
before anything is touched. Use **Preview plan** on the Debloat page to list every
single file first. Nothing is deleted until you confirm.

---

## What it removes

| Category | Frees | What it is |
|---|---|---|
| Installer leftovers | ~176 MB | `Update.exe`, `packages\`, `download\` — the Squirrel auto-updater |
| Language packs | ~46 MB | Chromium's own strings; you pick which to keep |
| GPU libraries | ~45 MB | ANGLE, SwiftShader, Vulkan, DirectX shader compilers |
| Optional modules | ~21 MB | Overlay, Rich Presence, spellcheck, cloud sync, dispatch, media, native notifications |
| Module trim | ~4 MB | Helper executables and unused model files inside modules that stay |
| Chromium assets | ~1 MB | HiDPI artwork, legacy snapshot, crash reporter |

**Always kept:** `Discord.exe`, the desktop core, voice, Krisp, input capture,
the tray icon and taskbar buttons, plus `updater.node` and
`installer.db`. Those last two are never removed — despite the name, `updater.node`
is also the module registry, and deleting it breaks voice rather than just updates.

---

## What you give up

Auto-update, the in-game overlay, Rich Presence, spellcheck, cloud sync,
hardware-accelerated rendering and video encoding, background blur, non-English
right-click menus, and HiDPI artwork.

**Auto-update stops working.** That is the point of removing the updater, but it means
you update Discord by reinstalling it. The tool also writes
`SKIP_HOST_UPDATE: true` and `enableHardwareAcceleration: false` into your
`settings.json` so the client does not fight the changes.

---

## Undoing it

**Leave "Back up removed files" ticked.** Every deleted file is copied to
`%LOCALAPPDATA%\DiscordDebloat\Backups\<timestamp>` first. The **Backups** page lists
your snapshots and restores any of them; restoring the same snapshot twice is safe.

Two things a restore does *not* undo: the `settings.json` edits and the desktop
shortcut. Both are harmless to change back by hand.

If anything goes badly wrong, reinstalling Discord from
[discord.com/download](https://discord.com/download) always works.

---

## The pages

**Overview** — scan and breakdown. Nothing is written here.

**Debloat** — pick categories, choose which language packs to keep, run it.
*Simulation* walks the whole plan and logs every target without touching disk.

**Tweaks** — configuration only, no files deleted. Disables auto-update and hardware
acceleration in `settings.json`, removes Discord's autostart entry, and can switch off
fullscreen optimizations for `Discord.exe`.

**Cache** — clears the caches in your Discord profile. Safe to run any time; Discord
rebuilds what it needs. *Local Storage* is opt-in because clearing it signs you out.
Cookies are never touched.

**Backups** — restore or delete snapshots.

---

## Krisp models

Krisp is Discord's noise suppression — and it also provides **voice-activity
detection**, which is what decides when your microphone transmits. Removing the wrong
part of it leaves you with a microphone that appears to work but that nobody can hear.

The Debloat page therefore treats Krisp as all-or-nothing, with a preset:

| Preset | Frees | Effect |
|---|---|---|
| **All models** (default) | 0 | Nothing removed |
| No background voice cancellation | 14.4 MB | Drops the mode that filters out *other people* talking near you |
| Essential only | 19.9 MB | Keeps voice-activity detection and full-band noise cancellation |
| Remove Krisp entirely | 40.4 MB | No noise suppression, no voice-activity detection |

Underneath the preset the tool reads your own client's logs and tells you which models
your machine has actually loaded, so the choice is based on your setup rather than a
guess.

---

## Requirements and limits

- **Windows 10 or 11.** Rounded corners and the translucent background need Windows 11;
  on Windows 10 the window simply looks flat.
- **Discord Stable.** Canary, PTB and Development builds are detected but have not been
  tested.
- Administrator rights, because Discord lives under your user profile and the tool
  terminates the running client before touching files.

---

## Honest caveats

This deletes files from an application it is not affiliated with. It is not endorsed by
Discord, and a future Discord release may lay things out differently — the profile is
written to survive version changes, but it cannot predict them.

Keep backups enabled, run the Overview scan and Preview plan first, and if something
misbehaves, restore or reinstall.

---

Built by **Amaaz** and **sLix1337**.
