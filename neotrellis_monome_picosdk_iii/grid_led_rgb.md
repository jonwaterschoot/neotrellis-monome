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
- `grid_color_intensity(z)` sets a master brightness (0–15) specifically for all `grid_led_rgb` overrides. This allows you to scale the brightness of your color scripts independently of the standard grid intensity.
- **Power Safety**: To prevent power brown-outs, the firmware includes a **Global Power Limiter**. If the total requested brightness of the entire grid exceeds the safe USB power budget (matching the original firmware's maximum for any grid size), all pixels are automatically and uniformly dimmed to stay within safe limits.
- `grid_led(x, y, z)` on an overridden pixel clears its override, reverting it to global tint behavior.
- `grid_led_all(z)` clears all overrides across the entire grid.
- Scripts that never call `grid_led_rgb` behave identically to before.

## Hardware Limitations

Due to the nature of 8-bit LED PWM and physical differences in LED efficiency:
- **Low Brightness Consistency**: At very low intensities (master brightness levels 1–3), some color tints may shift slightly. For example, Orange/Amber might appear redder, and Greenish tints might appear greener. 
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

To ensure your scripts run on both this firmware and original `iii` devices (which lack these functions), always check if the function exists before calling it. This is the **preferred way** to maximize compatibility.

```lua
-- Recommended way to set master brightness safely:
if grid_color_intensity then grid_color_intensity(12) end -- Set to 75% brightness

-- Recommended way to set a pixel color safely:
if grid_led_rgb then 
    grid_led_rgb(x, y, 255, 128, 0) -- Orange
else
    grid_led(x, y, 15) -- Fallback to monochromatic white/amber
end
```

On a standard `iii` device, these `nil` checks will evaluate to false, and the block will be safely skipped.

## Files changed

| File | Change |
|------|--------|
| `src/device.cpp` | Added `px_override[]` + `px_rgb[]` arrays; updated `sendLeds_iii()`, `device_led_set()`, `device_led_all()`; added `device_led_rgb_set()` |
| `src/device_ext.h` | Declared `device_led_rgb_set()` |
| `src/device_lua.c` | Added `l_grid_led_rgb()` binding, registered as `grid_led_rgb` |
