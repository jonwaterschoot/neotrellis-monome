-- scriptname: Color Threshold Test
-- v1.0.0
-- @author: jonwaterschoot
--
-- Tests color accuracy at different brightness levels to find where
-- NeoTrellis LEDs start rendering colors incorrectly.
--
-- @section Test Layout
-- Row 1 Left (cols 1-8): Cyan tint via grid_led() - shows color shift on NeoTrellis
-- Row 1 Right (cols 9-16): Cyan RGB via grid_led_rgb() - accurate colors
-- Row 2: Higher brightness levels (8-15) for comparison
-- Row 3 Left: Orange tint via grid_led() - compare color accuracy
-- Row 3 Right: Orange RGB via grid_led_rgb() - accurate reference
-- Note: On real NeoTrellis hardware, the left side may shift unexpectedly and appear a different hue than the reference, while the right side preserves the intended orange.
-- Rows 7-8: Checkerboard at level 4 cyan tint
--
-- @section Testing Notes
-- diii webapp: Shows full color rendering
-- viii webapp: Shows monochrome (white) - ignores RGB calls
-- Hardware: NeoTrellis shows colors, Monome grids show monochrome
-- @group

local W = grid_size_x()
local H = grid_size_y()

function init()
  -- Clear grid first
  grid_led_all(0)

  -- Set cyan tint for left side grid_led calls
  if grid_color then
    grid_color(40, 160, 220)  -- Cyan: low red, high green, high blue
  end
  if grid_color_intensity then
    grid_color_intensity(12)  -- Full brightness
  end

  -- Left side: Test tinted grid_led at levels 1-8
  for level = 1, 8 do
    grid_led(level, 1, level)  -- Row 1: levels 1-8
  end

  -- Right side: Test pure cyan RGB at levels 1-8 (scaled)
  if grid_led_rgb then
    for level = 1, 8 do
      local scale = level / 15  -- Scale 0-255 to match grid_led brightness
      local r = math.floor(40 * scale)
      local g = math.floor(160 * scale)
      local b = math.floor(220 * scale)
      grid_led_rgb(level + 8, 1, r, g, b)  -- Columns 9-16: scaled RGB cyan
    end
  end

  -- Row 2: Test different brightness levels for comparison
  for col = 1, 16 do
    if col <= 8 then
      grid_led(col, 2, col + 7)  -- Levels 8-15
    else
      if grid_led_rgb then
        local level = col - 8 + 7  -- Levels 8-15
        local scale = level / 15
        local r = math.floor(40 * scale)
        local g = math.floor(160 * scale)
        local b = math.floor(220 * scale)
        grid_led_rgb(col, 2, r, g, b)
      end
    end
  end

  -- Row 3: Test orange tint to see if it has similar issues
  if grid_color then
    grid_color(200, 80, 20)  -- Orange tint
  end
  for level = 1, 8 do
    grid_led(level, 3, level)
  end

  -- Row 4: Pure orange RGB reference
  if grid_led_rgb then
    for level = 1, 8 do
      local scale = level / 15
      local r = math.floor(200 * scale)
      local g = math.floor(80 * scale)
      local b = math.floor(20 * scale)
      grid_led_rgb(level + 8, 3, r, g, b)
    end
  end

  -- Bottom rows: Additional test patterns
  -- Row 7: Checkerboard pattern with cyan tint at level 4
  if grid_color then
    grid_color(40, 160, 220)  -- Back to cyan
  end
  for x = 1, 16 do
    for y = 7, 8 do
      if (x + y) % 2 == 0 then
        grid_led(x, y, 4)  -- Level 4 cyan tint
      end
    end
  end

  -- Row 8, column 16: Full brightness reference
  if grid_led_rgb then
    grid_led_rgb(16, 8, 40, 160, 220)  -- Full cyan RGB
  end

  grid_refresh()
end

init()