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
**607.5 MB down to 314.6 MB** (1074 files to 194) without breaking voice.

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
| Installer leftovers | ~176 MB | `Update.exe`, `packages\`, `download\`: the Squirrel auto-updater |
| Language packs | ~46 MB | Chromium's own strings; the set to keep is selectable |
| GPU libraries | ~45 MB | ANGLE, SwiftShader, Vulkan, DirectX shader compilers |
| Optional modules | ~21 MB | Overlay, Rich Presence, spellcheck, cloud sync, dispatch, media, native notifications |
| Module trim | ~4 MB | Helper executables and unused model files inside modules that stay |
| Chromium assets | ~1 MB | HiDPI artwork, legacy snapshot, crash reporter |

Always kept: `Discord.exe`, the desktop core, voice, Krisp, input capture, the tray icon
and taskbar buttons, plus `updater.node` and `installer.db`. Despite its name,
`updater.node` is also the module registry, and deleting it breaks voice rather than
just updates.

## What is given up

Auto-update, the in-game overlay, Rich Presence, spellcheck, cloud sync, hardware
acceleration and video encoding, background blur, non-English right-click menus, and
HiDPI artwork.

**Auto-update stops working**, so updating Discord requires reinstalling it.

## Krisp

Krisp is Discord's noise suppression and also provides **voice-activity detection**,
which decides when the microphone transmits. Removing the wrong piece produces a
microphone that looks functional but transmits nothing.

It is therefore treated as all-or-nothing, with a preset:

| Preset | Frees | Effect |
| --- | --- | --- |
| **All models** (default) | 0 | Nothing removed |
| No background voice cancellation | 14.4 MB | Drops the mode that filters out other people talking nearby |
| Essential only | 19.9 MB | Keeps voice-activity detection and full-band noise cancellation |
| Remove Krisp entirely | 40.4 MB | No noise suppression, and no voice-activity detection |

Under the preset it reads the local client's logs and reports which models the machine
has loaded, so the choice reflects the installed setup.

## Undoing it

Leave **Back up removed files** ticked. Every deleted file is copied to
`%LOCALAPPDATA%\DiscordDebloat\Backups\<timestamp>` first, and the Backups page restores
any snapshot. Restoring the same one twice is safe.

A restore does not undo the `settings.json` edits or the desktop shortcut; both are
harmless to change back by hand. Reinstalling from
[discord.com/download](https://discord.com/download) also works.

## Requirements and limits

- **Windows 10 or 11.** Rounded corners and the translucent window need 11; on 10 it
  looks flat.
- **Discord Stable.** Canary, PTB and Development builds are detected but untested.
- Administrator rights, because Discord lives under the user profile and the tool
  terminates the running client before touching files.

:::caution[This deletes files from a third-party application]
Not affiliated with or endorsed by Discord. A future Discord release may lay things out
differently; the removal profile is written to survive version changes but cannot
predict them.

Keep backups enabled, run the Overview scan and **Preview plan** first, and restore or
reinstall if something misbehaves.
:::

Full reference, including the page-by-page walkthrough:
[README](https://github.com/sLix1337x/Tweak-Collection/blob/main/scripts/discord-debloat/README.md).

## Doing it by hand

Delete everything under `%LocalAppData%\Discord\app-<version>\modules` except
`discord_desktop_core-1`, `discord_modules-1`, `discord_utils-1`, `discord_voice-1` and
`discord_voice-4`, keep `discord_krisp-1` where noise suppression is wanted, then thin
out `app-<version>\locales`.

The version number is in the path. Discord updates, creates `app-<next version>` and
re-downloads the deleted modules, so a written-down path goes stale — `app-1.0.9255` at
the time of writing, against `app-1.0.9184` a few releases back. Removing the Squirrel
updater is what makes the change stick.

`discord_krisp-1` also provides voice-activity detection, so removing it leaves a
microphone that appears functional and transmits nothing.
