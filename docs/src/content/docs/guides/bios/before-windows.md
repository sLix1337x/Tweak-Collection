---
title: Before Windows goes on
description: The four settings that have to be right before installation, and everything that can wait.
sidebar:
  order: 3
tags:
  - bios
---

Most of this page is tuning, and tuning belongs on a machine that already boots.
Only four settings genuinely have to be correct before Windows is installed:

| Setting | Why it cannot wait |
| --- | --- |
| **Boot mode: UEFI** | Windows partitions the disk GPT or MBR to match. Switching afterwards means a repair or a reinstall. |
| **Secure Boot: on** | Same install-time decision, and several anti-cheat systems now require it. |
| **TPM: on** | A Windows 11 install requirement. Easier to have on than to work around. |
| **SATA mode: AHCI** | Windows installs the matching storage driver. Switching to or from RAID afterwards is a classic way to produce a machine that will not boot. |

Everything else — the memory profile, Resizable BAR, disabling unused devices — is
better done once Windows is installed and running. An unstable XMP profile during
installation looks like a corrupt install; the same instability on a working system
looks like something you can memtest and back off from.

The full sequence is in the
[fresh install order](../../../reference/fresh-install-order/#the-order).

