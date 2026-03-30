-- scriptname: Serpentine Sequencer
-- v1.1.0-dev
-- @author: jonwaterschoot
-- llllllll.co/t/serpentine-sequencer
--
-- A snake sequencer game for the NeoTrellis / Monome-compatible 16x8 grid.
-- The snake eats fruit to collect notes into an arpeggiator pool.
-- Each fruit type triggers different musical events on collection.
-- Navigate with the D-PAD (bottom-right) or hold ALT to open settings.

-- @section Grid Layout
-- x=1..16, y=1..8: Full 16x8 play grid
-- x=1, y=8: ALT toggle — momentary press opens Settings, double-tap = sticky
-- x=15, y=7: D-PAD UP
-- x=14, y=8: D-PAD LEFT
-- x=15, y=8: D-PAD DOWN
-- x=16, y=8: D-PAD RIGHT

-- @section Settings View (hold ALT)
-- x=1..8, y=1: Fruit spawn quantity slider (each step = 2 fruits, max 16)
-- x=11..16, y=1: Fruit type toggles — Red, Blue, Yellow, Cyan, Orange, Purple
-- x=1..8, y=2: Arpeggio lifespan slider (each step = 8 ticks)
-- x=9..16, y=2: Arpeggio pool max capacity (1–8 notes)
-- x=1, y=3: Autopilot mode cycle — NON / SEM / AUT
-- x=3, y=3: Arpeggio playback order — ORD / RND / UP / DWN
-- x=10, y=3: BPM −10
-- x=11, y=3: BPM −1
-- x=12, y=3: BPM +1
-- x=13, y=3: BPM +10
-- x=15, y=3: Master brightness step (4 → 8 → 12)
-- x=16, y=3: Monochrome tint cycle (5 cinematic tints + off)
-- x=1..7, y=4: Scale selection — MAJ / MIN / PMA / PMI / DOR / LYD / CUS
-- x=8..16, y=4: 3×5 LED numeric readout (BPM / scale name / arp mode)
-- x=1..7, y=6: Black key root notes (C# D# F# G# A#)
-- x=1..7, y=7: White key root notes (C D E F G A B) / Custom scale toggles

-- @section Fruit Types
-- x=11, y=1: Red fruit — shrinks tail by 1, adds note to arp pool
-- x=12, y=1: Blue fruit — grows tail by 1, adds note to arp pool
-- x=13, y=1: Yellow fruit — halves tempo for 16 ticks, adds note to arp pool
-- x=14, y=1: Cyan fruit — plays diatonic triad chord (3 stages per position)
-- x=15, y=1: Orange fruit — 33% chance arp trigger, grows tail
-- x=16, y=1: Purple fruit — spawns decaying echo bounces, grows tail

local W, H = 16, 8
local ALT_X, ALT_Y = 1, 8
local DPAD = {{x=15,y=7,dx=0,dy=-1},{x=14,y=8,dx=-1,dy=0},{x=15,y=8,dx=0,dy=1},{x=16,y=8,dx=1,dy=0}}
local num_fruits = 3
local auto_mode = 0
local auto_target = {x=0, y=0}
local auto_has_target = false
local bpm = 120
local temp_slow_steps = 0

--- Calculate the metro tick interval in seconds.
-- Halves BPM when yellow fruit slow-down is active.
-- @treturn number interval in seconds (used by metro:start)
local function get_interval()
  local current_bpm = (temp_slow_steps > 0) and (bpm / 2) or bpm
  return 60 / current_bpm / 4
end

local ECHO_MAX = 16
local ECHO_BUF = {}
for i=1,ECHO_MAX do ECHO_BUF[i] = {active=false, note=0, vel=0, ticks_left=0, current_interval=0, bounces=0} end

local arp_pool = {}
for i=1,8 do arp_pool[i]={note=0,x=0,y=0,kind=0} end
local arp_pool_len = 0
local arp_pool_max = 8
local arp_mode = 1
local arp_lifespan = 32
local arp_steps_remaining = 0
local arp_labels = {"ORD","RND","UP","DWN"}
local SORT_BUF = {}
for i=1,8 do SORT_BUF[i]={note=0,x=0,y=0,kind=0} end

local COLLECTED_MAX = 128
local collected_notes = {}
for i=1,COLLECTED_MAX do collected_notes[i] = {x=0, y=0} end
local collected_len = 0

local FRUIT_COL = {{r=220,g=40,b=20},{r=80,g=120,b=240},{r=240,g=200,b=20},{r=40,g=220,b=200},{r=255,g=140,b=0},{r=200,g=40,b=240}}
local FRUIT_W = {20, 40, 20, 20, 15, 10}
local fruit_enabled = {true, true, true, true, true, true}
local arp_trigger_chance = 1.0
local arp_first_note = false
local halos = {}
for i=1,W*H do halos[i]={state=0,life=0} end

local SCALE_NAMES = {"MAJ", "MIN", "PMA", "PMI", "DOR", "LYD", "CUS"}
local SCALE_MASKS = {
  {0,2,4,5,7,9,11}, {0,2,3,5,7,8,10}, {0,2,4,7,9}, {0,3,5,7,10}, {0,2,3,5,7,9,10}, {0,2,4,6,7,9,11}
}
local scale_mode = 3
local root_note = 0
local custom_scale = {true,false,true,false,true,false,false,true,false,true,false,false}
local SCALE = {0,2,4,7,9,0,0,0,0,0,0,0}
local SCALE_LEN = 5
local BASE = 48
local KB_MAP = { [7] = {[1]=0, [2]=2, [3]=4, [4]=5, [5]=7, [6]=9, [7]=11}, [6] = {[2]=1, [3]=3, [5]=6, [6]=8, [7]=10} }

-- @section Music System

--- Rebuild the active SCALE table from current scale_mode and root_note.
-- Populates the global SCALE array and SCALE_LEN.
-- Must be called after changing scale_mode or root_note.
local function generate_scale()
  SCALE_LEN = 0
  if scale_mode == 7 then
    for i=0,11 do
      if custom_scale[i+1] then SCALE_LEN=SCALE_LEN+1; SCALE[SCALE_LEN]=i end
    end
    if SCALE_LEN == 0 then SCALE_LEN=1; SCALE[1]=0; custom_scale[1]=true end
  else
    local mask = SCALE_MASKS[scale_mode]
    for i=1,#mask do
      SCALE_LEN = SCALE_LEN + 1
      SCALE[SCALE_LEN] = mask[i] + root_note
    end
  end
end
generate_scale()
local SNAKE_MAX = W * H
local SNAKE_BUF = {}
for i=1,SNAKE_MAX do SNAKE_BUF[i]={x=0,y=0} end
local snake_head = 1
local snake_len = 0
local snk_len = 4

local function snk(i) return SNAKE_BUF[(snake_head+i-2)%SNAKE_MAX+1] end

local dir = {x=1,y=0}
local queued = {x=1,y=0}
local death_phase = 0
local death_col = 1
local death_note_i = 1
local last_death_note_idx = 0
local seq_i = 1
local on_note = nil
local on_chord = false
local chord_notes = {0,0,0}

local alt_held = false
local menu_sticky = false
local last_alt_tap = 0
local master_bright = 12
local alt_disp_timer = 0
local alt_disp_mode = "BPM"

local mono_mode = 0
local MONO_TINTS = {
  {r=0.14,g=1.0,b=0.79},{r=1.0,g=0.20,b=0.90},
  {r=0.80,g=0.80,b=0.80},{r=1.0,g=0.63,b=0.08},
  {r=1.0,g=1.0,b=1.0}
}

local fruits = {}
local m_game, m_death
local BFS_SZ = W * H
local BFS_S = {}
local BFS_Q = {}
local BFS_T = {}
for i=1,BFS_SZ do BFS_S[i]=0; BFS_Q[i]=0; BFS_T[i]=false end

local DIR_DX = {1, -1, 0, 0}
local DIR_DY = {0, 0, 1, -1}

-- @section Autopilot (BFS)

--- Breadth-first search for the nearest target.
-- Used by AUT mode (any fruit) and SEM mode (user-set target).
-- @tparam boolean use_tgt_flags true = seek any BFS_T flagged cell, false = seek (tx,ty)
-- @tparam number tx target x (1-based)
-- @tparam number ty target y (1-based)
-- @treturn number direction index 1–4 (matching DIR_DX/DIR_DY), or 0 if unreachable
local function bfs_run(use_tgt_flags, tx, ty)
  if snake_len == 0 then return 0 end
  local h = snk(1)
  local sx, sy = h.x, h.y
  for i=1,BFS_SZ do BFS_S[i]=0 end
  for i=1,snake_len-1 do
    local s = snk(i)
    BFS_S[(s.y-1)*W+s.x] = 5
  end
  BFS_S[(sy-1)*W+sx] = 5
  local qi, qe = 1, 0
  for d=1,4 do
    local nx = wrap(sx+DIR_DX[d],1,W)
    local ny = wrap(sy+DIR_DY[d],1,H)
    local k = (ny-1)*W+nx
    if BFS_S[k] == 0 then BFS_S[k]=d; qe=qe+1; BFS_Q[qe]=k end
  end
  local tk = (ty-1)*W+tx
  while qi <= qe do
    local ck = BFS_Q[qi]; qi=qi+1
    if use_tgt_flags then
      if BFS_T[ck] then return BFS_S[ck] end
    else
      if ck == tk then return BFS_S[ck] end
    end
    local cx = ((ck-1)%W)+1
    local cy = math.floor((ck-1)/W)+1
    local fd = BFS_S[ck]
    for d=1,4 do
      local nx = wrap(cx+DIR_DX[d],1,W)
      local ny = wrap(cy+DIR_DY[d],1,H)
      local k = (ny-1)*W+nx
      if BFS_S[k] == 0 then BFS_S[k]=fd; qe=qe+1; BFS_Q[qe]=k end
    end
  end
  return 0
end

local function spx(x,y,r,g,b)
  if x<1 or x>W or y<1 or y>H then return end
  if mono_mode > 0 then
    local lum = r*0.299 + g*0.587 + b*0.114
    local t = MONO_TINTS[mono_mode]
    r,g,b = math.floor(lum*t.r), math.floor(lum*t.g), math.floor(lum*t.b)
  end
  if grid_led_rgb then grid_led_rgb(x,y,r,g,b)
  else grid_led(x,y,math.floor(math.max(r,g,b)/17)) end
end

local function clr() grid_led_all(0) end

local function degree_note(deg, oct)
  local _d = ((deg-1)%SCALE_LEN)+1
  local oct_shift = math.floor((deg-1)/SCALE_LEN)
  local note = BASE + SCALE[_d] + (oct+oct_shift)*12
  return math.max(36,math.min(96,note))
end

local function note_for(x,y)
  local oct = math.floor((H-y)/4) + math.floor((x-1)/SCALE_LEN)%2
  return degree_note(x, oct)
end

local FONT={["0"]=0x75557,["1"]=0x22222,["2"]=0x71747,["3"]=0x71717,["4"]=0x55711,["5"]=0x74717,["6"]=0x74757,["7"]=0x71111,["8"]=0x75757,["9"]=0x75711,["A"]=0x75755,["C"]=0x74447,["D"]=0x65556,["E"]=0x74747,["I"]=0x72227,["J"]=0x71153,["L"]=0x44447,["M"]=0x57555,["N"]=0x75555,["O"]=0x75557,["P"]=0x75744,["R"]=0x75765,["S"]=0x74717,["T"]=0x72222,["U"]=0x55557,["W"]=0x55575,["Y"]=0x55222}

local function draw_char(x,y,char,r,g,b,bm)
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

local function draw_label(x,y,str,r,g,b,hl_idx)
  for i=1,#str do
    draw_char(x+(i-1)*3, y, str:sub(i,i), r, g, b, (i==hl_idx) and 0.2 or 1.0)
  end
end

local function draw_scene_raw()
  for hkey=1,128 do
    local h = halos[hkey]
    if h.life > 0 then
      local hx = ((hkey-1)%W)+1
      local hy = math.floor((hkey-1)/W)+1
      if h.state == 1 then
        spx(hx-1,hy,10,40,50); spx(hx+1,hy,10,40,50)
        spx(hx,hy-1,10,40,50); spx(hx,hy+1,10,40,50)
      elseif h.state == 2 then
        spx(hx,hy,20,80,100)
      end
      spx(hx,hy,5,20,25)
    end
  end
  if auto_has_target then spx(auto_target.x, auto_target.y, 200, 100, 15) end
  for i=1,#fruits do
    local f=fruits[i]; local c=FRUIT_COL[f.kind]
    spx(f.x, f.y, c.r, c.g, c.b)
  end
  spx(ALT_X, ALT_Y, alt_held and 232 or 50, alt_held and 112 or 18, alt_held and 18 or 5)
  for i=1,#DPAD do local a=DPAD[i]; spx(a.x,a.y,12,12,28) end
  local n = snake_len
  for i=n,2,-1 do
    local s = snk(i)
    local bright = math.max(34, math.floor((1 - i/n)*187)+34)
    spx(s.x, s.y, math.floor(bright*0.18), bright, 0)
  end
  if n > 0 then local h=snk(1); spx(h.x, h.y, 95, 210, 28) end
end

local function draw_game()
  clr()
  draw_scene_raw()
  grid_refresh()
end

local function draw_alt()
  clr()
  for x=1,8 do
    if x*2<=num_fruits then spx(x,1,20,140,110) else spx(x,1,5,30,25) end
  end
  for x=11,16 do
    local f_idx = x-10
    local c = FRUIT_COL[f_idx]
    if fruit_enabled[f_idx] then spx(x,1,c.r,c.g,c.b)
    else spx(x,1,math.floor(c.r*0.1),math.floor(c.g*0.1),math.floor(c.b*0.1)) end
  end
  for x=1,8 do
    if x<=(arp_lifespan/8) then spx(x,2,200,40,180) else spx(x,2,40,10,35) end
  end
  for x=9,16 do
    if (x-8)<=arp_pool_max then spx(x,2,100,100,255) else spx(x,2,20,20,50) end
  end
  spx(10,3,180,20,10); spx(11,3,200,80,20); spx(12,3,20,200,80); spx(13,3,10,180,20)
  if auto_mode == 0 then spx(1,3,30,8,4)
  elseif auto_mode == 1 then spx(1,3,130,75,10)
  else spx(1,3,20,240,50) end
  spx(3,3,240,150,20)
  local b_r = math.floor(master_bright*17)
  spx(15,3,b_r,b_r,b_r)
  if mono_mode > 0 then
    local t = MONO_TINTS[mono_mode]
    spx(16,3,math.floor(t.r*200),math.floor(t.g*200),math.floor(t.b*200))
  else spx(16,3,30,30,30) end

  for y_kb=6,7 do
    for x_kb=1,7 do
      local note = KB_MAP[y_kb][x_kb]
      if note then
        local is_root, is_active = false, false
        if scale_mode == 7 then
          is_active = custom_scale[note+1]
        else
          is_root = (note == root_note)
          for i=1,SCALE_LEN do if (SCALE[i] % 12) == note then is_active = true break end end
        end
        if is_root then spx(x_kb, y_kb, 20, 100, 255)
        elseif is_active then spx(x_kb, y_kb, 200, 200, 200)
        else spx(x_kb, y_kb, 15, 15, 15) end
      end
    end
  end
  for x_sc=1,7 do
    if scale_mode == x_sc then spx(x_sc, 4, 255, 255, 255)
    else spx(x_sc, 4, 40, 40, 40) end
  end

  if alt_disp_timer > 0 and alt_disp_mode == "ARP" then
    local label = arp_labels[arp_mode]
    if label == "UP" then label = " UP" end
    draw_label(8, 4, label, 200, 150, 10, 2)
  elseif alt_disp_timer > 0 and alt_disp_mode == "AUTO" then
    local auto_labels = {"NON", "SEM", "AUT"}
    draw_label(8, 4, auto_labels[auto_mode + 1], 20, 200, 60, 2)
  elseif alt_disp_timer > 0 and alt_disp_mode == "SCA" then
    draw_label(8, 4, SCALE_NAMES[scale_mode], 100, 255, 100, 2)
  else
    local s_bpm = string.format("%03d", bpm)
    draw_label(8, 4, s_bpm, 180, 120, 20, 2)
  end
  spx(ALT_X, ALT_Y, 232, 112, 18)
  grid_refresh()
end

local function is_dpad(x,y)
  for i=1,#DPAD do if DPAD[i].x==x and DPAD[i].y==y then return true end end
  return false
end

local function occupied(x,y)
  for i=1,snake_len do
    local s = snk(i); if s.x==x and s.y==y then return true end
  end
  for i=1,#fruits do
    local f = fruits[i]; if f.x==x and f.y==y then return true end
  end
  return (x==ALT_X and y==ALT_Y) or is_dpad(x,y)
end

-- @section Fruit Spawning

--- Move a fruit to a random unoccupied position with weighted kind selection.
-- @tparam table f fruit object with {x, y, kind} fields
local function reposition_fruit(f)
  f.x, f.y = -1, -1
  for _=1,100 do
    local x, y = math.random(W), math.random(H)
    if not occupied(x,y) then
      local wt = 0; for i=1,#FRUIT_W do if fruit_enabled[i] then wt=wt+FRUIT_W[i] end end
      if wt == 0 then fruit_enabled[1]=true; wt=FRUIT_W[1] end
      local roll, acc, k = math.random(wt), 0, #FRUIT_W
      for i=1,#FRUIT_W do
        if fruit_enabled[i] then
          acc = acc + FRUIT_W[i]
          if roll <= acc then k=i; break end
        end
      end
      f.x, f.y, f.kind = x, y, k
      return
    end
  end
end

local function spawn_fruit()
  if #fruits >= num_fruits then return end
  local f = {x=-1, y=-1, kind=0}
  table.insert(fruits, f)
  reposition_fruit(f)
end

local function reset_snake()
  snake_head, snake_len = 1, 4
  for i=1,4 do
    local s = SNAKE_BUF[(snake_head+i-2)%SNAKE_MAX+1]
    s.x, s.y = 10-i, 4
  end
  dir.x, dir.y, queued.x, queued.y = 1,0,1,0
  snk_len, auto_has_target = 4, false
end

-- @section Death Animation

--- Advance the two-phase death animation by one tick.
-- Phase 1: orange wipe sweeps left-to-right, triggering echo on each fruit/snake segment.
-- Phase 2: black curtain sweeps right-to-left, playing collected notes in reverse.
local function death_tick()
  if death_phase == 1 then
    if on_note then midi_note_off(on_note); on_note=nil end
    local hit_item = false
    for i=1,#fruits do
      local f = fruits[i]
      if f.x == death_col then
        hit_item = true
        for ei=1,ECHO_MAX do
          if not ECHO_BUF[ei].active then
            local e = ECHO_BUF[ei]; e.active = true; e.note = note_for(f.x, f.y)
            e.vel = 90; e.bounces = math.random(8, 16); e.current_interval = math.random(6, 12); e.ticks_left = e.current_interval
            break
          end
        end
      end
    end
    for i=1,snake_len do
      local s = snk(i)
      if s.x == death_col then
        hit_item = true
        for ei=1,ECHO_MAX do
          if not ECHO_BUF[ei].active then
            local e = ECHO_BUF[ei]; e.active = true; e.note = note_for(s.x, s.y)
            e.vel = 70; e.bounces = math.random(4, 10); e.current_interval = math.random(4, 8); e.ticks_left = e.current_interval
            break
          end
        end
      end
    end
    if not hit_item then
      local note = 80 - death_col*2
      midi_note_on(note, 30); on_note = note
    end
    clr()
    for y=1,H do spx(death_col,y,210,90,20) end
    grid_refresh()
    death_col = death_col + 1
    if death_col > W then
      if on_note then midi_note_off(on_note); on_note=nil end
      arp_pool_len, arp_steps_remaining = 0, 0
      arp_trigger_chance, arp_first_note = 1.0, false
      for hk=1,128 do halos[hk].life=0; halos[hk].state=0 end
      for ei=1,ECHO_MAX do ECHO_BUF[ei].active=false end
      reset_snake()
      for fi=#fruits,1,-1 do fruits[fi]=nil end
      while #fruits < num_fruits do spawn_fruit() end
      death_phase, death_col = 2, W
      death_note_i = collected_len
    end
  elseif death_phase == 2 then
    if on_note then midi_note_off(on_note); on_note=nil end
    if collected_len > 0 then
      local idx = math.ceil(collected_len * (death_col/W))
      idx = math.max(1, math.min(collected_len, idx))
      if idx ~= last_death_note_idx then
        local c = collected_notes[idx]
        local n = note_for(c.x, c.y)
        midi_note_on(n, 70); on_note, last_death_note_idx = n, idx
      end
    end
    clr()
    draw_scene_raw()
    for bx=1,death_col do for by=1,H do spx(bx,by,0,0,0) end end
    for y=1,H do spx(death_col,y,210,90,20) end
    grid_refresh()
    death_col = death_col - 1
    if death_col < 1 then
      if on_note then midi_note_off(on_note); on_note=nil end
      death_phase, collected_len = 0, 0
      draw_game()
    end
  end
end

-- @section Arpeggiator

--- Add a note to the arp pool.
-- Evicts the oldest entry if pool is at capacity.
-- Resets the lifespan countdown and records position in collected_notes.
-- @tparam number note MIDI note number
-- @tparam number x grid x position of collected fruit
-- @tparam number y grid y position of collected fruit
-- @tparam number kind fruit kind index (1–6)
local function arp_add(note, x, y, kind)
  if arp_pool_len >= arp_pool_max then
    local old = arp_pool[1]
    for i=2,arp_pool_max do arp_pool[i-1] = arp_pool[i] end
    arp_pool[arp_pool_max] = old
    arp_pool_len = arp_pool_max
  else
    arp_pool_len = arp_pool_len + 1
  end
  local target = arp_pool[arp_pool_len]
  target.note, target.x, target.y, target.kind = note, x, y, kind
  arp_steps_remaining = arp_lifespan
  arp_first_note = true
  if collected_len >= COLLECTED_MAX then
    for i=2,COLLECTED_MAX do collected_notes[i-1].x, collected_notes[i-1].y = collected_notes[i].x, collected_notes[i].y end
    collected_notes[COLLECTED_MAX].x, collected_notes[COLLECTED_MAX].y = x, y
  else
    collected_len = collected_len + 1
    collected_notes[collected_len].x, collected_notes[collected_len].y = x, y
  end
end

local function seq_tick()
  if on_note then midi_note_off(on_note); on_note=nil end
  if on_chord then
    for i=1,3 do midi_note_off(chord_notes[i]) end
    on_chord = false
  end
  if arp_pool_len == 0 then return end
  if arp_lifespan > 0 then
    if arp_steps_remaining <= 0 then arp_pool_len = 0; return end
    arp_steps_remaining = arp_steps_remaining - 1
  end
  if arp_first_note then arp_first_note = false
  elseif arp_trigger_chance < 1.0 then
    if math.random() > arp_trigger_chance then return end
  end
  if arp_pool_len == 0 then return end

  local n = arp_pool_len
  for i=1,n do arp_pool[i].note = note_for(arp_pool[i].x, arp_pool[i].y) end 
  local triggered_note_obj = nil
  if arp_mode == 3 or arp_mode == 4 then
    for i=1,n do SORT_BUF[i].note = arp_pool[i].note; SORT_BUF[i].kind = arp_pool[i].kind end
    for i=2,n do
      local key_n = SORT_BUF[i].note; local key_k = SORT_BUF[i].kind; local j = i-1
      if arp_mode == 3 then
        while j>=1 and SORT_BUF[j].note>key_n do 
          SORT_BUF[j+1].note=SORT_BUF[j].note; SORT_BUF[j+1].kind=SORT_BUF[j].kind; j=j-1 
        end
      else
        while j>=1 and SORT_BUF[j].note<key_n do 
          SORT_BUF[j+1].note=SORT_BUF[j].note; SORT_BUF[j+1].kind=SORT_BUF[j].kind; j=j-1 
        end
      end
      SORT_BUF[j+1].note = key_n; SORT_BUF[j+1].kind = key_k
    end
    seq_i = (seq_i%n)+1
    triggered_note_obj = SORT_BUF[seq_i]
  elseif arp_mode == 2 then
    seq_i = math.random(n)
    triggered_note_obj = arp_pool[seq_i]
  else
    seq_i = (seq_i%n)+1
    triggered_note_obj = arp_pool[seq_i]
  end

  midi_note_on(triggered_note_obj.note, 90); on_note = triggered_note_obj.note

  if triggered_note_obj.kind == 6 then
    for ei=1,ECHO_MAX do
      if not ECHO_BUF[ei].active then
        local e = ECHO_BUF[ei]
        e.active = true
        e.note = triggered_note_obj.note
        e.vel = 80
        e.bounces = math.random(12, 24)
        e.current_interval = 12
        e.ticks_left = e.current_interval
        break
      end
    end
  end
end

local need_interval_update = false
local fast_tick = 0
-- @section Game Loop

--- Main game tick — called by the metro every interval.
-- Handles: echo decay, death phases, autopilot BFS, snake movement,
-- collision detection, fruit collection effects, and arp sequencer trigger.
local function game_tick()
  if alt_held then return end

  fast_tick = fast_tick + 1

  for i=1,ECHO_MAX do
    local e = ECHO_BUF[i]
    if e.active then
      e.ticks_left = e.ticks_left - 1
      if e.ticks_left <= 0 then
        midi_note_on(e.note, math.floor(e.vel))
        e.bounces = e.bounces - 1
        if e.bounces <= 0 then e.active = false
        else
          e.vel = e.vel * 0.85
          e.current_interval = math.max(1, e.current_interval * 0.85)
          e.ticks_left = math.max(1, math.floor(e.current_interval))
        end
      end
    end
  end

  if death_phase == 1 then
    if fast_tick % 4 == 0 then death_tick() end
    return
  elseif death_phase == 2 then
    if fast_tick % 8 == 0 then death_tick() end
    return
  end

  if fast_tick % 4 ~= 0 then return end
  if auto_mode == 2 then
    for i=1,BFS_SZ do BFS_T[i] = false end
    for i=1,#fruits do local f=fruits[i]; BFS_T[(f.y-1)*W+f.x]=true end
    local d = bfs_run(true,0,0)
    if d>0 then queued.x=DIR_DX[d]; queued.y=DIR_DY[d] end
  elseif auto_mode == 1 and auto_has_target then
    local h = snk(1)
    if h.x == auto_target.x and h.y == auto_target.y then auto_has_target = false
    else
      local d = bfs_run(false, auto_target.x, auto_target.y)
      if d>0 then queued.x=DIR_DX[d]; queued.y=DIR_DY[d] end
    end
  end

  if not (queued.x == -dir.x and dir.x ~= 0) and not (queued.y == -dir.y and dir.y ~= 0) then
    dir.x, dir.y = queued.x, queued.y
  end
  local h = snk(1)
  local hx, hy = wrap(h.x+dir.x,1,W), wrap(h.y+dir.y,1,H)

  for i=1,snake_len-1 do
    local s = snk(i)
    if s.x==hx and s.y==hy then
      death_phase, death_col = 1, 1
      return
    end
  end

  snake_head = (snake_head-2)%SNAKE_MAX+1
  local nh = SNAKE_BUF[snake_head]
  nh.x, nh.y = hx, hy
  snake_len = snake_len + 1

  for i=1,#fruits do
    local f = fruits[i]
    if f.x==hx and f.y==hy then
      local pool_note = note_for(hx, hy)
      if f.kind == 1 then
        snk_len = math.max(2, snk_len - 1); arp_add(pool_note, hx, hy, f.kind)
      elseif f.kind == 2 then
        snk_len = snk_len + 1; arp_add(pool_note, hx, hy, f.kind)
      elseif f.kind == 3 then
        temp_slow_steps = 16; need_interval_update = true; arp_add(pool_note, hx, hy, f.kind)
      elseif f.kind == 4 then
        local hkey = (hy-1)*W+hx
        if halos[hkey].life <= 0 then halos[hkey].state=1; halos[hkey].life=3
        else halos[hkey].state=halos[hkey].state+1; halos[hkey].life=halos[hkey].life-1 end
        local c_type = halos[hkey].state
        local deg_root, oct_root = hx, math.floor((H-hy)/4) + math.floor((hx-1)/SCALE_LEN)%2
        if c_type == 1 then
          chord_notes[1], chord_notes[2], chord_notes[3] = degree_note(deg_root, oct_root), degree_note(deg_root+2, oct_root), degree_note(deg_root+4, oct_root)
        elseif c_type == 2 then
          chord_notes[1], chord_notes[2], chord_notes[3] = degree_note(deg_root, oct_root), degree_note(deg_root+3, oct_root), degree_note(deg_root+5, oct_root)
        else
          chord_notes[1], chord_notes[2], chord_notes[3] = degree_note(deg_root, oct_root), degree_note(deg_root+4, oct_root), degree_note(deg_root+7, oct_root)
        end
        for ci=1,3 do chord_notes[ci]=math.max(36,math.min(96,chord_notes[ci])) end
        midi_note_on(chord_notes[1],80); midi_note_on(chord_notes[2],70); midi_note_on(chord_notes[3],60)
        on_chord = true
        if halos[hkey].life <= 0 then reposition_fruit(f) end
        goto after_fruit
      elseif f.kind == 5 then
        arp_trigger_chance = 0.33; snk_len = snk_len + 1; arp_add(pool_note, hx, hy, f.kind)
      elseif f.kind == 6 then
        snk_len = snk_len + 1; arp_add(pool_note, hx, hy, f.kind)
      end
      reposition_fruit(f)
      break
    end
  end
  ::after_fruit::

  if temp_slow_steps > 0 then
    temp_slow_steps = temp_slow_steps - 1
    if temp_slow_steps == 0 then need_interval_update = true end
  end
  if need_interval_update then
    need_interval_update = false; m_game:start(get_interval() / 4)
  end
  while snake_len > snk_len do snake_len = snake_len - 1 end
  seq_tick()
  draw_game()
end

-- @section Input Handler

--- Grid key event handler — called by the hardware / emulator on pad press/release.
-- Routes to: ALT toggle, settings controls (when alt_held), D-PAD, autopilot target, or direction steering.
-- @tparam number x grid column (1-based)
-- @tparam number y grid row (1-based)
-- @tparam number z 1 = pressed, 0 = released
function event_grid(x,y,z)
  if x==ALT_X and y==ALT_Y then
    if z==1 then
      local now = get_time()
      if (now-last_alt_tap)<0.3 then menu_sticky = not menu_sticky end
      last_alt_tap, alt_held = now, true
      draw_alt()
    else
      if not menu_sticky then alt_held=false; draw_game() end
    end
    return
  end
  if z==0 then return end
  if alt_held then
    if y==4 and x<=7 then
      scale_mode = x
      generate_scale()
      alt_disp_mode="SCA"; alt_disp_timer=15
    elseif (y==6 or y==7) and x<=7 then
      local note = KB_MAP[y][x]
      if note then
        if scale_mode == 7 then custom_scale[note+1] = not custom_scale[note+1]
        else root_note = note end
        generate_scale()
        alt_disp_mode="SCA"; alt_disp_timer=15
      end
    elseif y==1 then
      if x<=8 then
        num_fruits = math.max(2,x*2)
        while #fruits < num_fruits do spawn_fruit() end
        while #fruits > num_fruits do table.remove(fruits) end
      elseif x>=11 and x<=16 then
        fruit_enabled[x-10] = not fruit_enabled[x-10]
      end
    elseif y==2 then
      if x<=8 then arp_lifespan=x*8 else arp_pool_max=x-8 end
      alt_disp_mode="ARP"; alt_disp_timer=15
    elseif y==3 then
      if x==10 then bpm=math.max(40,bpm-10); alt_disp_timer=0
      elseif x==11 then bpm=math.max(40,bpm-1); alt_disp_timer=0
      elseif x==12 then bpm=math.min(240,bpm+1); alt_disp_timer=0
      elseif x==13 then bpm=math.min(240,bpm+10); alt_disp_timer=0
      elseif x==1 then
        auto_mode = (auto_mode+1)%3
        if auto_mode~=1 then auto_has_target=false end
        alt_disp_mode="AUTO"; alt_disp_timer=15
      elseif x==3 then
        arp_mode=(arp_mode%#arp_labels)+1; alt_disp_mode="ARP"; alt_disp_timer=15
      elseif x==15 then
        master_bright = master_bright+4
        if master_bright>15 then master_bright=4 end
        if grid_color_intensity then grid_color_intensity(master_bright) end
      elseif x==16 then
        mono_mode = (mono_mode+1)%(#MONO_TINTS+1)
      end
      m_game:start(get_interval() / 4)
    end
    draw_alt()
    return
  end

  for i=1,#DPAD do
    local a = DPAD[i]
    if a.x==x and a.y==y then
      queued.x, queued.y = a.dx, a.dy
      if auto_mode == 1 then auto_has_target = false end
      return
    end
  end

  if snake_len == 0 then return end
  if auto_mode == 1 then
    auto_target.x, auto_target.y = x, y; auto_has_target = true
    return
  end
  local h = snk(1)
  local dx, dy = x - h.x, y - h.y
  if dx == 0 and dy == 0 then return end
  if math.abs(dx) >= math.abs(dy) then
    queued.x, queued.y = (dx>0) and 1 or -1, 0
  else
    queued.x, queued.y = 0, (dy>0) and 1 or -1
  end
end

math.randomseed(math.floor(get_time()*1e6)%999983)
if grid_color_intensity then grid_color_intensity(master_bright) end
reset_snake()
while #fruits < num_fruits do spawn_fruit() end
draw_game()

m_game = metro.init(game_tick, get_interval() / 4)
m_game:start()
