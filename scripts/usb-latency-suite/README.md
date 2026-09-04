# USB / HID Latency Tweak Scripts — Analysis

Two files that disable every USB and HID power-saving, idle and wake feature Windows exposes, with the goal of removing input latency and micro-stutter on mice, keyboards and other input devices.

| File | Type | Scope |
|---|---|---|
| `USB_Static_Tweaks.reg` | Registry import | Fixed, machine-wide driver/service keys |
| `USB_Dynamic_Tweaks.bat` | Batch + PowerShell + WMI | Per-device keys discovered at runtime |

Both require administrator rights and a reboot to take effect.

---

## 1. What the tweaks actually target

Windows saves power on USB by letting devices go idle and by suspending individual ports. The relevant mechanisms:

- **Selective Suspend** — the USB hub driver puts an individual port into a low-power state after an idle timeout. Waking it costs milliseconds and can drop or delay input reports.
- **Device idle / D-states (D1/D2/D3, D3cold)** — a device drops into a lower power state; the `fid_D*Latency` values describe how long it takes to come back.
- **Enhanced Power Management (EPM)** — link-level power management on USB 3.x (U1/U2 link states, `LPMEnabled`).
- **Wake capability** — the device is allowed to wake the machine from sleep; keeping this armed keeps extra power-management logic in the path.
- **WDF idle policy** (`IdleInWorkingState`, `IdleEnabled`) — the Kernel-Mode Driver Framework's own idle timer, separate from the USB stack's.

Every value both scripts write is a variation on "turn one of the above off".

---

## 2. `USB_Static_Tweaks.reg` — static, hard-coded keys

A plain registry import covering 14 groups of keys. It touches driver *service* keys, not individual devices, so it applies to any device that binds to those drivers — including ones plugged in later.

| # | Key area | Purpose |
|---|---|---|
| 1 | `Enum\USB` (root) | Idle/suspend values written at the top of the enumerator tree |
| 2 | `Control\usbflags` | D1/D2/D3 latency = 0, `DisableHCS0Idle`, `IgnoreHWSerNum` |
| 3 | `Services\USB[\Parameters]` | Core USB stack: disable selective suspend, idle power management, `ForceFullSpeed`, `ForceHCResetOnResume` |
| 4 | `Services\USBXHCI\Parameters` | USB 3.x host controller: no selective suspend, `LowLatencyMode`, `InterruptThreshold=1`, WDF `NoExtraBufferRoom` |
| 5 | `Services\usbhub\Parameters` | USB 2.0 hub: no aggressive suspend, suspend timeout 0 |
| 6 | `Services\USBHUB3\Parameters` | USB 3.x hub: same, plus `DisableWakeFromSuspend`, `InterruptThreshold=1` |
| 7–8 | `Services\usbehci`, `usbuhci` | Legacy EHCI (USB 2.0) and UHCI (USB 1.1) controllers |
| 9–10 | `Services\HidUsb`, `HidClass` | HID-over-USB driver and the HID class driver — the layer mice/keyboards live on |
| 11 | `Services\xusb22\Parameters` | Xbox controller driver, `IoQueueWorkItem` |
| 12 | `Services\usbaudio\Parameters` | USB audio, power saving only |
| 13 | `Services\WinUsb\Parameters` | Generic user-mode USB driver |
| 14 | `Control\USB\AutomaticSurpriseRemovals` | Disables recovery-from-power-drain behavior |

`InterruptThreshold=1` is the one value here that is a genuine latency knob rather than a power-saving switch: it tells the xHCI/hub driver to fire an interrupt per transfer instead of coalescing them.

---

## 3. `USB_Dynamic_Tweaks.bat` — runtime device enumeration

Where the `.reg` file writes fixed paths, the batch file discovers the machine's actual devices and writes per-device `Device Parameters` keys. It does this five times over, deliberately overlapping so nothing is missed.

**Step 0 — self-elevate.** Uses the classic `cacls` on `config\system` trick to test for admin, and re-launches itself through `Start-Process -Verb RunAs` if not elevated.

**Pass 1 — `reg query Enum\USB /s /f "Device Parameters"`**
Walks the whole USB enumerator tree and writes ~22 values into every `Device Parameters` subkey found: the idle/suspend set, the `fid_D*Latency` set, `LPMSupported`/`LPMEnable`, `PerformanceIdleTime`, `DisableWakeFromSuspend=1`, `WriteReportExSupported=1`. Then attempts a `WDF` subkey pass (`IdleInWorkingState`, `IdleEnabled`, `PowerPolicyOwnershipEnabled`).

**Pass 2 — `wmic path Win32_USBHub GET DeviceID`**
Filters for `VID_` and re-applies the core set plus the latency values at hub level.

**Pass 3 — `wmic path Win32_PnPEntity GET DeviceID`**
Filters device IDs starting with `USB\` or `HID\`. This is the pass that actually catches HID devices, which do not live under `Enum\USB`.

**Pass 4 — `Get-CimInstance Win32_USBController`**
Filters for `PCI\VEN_*` and applies the set to the PCI host controllers themselves, plus their WDF `IdleInWorkingState`.

**Pass 5 — WMI `MSPower_DeviceEnable`**
The programmatic equivalent of unticking *"Allow the computer to turn off this device to save power"* in Device Manager. Iterates every power-manageable instance, matches it against USB controllers/hubs by PNP device ID, and sets `enable = $False`.

**Then:**
- Writes `IdleEnable=0` on legacy class subkeys `Services\Class\USB\0000`–`0032`.
- Runs `powercfg -devicedisablewake` on four hard-coded friendly names ("HID-compliant mouse", "HID Keyboard Device", and their `(001)` variants).

---

## 4. Effects and trade-offs

**Expected upside:** no port ever suspends, so there is no wake-from-suspend penalty on the first input after an idle moment; interrupt coalescing on the xHCI path is reduced; devices are never renegotiated after a power transition.

**Cost:**
- Higher idle power draw — meaningful on a laptop, irrelevant on a desktop.
- Sleep, hibernate and Modern Standby behavior can change; devices that stay powered can block or complicate sleep transitions.
- USB wake (moving the mouse to wake the PC) is deliberately disabled.
- These are machine-wide, permanent registry changes with **no uninstall path in either file**.

---

## 5. Problems found in the current implementation

Worth fixing in any rewrite:

1. **No backup, no revert.** Neither file records prior values. Undoing this means a restore point or a manual registry rebuild.
2. **`if exist "%%i\WDF"`** (batch, pass 1) is a *filesystem* existence test applied to a registry path. It is always false, so the three WDF values in that block never get written. Should be a `reg query` test.
3. **`wmic` is deprecated and absent on current Windows 11 builds.** Passes 2 and 3 silently do nothing on such systems — and pass 3 is the only one that reaches HID devices, so on a modern machine the mouse and keyboard themselves may be skipped entirely.
4. **Hard-coded `ControlSet001`** in two `.reg` entries. The live control set is not guaranteed to be 001; `CurrentControlSet` is used everywhere else and should be used there too.
5. **`ForceFullSpeed=1`** forces USB 2.0 devices to negotiate Full Speed (12 Mbit/s) instead of High Speed (480 Mbit/s). This is a debugging switch. It is a bandwidth *downgrade*, not a latency improvement, and can break webcams, audio interfaces and storage.
6. **Hard-coded English device names** in the `powercfg` calls. On a non-English Windows, or with more than two HID devices, most of these miss. `powercfg -devicequery wake_armed` should drive this instead.
7. **Many written values do not exist in any Microsoft driver.** Unknown registry values are simply ignored, so they are harmless — but they inflate the script and make it impossible to tell which changes are actually doing anything.
8. **Writing idle values to the `Enum\USB` root** does not create a "fallback default"; Windows reads these per-device, not inherited from the enumerator root.
9. **Deprecated `Get-WmiObject`** in pass 5 (should be `Get-CimInstance`), and the `-like "*$pnp_id*"` match treats PNP IDs containing `[` or `]` as wildcard patterns.
10. **Five overlapping passes** re-write the same values to the same keys repeatedly, with all output suppressed — so there is no way to know what changed or whether anything failed.

---

## 6. The rewrite — `USB-LatencySuite.ps1`

A single PowerShell script with a WPF UI that replaces both files and fixes every issue above.

**Run it:** double-click `Run.vbs`. Accept the UAC prompt.

`Run.vbs` has no window of its own. It elevates and starts `powershell.exe -STA -WindowStyle Hidden` in one step, and the script hides its own console before the UI opens, so no terminal is ever visible. `-ExecutionPolicy Bypass` also ignores the downloaded-file mark. Running the `.ps1` directly works too:

```
powershell -NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File .\USB-LatencySuite.ps1
```

**Five modules**, each an independent toggle: Selective Suspend, Device Idle / D-States, Link Power Management, Wake Capability, Interrupt Threshold.

**Device list** built from one `Get-PnpDevice -PresentOnly` call — every `USB\*` and `HID\*` device plus the PCI USB host controllers. Each device has a checkbox, so a single mouse can be tuned without touching the webcam.

**Preview** builds the plan and prints every change as `key :: value: old -> new`, writing nothing. Values already at the target are not listed, so the preview doubles as a status view.

**Apply** writes each value and records the previous state — including *"this value did not exist"* — to `.\Backups\usb-tweaks-<timestamp>.json`. Failures are reported per key rather than swallowed.

**Revert last** replays the newest backup: restores prior values, deletes values that the script created, re-arms any device whose wake it disarmed, then renames the backup to `.reverted`.

Other differences from the originals:

| | Original | Rewrite |
|---|---|---|
| Device discovery | 5 overlapping passes, 2 via dead `wmic` | 1 × `Get-PnpDevice` |
| Registry access | `reg.exe` through `for /f` string parsing | `Microsoft.Win32.Registry` API — no wildcard or quoting bugs |
| WDF subkey | never written (`if exist` bug) | written |
| `ForceFullSpeed` | set to 1 | removed |
| `ControlSet001` | hard-coded in 2 places | `CurrentControlSet` throughout |
| Wake devices | 4 hard-coded English names | `powercfg /devicequery wake_armed`, intersected with the selected USB/HID set so the NIC is never disarmed |
| Undo | none | exact, per-value |

**Self-check:** `USB-LatencySuite.ps1 -SelfTest` (elevated console) round-trips the write/backup/revert path against a scratch registry key and cleans up after itself. It verifies that an existing value is restored to its old data and a newly created value is deleted.

---

## 7. Release

Ship these three files together in one folder or zip:

```
USB-LatencySuite.ps1
Run.vbs
README.md
```

Nothing else is required — no installer, no modules, no .NET download. The script uses only what ships with Windows.

**Requirements:** Windows 10 or 11 (Windows 8 is the floor — the script checks for `Get-PnpDevice` and stops with a message on anything older), Windows PowerShell 5.1, administrator rights.

**Portability handled by the release build:**

- Runs from anywhere — USB stick, Downloads, a network share.
- Backups go next to the script; if that location is read-only the script falls back to `%LOCALAPPDATA%\USBLatencySuite\Backups`. The output pane is also mirrored to `session.log` there.
- Service-level values are only written for drivers the machine actually has. `usbehci` and `usbuhci` no longer exist on modern hardware, and the script no longer creates empty service keys for them.
- Window size is clamped to the desktop work area, so it fits small and high-DPI laptop screens.
- A battery is detected and called out in the output pane — these tweaks keep USB devices powered and cost idle runtime on a laptop.
- **Reboot** button in the footer.
- **Revert last** is greyed out when there is no backup to restore.

**Own icon.** The mark in the title bar, and the taskbar/Alt+Tab icon, is a 128px PNG
embedded in the script as base64 rather than shipped beside it — the tool is meant to
be one file you can drop anywhere and run, and a loose icon file would be one more
thing to lose. If it ever fails to decode the mark is simply hidden; nothing else
depends on it.

**No console window.** The interface is the only thing on screen. `Run.vbs` has no window of its own, and it elevates and starts PowerShell hidden in a single `ShellExecute`, so nothing paints even for a frame. The script also hides its own console as a second line of defence — but only when it owns that console outright. If the script was started from a terminal that was already open, that window belongs to you and is left alone. `-SelfTest` keeps its console too, because its whole output is text.

Because nothing is printed to a console any more, an unexpected error is shown in a message box instead of vanishing with the window.

The launcher is a `.vbs` because Windows Script Host is the only thing shipped with Windows that can start a process with no window of its own — a `.cmd` is itself a console program and flashes a window on the way past. Microsoft has deprecated VBScript and moved it to a Feature on Demand, still enabled by default; if a future release or a group policy turns it off, run the `.ps1` from an admin prompt with the command above.

**If it does not start:**

| Symptom | Cause | Fix |
|---|---|---|
| `.ps1` opens in Notepad | `.ps1` is not an executable file type by design | use `Run.vbs` |
| "running scripts is disabled on this system" | execution policy | use `Run.vbs`, or add `-ExecutionPolicy Bypass` |
| "file is not digitally signed" / blocked | Mark of the Web after download | `-ExecutionPolicy Bypass` ignores it; or right-click the `.ps1` → Properties → Unblock |
| Window never appears | launched without `-STA` | use `Run.vbs` |
| Windows Script Host is disabled by policy | the launcher cannot run | start the `.ps1` from an admin PowerShell prompt with the command above |
| Antivirus flags it | any script that writes bulk registry values under `HKLM\SYSTEM` looks like a tweaker to heuristics | it is plain text — read it, or add an exclusion |

**A few keys may fail to write on some systems.** Parts of the `Enum` tree are ACL'd to SYSTEM rather than Administrators. Those failures are listed individually in the output pane instead of being swallowed; everything else still applies.
