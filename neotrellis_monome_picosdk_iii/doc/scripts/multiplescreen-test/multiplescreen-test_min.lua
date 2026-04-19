local W, H = 16, 8
local active_screen = 1
local digits = {}
local colors = {
    {r=120, g=220, b=120},
    {r=255, g=190, b=100},
    {r=255, g=180, b=220},
    {r=130, g=220, b=220}
}
local brightness_levels = {0.1, 0.4, 0.7, 1.0}
local blink_rates = {0, 800, 600, 200}
local control_y = 8
local screen_buttons_x = {7, 8, 9, 10}
local FONT={["0"]=0x75557,["1"]=0x22222,["2"]=0x71747,["3"]=0x71717,["4"]=0x55711,["5"]=0x74717,["6"]=0x74757,["7"]=0x71111,["8"]=0x75757,["9"]=0x75711}
function spx(x, y, r, g, b, brightness)
    if x < 1 or x > W or y < 1 or y > H then return end
    brightness = brightness or 1.0
    r = r * brightness
    g = g * brightness
    b = b * brightness
    if grid_led_rgb then
        grid_led_rgb(x, y, r, g, b)
    else
        local level = math.floor(math.max(r, g, b) / 17)
        grid_led(x, y, level)
    end
end
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
function draw_editor_screen(digit_idx)
    local digit = digits[digit_idx]
    local control_x_offset = 1
    for i=1, #colors do
        local color = colors[i]
        local brightness = (i == digit.color_idx) and 1.0 or 0.3
        spx(i + control_x_offset, 2, color.r, color.g, color.b, brightness)
    end
    for i=1, #brightness_levels do
        local display_brightness = brightness_levels[i]
        local r, g, b = 255, 255, 255
        if i == digit.brightness_idx then
             spx(i + control_x_offset, 4, r, g, b, 1.0)
        else
             spx(i + control_x_offset, 4, r, g, b, display_brightness * 0.5)
        end
    end
    for i=1, #blink_rates do
        local brightness = (i == digit.blink_idx) and 1.0 or 0.3
        local r, g, b = 150, 150, 255
        spx(i + control_x_offset, 6, r, g, b, brightness)
    end
    if not digit.blink_on then
        local color = colors[digit.color_idx]
        local brightness = brightness_levels[digit.brightness_idx]
        draw_char(12, 2, tostring(digit_idx), color.r, color.g, color.b, brightness)
    end
end
function redraw()
    grid_set_screen('live')
    grid_led_all(0)
    draw_control_row(1)
    draw_main_screen()
    for i = 1, 3 do
        grid_set_screen('edit' .. i)
        grid_led_all(0)
        draw_control_row(i + 1)
        draw_editor_screen(i)
    end
    grid_refresh()
end
function event_grid(x, y, z)
    if z == 0 then return end
    if y == control_y then
        for i=1, #screen_buttons_x do
            if x == screen_buttons_x[i] then
                active_screen = i
                local screen_name = active_screen == 1 and 'live' or ('edit' .. (active_screen - 1))
                if display_screen then display_screen(screen_name) end
                redraw()
                return
            end
        end
    end
    if active_screen > 1 then
        local digit_idx = active_screen - 1
        local control_x_offset = 1
        if y == 2 and x > control_x_offset and x <= #colors + control_x_offset then
            digits[digit_idx].color_idx = x - control_x_offset
        end
        if y == 4 and x > control_x_offset and x <= #brightness_levels + control_x_offset then
            digits[digit_idx].brightness_idx = x - control_x_offset
        end
        if y == 6 and x > control_x_offset and x <= #blink_rates + control_x_offset then
            digits[digit_idx].blink_idx = x - control_x_offset
            digits[digit_idx].last_blink_time = get_time()
            digits[digit_idx].blink_on = false
        end
        redraw()
    end
end
function init()
    for i=1, 3 do
        digits[i] = {
            color_idx = i,
            brightness_idx = 4,
            blink_idx = 1,
            blink_on = false,
            last_blink_time = 0
        }
    end
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
    end, 0.05)
    blink_metro:start()
    redraw()
end
init()
