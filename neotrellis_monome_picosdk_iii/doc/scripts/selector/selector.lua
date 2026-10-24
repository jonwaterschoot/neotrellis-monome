-- selector.lua: script picker for iii grids
-- Every .lua script on the device gets a slot, sorted by name, filling the
-- top rows left to right. Press a slot to show its name along the bottom of
-- the grid (a few letters at a time when it doesn't fit), press it again to
-- load it.
-- Press anywhere else to deselect.
-- Make it the boot script with: first("selector.lua")

local self_name = "selector.lua"
local skip = { ["init.lua"]=true, ["lib.lua"]=true, [self_name]=true }
local skip_prefix = { "pset_", "data_", "state_" } -- support files

local palette = {
  {255,40,40}, {255,140,0}, {255,230,0}, {60,220,60},
  {0,200,200}, {40,90,255}, {170,60,255}, {255,60,170},
}
local white = {255,255,255}

-- 3x5 font: one value per row, top to bottom; bit 4 is the left column
local font = {
  A={2,5,7,5,5}, B={6,5,6,5,6}, C={3,4,4,4,3}, D={6,5,5,5,6}, E={7,4,6,4,7},
  F={7,4,6,4,4}, G={3,4,5,5,3}, H={5,5,7,5,5}, I={7,2,2,2,7}, J={1,1,1,5,2},
  K={5,5,6,5,5}, L={4,4,4,4,7}, M={5,7,7,5,5}, N={6,5,5,5,5}, O={2,5,5,5,2},
  P={6,5,6,4,4}, Q={2,5,5,6,3}, R={6,5,6,5,5}, S={3,4,2,1,6}, T={7,2,2,2,2},
  U={5,5,5,5,7}, V={5,5,5,5,2}, W={5,5,7,7,5}, X={5,5,2,5,5}, Y={5,5,2,2,2},
  Z={7,1,2,4,7},
  ["0"]={7,5,5,5,7}, ["1"]={2,6,2,2,7}, ["2"]={6,1,2,4,7}, ["3"]={6,1,2,1,6},
  ["4"]={5,5,7,1,1}, ["5"]={7,4,6,1,6}, ["6"]={3,4,6,5,2}, ["7"]={7,1,2,2,2},
  ["8"]={2,5,2,5,2}, ["9"]={2,5,3,1,6},
  ["-"]={0,0,7,0,0}, ["_"]={0,0,0,0,7}, [" "]={0,0,0,0,0},
}
local unknown = {0,0,2,0,0}

local cols, rows = grid_size_x(), grid_size_y()
local show_text = rows >= 7           -- 5 rows of text + a gap + 1 slot row
local text_y = rows - 4               -- top row of the name display
local slot_rows = show_text and rows - 6 or rows
local max_slots = cols * slot_rows
local page_chars = (cols + 1) // 4    -- 3 columns per letter + 1 spacer
local page_time = 1.0                 -- seconds per page of a long name

local function skipped(f)
  if f:sub(-4) ~= ".lua" or skip[f] then return true end
  for _,p in ipairs(skip_prefix) do
    if f:sub(1,#p) == p then return true end
  end
  return false
end

local scripts = {}
for _,f in ipairs(fs_list_files()) do
  if not skipped(f) then table.insert(scripts, f) end
end
table.sort(scripts)
for i,name in ipairs(scripts) do print(i..": "..name) end
if #scripts > max_slots then
  print("selector: "..#scripts.." scripts, only "..max_slots.." slots")
end

-- text as a list of columns; bit r-1 of a column is text row r
local function columns(str)
  local out = {}
  for ch in str:gmatch(".") do
    local g = font[ch] or unknown
    for c = 2,0,-1 do
      local col = 0
      for r = 1,5 do
        if (g[r] >> c) & 1 == 1 then col = col | (1 << (r-1)) end
      end
      table.insert(out, col)
    end
    table.insert(out, 0)
  end
  table.remove(out) -- trailing spacer
  return out
end

-- the name split into pages of columns that fit the grid width
local function name_pages(name)
  local s = (name:gsub("%.lua$", "")):upper()
  local pages = {}
  for i = 1, #s, page_chars do
    table.insert(pages, columns(s:sub(i, i + page_chars - 1)))
  end
  return pages
end

local function led(x, y, c, level)
  if grid_led_rgb then grid_led_rgb(x, y, c[1], c[2], c[3])
  else grid_led(x, y, level) end
end

local function slot_color(i) return palette[(i-1) % #palette + 1] end

local sel, text, page = nil, nil, 1

local function draw()
  grid_led_all(0)
  for i=1,math.min(#scripts, max_slots) do
    local x, y = (i-1) % cols + 1, (i-1) // cols + 1
    if i == sel then led(x, y, white, 15) else led(x, y, slot_color(i), 6) end
  end
  if sel and text then
    local c = slot_color(sel)
    local cur = text[page]
    for x=1,math.min(#cur, cols) do
      local col = cur[x]
      for r=1,5 do
        if (col >> (r-1)) & 1 == 1 then led(x, text_y + r - 1, c, 10) end
      end
    end
  end
  grid_refresh()
end

local ticker = metro.init(function()
  if text and #text > 1 then
    page = page % #text + 1
    draw()
  end
end, page_time)
ticker:start()

local function load(name)
  print("loading: "..name)
  ticker.event = nil -- drop references so the selector can be collected
  metro.free(ticker.id)
  -- LEDs only update after event_grid returns, so load a moment later
  -- to let the cleared name display show first.
  local m
  m = metro.init(function()
    m.event = nil
    metro.free(m.id)
    event_grid = nil -- in case the script doesn't define its own
    grid_led_all(0)
    grid_refresh()
    collectgarbage()
    fs_run_file(name)
  end, 0.15, 1)
  m:start()
end

local loading = false
event_grid = function(x,y,z)
  if z ~= 1 or loading then return end
  local i = (y <= slot_rows) and (y-1)*cols + x or nil
  if i and scripts[i] then
    if i == sel then
      loading = true
      text = nil
      draw()
      load(scripts[i])
      return
    end
    sel, page = i, 1
    text = show_text and name_pages(scripts[i]) or nil
    ticker:stop() -- restart so the first page gets a full interval
    ticker:start()
    print(i..": "..scripts[i])
  else
    sel, text = nil, nil
  end
  draw()
end

draw()
