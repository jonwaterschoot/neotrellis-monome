-- select.lua: script picker
-- Every .lua script on the device gets a slot on the grid, sorted by name,
-- filling left to right, top to bottom. Press a slot to load that script.
-- Make it the boot script with: first("select.lua")

local self_name = "select.lua"
local skip = { ["init.lua"]=true, ["lib.lua"]=true, [self_name]=true }

local palette = {
  {255,40,40}, {255,140,0}, {255,230,0}, {60,220,60},
  {0,200,200}, {40,90,255}, {170,60,255}, {255,60,170},
}

local cols, rows = grid_size_x(), grid_size_y()
local scripts = {}
for _,f in ipairs(fs_list_files()) do
  if f:sub(-4) == ".lua" and not skip[f] and f:sub(1,5) ~= "pset_" then
    table.insert(scripts, f)
  end
end
table.sort(scripts)
if #scripts > cols*rows then
  print("select: "..#scripts.." scripts, only "..cols*rows.." slots")
end

local function draw(sel)
  grid_led_all(0)
  for i=1,math.min(#scripts, cols*rows) do
    local x, y = (i-1) % cols + 1, (i-1) // cols + 1
    if grid_led_rgb then
      local c = (i == sel) and {255,255,255} or palette[(i-1) % #palette + 1]
      grid_led_rgb(x, y, c[1], c[2], c[3])
    else
      grid_led(x, y, (i == sel) and 15 or 6)
    end
  end
  grid_refresh()
end

for i,name in ipairs(scripts) do print(i..": "..name) end
draw()

local loading = false
event_grid = function(x,y,z)
  if z ~= 1 or loading then return end
  local name = scripts[(y-1)*cols + x]
  if not name then return end
  loading = true
  print("loading: "..name)
  draw((y-1)*cols + x)
  -- LEDs only update after this callback returns, so load a moment later
  -- to let the selected slot light up first.
  local m
  m = metro.init(function()
    metro.free(m.id)
    event_grid = nil -- in case the script doesn't define its own
    grid_led_all(0)
    grid_refresh()
    collectgarbage()
    fs_run_file(name)
  end, 0.15, 1)
  m:start()
end
