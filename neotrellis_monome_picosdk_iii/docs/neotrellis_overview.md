# Neotrellis Pico RGB Fork Overview

**Status: Working build available — [`neotrellis-iii-pico-25ktresholdsolver-jonwtr.uf2`](../uf2s/neotrellis-iii-pico-25ktresholdsolver-jonwtr.uf2)**

This fork lives on top of two separate repos. Changes are split across both:

| Layer | Base | This fork |
|---|---|---|
| Parent project | [@okyeron/neotrellis-monome](https://github.com/okyeron/neotrellis-monome) `main` | `jonwaterschoot/neotrellis-monome` `feature/colors` |
| `iii` submodule | [tehn/iii](https://codeberg.org/tehn/iii) `main` | [jonwaterschoot/iii](https://codeberg.org/jonwaterschoot/iii) `fix/25kb-streaming` |

The RGB color work is entirely in the parent project. The 25KB script size fix is entirely in the `iii` submodule. Neither set of changes depends on the other — they can be considered independently.

---

## Background

As I kept running into the 25KB ceiling for scripts, I started thinking there should be a way to surpass that.
I ran into size issues with my [neotrellis monome grid emulator](https://jonwaterschoot.github.io/diii-neotrellis-emulator/), a webapp that allows running `.lua` scripts in the browser and has an option to overlay a live manual using the ldoc method (including info about the script's controls inside the scripts).

In all my scripts this soon caused the file to be too big, so I implemented a minify script that strips all comments with a `download for device` button.

However, the threshold could actually be raised by handling the upload to the Pico differently. It remains compatible with the `diii` uploader, as the new parsing happens entirely in the firmware.
(By "I researched this" I _obviously_ mean I provided an LLM with the details and we looked into options together, while still trying to respect backwards compatibility.)

The only downside is that by successfully loading larger scripts, I am one step further from compatibility with the build from @okyeron and the broader monome ecosystem. Backwards compatibility has been one of my main goals when implementing color features.

**TLDR — this is a working implementation.** Should I suggest this approach to tehn or other developers involved? I am of course reluctant to put forward vibe-coded work that might not be appreciated by everyone. Or a manual copy keeping stuff / adjusting stuff / etc. I do not insist on credit. I'd just like to maintain a good working environment to play in.

---

## 1. Changes to the parent project — `feature/colors` vs @okyeron/main

These changes are in `neotrellis_monome_picosdk_iii/src/` inside this repo.
They add RGB color support to the Neotrellis hardware while remaining non-destructive to existing monochrome scripts.

### `config.h`
* Adjusted the `gammaTable` curve to ensure minimum pixel visibility at low brightness levels.

### `device.cpp`
* **Per-pixel RGB override:** Added a `px_override[i]` flag array and `px_rgb[i]` color buffer. When a pixel is set via `grid_led_rgb`, the override flag is raised and its exact RGB value is stored. Standard monochrome commands (`grid_led`, `grid_all`) clear the override flag automatically — so existing scripts are unaffected.
* **`sendLeds_iii()` rewritten as a two-pass system:**
  * *Pass 1:* Computes final color per pixel. Override pixels use `px_rgb` scaled by global `px_gain`; non-override pixels use the existing `level_to_color` path.
  * *Pass 2:* Sums total color load. If it exceeds `max_safe` (the power budget matching the original firmware's worst case), a fixed-point scaler dims the whole grid proportionally — preventing hardware brownouts from aggressive color assignments.
* **`device_color_intensity(z)`:** Sets the global `px_gain` multiplier (0–15 → 0–255).
* **`device_led_rgb_set(x, y, r, g, b)`:** Sets exact RGB and raises the override flag for a pixel.

### `device_ext.h`
* Added extern declarations for `device_led_rgb_set` and `device_color_intensity`.

### `device_lua.c` — new Lua API
Two new commands exposed to user scripts:
* `grid_led_rgb(x, y, r, g, b)` — sets exact RGB values for a pixel.
* `grid_color_intensity(z)` — adjusts the global brightness multiplier (0–15 scale).

### `.gitmodules`
* The `iii` submodule URL was changed from `tehn/iii` to `jonwaterschoot/iii` (see Section 2).

---

## 2. Changes to the `iii` submodule — `jonwaterschoot/iii` vs `tehn/iii`

These changes are in `neotrellis_monome_picosdk_iii/src/iii/`, which is a separate git repo (a submodule).
The base for this work is [tehn/iii](https://codeberg.org/tehn/iii); the fork lives at [codeberg.org/jonwaterschoot/iii](https://codeberg.org/jonwaterschoot/iii).

The goal was to remove the RAM bottleneck that limited script uploads to ~25KB. Here's the recap:

> "Currently, the firmware's serial upload architecture (`repl.c`) uses a large line buffer to hold incoming script data in RAM, and `vm.c` loads the whole file into another RAM buffer to parse it. This limits scripts to ~25KB before hitting Out-Of-Memory crashes. By reducing `repl.c`'s line buffer to 512 bytes and streaming each line directly to LittleFS, and by using Lua's stream-native `lua_load` reader (with a custom `fs_lua_reader`) instead of `luaL_dostring` for file execution, we can eliminate these massive RAM buffers. This effectively raises the allowable script size for all users without changing the `diii` interface."

### `repl.c`
* Line buffer reduced from ~16KB to 512 bytes.
* Each incoming script line is written directly to flash via `fs_file_write` rather than accumulated in RAM.
* Script is first written to `.uploading.tmp`, compiled, then renamed — only if compilation succeeds.

### `vm.c` / `vm.h`
* File execution uses `lua_load(L, fs_lua_reader, ...)` with a custom 256-byte chunk reader instead of loading the entire file into a RAM buffer. Lua tokenizes the script sequentially from flash, never holding the full source in SRAM.
* `luaL_dostring` is still used for interactive REPL lines, which are short by nature.

### `resource/lib_lua.c`
* Supporting changes for the above.

*Script size is now constrained by LittleFS flash capacity rather than SRAM.*

A PR has been opened from `jonwaterschoot/iii:fix/25kb-streaming` → `tehn/iii:main` on Codeberg.

---

## 3. Repository setup: how the submodule fork was wired up

The `iii` submodule originally pointed directly at `tehn/iii`. Changes committed there would only exist locally — anyone cloning this repo would get a broken submodule. To fix that:

1. Created Codeberg account: https://codeberg.org/jonwaterschoot
2. Forked `tehn/iii` to: https://codeberg.org/jonwaterschoot/iii
3. Committed the 4 modified files inside the submodule:
   ```bash
   cd neotrellis_monome_picosdk_iii/src/iii
   git add repl.c vm.c vm.h resource/lib_lua.c
   git commit -m "stream serial uploads to flash and add file-streaming Lua reader for 25KB+ script support"
   ```
4. Added Codeberg SSH key, added `tehn/iii` as upstream, and created a feature branch on top of the latest upstream `main`:
   ```bash
   git remote add upstream https://codeberg.org/tehn/iii
   git fetch upstream
   git checkout -b fix/25kb-streaming upstream/main
   git cherry-pick <fix-commit>
   ```
5. Switched origin to SSH and pushed the feature branch:
   ```bash
   git remote set-url origin git@codeberg.org:jonwaterschoot/iii.git
   git push origin fix/25kb-streaming
   ```
6. Updated `.gitmodules` in the parent repo and committed the pointer:
   ```bash
   git submodule sync
   git add .gitmodules neotrellis_monome_picosdk_iii/src/iii
   git commit -m "point iii submodule to personal fork with 25KB streaming fix"
   ```

`littlefs` was not touched — it remains pointed at the upstream Codeberg repo.
