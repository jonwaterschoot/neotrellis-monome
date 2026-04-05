-- scriptname: Color Workaround Demo
-- v1.0.0
-- @author: jonwaterschoot
--
-- Demonstrates workarounds for NeoTrellis color accuracy issues.
-- Shows how to get consistent cyan colors at low brightness levels.
--
-- @section Test Layout
-- Left (cols 1-8): Problem - tinted grid_led() at level 4 (appears orange on NeoTrellis)
-- Right (cols 9-16): Solution - RGB override at equivalent brightness (stays cyan)
-- Top row: Full brightness cyan references
--
-- @section Testing Notes
-- diii webapp: Shows color difference between left/right sides
-- viii webapp: Shows only left side (monochrome white), right side invisible
-- Hardware: NeoTrellis shows the color difference, Monome grids show monochrome
-- @group

local W = grid_size_x()
local H = grid_size_y()

function init()
  -- Clear grid
  grid_led_all(0)

  -- PROBLEM: Tinted grid_led at low brightness (level 4)
  -- This appears orange on NeoTrellis hardware due to LED efficiency
  if grid_color then
    grid_color(40, 160, 220)  -- Cyan tint
  end
  if grid_color_intensity then
    grid_color_intensity(12)
  end

  -- Left side: Problem demonstration
  for x = 1, 8 do
    for y = 1, 8 do
      if (x + y) % 2 == 0 then
        grid_led(x, y, 4)  -- Level 4 cyan tint - appears orange on hardware
      end
    end
  end

  -- SOLUTION: Use RGB overrides for accurate colors at low brightness
  if grid_led_rgb then
    -- Right side: RGB workaround
    for x = 9, 16 do
      for y = 1, 8 do
        if (x + y) % 2 == 0 then
          -- Calculate RGB equivalent of level 4 cyan tint
          local scale = 4 / 15  -- Same scaling as grid_led
          local r = math.floor(40 * scale)   -- 10
          local g = math.floor(160 * scale)  -- 42
          local b = math.floor(220 * scale)  -- 58
          grid_led_rgb(x, y, r, g, b)  -- Accurate cyan at low brightness
        end
      end
    end
  end

  -- Top row: Comparison reference
  if grid_led_rgb then
    grid_led_rgb(1, 1, 40, 160, 220)  -- Full brightness cyan reference
    grid_led_rgb(16, 1, 40, 160, 220) -- Full brightness cyan reference
  end

  grid_refresh()
end

init()