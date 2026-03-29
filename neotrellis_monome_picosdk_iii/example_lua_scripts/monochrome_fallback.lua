-- monochrome_fallback.lua
--
-- Row 1  : Brightness Slider
-- Rows 3–6: Animated rectangle (4 blocks high, middle)
-- Row 7, Key 1: Toggle Palette RGB simulation (above White LED)
-- Row 7, Key 8: Toggle Movement (Default: OFF)
-- Row 7, Key 9: Cycle Animation Mode (Rainbow -> Mono -> Shimmer -> 16 Steps)
-- Row 8  : Global Palette (tap to set the 'mono' tint)

local W, H = grid_size_x(), grid_size_y()
local anim_mode   = 0     -- 0=Rainbow, 1=Mono, 2=Shimmer, 3=Steps
local palette_rgb = true  
local moving      = false -- Toggle scanning movement
local master_int  = 7     
local anim_step   = 0     -- Always increments to drive shimmer/rainbow
local move_pos    = 0     -- Increments only when 'moving' is true

-- 16 Palette colors
local PALETTE = {
    {255, 255, 255}, {255, 120, 0}, {255, 80, 0}, {255, 0, 0},
    {255, 0, 127}, {255, 0, 255}, {127, 0, 255}, {0, 0, 255},
    {100, 200, 255}, {0, 255, 255}, {0, 255, 127}, {0, 255, 0},
    {127, 255, 0}, {255, 255, 0}, {100, 255, 100}, {200, 200, 200}
}

local function hsv_to_rgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

function tick()
    anim_step = (anim_step + 0.1) % W
    if moving then
        move_pos = (move_pos + 0.15) % W
    end
    
    grid_led_all(0)
    
    -- Row 1: Brightness Slider
    for x = 1, W do grid_led(x, 1, x <= (master_int + 1) and 15 or 1) end

    -- Row 7: Toggles
    if grid_led_rgb then
        -- Key 1: Palette Ghosting toggle
        if palette_rgb then grid_led_rgb(1, 7, 0, 255, 0) else grid_led_rgb(1, 7, 255, 0, 0) end
        -- Key 8: Movement toggle (starts blue, turns green when active)
        if moving then grid_led_rgb(8, 7, 0, 255, 0) else grid_led_rgb(8, 7, 0, 0, 255) end
        -- Key 9: Mode indicator
        if anim_mode == 0 then grid_led_rgb(9, 7, 255, 0, 255) -- Magenta (Rainbow)
        elseif anim_mode == 1 then grid_led_rgb(9, 7, 255, 255, 255) -- White (Mono)
        elseif anim_mode == 2 then grid_led_rgb(9, 7, 0, 255, 255) -- Cyan (Shimmer)
        else grid_led_rgb(9, 7, 10, 200, 255) end -- Light Blue (16 Steps)
    else
        grid_led(1, 7, 8); grid_led(8, 7, moving and 15 or 4); grid_led(9, 7, 15)
    end
    
    -- Row 8: Palette
    for x = 1, 16 do
        if palette_rgb and grid_led_rgb then
             local c = PALETTE[x]; grid_led_rgb(x, 8, c[1], c[2], c[3])
        else grid_led(x, 8, 8) end
    end

    -- Rows 3–6: Animation Grid
    for x = 1, W do
        if anim_mode == 3 then
            -- MODE 3: 16 Steps of Brightness
            -- One level per column, using global tint
            for y = 3, 6 do grid_led(x, y, x - 1) end
            
            -- Origin Marker: (1,1) Blue to confirm orientation
            if grid_led_rgb then grid_led_rgb(1, 1, 0, 0, 255) end
        else
            local bright = 1 -- Default brightness for the static rectangle
            
            -- If movement is toggled, add the scanning fade effect
            if moving then
                local dist = math.abs(x - (move_pos + 1))
                bright = math.max(0, 1 - dist / 4)
            end

            if bright > 0 then
                for y = 3, 6 do
                    if anim_mode == 0 and grid_led_rgb then
                        -- MODE 0: Rainbow 
                        local h = (x / W + anim_step / W) % 1.0
                        local r, g, b = hsv_to_rgb(h, 1.0, bright)
                        grid_led_rgb(x, y, r, g, b)
                    elseif anim_mode == 1 then
                        -- MODE 1: Mono / Tint
                        grid_led(x, y, math.floor(bright * 14) + 1)
                    else
                        -- MODE 2: Shimmer / Internal Pulse
                        local local_h = (x / W + anim_step / 4) % 1.0
                        local shimmer = 0.5 + 0.5 * math.sin(anim_step * 2 + x * 0.5)
                        local r, g, b = hsv_to_rgb(local_h, 0.8, bright * shimmer)
                        if grid_led_rgb then
                            grid_led_rgb(x, y, r, g, b)
                        else
                            grid_led(x, y, math.floor(bright * shimmer * 15))
                        end
                    end
                end
            end
        end
    end
    grid_refresh()
end

function event_grid(x, y, z)
    if z == 0 then return end
    if y == 1 then
        master_int = x - 1
        if grid_color_intensity then grid_color_intensity(master_int) end
        grid_intensity(master_int)
    elseif y == 7 then
        if x == 1 then palette_rgb = not palette_rgb
        elseif x == 8 then moving = not moving
        elseif x == 9 then anim_mode = (anim_mode + 1) % 4 end
    elseif y == 8 then
        local c = PALETTE[x]
        if c and grid_color then grid_color(c[1], c[2], c[3]); anim_mode = 1 end
    end
end

if not grid_led_rgb then anim_mode = 1; palette_rgb = false end

if grid_color_intensity then grid_color_intensity(master_int) end
grid_intensity(master_int)

m_demo = metro.init(tick, 0.05)
m_demo:start()
