# NVIDIA legacy image sharpening

Two `.reg` files that bring the driver-side **Image Sharpening** option back to
NVIDIA Control Panel on drivers that hid it behind the NVIDIA App.

| File | Does |
| --- | --- |
| `Nvidia Legacy Sharpen.reg` | Writes `EnableGR535 = 0`. Reboot, then the option is back under *Manage 3D settings*. |
| `Nvidia Legacy Sharpen (undo).reg` | Deletes the value. Reboot, and the driver is back to stock. |

Full explanation, what it costs and why it matters for 4:3 stretched:
https://slix1337x.github.io/Tweak-Collection/tools/nvidia-legacy-sharpen/
