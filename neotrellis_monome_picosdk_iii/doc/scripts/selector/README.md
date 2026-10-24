# selector

Script picker for iii grids. Every `.lua` script on the device gets a slot, so there's no list of names to maintain.

- Slots fill the top rows, sorted by name, each in its own color (or a plain brightness level on firmware without `grid_led_rgb`).
- Press a slot to show the script's name along the bottom five rows in a 3x5 font. Long names are shown as many letters as fit at a time (4 on a 16-wide grid, 2 on an 8-wide one), switching every second. Change `page_time` at the top of the script to adjust.
- Press the same slot again to load the script. Press anywhere else to deselect.
- The slot list is also printed to the diii console.

## Install

1. Upload `selector.lua` with diii, along with your scripts.
2. Make it the boot script in the REPL: `first("selector.lua")`. `first()` with no argument removes the boot script again.

## Notes

- Skipped files: `init.lua`, `lib.lua`, `selector.lua`, anything not ending in `.lua`, and support files starting with `pset_`, `data_` or `state_`. Add names to `skip` or prefixes to `skip_prefix` at the top of the script.
- On a 16x8 or 8x8 grid there are 2 slot rows (32 or 16 slots). On a 4x4 grid there's no room for the name, so every row holds slots and the second press still loads.
- To get back to the selector, power-cycle the grid, or use the `reboot` button in diii.
- Similar scripts:
  - [many-roads-grid](https://github.com/boreal-ground/many-roads-grid) loads on the first press, and triple-clicking the top-left key reboots back to the menu.
  - The [carlosedp `indication` fork](https://github.com/carlosedp/many-roads-grid/tree/indication) adds a continuous "tour" that scrolls each script's name in turn. It still loads on the first press.
  - selector shows a name only when you press a slot, needs a second press to load, and has no in-script shortcut that could clash with a running script. To pick another script, reboot.
