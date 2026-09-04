---
title: DiscordDebloat.ps1
description: Strips a Discord Stable install down to a minimal, fast-starting client while keeping voice, Krisp, input capture and the tray icon working.
sidebar:
  order: 3
tags:
  - services
  - privacy
---

Built with **Amaaz**. A WPF tool that takes a stock Discord Stable install from
**607.5 MB down to 314.6 MB** — 1074 files to 194 — without breaking voice.

Single PowerShell file, no installer, no dependencies. Windows PowerShell 5.1 and
PowerShell 7 both work.

```
scripts/discord-debloat/
  DiscordDebloat.ps1          the tool
  Launch DiscordDebloat.cmd   double-click launcher, requests elevation
  README.md                   the full reference
```

## What it removes

| Category | Frees | What it is |
| --- | --- | --- |
| Installer leftovers | ~176 MB | `Update.exe`, `packages\`, `download\` — the Squirrel auto-updater |
| Language packs | ~46 MB | Chromium's own strings; you pick which to keep |
| GPU libraries | ~45 MB | ANGLE, SwiftShader, Vulkan, DirectX shader compilers |
| Optional modules | ~21 MB | Overlay, Rich Presence, spellcheck, cloud sync, dispatch, media, native notifications |
| Module trim | ~4 MB | Helper executables and unused model files inside modules that stay |
| Chromium assets | ~1 MB | HiDPI artwork, legacy snapshot, crash reporter |

Always kept: `Discord.exe`, the desktop core, voice, Krisp, input capture,
the tray icon and taskbar buttons, plus `updater.node` and
`installer.db`. Those last two are never removed — despite the name, `updater.node`
is also the module registry, and deleting it breaks voice rather than just updates.

## What you give up

Auto-update, the in-game overlay, Rich Presence, spellcheck, cloud sync, hardware
acceleration and video encoding, background blur, non-English right-click menus, and
HiDPI artwork.

**Auto-update stops working.** That is the point of removing the updater, but it
means you update Discord by reinstalling it.

## Krisp is the part to read before running

Krisp is Discord's noise suppression, and it also provides **voice-activity
detection** — what decides when your microphone actually transmits. Remove the wrong
piece and you get a microphone that looks like it works but that nobody can hear.

So it is treated as all-or-nothing, with a preset:

| Preset | Frees | Effect |
| --- | --- | --- |
| **All models** (default) | 0 | Nothing removed |
| No background voice cancellation | 14.4 MB | Drops the mode that filters out other people talking near you |
| Essential only | 19.9 MB | Keeps voice-activity detection and full-band noise cancellation |
| Remove Krisp entirely | 40.4 MB | No noise suppression, and no voice-activity detection |

Underneath the preset it reads your own client's logs and reports which models your
machine has actually loaded, so the choice is based on your setup rather than a
guess.

## Undoing it

Leave **Back up removed files** ticked. Every deleted file is copied to
`%LOCALAPPDATA%\DiscordDebloat\Backups\<timestamp>` first, and the Backups page
restores any snapshot — restoring the same one twice is safe.

Two things a restore does not undo: the `settings.json` edits and the desktop
shortcut. Both are harmless to change back by hand. And reinstalling Discord from
[discord.com/download](https://discord.com/download) always works.

## Requirements and limits

- **Windows 10 or 11.** Rounded corners and the translucent window need 11; on 10 it
  simply looks flat.
- **Discord Stable.** Canary, PTB and Development builds are detected but untested.
- Administrator rights, because Discord lives under your user profile and the tool
  terminates the running client before touching files.

:::caution[This deletes files from an application you do not maintain]
It is not affiliated with or endorsed by Discord, and a future Discord release may
lay things out differently. The removal profile is written to survive version
changes, but it cannot predict them.

Keep backups enabled, run the Overview scan and **Preview plan** first, and if
something misbehaves, restore or reinstall.
:::

Full reference, including the page-by-page walkthrough, is in the tool's own
[README](https://github.com/sLix1337x/Tweak-Collection/blob/main/scripts/discord-debloat/README.md).

## Doing it by hand

The manual version — delete everything under
`%LocalAppData%\Discord\app-<version>\modules` except `discord_desktop_core-1`,
`discord_modules-1`, `discord_utils-1`, `discord_voice-1` and `discord_voice-4`,
keep `discord_krisp-1` if you want noise suppression, then thin out
`app-<version>\locales` — works, and undoes itself.

The version number is in the path. Discord updates, creates `app-<next version>`,
and re-downloads the modules you deleted, so a path written down once goes stale:
`app-1.0.9255` at the time of writing, against `app-1.0.9184` a few releases back.

Removing the Squirrel updater is what makes it stick, and at that point you want
something that takes a backup first and knows which files break voice. That is what this
tool is for. `discord_krisp-1` is
the piece to be careful with either way: it also provides voice-activity detection,
so removing it gives you a microphone that looks fine and transmits nothing.
