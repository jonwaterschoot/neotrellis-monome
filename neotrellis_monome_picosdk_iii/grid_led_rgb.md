# `grid_led_rgb(x, y, r, g, b)` — per-pixel RGB override

Adds a per-pixel RGB Lua function alongside the existing `grid_color()`, so scripts can set individual pixels to any true color without multiplexing hacks or constant refreshes.

## Lua API

```lua
grid_led_rgb(x, y, r, g, b)   -- x, y: 1-based; r, g, b: 0–255
grid_color_intensity(z)       -- z: 0–15 master brightness for RGB overrides
grid_refresh()
```

Existing functions are unchanged and fully backward-compatible.

## Behavior

- `grid_led_rgb(x, y, r, g, b)` sets a per-pixel RGB override. On the next `grid_refresh()` the pixel displays that exact color.
- `grid_color(r, g, b)` sets a global tint for subsequent `grid_led()` / `grid_led_all()` output.
- `grid_color_intensity(z)` sets a master brightness (0–15) for the final rendered output. This scales both tinted and RGB pixels, making it useful for overall brightness control.
- **Power Safety**: To prevent power brown-outs, the firmware includes a **Global Power Limiter**. If the total requested brightness of the entire grid exceeds the safe USB power budget (matching the original firmware's maximum for any grid size), all pixels are automatically and uniformly dimmed to stay within safe limits.
- `grid_led(x, y, z)` on an overridden pixel clears its override, reverting it to global tint behavior.
- `grid_led_all(z)` clears all overrides across the entire grid.
- Scripts that never call `grid_led_rgb` behave identically to before.

## Hardware Limitations

Due to the nature of 8-bit LED PWM and physical differences in LED efficiency:
- **Low Brightness Consistency**: At very low intensities (master brightness levels 1–3), some color tints may shift slightly. For example, Orange/Amber might appear redder, and Greenish tints might appear greener.
- **Cyan/Blue Color Shift**: At brightness levels 4-7, cyan and blue tints (high blue channel values) may render as orange/reddish due to LED efficiency differences. This affects `grid_led()` calls with blue-heavy tints at low brightness levels.
- **Visibility Thresholds** (hardware tested):
  - **Levels 1-2**: Physically invisible on tinted `grid_led()` calls
  - **Level 3**: First visible level on tinted `grid_led()` calls, but colors may be inaccurate
  - **Levels 4-7**: Visible but tinted `grid_led()` output may shift unpredictably; blue/cyan tints can look orange, and low-brightness orange tints can even appear cyan depending on channel thresholds
  - **Levels 8+**: Generally accurate color reproduction
  - **RGB overrides**: `grid_led_rgb()` provides better color accuracy even at low brightness levels
- **Minimum Signal**: The firmware includes a "Minimum Signal Guarantee" that prevents individual color channels from turning off completely if they are part of a tint, but the hardware's smallest step may still be brighter for one color than another.

## Example

```lua
-- Single pixel override
grid_led_all(0)
grid_led_rgb(3, 3, 255, 0, 0)   -- pixel (3,3) pure red
grid_refresh()

-- Mix global tint with per-pixel overrides
grid_color(0, 150, 150)          -- global tint: teal
grid_led_all(8)                  -- all pixels teal at half brightness
grid_led_rgb(1, 1, 255, 0, 0)   -- pixel (1,1) overrides to pure red
grid_led_rgb(2, 1, 0, 255, 0)   -- pixel (2,1) overrides to pure green
grid_refresh()
```

## Compatibility & Best Practices

To ensure your scripts run on both this firmware and original `iii` devices (which lack these functions), always check if the function exists before calling it.

The recommended approach is a single `spx` wrapper at the top of your script that handles both paths. This way all draw calls use one function and the fallback logic is written once:

```lua
local W, H = grid_size_x(), grid_size_y()

-- Cross-device pixel writer.
-- NeoTrellis: sends full RGB color.
-- Standard iii / monochrome grids: converts to 0-15 brightness level.
-- Non-black pixels are floored at level 4 — the confirmed minimum
-- visible threshold on NeoTrellis hardware (levels 1-3 appear off).
local function spx(x, y, r, g, b)
  if x < 1 or x > W or y < 1 or y > H then return end
  if grid_led_rgb then
    grid_led_rgb(x, y, r, g, b)
  else
    local lv = math.floor(math.max(r, g, b) / 17)
    if lv < 4 and (r > 0 or g > 0 or b > 0) then lv = 4 end
    grid_led(x, y, lv)
  end
end

-- Set master brightness safely:
if grid_color_intensity then grid_color_intensity(12) end
```

Use `spx` for every pixel draw. The color contrast you design for NeoTrellis (bright active vs dim inactive) automatically becomes brightness contrast on monochrome grids.

On a standard `iii` device, `grid_led_rgb` is `nil`, so `spx` takes the `else` branch and drives `grid_led` directly.

## Color Accuracy Testing

For critical color applications, test your tints at various brightness levels using systematic testing. The included `color-threshold-test.lua` script tests cyan tint accuracy across brightness levels 4-11 to identify where color shifts occur on your specific hardware.

**Cross-Platform Testing Notes**:
- **diii webapp**: Shows full RGB color rendering including `grid_led_rgb()` overrides
- **viii webapp**: Shows monochrome fallback (standard white tint) - ignores RGB calls and only displays `grid_led()` calls
- **Hardware**: NeoTrellis shows color, original Monome grids show monochrome

**Recommendation**: For reliable color reproduction, prefer brightness levels 8-15 or use `grid_led_rgb()` overrides for precise colors at any brightness level. Avoid tinted `grid_led()` calls at levels 1-7 for blue/cyan colors.

## Files changed

| File | Change |
|------|--------|
| `src/device.cpp` | Added `px_override[]` + `px_rgb[]` arrays; updated `sendLeds_iii()`, `device_led_set()`, `device_led_all()`; added `device_led_rgb_set()` |
| `src/device_ext.h` | Declared `device_led_rgb_set()` |
| `src/device_lua.c` | Added `l_grid_led_rgb()` binding, registered as `grid_led_rgb` |
