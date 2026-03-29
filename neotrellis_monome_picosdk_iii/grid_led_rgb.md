# `grid_led_rgb(x, y, r, g, b)` — per-pixel RGB override

Adds a per-pixel RGB Lua function alongside the existing `grid_color()`, so scripts can set individual pixels to any true color without multiplexing hacks or constant refreshes.

## Lua API

```lua
grid_led_rgb(x, y, r, g, b)   -- x, y: 1-based; r, g, b: 0–255
grid_refresh()
```

Existing functions are unchanged and fully backward-compatible.

## Behavior

- `grid_led_rgb(x, y, r, g, b)` sets a per-pixel RGB override. On the next `grid_refresh()` the pixel displays that exact color.
- **Power Safety**: To prevent power brown-outs, the firmware includes a **Global Power Limiter**. If the total requested brightness of the entire grid exceeds the safe USB power budget (matching the original firmware's maximum for any grid size), all pixels are automatically and uniformly dimmed to stay within safe limits.
- `grid_led(x, y, z)` on an overridden pixel clears its override, reverting it to global tint behavior.
- `grid_led_all(z)` clears all overrides across the entire grid.
- Scripts that never call `grid_led_rgb` behave identically to before.

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

## Using in portable scripts

`grid_color` and `grid_led_rgb` are not available on regular iii devices. To write scripts that run on both without errors, guard the calls with a nil check:

```lua
if grid_color then grid_color(250, 80, 10) end
if grid_led_rgb then grid_led_rgb(x, y, 255, 0, 0) end
```

On a regular iii device the functions will be `nil` and the block is skipped. On this firmware they are registered globals and the call proceeds normally.

## Files changed

| File | Change |
|------|--------|
| `src/device.cpp` | Added `px_override[]` + `px_rgb[]` arrays; updated `sendLeds_iii()`, `device_led_set()`, `device_led_all()`; added `device_led_rgb_set()` |
| `src/device_ext.h` | Declared `device_led_rgb_set()` |
| `src/device_lua.c` | Added `l_grid_led_rgb()` binding, registered as `grid_led_rgb` |
