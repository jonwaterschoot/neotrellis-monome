-- scriptname: Multi-Screen Test
-- v1.2.0
-- @author: Gemini / jonwtr
--
-- A script to demonstrate a multi-screen setup with a common control row.
-- - Bottom row buttons toggle which screen is active.
-- - Screen 1 is the main screen, showing 3 "digits".
-- - Screens 2, 3, 4 are editors for each digit's color, brightness, and blink rate.
--
-- KEY PATTERN: All screens are rendered into separate buffers on every redraw().
-- grid_set_screen(name) selects which buffer to write to before drawing.
-- grid_refresh() flushes all buffers at once — minimap and dual-view stay current.
-- display_screen(name) signals the emulator which screen to show as active.
--
-- @key 7: Main
-- @key 8: Edit 1
-- @key 9: Edit 2
-- @key 10: Edit 3
--
-- @section Main Screen
-- @screen live
-- @group Digit Displays
-- x=2..4, y=2..6: Visual representation of Digit 1.
-- x=7..9, y=2..6: Visual representation of Digit 2.
-- x=12..14, y=2..6: Visual representation of Digit 3.
-- @group
-- @group Screen Navigation
-- x=7, y=8: View Main Screen (this screen).
-- x=8, y=8: Switch to editor for Digit 1.
-- x=9, y=8: Switch to editor for Digit 2.
-- x=10, y=8: Switch to editor for Digit 3.
-- @group
--
-- @section Digit 1 Editor
-- @screen edit1
-- @group Controls
-- x=2..5, y=2: Color — Select from 4 color options.
-- x=2..5, y=4: Brightness — Select from 4 brightness levels.
-- x=2..5, y=6: Blink Rate — Select blink speed (Off, 800ms, 600ms, 200ms).
-- @group
-- @group Preview
-- x=12..14, y=2..6: Live preview of Digit 1.
-- @group
-- @group Screen Navigation
-- x=7, y=8: View Main Screen.
-- x=8, y=8: Switch to editor for Digit 1 (this screen).
-- x=9, y=8: Switch to editor for Digit 2.
-- x=10, y=8: Switch to editor for Digit 3.
-- @group

-- BACKWARDS COMPATIBILITY: Check if multi-screen is supported
local multi_screen_supported = (grid_set_screen ~= nil)
--
-- @section Digit 2 Editor
-- @screen edit2
-- @group Controls
-- x=2..5, y=2: Color — Select from 4 color options.
-- x=2..5, y=4: Brightness — Select from 4 brightness levels.
-- x=2..5, y=6: Blink Rate — Select blink speed (Off, 800ms, 600ms, 200ms).
-- @group
-- @group Preview
-- x=12..14, y=2..6: Live preview of Digit 2.
-- @group
-- @group Screen Navigation
-- x=7, y=8: View Main Screen.
-- x=8, y=8: Switch to editor for Digit 1.
-- x=9, y=8: Switch to editor for Digit 2 (this screen).
-- x=10, y=8: Switch to editor for Digit 3.
-- @group
--
-- @section Digit 3 Editor
-- @screen edit3
-- @group Controls
-- x=2..5, y=2: Color — Select from 4 color options.
-- x=2..5, y=4: Brightness — Select from 4 brightness levels.
-- x=2..5, y=6: Blink Rate — Select blink speed (Off, 800ms, 600ms, 200ms).
-- @group
-- @group Preview
-- x=12..14, y=2..6: Live preview of Digit 3.
-- @group
-- @group Screen Navigation
-- x=7, y=8: View Main Screen.
-- x=8, y=8: Switch to editor for Digit 1.
-- x=9, y=8: Switch to editor for Digit 2.
-- x=10, y=8: Switch to editor for Digit 3 (this screen).
-- @group

local W, H = 16, 8 -- Grid size

-- STATE
local active_screen = 1
local digits = {}
local colors = {
    {r=120, g=220, b=120},  -- Soft Green
    {r=255, g=190, b=100},  -- Soft Orange
    {r=255, g=180, b=220},  -- Soft Pink
    {r=130, g=220, b=220}   -- Soft Cyan
}
local brightness_levels = {0.1, 0.4, 0.7, 1.0}
local blink_rates = {0, 800, 600, 200} -- off, slow, medium, fast

local control_y = 8
local screen_buttons_x = {7, 8, 9, 10}

-- FONT (from serpentine_dev.lua)
local FONT={["0"]=0x75557,["1"]=0x22222,["2"]=0x71747,["3"]=0x71717,["4"]=0x55711,["5"]=0x74717,["6"]=0x74757,["7"]=0x71111,["8"]=0x75757,["9"]=0x75711}


-- HELPER FUNCTIONS

--- Set pixel color with RGB support and monochrome fallback
function spx(x, y, r, g, b, brightness)
    if x < 1 or x > W or y < 1 or y > H then return end
    brightness = brightness or 1.0
    r = r * brightness
    g = g * brightness
    b = b * brightness

    if grid_led_rgb then
        -- Round and clamp so low-intensity values behave consistently.
        r = math.max(0, math.min(255, math.floor(r + 0.5)))
        g = math.max(0, math.min(255, math.floor(g + 0.5)))
        b = math.max(0, math.min(255, math.floor(b + 0.5)))

        local maxc = math.max(r, g, b)
        if maxc > 0 and maxc < 16 then
            local scale = 16 / maxc
            r = math.min(255, math.floor(r * scale + 0.5))
            g = math.min(255, math.floor(g * scale + 0.5))
            b = math.min(255, math.floor(b * scale + 0.5))
        end

        grid_led_rgb(x, y, r, g, b)
    else
        local level = math.floor(math.max(r, g, b) / 17)
        if level < 4 and (r > 0 or g > 0 or b > 0) then
            level = 4
        end
        grid_led(x, y, level)
    end
end

--- Draw a 3x5 character
function draw_char(x,y,char,r,g,b,bm)
  local f = FONT[tostring(char)]
  if not f then return end
  bm = bm or 1.0
  for row=1,5 do
    local bits = (f >> ((5-row)*4)) & 0xF
    for col=1,3 do
      if (bits & (1 << (3-col))) ~= 0 then
        spx(x+col-1, y+row-1, math.floor(r*bm), math.floor(g*bm), math.floor(b*bm))
      end
    end
  end
end


-- DRAWING FUNCTIONS

--- Draw the shared control row (screen navigation buttons).
--- active_idx: 1=main, 2=edit1, 3=edit2, 4=edit3
function draw_control_row(active_idx)
    for i=1, #screen_buttons_x do
        local x = screen_buttons_x[i]
        local brightness = (i == active_idx) and 1.0 or 0.3
        spx(x, control_y, 100, 100, 255, brightness)
    end
end

function draw_main_screen()
    for i=1, #digits do
        local digit = digits[i]
        local x_offset = (i-1) * 5 + 2
        if not digit.blink_on then
            local color = colors[digit.color_idx]
            local brightness = brightness_levels[digit.brightness_idx]
            draw_char(x_offset, 2, tostring(i), color.r, color.g, color.b, brightness)
        end
    end
end

--- Draw the editor UI for a specific digit index (1, 2, or 3).
function draw_editor_screen(digit_idx)
    local digit = digits[digit_idx]
    local control_x_offset = 1

    -- Color options (Row 2)
    for i=1, #colors do
        local color = colors[i]
        local brightness = (i == digit.color_idx) and 1.0 or 0.3
        spx(i + control_x_offset, 2, color.r, color.g, color.b, brightness)
    end

    -- Brightness options (Row 4)
    for i=1, #brightness_levels do
        local display_brightness = brightness_levels[i]
        local r, g, b = 255, 255, 255
        if i == digit.brightness_idx then
             spx(i + control_x_offset, 4, r, g, b, 1.0)
        else
             spx(i + control_x_offset, 4, r, g, b, display_brightness * 0.5)
        end
    end

    -- Blink options (Row 6)
    for i=1, #blink_rates do
        local brightness = (i == digit.blink_idx) and 1.0 or 0.3
        local r, g, b = 150, 150, 255
        spx(i + control_x_offset, 6, r, g, b, brightness)
    end

    -- Draw a live preview of the digit
    if not digit.blink_on then
        local color = colors[digit.color_idx]
        local brightness = brightness_levels[digit.brightness_idx]
        draw_char(12, 2, tostring(digit_idx), color.r, color.g, color.b, brightness)
    end
end

--- Redraw all screens into their respective buffers, then flush once.
--- This ensures dual-view and minimap always have current data for every screen.
function redraw()
    if multi_screen_supported then
        -- Draw live (main) screen into the 'live' buffer
        grid_set_screen('live')
        grid_led_all(0)
        draw_control_row(1)
        draw_main_screen()

        -- Draw each editor into its own named buffer
        for i = 1, 3 do
            grid_set_screen('edit' .. i)
            grid_led_all(0)
            draw_control_row(i + 1)
            draw_editor_screen(i)
        end
    else
        -- Single-screen mode: only draw the active screen
        grid_led_all(0)
        draw_control_row(active_screen)
        if active_screen == 1 then
            draw_main_screen()
        else
            draw_editor_screen(active_screen - 1)
        end
    end

    -- Flush all buffers at once → updates main grid, ghost grid, and minimap
    grid_refresh()
end

-- INPUT HANDLING

function event_grid(x, y, z)
    if z == 0 then return end -- Only handle key down

    -- Screen selection
    if y == control_y then
        for i=1, #screen_buttons_x do
            if x == screen_buttons_x[i] then
                active_screen = i
                -- Signal the emulator which screen is now active.
                -- live=primary, edit1/edit2/edit3=secondary.
                local screen_name = active_screen == 1 and 'live' or ('edit' .. (active_screen - 1))
                if display_screen then display_screen(screen_name) end
                redraw()
                return
            end
        end
    end

    -- Editor screen input (only when an editor is active)
    if active_screen > 1 then
        local digit_idx = active_screen - 1
        local control_x_offset = 1

        -- Color selection (y=2)
        if y == 2 and x > control_x_offset and x <= #colors + control_x_offset then
            digits[digit_idx].color_idx = x - control_x_offset
        end

        -- Brightness selection (y=4)
        if y == 4 and x > control_x_offset and x <= #brightness_levels + control_x_offset then
            digits[digit_idx].brightness_idx = x - control_x_offset
        end

        -- Blink selection (y=6)
        if y == 6 and x > control_x_offset and x <= #blink_rates + control_x_offset then
            digits[digit_idx].blink_idx = x - control_x_offset
            digits[digit_idx].last_blink_time = get_time()
            digits[digit_idx].blink_on = false
        end

        redraw()
    end
end

-- INITIALIZATION AND TIMERS

function init()
    for i=1, 3 do
        digits[i] = {
            color_idx = i,
            brightness_idx = 4,
            blink_idx = 1, -- Off
            blink_on = false,
            last_blink_time = 0
        }
    end

    -- Blinking timer
    local blink_metro = metro.init(function()
        local now = get_time()
        local needs_redraw = false
        for i=1, #digits do
            local digit = digits[i]
            local rate_ms = blink_rates[digit.blink_idx]
            if rate_ms > 0 then
                if now - digit.last_blink_time > (rate_ms / 1000) then
                    digit.blink_on = not digit.blink_on
                    digit.last_blink_time = now
                    needs_redraw = true
                end
            elseif digit.blink_on then
                digit.blink_on = false
                needs_redraw = true
            end
        end
        if needs_redraw then
            redraw()
        end
    end, 0.05) -- check every 50ms

    blink_metro:start()

    redraw()
end

init()
