-- scriptname: Grid Color Test
-- v1.0.0
-- @author: jonwaterschoot
--
-- Test script for NeoTrellis / Monome color compatibility.
-- Verifies global tint, per-pixel RGB, and monochrome fallback behavior.
--
-- @section Test Layout
-- x=1..16, y=1..8: Color test patterns
-- x=1..4, y=1: RGB override pixels
-- x=1..4, y=3: Monochrome fallback pixels
-- x=1..4, y=5: Tint + brightness levels
-- @group

local W = grid_size_x()
local H = grid_size_y()

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

function init()
  -- Global tint test for grid_led() and grid_led_all().
  if grid_color then
    grid_color(40, 160, 220)
  end
  if grid_color_intensity then
    grid_color_intensity(12)
  end

  grid_led_all(4)

  -- Per-pixel RGB override sample.
  if grid_led_rgb then
    grid_led_rgb(2, 2, 255, 0, 0)
    grid_led_rgb(4, 2, 0, 255, 0)
    grid_led_rgb(6, 2, 0, 0, 255)
    grid_led_rgb(8, 2, 255, 255, 0)
  end

  -- Monochrome fallback using spx().
  spx(2, 4, 255, 128, 0)
  spx(4, 4, 0, 255, 128)
  spx(6, 4, 128, 0, 255)
  spx(8, 4, 255, 255, 255)

  -- Tint + brightness levels.
  if grid_color then
    grid_color(200, 80, 20)
  end
  grid_led(2, 6, 15)
  grid_led(4, 6, 10)
  grid_led(6, 6, 6)
  grid_led(8, 6, 4)

  -- Label row indicating test mode.
  for x = 1, 16 do
    if x % 2 == 0 then
      spx(x, 8, 255, 255, 255)
    else
      spx(x, 8, 20, 20, 20)
    end
  end

  grid_refresh()
end

init()
