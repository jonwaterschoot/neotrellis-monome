-- power_test.lua
-- Tests the Power Limiter and the new grid_color_intensity() function.
--
-- OBSERVATION:
-- 1. Watch the top-left pixel (1,1). It starts at full white.
-- 2. As the rest of the grid fills with white, the (1,1) pixel will 
--    automatically DIM because the firmware is limiting total power.
-- 3. Then, a rainbow wave will sweep across at "safe" maximum brightness.
-- 4. Finally, it demonstrates grid_color_intensity() by fading the colors.

local W, H = grid_size_x(), grid_size_y()
local phase = 0
local counter = 0
local intensity = 15

-- Simple HSV to RGB conversion
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
    counter = counter + 1
    
    if phase == 0 then
        -- PHASE 0: Grow a white field
        grid_color_intensity(15) -- Full scale
        grid_led_all(0)
        local num_on = math.min(counter, W * H)
        for i = 1, num_on do
            local x = (i - 1) % W + 1
            local y = math.floor((i - 1) / W) + 1
            grid_led_rgb(x, y, 255, 255, 255)
        end
        
        if counter > W * H + 20 then 
            phase = 1 
            counter = 0
        end
        
    elseif phase == 1 then
        -- PHASE 1: Rainbow Wave + Intensity Fade
        -- Every 50 ticks, we lower the master color intensity
        if counter % 50 == 0 then
            intensity = intensity - 1
            if intensity < 0 then intensity = 15 end
            if grid_color_intensity then
                grid_color_intensity(intensity)
                print("Setting color intensity to: " .. intensity)
            end
        end

        for y = 1, H do
            for x = 1, W do
                local h = ((x/W) + (y/H) + (counter/50)) % 1.0
                local r, g, b = hsv_to_rgb(h, 1.0, 1.0)
                grid_led_rgb(x, y, r, g, b)
            end
        end
        
        if counter > 800 then
            phase = 0
            counter = 0
            intensity = 15
        end
    end

    grid_refresh()
end

-- Start a 20fps timer
m_test = metro.init(tick, 0.05)
m_test:start()

print("Master Intensity test started: " .. W .. "x" .. H)
