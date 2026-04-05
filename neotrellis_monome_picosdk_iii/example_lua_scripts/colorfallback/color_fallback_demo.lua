-- scriptname: Color Fallback Demo
-- v1.0.0
-- @author: jonwaterschoot aka jonwtr
-- https://github.com/jonwaterschoot/diii-neotrellis-emulator/tree/de3f14acc5c8c2c969d4a53d6fa87458d3be568f/uf2s
--
-- Demonstrates the cross-device color/monochrome fallback pattern.
-- 4 color zones of 4 columns each, split into top/bottom tiles at alternating brightness.
-- On NeoTrellis: full color per zone. On monochrome grids: same 4 brightness steps in white,
-- proving the spx() helper spans the full hardware contrast range on both device types.

-- @section Grid Layout
-- x=1..4: Zone 1 — green (odd zone: top tile bright, bottom tile dim)
-- x=5..8: Zone 2 — blue (even zone: top tile dim, bottom tile bright)
-- x=9..12: Zone 3 — orange (odd zone: top tile bright, bottom tile dim)
-- x=13..16: Zone 4 — purple (even zone: top tile dim, bottom tile bright)
-- y=1..4: Top tile half of each zone
-- y=5..8: Bottom tile half of each zone

-- @section Controls
-- x=1..16, y=1..8: Press any pad — cycles brightness: off → dim (~lv4) → mid (~lv8) → max (lv15) → off

local W = grid_size_x()
local H = grid_size_y()

-- ── Cross-device pixel writer ─────────────────────────────────────────────
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

-- ── Zones ─────────────────────────────────────────────────────────────────
-- Hue at full brightness. Stages scale this down.
local ZONES = {
  { r=20,  g=255, b=80  }, -- green
  { r=20,  g=100, b=255 }, -- blue
  { r=255, g=80,  b=20  }, -- orange
  { r=180, g=20,  b=255 }, -- purple
}
local ZONE_W = math.floor(W / #ZONES)  -- 4 columns per zone
local TILE_H = math.floor(H / 2)       -- 4 rows per tile

-- Brightness scales for stages 0-3.
-- Stage 1 floor ensures max channel >= 68 after scaling (level 4 guaranteed).
local SCALES = { 0, 68/255, 140/255, 1.0 }

local function zone_idx(x)
  return math.min(#ZONES, math.floor((x - 1) / ZONE_W) + 1)
end

-- Initial tile brightness per zone: odd zones bright-top/dim-bottom,
-- even zones dim-top/bright-bottom.
local function init_stage(zi, y)
  local top = y <= TILE_H
  local bright_top = (zi % 2 == 1)
  return (top == bright_top) and 3 or 1
end

-- ── Per-pixel state ───────────────────────────────────────────────────────
local state = {}
for y = 1, H do
  state[y] = {}
  for x = 1, W do
    state[y][x] = init_stage(zone_idx(x), y)
  end
end

-- ── Draw ──────────────────────────────────────────────────────────────────
local function draw()
  grid_led_all(0)
  for y = 1, H do
    for x = 1, W do
      local zi = zone_idx(x)
      local z = ZONES[zi]
      local sc = SCALES[state[y][x] + 1]
      spx(x, y, math.floor(z.r * sc), math.floor(z.g * sc), math.floor(z.b * sc))
    end
  end
  grid_refresh()
end

-- ── Input ─────────────────────────────────────────────────────────────────
function event_grid(x, y, z)
  if z == 1 then
    state[y][x] = (state[y][x] + 1) % 4
    draw()
  end
end

-- ── Init ──────────────────────────────────────────────────────────────────
if grid_color_intensity then grid_color_intensity(12) end
draw()
print("color_fallback_demo loaded — " ..
  (grid_led_rgb and "RGB mode (NeoTrellis)" or "Monochrome mode (standard grid)"))
