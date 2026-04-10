# Neotrellis Pico RGB Fork Overview

**Status: Working build available — [`neotrellis-iii-pico-25ktresholdsolver-jonwtr.uf2`](../uf2s/neotrellis-iii-pico-25ktresholdsolver-jonwtr.uf2)**

As I kept running into the 25KB ceiling for scripts, I started thinking there should be a way to surpass that.  
I ran into size issues with my [neotrellis monome grid emulator](https://jonwaterschoot.github.io/diii-neotrellis-emulator/), a webapp that allows to run the `.lua` scripts in the browser and has an option to overlay a live manual using the ldoc method (including info about the script's controls inside the scripts). 

In all my scripts this soon caused the file to be too big, so I implemented a minify script that strips all comments with a `download for device` button.

However, the threshold could actually be raised by handling the upload to the Pico differently.  
It remains compatible with the `diii` uploader, as the new parsing happens entirely in the new Pico firmware.  
(By "I researched this" I _obviously_ mean I provided an LLM with the details and we looked into options together, while still trying to respect backwards compatibility.)

The only downside is that by successfully loading larger scripts, I am one step further from compatibility with the build from @okyeron and the broader monome ecosystem. Backwards compatibility has been one of my main goals when implementing color features.

So, **TLDR — this is a working implementation.**

Should I suggest this approach to tehn or other developers involved? I am of course reluctant to put forward vibe-coded work that might not be appreciated by everyone.

Here's a recap of the brainstorm and refactoring:
> "Currently, the firmware's serial upload architecture (`repl.c`) uses a large line buffer to hold incoming script data in RAM, and `vm.c` loads the whole file into another RAM buffer to parse it. This limits scripts to ~25KB before hitting Out-Of-Memory crashes. By reducing `repl.c`'s line buffer to 512 bytes and streaming each line directly to LittleFS, and by using Lua's stream-native `lua_load` reader (with a custom `fs_lua_reader`) instead of `luaL_dostring` for file execution, we can eliminate these massive RAM buffers. This effectively raises the allowable script size for all users without changing the `diii` interface."

*Note: `luaL_dostring` is still used for interactive REPL lines, which are short by nature. The streaming `lua_load` path applies only to file execution from LittleFS.*


This document summarizes the custom modifications introduced in this fork to enable rich RGB color on Neotrellis boards, alongside an architectural proposal for the upstream Monome `iii` firmware to fix script memory limits.

## 1. Custom Neotrellis Additions (Compared to Upstream)
To support RGB functionality on Neotrellis clones while retaining backward compatibility, the following non-destructive improvements were made to the C++ core:

### `device.cpp`
* **Per-Pixel Intercepts:** Integrated a secondary `px_override` state array and `px_rgb` color buffer array to map specific pixels independently from the global monochrome `mmap` values.
* **RGB Gamma & Scale Engine:** 
  * Adjusted the base `gammaTable` curve to ensure minimum pixel visibility.
  * Re-architected `sendLeds_iii()` into a two-pass system: 
    * *Pass 1:* Computes true RGB values. If a pixel was set using traditional monome variables, it delegates to `level_to_color`. If it was overridden with exact RGB values, it scales the raw RGB by a global `px_gain` multiplier.
    * *Pass 2:* Analyzes the total requested color load. If it exceeds a safe hardcoded hardware power limit (`max_safe`), it computes a fixed-point scaler to automatically dim the grid, absolutely preventing hardware brownouts from aggressive color assignments.

### `device_lua.c` & Lua API Interfaces
Exposed two new commands accessible via user scripts:
* `grid_led_rgb(x, y, r, g, b)`: Sets exact RGB values and triggers the override buffer.
* `grid_color_intensity(z)`: Adjusts the global `px_gain` (translates 0-15 grid metrics into a 0-255 RGB brightness modifier).

*These features do not break existing scripts; any script executing traditional monochrome commands (`grid_led`, `grid_all`) simply bypasses the `px_override` flags automatically.*

---

## 2. Implemented: Script Size Limit Fix
Previously, the firmware's large serial line buffer and full-RAM script loading caused Out-Of-Memory reboots when uploading `.lua` files larger than ~25KB. This fork implements a direct-to-LittleFS streaming architecture that is fully compatible with existing IDEs like `diii` and the WebEmulator.

### What Was Changed
* **Streaming File Transfers (`repl.c`):** The line buffer was reduced from ~16KB to 512 bytes. Each line of an incoming script is now written directly to LittleFS via `fs_file_write` rather than accumulated in RAM. The script is written to a `.uploading.tmp` file first, then compiled and renamed only if the compilation succeeds.
* **Stream-Native Lua Parsing (`vm.c`):** File execution uses `lua_load(L, fs_lua_reader, ...)` with a custom 256-byte chunk reader (`fs_lua_reader`) instead of loading the entire file into a RAM buffer. Lua tokenizes the script sequentially from LittleFS flash, never holding the full source in SRAM.

*This effectively raises the allowable size of Lua scripts well beyond the old ~25KB ceiling by removing the RAM bottleneck. Script size is now constrained by LittleFS flash capacity rather than SRAM.*

---

## 3. Repository Setup: Submodule Fork

Because the `iii` and `littlefs` directories inside this project are git submodules pointing to [tehn's upstream repos on Codeberg](https://codeberg.org/tehn/iii), the changes to `repl.c`, `vm.c`, `vm.h`, and `resource/lib_lua.c` had to be committed into a personal fork — otherwise the parent repo would reference a commit hash that only exists locally and anyone cloning would get a broken submodule.

### What was done

1. Created a Codeberg account: https://codeberg.org/jonwaterschoot
2. Forked `tehn/iii` to: https://codeberg.org/jonwaterschoot/iii
3. Committed the 4 modified files inside the `iii` submodule:
   ```bash
   cd neotrellis_monome_picosdk_iii/src/iii
   git add repl.c vm.c vm.h resource/lib_lua.c
   git commit -m "stream serial uploads to flash and add file-streaming Lua reader for 25KB+ script support"
   ```
4. Redirected the submodule's `origin` to the personal fork:
   ```bash
   git remote set-url origin https://codeberg.org/jonwaterschoot/iii
   git push origin main
   ```
5. Updated `.gitmodules` in the parent repo to point to the fork, then staged and committed:
   ```bash
   git submodule sync
   git add .gitmodules neotrellis_monome_picosdk_iii/src/iii
   git commit -m "point iii submodule to personal fork with 25KB streaming fix"
   ```

`littlefs` was not touched — it remains pointed at the upstream Codeberg repo.

### Relationship to upstream

| Repo | Remote | Contains |
|---|---|---|
| `neotrellis-monome` | GitHub (this repo) | Main project, references the iii fork |
| `iii` | https://codeberg.org/jonwaterschoot/iii | Streaming upload + file-streaming Lua reader |
| `tehn/iii` | https://codeberg.org/tehn/iii | Upstream — unchanged, fork branched from it |

If the 25KB fix is ever worth proposing upstream, a PR from `jonwaterschoot/iii` → `tehn/iii` on Codeberg is the path.

Or a manual copy keeping stuff / adjusting stuff / etc. I do not insist on credit. I'd just like to maintain a good working environment to play in.

---

##
