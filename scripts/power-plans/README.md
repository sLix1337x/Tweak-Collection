# Power plans

Exported Windows power schemes. A `.pow` is a binary export from `powercfg`; it
carries every setting in the scheme, hidden ones included.

| File | What it is |
| --- | --- |
| `CS2 Zen3 Frametime.pow` | Ultimate Performance with a handful of deliberate changes for a Ryzen 5950X desktop. |

## Import

```powershell
powercfg /import "CS2 Zen3 Frametime.pow"     # prints the new scheme's GUID
powercfg /setactive <guid>
```

## Undo

```powershell
powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e   # Balanced
powercfg /delete <guid>
```

## Export your own

```powershell
powercfg /getactivescheme
powercfg /export "My plan.pow" <guid>
```

What each changed setting does, and which ones are only inherited defaults:
https://slix1337x.github.io/Tweak-Collection/tools/cs2-zen3-frametime/
