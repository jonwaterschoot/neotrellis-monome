# Neotrellis Grid + iii Code for Raspberry Pi Pico/RP2040 boards  

This version is rewritten to use the Raspberry Pi Pico VS Code Extension and includes the monome iii scripting mode.  

Install the Raspberry Pi Pico VS Code Extension from the Extensions tab in VSCode.  

![alt text](PicoVSCodeExtn.png)

### Configuration

Look at the `# UPDATE HERE FOR YOUR BOARD AND BUILD` sections of `CMakeLists.txt` to configure for your specific board. This *should* be the only configuration changes needed.  

```
# SET BOARD TYPE
# board type can be:
# pico  (included in Pico SDK)
# adafruit_kb2040  (included in Pico SDK)
# board_dinkii  (included in neotrellis repo)
# adafruit_feather_rp2040  (included in Pico SDK)

set(PICO_BOARD pico CACHE STRING "Board type")

```
and then further down, look for...  

```
# Build defines
```

Set these according to your specific build  
```
    BOARDTYPE=1   # must be number - options are:  1=PICO, 2=KB2040QT, 3=DINKII, 4=FEATHER2040QT
    GRIDCOUNT=3   # must be number - options are:  1=4X4, 2=8x8, 3=16x8, 4=16x16 
```

### Building

Use the __Raspberry Pi Pico VS Code Extension__ to configure and build:

1. Open the project folder in VS Code  
2. Run **Raspberry Pi Pico: Configure CMake** from the Command Palette to generate the build directory  
3. Run **Raspberry Pi Pico: Build Project** (or press the build button in the status bar). 

The build output (`neotrellis-iii.uf2`) will be in the `build/` directory.  

> **Note:** You do not need to wipe the `build/` folder between builds. CMake/Ninja performs incremental builds automatically — only changed files are recompiled. Only wipe the build folder if you change CMake configuration options (board type, SDK version, etc.) and the build behaves unexpectedly.  

To flash: hold the BOOTSEL button on the Pico while plugging in USB, then drag-and-drop the `.uf2` file onto the mass storage drive that appears.  

### Device modes. 

The firmware supports two modes, stored in flash and persisted across power cycles and UF2 uploads:  

- **Mode 0 (iii)** — Lua scripting via iii. Connect to https://monome.org/diii in Chrome to use the interactive REPL. The device appears as a USB CDC serial port and MIDI device.  
- **Mode 1 (monome)** — Standard monome serial protocol over USB CDC. Use with serialosc and monome-compatible apps.  

To toggle between modes: hold key **(0,0)** (top-left) while the device is powering up.  

### i2c address configuration  

NeoTrellis tiles have I2C address jumpers (A0–A4) and a base address of `0x2E`. The addresses in `config.h` must match the physical jumper settings on your tiles.  

The reference address map (as shown in [neotrellis_addresses.jpg](https://github.com/okyeron/neotrellis-monome/blob/main/neotrellis_addresses.jpg)) lists tiles left-to-right:  

**16×8 (ONETWENTYEIGHT) — 8 tiles:**

| | col 1 | col 2 | col 3 | col 4 |
|---|---|---|---|---|
| **Row 1 (top)** | none → `0x2E` | A0 → `0x2F` | A1 → `0x30` | A2 → `0x32` |
| **Row 2 (bottom)** | A3 → `0x36` | A4 → `0x3E` | A0+A1 → `0x31` | A0+A2 → `0x33` |

**8×8 (SIXTYFOUR) — 4 tiles:**

| | col 1 | col 2 |
|---|---|---|
| **Row 1 (top)** | none → `0x2E` | A0 → `0x2F` |
| **Row 2 (bottom)** | A3 → `0x36` | A4 → `0x3E` |

Note: the arrays in `config.h` are written right-to-left (matching the pixel index ordering), which is the mirror of the picture. If your grid's first column responds to the wrong tile, swap the address order in `config.h`:

```c
// ONETWENTYEIGHT
const uint8_t addrRowOne[4] = {0x32, 0x30, 0x2F, 0x2E};
const uint8_t addrRowTwo[4] = {0x33, 0x31, 0x3E, 0x36};

// SIXTYFOUR
static const uint8_t addrRowOne[2] = {0x2F, 0x2E};
static const uint8_t addrRowTwo[2] = {0x3E, 0x36};
```

If you're not using the default address configuration, update these arrays in `config.h` to match your boards.

### LED color and brightness

All LED settings are in `config.h`:

```
#define BRIGHTNESS 96   // overall brightness (lower = dimmer; may need reduction for larger grids)

#define R 255           // red component   (0–255)
#define G 255           // green component (0–255)
#define B 255           // blue component  (0–255)

// gamma table for 16 brightness levels (monome uses 0–15)
static const uint8_t gammaTable[16] = {0, 2, 3, 6, 11, 18, 25, 32,
                                       41, 59, 70, 80, 92, 103, 115, 127};
static const uint8_t gammaAdj = 1; // multiply gamma output by 1 or 2
```

For example, to use a green-tinted color:
```
// Seafoam / Mint Green
#define R 73
#define G 214
#define B 148
```

`BRIGHTNESS` caps the overall output — useful if NeoPixels are too bright when powered over USB. `gammaAdj` can be set to `2` to boost perceived brightness at lower levels.

### iii  

iii is an interactive scripting environment that runs on the device itself.  With grid, this can turn the device into a user-scriptable midi controller/sequencer.  

See https://github.com/monome/iii for documentation.  

The `diii` REPL tool is hosted at https://monome.org/diii  

The neotrellis build includes custom lua functions to change LED colors.

`grid_color(r, g, b)` sets a global tint applied to all pixels. You can use this in scripts as follows. The if statement is there to avoid errors on regular iii devices.

```if grid_color then grid_color(250,80,10) end```

This tint applies to `grid_led()` / `grid_led_all()` output, while `grid_led_rgb()` provides true independent per-pixel color.

`grid_led_rgb(x, y, r, g, b)` sets a true per-pixel RGB color (0–255 per channel), bypassing the global tint. This allows multicolor scripts without any multiplexing or constant refresh. Use the same if guard:

```if grid_led_rgb then grid_led_rgb(x, y, 255, 0, 0) end```

See [grid_led_rgb.md](grid_led_rgb.md) for full details, behavior notes, and examples.

### Writing cross-device scripts — monochrome fallback

Scripts that call `grid_led_rgb` run in full color on NeoTrellis. On a standard iii device `grid_led_rgb` is `nil`, so those calls are safely skipped — but that means **every pixel stays dark**. A well-written script degrades gracefully by translating its color intent into a `grid_led` brightness level.

The recommended pattern is a single `spx` wrapper function at the top of your script:

```lua
local W, H = grid_size_x(), grid_size_y()

local function spx(x, y, r, g, b)
  if x < 1 or x > W or y < 1 or y > H then return end
  if grid_led_rgb then
    grid_led_rgb(x, y, r, g, b)
  else
    -- Convert brightest channel to 0-15 level.
    -- Floor at 4: levels 1-3 are physically invisible on NeoTrellis
    -- hardware and very dim on standard grids — any non-black pixel
    -- should be at least faintly visible.
    local lv = math.floor(math.max(r, g, b) / 17)
    if lv < 4 and (r > 0 or g > 0 or b > 0) then lv = 4 end
    grid_led(x, y, lv)
  end
end
```

Then replace every direct `grid_led_rgb` / `grid_led` call in your draw code with `spx(x, y, r, g, b)`. The color ratios you choose for NeoTrellis become the brightness contrast on monochrome grids automatically — a bright green active state and a dark green inactive state will render as level 15 and level 4 respectively.

**Why level 4?** Confirmed through hardware testing on NeoTrellis via the viii app (WebSerial/mext protocol). The mext protocol uses a 0-15 brightness scale; levels 1–3 fall below the physical LED threshold and appear off. Level 4 (~27% of maximum) is the lowest level that renders as visibly dim-but-intentional. Bright active states typically land at level 10–15, giving clear contrast.

**Testing with viii**: [dessertplanet/viii](https://github.com/dessertplanet/viii) is a browser app that connects to a physical Monome-compatible grid over WebSerial and runs iii Lua scripts directly. It exposes only `grid_led` (0-15), not `grid_led_rgb` — making it the ideal tool to verify your monochrome fallback before deploying to hardware, without needing a second device.

See [color_fallback_demo.lua](../scripts/color_fallback_demo.lua) for a minimal, runnable example of this pattern.

Please don't bother monome or the lines forum with regards to these particular features.