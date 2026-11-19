# selector

Script picker for iii grids. Every `.lua` script on the device gets a slot, so there's no list of names to maintain.

- Slots fill the top rows, sorted by name, each in its own color (or a plain brightness level on firmware without `grid_led_rgb`).
- Press a slot to show the script's name along the bottom five rows in a 3x5 font. Letters touch, with every other one dimmed to 10% to tell them apart (the same approach as leaveseqr). Long names are shown as many letters as fit at a time (5 on a 16-wide grid, 2 on an 8-wide one), switching every 3 seconds. Change `page_time` or `dim` at the top of the script to adjust.
- Press the same slot again to load the script. Press anywhere else to deselect.
- The slot list is also printed to the diii console.

## Install

1. Upload `selector.lua` with diii, along with your scripts.
2. Make it the boot script in the REPL: `first("selector.lua")`. `first()` with no argument removes the boot script again.

## Notes

- Skipped files: `init.lua`, `lib.lua`, `selector.lua`, anything not ending in `.lua`, and support files starting with `pset_`, `data_` or `state_`. Add names to `skip` or prefixes to `skip_prefix` at the top of the script.
- On a 16x8 or 8x8 grid there are 2 slot rows (32 or 16 slots). On a 4x4 grid there's no room for the name, so every row holds slots and the second press still loads.
- To get back to the selector, power-cycle the grid, or use the `reboot` button in diii.
- Font: there are only so many ways to draw letters in 3x5. Our serpentine and leaveseqr readouts use square shapes, where S and 5, and O and 0, look the same. For names we picked the rounder shapes, as in carlosedp's font in many-roads-grid, and drew our own 6, 8 and 9.
- Similar scripts:
  - [many-roads-grid](https://github.com/boreal-ground/many-roads-grid) tours through the scripts, scrolling each name across the bottom rows. A short press loads a script on release, and holding a key shows its name. While a loaded script runs, triple-clicking the top-left key restarts the grid into many-roads.
  - selector shows a name only when you press a slot, needs a second press to load, and has no in-script shortcut that could clash with a running script. To pick another script, reboot.
  - selector pages names instead of scrolling them, because scrolling text flickers and is hard to read. Dimming every other letter instead of leaving a blank column between letters fits 5 letters on a 16-wide grid instead of 4.
