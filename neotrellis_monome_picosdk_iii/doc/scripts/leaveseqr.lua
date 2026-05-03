-- scriptname: LeaveSeqr
-- v0.3.0
-- @author: jonwaterschoot
--
-- Ambient leaf physics sequencer: leaves drift through air, float on water, sink to mud.
-- Three generative water tracks; triops leap from mud to eat leaves and decay into bass echoes.
--
-- @key Tab: Cycle screen (Live → Seq → Scale)
-- @key 1/2: BPM -10/-1
-- @key 3/4: BPM +1/+10

-- ---------------------------------------------------------------------------
-- @section Grid Layout
-- @screen live
-- @group Canopy
-- @detail Leaves grow here over time (rate set by Density in Seq screen).
-- @detail Tap an empty cell to plant a leaf. Tap a lit leaf to knock it loose and let it fall.
-- @detail Wind gusts and high density can blow canopy leaves off automatically.
-- Row 1: CAN — Canopy leaves grow here; tap to plant/knock loose
-- @group Left Wind
-- x=1..3, y=2: WIND gusts push leaves rightward; blows canopy loose
-- @group Right Wind
-- x=14..16, y=2: WIND gusts push leaves leftward; blows canopy loose
-- @group Air Zone
-- @detail Falling leaves drift slowly downward through this zone.
-- @detail Wind strength (set in Seq screen) pushes leaves horizontally and occasionally upward.
-- @detail Leaves spend time here before reaching the water tracks below.
-- Row 2..4: AIR — leaves drift slowly, wind pushes horizontal and upward
-- @group Water Tracks
-- @detail Each row is an independent sequencer track with its own playhead.
-- @detail When a leaf sits on a playhead position, it triggers a note. Octave depth increases downward.
-- @detail Track length, speed (division), MIDI channel, and octave offset are configured on the Seq screen.
-- @detail Tap a track row on the Seq screen to set loop bounds (LEN), speed (DIV), channel (CH), or octave (OCT).
-- Row 5: TR1 — Water surface, base octave
-- Row 6: TR2 — Underwater mid, one octave down
-- Row 7: TR3 — Underwater deep, two octaves down
-- @group Mud
-- @detail Leaves that sink past the water tracks collect here and slowly decay.
-- @detail Triops occasionally leap from the mud to eat a sinking leaf, triggering a bouncing bass echo delay.
-- @detail Triop spawn rate and strength are set in the Seq screen (TRIOP control).
-- Row 8: MUD — leaves collect; leaves decay here
-- @group Playback
-- x=1, y=3: PLAY/STOP sequencer and physics
-- @group Freeze
-- x=16, y=3: FREEZE (pauses leaf movement in water zones)
-- @group Screen Swap
-- x=1, y=8: CYCLE Live → Seq → Scale
-- ---------------------------------------------------------------------------
-- @section Sequencer Settings
-- @screen seq
-- @group Track Config
-- x=1, y=1: LEN — tap track twice to set loop start and end
-- x=2, y=1: DIV — tap x=1..6 on track to set division
-- x=3, y=1: CH — tap x=1..16 on track to set MIDI channel
-- x=4, y=1: OCT — tap x=1..8 (-4 to +3) on track to set octave bounds
-- @group Tempo
-- x=1..4, y=2: BPM (-10, -1, +1, +10)
-- @group Environment
-- x=1..3, y=3: WIND strength (lo, mid, hi)
-- @group Canopy Generator
-- x=5..8, y=3: DENS leaf spawn density (off, lo, mid, hi)
-- @group Timing Feel
-- x=1..3, y=4: HUM humanize (off, soft, heavy)
-- @group Ecosystem
-- x=5, y=4: TRIOP auto-spawn and strength (off, soft, strong)
-- @group Tracks
-- Row 5: TR1 — Track 1 (surface)
-- Row 6: TR2 — Track 2 (mid water)
-- Row 7: TR3 — Track 3 (deep water)
-- @group Screen Swap
-- x=1, y=8: CYCLE Live → Seq → Scale
-- ---------------------------------------------------------------------------
-- @section Scale / Display Settings
-- @screen scale
-- @group Key Scale
-- x=1..7, y=1: SCALE — MAJ, MIN, PMA, PMI, DOR, LYD, CUS
-- @group Custom Overrides
-- x=1..7, y=3: BLACK keys (gaps at 1 and 4)
-- x=1..7, y=4: WHITE keys — C D E F G A B
-- @group Octave Center
-- x=1..4, y=6: OCT base (2, 3, 4, 5)
-- @group Themes
-- @detail Seasons shape leaf colors, note character, and MIDI CC filter automation.
-- @detail SP Spring · bright greens · short energetic notes · high velocity · CC stays neutral
-- @detail SU Summer · warm yellow-greens · long sustained notes · high velocity · CC stays neutral
-- @detail AU Autumn · warm oranges/reds · short-medium notes · 25% chord chance (thirds/fifths) · slow wide CC filter sweeps
-- @detail WI Winter · cool blues/greys · long and short mixed · lower velocity · 15% echo chance · fast jittery CC filter drift
-- x=1..4, y=7: SEAS — Season (SP, SU, AU, WI)
-- @group Monochrome
-- x=6, y=7: MONO mode toggle
-- @group Grid Display
-- x=3..5, y=8: DIM grid dimming levels (lo, mid, max)
-- @group Screen Swap
-- x=1, y=8: CYCLE Live → Seq → Scale
-- ---------------------------------------------------------------------------

local supports_multi_screen = (grid_set_screen ~= nil)
if not grid_set_screen    then grid_set_screen    = function(_) end end
if not display_screen     then display_screen     = function(_) end end
if not get_focused_screen then get_focused_screen = function() return "live" end end
if not get_time           then get_time           = function() return 0 end end

-- ===========================================================================
-- CONSTANTS
-- ===========================================================================
local W, H   = 16, 8

local Y_CAN  = 1   -- canopy row
local Y_AIR1 = 2   -- top of air (also wind button row)
local Y_AIR2 = 4   -- bottom of air
local Y_SURF = 5   -- water surface — Track 1
local Y_MID  = 6   -- underwater mid — Track 2
local Y_DEEP = 7   -- underwater deep — Track 3
local Y_MUD  = 8   -- mud layer

-- Leaf types
local T_EMPTY   = 0
local T_CANOPY  = 1
local T_AIR     = 2
local T_SURFACE = 3
local T_UNDER   = 4
local T_MUD     = 5

-- Triop states
local TS_MUD_WAIT = 0
local TS_RISING   = 1
local TS_SINKING  = 2

-- Physics
local PHYS_HZ  = 6
local PHYS_INT = 1.0 / PHYS_HZ

-- Fall / sink probabilities per tick (ambient-slow)
local PROB_AIR  = 16   -- leaves hover in air
local PROB_SURF = 4    -- surface float is long
local PROB_MID  = 3    -- mid water sinks very slowly
local PROB_DEEP = 2    -- deep water almost still

-- Passive drift (brownian, no wind needed)
local DRIFT_AIR  = 14  -- lazy left/right in air
local DRIFT_SURF = 7   -- gentle surface drift
local DRIFT_MID  = 2   -- minimal underwater drift

-- ===========================================================================
-- COLORS (pre-allocated — no runtime alloc)
-- ===========================================================================
local S1A={r=80,g=220,b=80};  local S1B={r=165,g=230,b=58}
local S2A={r=28,g=155,b=48};  local S2B={r=18,g=178,b=108}
local S3A={r=215,g=105,b=18}; local S3B={r=175,g=45,b=18}
local S4A={r=130,g=175,b=215};local S4B={r=72,g=112,b=138}
local SEASONS = {{S1A,S1B},{S2A,S2B},{S3A,S3B},{S4A,S4B}}
local season   = 3  -- autumn default

local HC1={r=55,g=55,b=55}; local HC2={r=18,g=195,b=175}; local HC3={r=215,g=75,b=215}
local HUM_COLORS = {HC1, HC2, HC3}
local SC1={r=75,g=195,b=75}; local SC2={r=18,g=145,b=55}
local SC3={r=195,g=95,b=18}; local SC4={r=72,g=112,b=152}
local SEA_COLORS = {SC1, SC2, SC3, SC4}
local BRI_VALS = {255, 138, 58}
-- Seq/scale draw constants (pre-allocated at module scope — avoid heap allocs inside draw fns)
local SEQ_OPT_COLORS = {{140,88,14},{155,45,175},{185,105,18},{55,100,245}}
local BPM_COL_HI     = {220, 20,  20}   -- outer BPM buttons (x=1, x=4)
local BPM_COL_MID    = {192, 112, 16}   -- inner BPM buttons (x=2, x=3)
local SCALE_SEA_DRAW = {{0,150,40},{250,200,0},{200,80,0},{50,100,200}}
local SCALE_BLK_KEYS = {-1, 1, 3, -1, 6, 8, 10}

-- ===========================================================================
-- GRID STATE (flat pre-allocated [1..128])
-- ===========================================================================
local is_dirty    = true  -- live screen needs redraw
local seq_dirty   = true  -- seq screen needs redraw
local scale_dirty = true  -- scale screen needs redraw
local GTYPE  = {}
local GCOL   = {}
local GMOVED = {}
local P_R, P_G, P_B = {}, {}, {}

for i = 1, W * H * 3 do
  P_R[i]=-1; P_G[i]=-1; P_B[i]=-1
end
for i = 1, W * H do
  GTYPE[i]=0; GCOL[i]=1; GMOVED[i]=false
end

local function gidx(x, y)  return (y - 1) * W + x  end
local function dirty_all()
  local n = supports_multi_screen and W*H*3 or W*H
  for i = 1, n do P_R[i]=-1; P_G[i]=-1; P_B[i]=-1 end
end
local function dirty_all_screens()
  dirty_all(); is_dirty=true; seq_dirty=true; scale_dirty=true
end

-- ===========================================================================
-- SCALE / MUSIC
-- ===========================================================================
local SCALE_MASKS = {
  {0,2,4,5,7,9,11}, {0,2,3,5,7,8,10}, {0,2,4,7,9},
  {0,3,5,7,10},     {0,2,3,5,7,9,10}, {0,2,4,6,7,9,11},
}
local SCALE     = {}
local SCALE_LEN = 5
local scale_mode = 3
local root_note  = 0
local custom_scale = {true,false,true,false,true,false,false,true,false,true,false,false}
local oct_base   = 3

local KB_WHITE = {0, 2, 4, 5, 7, 9, 11}
local KB_BLACK = {1, 3,-1, 6, 8,10,-1}

for i = 1, 12 do SCALE[i] = 0 end

local function gen_scale()
  SCALE_LEN = 0
  if scale_mode == 7 then
    for i=0,11 do
      if custom_scale[i+1] then SCALE_LEN=SCALE_LEN+1; SCALE[SCALE_LEN]=i end
    end
    if SCALE_LEN == 0 then SCALE_LEN=1; SCALE[1]=0; custom_scale[1]=true end
  else
    local m = SCALE_MASKS[scale_mode]
    SCALE_LEN = #m
    for i = 1, #m do SCALE[i] = (m[i] + root_note) % 12 end
  end
end
gen_scale()

local function col_to_note(x, oct_off, o_min, o_max)
  local deg  = ((x - 1) % SCALE_LEN) + 1
  local eoct = math.floor((x - 1) / SCALE_LEN)
  
  -- Calculate target relative octave
  local target_rel = (oct_off or 0) + eoct
  
  -- Strict clamp if bounds provided
  if o_min and o_max then
    local start_o = math.min(o_min, o_max)
    local end_o = math.max(o_min, o_max)
    target_rel = math.max(start_o, math.min(end_o, target_rel))
  end
  
  return math.max(24, math.min(108,
    12 + (oct_base + target_rel) * 12 + SCALE[deg]))
end

-- ===========================================================================
-- BPM / TIMING
-- ===========================================================================
local bpm            = 60
local humanize_level = 0
local dim_lvl        = 0
local dim_f          = 1.0
local DIM_VALS       = {1.0, 0.55, 0.25}
local HUM_VEL        = {0, 14, 30}
local HUM_DUR        = {0, 1, 2}
local function get_interval() return 60.0 / bpm / 4 end

-- ===========================================================================
-- ACTIVE NOTE TRACKING
-- ===========================================================================
local MAX_ACT = 16
local ANS = {}
for i = 1, MAX_ACT do ANS[i] = {note=0, active=false, ticks=0, ch=1} end

local MAX_ECH = 4
local ECH = {}
for i = 1, MAX_ECH do ECH[i] = {active=false, note=0, delay=0, b=0, ch=4, init_vel=0} end
local BDEL = {1, 2, 4, 8}
local BVEL = {88, 65, 42, 20}

local function stop_note(note, ch)
  -- Clear from ANS
  for i=1,MAX_ACT do
    if ANS[i].active and ANS[i].note == note and ANS[i].ch == ch then
      midi_note_off(note, 0, ch); ANS[i].active = false
    end
  end
  -- Clear from ECH
  for i=1,MAX_ECH do
    if ECH[i].active and ECH[i].note == note and ECH[i].ch == ch then
      midi_note_off(note, 0, ch); ECH[i].active = false
    end
  end
end

local function play_note(note, vel, dur, ch)
  ch = ch or 1
  stop_note(note, ch) -- Ensure clean start
  local slot, oldest_t = 1, math.huge
  for i = 1, MAX_ACT do
    if not ANS[i].active then slot = i; break end
    if ANS[i].ticks < oldest_t then oldest_t = ANS[i].ticks; slot = i end
  end
  if ANS[slot].active then midi_note_off(ANS[slot].note, 0, ANS[slot].ch) end
  if humanize_level > 0 then
    local hv = HUM_VEL[humanize_level + 1]
    vel = vel + math.random(-hv, hv)
    dur = dur + math.random(0, HUM_DUR[humanize_level + 1])
  end
  vel = math.max(1, math.min(127, vel))
  midi_note_on(note, vel, ch)
  ANS[slot].note=note; ANS[slot].active=true; ANS[slot].ticks=dur; ANS[slot].ch=ch
end

local function notes_off()
  for i = 1, MAX_ACT do
    if ANS[i].active then midi_note_off(ANS[i].note, 0, ANS[i].ch); ANS[i].active=false end
  end
  if echo_off then echo_off() end
  if midi_panic then midi_panic() end
end

local function tick_notes()
  for i = 1, MAX_ACT do
    if ANS[i].active then
      ANS[i].ticks = ANS[i].ticks - 1
      if ANS[i].ticks <= 0 then
        midi_note_off(ANS[i].note, 0, ANS[i].ch); ANS[i].active = false
      end
    end
  end
end

-- ===========================================================================
-- DIGITS HUD SYSTEM
-- ===========================================================================
local hud_timer = 0
local hud_label = ""
local hud_val = ""
local hud_color = {255, 255, 255}

local FONT={
  ["0"]=0x75557,["1"]=0x22222,["2"]=0x71747,["3"]=0x71717,["4"]=0x55711,["5"]=0x74717,["6"]=0x74757,["7"]=0x71111,["8"]=0x75757,["9"]=0x75711,
  ["A"]=0x75755,["C"]=0x74447,["D"]=0x65556,["E"]=0x74747,["H"]=0x55755,["I"]=0x72227,["L"]=0x44447,["P"]=0x75744,["R"]=0x75765,["V"]=0x55552,
  ["B"]=0x65756,["M"]=0x57555,["O"]=0x75557,["N"]=0x75555,["F"]=0x74744,["S"]=0x74717,["T"]=0x72222,["-"]=0x00700,
  ["J"]=0x11153,["U"]=0x55557,["W"]=0x55575,["Y"]=0x55222,["X"]=0x55255 -- X just in case
}

local spx     -- forward declaration
local echo_off -- forward declaration

local function draw_char(x,y,char,r,g,b)
  local char_str = tostring(char)
  local f = FONT[char_str]
  if not f then return end
  for row=1,5 do
    local bits = (f >> ((5-row)*4)) & 0xF
    for col=1,3 do
      if (bits & (1 << (3-col))) ~= 0 then
        spx(x+col-1, y+row-1, r, g, b)
      end
    end
  end
end

local function show_hud(lbl, val, r, g, b)
  -- User requested: display changes according to last selected option.
  -- Simplified: If value is 1-4 letters, it becomes the display. 
  -- If BPM is 3 digits, it becomes the display.
  hud_label = lbl or ""
  local v_str = tostring(val or "")
  if #v_str > 0 then hud_val = v_str else hud_val = hud_label end
  -- Mutate pre-allocated table; avoids a heap alloc on every show_hud call
  hud_color[1] = r or 255; hud_color[2] = g or 255; hud_color[3] = b or 255
  hud_timer = 12  -- 1.5s
  is_dirty = true; seq_dirty = true; scale_dirty = true  -- HUD appears on all screens
end

local function draw_hud()
  if hud_timer <= 0 then return end
  
  -- Localized to top-right 9x5 block (x=8..16, y=1..5)
  for y=1,5 do
    for x=8,16 do
      spx(x,y,0,4,8) 
    end
  end
  
  local s = tostring(hud_val)
  if #s > 3 then s = s:sub(1,3) end -- Cap at 3 for layout
  
  local start_x = 8 -- left of the 9-wide block
  local offset = (3 - #s) * 3 -- Right-align strings shorter than 3 chars
  
  for i=1,#s do
    local char_x = start_x + (i-1)*3 + offset
    local hr, hg, hb = hud_color[1], hud_color[2], hud_color[3]
    
    -- Center dimming applies to both numbers and letters (per user feedback)
    -- With offset, the 'middle' character index depends on the string length relative to the 3-slot box.
    -- However, the user feedback was: "middle character was using a lower brightness".
    -- If string is 3 chars, middle is index 2. If 2 chars, it resides in slots 2 and 3.
    -- I'll keep it simple: if the character occupies the MIDDLE slot (x=11), dim it.
    if char_x == 11 then
      hr, hg, hb = math.floor(hr * 0.4), math.floor(hg * 0.4), math.floor(hb * 0.4)
    end
    
    draw_char(char_x, 1, s:sub(i,i), hr, hg, hb)
  end
end

-- ===========================================================================
-- TRIOP ECHO — bouncing decay (short → long gaps, falling pitch)
-- Reversed-ball: first hit fast, each bounce slower and lower.
-- ===========================================================================

local function start_echo(note, ch, init_vel)
  ch = ch or 4
  init_vel = init_vel or BVEL[1]
  for i = 1, MAX_ECH do
    if not ECH[i].active then
      ECH[i].active=true; ECH[i].note=note; ECH[i].delay=BDEL[1]; ECH[i].b=1; ECH[i].ch=ch
      ECH[i].init_vel = init_vel
      midi_note_on(note, init_vel, ch)
      return
    end
  end
end

local function tick_echo()
  for i = 1, MAX_ECH do
    local e = ECH[i]
    if e.active then
      e.delay = e.delay - 1
      if e.delay <= 0 then
        midi_note_off(e.note, 0, e.ch)
        e.b = e.b + 1
        if e.b > 4 then
          e.active = false
        else
          e.note  = math.max(24, e.note - 2)
          e.delay = BDEL[e.b]
          local v = math.max(1, math.floor(e.init_vel * (BVEL[e.b] / BVEL[1])))
          midi_note_on(e.note, v, e.ch)
        end
      end
    end
  end
end

echo_off = function()
  for i = 1, MAX_ECH do
    if ECH[i].active then midi_note_off(ECH[i].note, 0, ECH[i].ch); ECH[i].active=false end
  end
end

-- ===========================================================================
-- TRIOPS — leap from mud into water to eat leaves, then sink and disappear
local MAX_TR         = 4
local triop_strength = 1 -- 0=off, 1=soft, 2=strong
local triop_auto_spawn = true
local triop_spawn_t  = 0
local TRIOP_INT     = 52   -- auto-spawn every ~6.5 s

-- MIDI CC Automation State
local CC_NUM        = 74   -- Filter Cutoff/Brightness
local cc_val        = 100.0
local cc_target     = 100.0
local cc_slew       = 0.1
local cc_timer      = 0

-- Pre-allocated triop structs
local TR = {}
for i = 1, MAX_TR do
  TR[i] = {
    active=false, x=1, y=Y_MUD, state=TS_MUD_WAIT, blink=false, peak_y=Y_DEEP, timer=0
  }
end

--- Spawn a new triop at column x (mud row). Returns true on success.
local function spawn_triop(x)
  for i = 1, MAX_TR do
    if not TR[i].active then
      TR[i].active=true; 
      TR[i].x = x or math.random(W); 
      TR[i].y = Y_MUD
      TR[i].state = TS_MUD_WAIT
      TR[i].peak_y = math.random(Y_MID, Y_DEEP)
      TR[i].timer = math.random(4, 12) -- brief initial wait in mud
      TR[i].blink = true -- always blink once when entering state
      return true
    end
  end
  return false
end



-- ===========================================================================
-- SEQUENCER STATE — three independent tracks
-- ===========================================================================
local seq_running = false
local beat_count  = 0

-- Division multipliers (relative to 1 tick = 1/16th note at 4 subticks/beat)
-- x=1..6 → 1/32 1/16 1/8 1/4 1/2 1/1
local DIV_MULT = {4.0, 2.0, 1.0, 0.5, 0.25, 0.125}

-- t1: surface (high); t2: mid (medium); t3: deep (low)
local t1 = {y=Y_SURF, step=1, div=3, dir=1, ch=1, accum=0.0, start_step=1, end_step=16, loop_input=0, oct_min=1,  oct_max=1,  oct_input=0}
local t2 = {y=Y_MID,  step=1, div=4, dir=1, ch=2, accum=0.0, start_step=1, end_step=16, loop_input=0, oct_min=0,  oct_max=0,  oct_input=0}
local t3 = {y=Y_DEEP, step=1, div=5, dir=1, ch=3, accum=0.0, start_step=1, end_step=16, loop_input=0, oct_min=-1, oct_max=-1, oct_input=0}
local TRACKS = {t1, t2, t3}

local function advance_track(tr)
  tr.step = tr.step + tr.dir
  if tr.dir == 1 then
    if tr.step > tr.end_step   then tr.step = tr.start_step end
  else
    if tr.step < tr.start_step then tr.step = tr.end_step   end
  end
end

-- ===========================================================================
-- WIND
-- ===========================================================================
local WIND_DIR   = 0
local WIND_TIMER = 0
local WIND_STR   = 1
-- Wind buttons at y=2 (top of air zone): x=1-3 left, x=14-16 right
local WIND_L_MAX = 3
local WIND_R_MIN = 14
-- Gust duration and push probability by strength
local WIND_TICKS = {6, 10, 16}
local WIND_PROB  = {30, 52, 75}

-- ===========================================================================
-- CANOPY / AUTO-GROW
-- ===========================================================================
local auto_grow    = true
local grow_density = 1   -- 0=off, 1=sparse, 2=medium, 3=busy
local grow_timer   = 0
local GROW_INT     = {99999, 32, 14, 6}  -- DE0..DE3 (DE0 = effectively off)
local RELEASE_PROB = {0, 2, 6, 14}       -- release chance per tick for DE0..DE3

-- FREEZE: pauses leaf movement in water rows (surf/mid/deep); seqr keeps running
local freeze = false

-- ===========================================================================
-- CONTROL STATE
-- ===========================================================================
local ALT_X,    ALT_Y    = 1, 8
local PLAY_X,   PLAY_Y   = 1, 3
local FREEZE_X, FREEZE_Y = 16, 3  -- was AUTO (grow toggle), now freeze/hold

local cur_screen = "live"
local seq_opt    = 1   -- 1=LOOP 2=DIV 3=DIR 4=CH
local alt_on     = false

local function cycle_screen()
  if     cur_screen == "live"  then cur_screen = "seq"
  elseif cur_screen == "seq"   then cur_screen = "scale"
  else                              cur_screen = "live" end
  if display_screen then display_screen(cur_screen) end
  -- In multi-screen mode each screen has its own P_ region and is continuously
  -- maintained, so no cache flush is needed. In single-screen mode the same 128
  -- entries just represented the *old* screen; flush them so the new screen gets
  -- a full repaint rather than hitting stale differential matches.
  if not supports_multi_screen then dirty_all() end
  is_dirty = true; seq_dirty = true; scale_dirty = true
end

-- ===========================================================================
-- PIXEL HELPER (differential, with brightness and mono fallback)
-- ===========================================================================
local mono_ui = false
local spx_offset = 0

spx = function(x, y, r, g, b)
  if x < 1 or x > W or y < 1 or y > H then return end
  r = math.floor(r * dim_f); g = math.floor(g * dim_f); b = math.floor(b * dim_f)
  
  if mono_ui then
    local lv = math.floor(math.max(r, g, b) / 17)
    if lv < 4 and (r > 0 or g > 0 or b > 0) then lv = 4 end
    r = lv * 17; g = lv * 17; b = lv * 17
  end

  local i = spx_offset + (y - 1) * W + x
  if P_R[i] == r and P_G[i] == g and P_B[i] == b then return end
  P_R[i]=r; P_G[i]=g; P_B[i]=b
  if grid_led_rgb then
    grid_led_rgb(x, y, r, g, b)
  else
    local lv = math.floor(math.max(r, g, b) / 17)
    if lv < 4 and (r > 0 or g > 0 or b > 0) then lv = 4 end
    grid_led(x, y, lv)
  end
end

-- ===========================================================================
-- SHARED DRAW HELPERS
-- ===========================================================================
local function draw_ctrl_buttons(view_name)
  spx(ALT_X,  ALT_Y,  cur_screen=="live" and 22 or 80, cur_screen=="live" and 22 or 80, cur_screen=="live" and 22 or 80)
  if view_name == "live" then
    if seq_running then spx(PLAY_X, PLAY_Y, 16, 170, 55)
    else                spx(PLAY_X, PLAY_Y, 170, 26, 16) end
    -- Freeze/hold button: cyan when frozen, dark when running free
    if freeze then spx(FREEZE_X, FREEZE_Y, 18, 200, 185)
    else           spx(FREEZE_X, FREEZE_Y, 8,  22,  18) end
  end
end

--- Draw one track row on the seq screen with option overlays + playhead.
-- tr = track table, ry = y row to draw on
local function draw_track_row(ry, tr)
  -- Base zone colors (surface vs underwater)
  local br = ry == Y_SURF and 0 or 0
  local bg = ry == Y_SURF and 12 or 6
  local bb = ry == Y_SURF and 26 or 20

  for x = 1, W do
    local r, g, b = br, bg, bb

    if seq_opt == 1 then   -- LOOP: highlight range, mark endpoints
      local start_step = math.min(tr.start_step, tr.end_step)
      local end_step = math.max(tr.start_step, tr.end_step)
      local in_loop = (x >= start_step and x <= end_step)
      if in_loop then r=r+14; g=g+10; b=b+6 end
      if x == tr.start_step then r=r+120; g=g+64; b=b end
      if x == tr.end_step   then r=r+155; g=g+96; b=b end
    elseif seq_opt == 2 then   -- DIV: x=1..6 selectors
      if x <= 6 then
        if x == tr.div then r=155; g=45; b=175 else r=26; g=8; b=32 end
      end
    elseif seq_opt == 3 then   -- CH: x=1..16 selectors
      if x <= 16 then
        if x == tr.ch then r=185; g=105; b=18 else r=32; g=18; b=6 end
      end
    elseif seq_opt == 4 then   -- OCT: x=1..8 offsets (-4 to +3)
      if x <= 8 then
        local off = x - 5
        local start_o = math.min(tr.oct_min, tr.oct_max)
        local end_o = math.max(tr.oct_min, tr.oct_max)
        local in_range = (off >= start_o and off <= end_o)
        if in_range then r=r+22; g=g+42; b=b+125 end
        if off == tr.oct_min then r=r+42; g=g+64; b=245 end
        if off == tr.oct_max then r=r+62; g=g+96; b=245 end
      end
    end

    -- Playhead flash (orange)
    if seq_running and x == tr.step then
      r=math.min(255,r+100); g=math.min(255,g+68); b=math.min(255,b+6)
    end

    spx(x, ry, r, g, b)
  end
end

-- ===========================================================================
-- DRAW: LIVE
-- ===========================================================================
local function draw_live()
  spx_offset = 0
  if supports_multi_screen then grid_set_screen("live") end

  for y = 1, H do
    for x = 1, W do
      local i = gidx(x, y)
      local t = GTYPE[i]
      local r, g, b = 0, 0, 0

      -- Zone tints
      if y == Y_SURF then r,g,b = 0,12,26
      elseif y == Y_MID  then r,g,b = 0,8,22
      elseif y == Y_DEEP then r,g,b = 0,5,18
      elseif y == Y_MUD  then 
        r,g,b = 14,9,4
        -- Mud density feedback
        if triop_strength > 0 then
          local base = (triop_strength == 1) and 12 or 28
          r=math.min(255, r+base); g=math.min(255, g+math.floor(base*0.8)); b=math.min(255, b+math.floor(base*0.4))
          
          if triop_auto_spawn then
            local p = math.floor(35 * (triop_spawn_t / TRIOP_INT))
            r=math.min(255, r+p); g=math.min(255, g+p); b=math.min(255, b+math.floor(p*0.5))
          end
        end
      end

      -- Sequencer playheads
      if seq_running then
        if y == Y_SURF and x == t1.step and x >= t1.start_step and x <= t1.end_step then
          r=math.min(255,r+22); g=math.min(255,g+16); b=math.min(255,b+6)
        elseif y == Y_MID and x == t2.step and x >= t2.start_step and x <= t2.end_step then
          r=math.min(255,r+8); g=math.min(255,g+22); b=math.min(255,b+40)
        elseif y == Y_DEEP and x == t3.step and x >= t3.start_step and x <= t3.end_step then
          r=math.min(255,r+5); g=math.min(255,g+12); b=math.min(255,b+55)
        end
      end

      -- Wind button indicators at y=2
      if y == Y_AIR1 and (x <= WIND_L_MAX or x >= WIND_R_MIN) then
        local lit = (WIND_DIR==1 and x<=WIND_L_MAX) or (WIND_DIR==-1 and x>=WIND_R_MIN)
        -- Only show if no leaf covering the spot
        if t == T_EMPTY then
          r=lit and 55 or 8; g=lit and 55 or 8; b=lit and 110 or 18
        end
      end

      -- Leaf rendering
      if t == T_CANOPY then
        local c = SEASONS[season][GCOL[i]]
        r=math.floor(c.r*0.80); g=math.floor(c.g*0.80); b=math.floor(c.b*0.80)
      elseif t == T_AIR then
        local c = SEASONS[season][GCOL[i]]
        r=c.r; g=c.g; b=c.b
      elseif t == T_SURFACE then
        local c = SEASONS[season][GCOL[i]]
        r=math.floor(c.r*0.60+14); g=math.floor(c.g*0.60+16); b=math.floor(c.b*0.50+52)
      elseif t == T_UNDER then
        local c = SEASONS[season][GCOL[i]]
        -- Slightly different tint at MID vs DEEP rows
        local df = y == Y_MID and 0.28 or 0.18
        r=math.floor(c.r*df+8); g=math.floor(c.g*(df+0.08)+10); b=math.floor(c.b*(df-0.02)+52)
      elseif t == T_MUD then
        local c = SEASONS[season][GCOL[i]]
        r=math.floor(c.r*0.12+14); g=math.floor(c.g*0.12+9); b=math.floor(c.b*0.07+3)
      end

      spx(x, y, r, g, b)
    end
  end

  -- Triops (amber)
  for i = 1, MAX_TR do
    local tr = TR[i]
    if tr.active then
      local b = tr.blink and 255 or 140
      spx(tr.x, tr.y, b, math.floor(b*0.55), 18)
    end
  end

  draw_ctrl_buttons("live")
  draw_hud()
end

-- ===========================================================================
-- DRAW: SEQ
-- ===========================================================================
local function draw_seq()
  spx_offset = supports_multi_screen and (W*H) or 0
  if supports_multi_screen then grid_set_screen("seq") end
  for y = 1, H do for x = 1, W do spx(x, y, 0, 0, 0) end end

  -- Row 1: Track Selectors (LEN, DIV, CH, OCT) at x=1..4
  for x = 1, 4 do
    local on = (x == seq_opt)
    local v  = on and 1.0 or 0.12
    local oc = SEQ_OPT_COLORS[x]
    spx(x, 1, math.floor(oc[1]*v), math.floor(oc[2]*v), math.floor(oc[3]*v))
  end

  -- Row 2: BPM (x=1..4)
  for x = 1, 4 do
    local c = (x == 1 or x == 4) and BPM_COL_HI or BPM_COL_MID
    spx(x, 2, c[1], c[2], c[3])
  end

  -- Row 3: Wind Str (x=1..3) and Density (x=5..8)
  for x = 1, 3 do
    local on = (x == WIND_STR)
    local v = on and 1.0 or 0.12
    spx(x, 3, math.floor(100*v), math.floor(140*v), math.floor(200*v))
  end
  for x = 0, 3 do
    local on = (x == grow_density)
    local v = on and 1.0 or 0.12
    if x == 0 then
      spx(x+5, 3, math.floor(60*v), math.floor(60*v), math.floor(60*v))
    else
      spx(x+5, 3, math.floor(32*v), math.floor(185*v), math.floor(100*v))
    end
  end

  -- Row 4: Humanize (x=1..3) and Triops (x=5)
  for x = 1, 3 do
    local on = (x-1 == humanize_level)
    local v = on and 1.0 or 0.12
    spx(x, 4, math.floor(200*v), math.floor(160*v), math.floor(40*v))
  end
  spx(5, 4, triop_strength==2 and 255 or (triop_strength==1 and 160 or 40), 120, 20)

  -- y=5,6,7: Tracks at their live y positions
  draw_track_row(Y_SURF, t1)
  draw_track_row(Y_MID,  t2)
  draw_track_row(Y_DEEP, t3)

  -- y=8: Mud reference — static tint; no live GTYPE read on the settings screen
  for x = 1, W do spx(x, Y_MUD, 14, 9, 4) end

  draw_ctrl_buttons("seq")
  draw_hud()
end

-- ===========================================================================
-- DRAW: SCALE
-- ===========================================================================
local function draw_scale()
  spx_offset = supports_multi_screen and (W*H*2) or 0
  if supports_multi_screen then grid_set_screen("scale") end
  for y = 1, H do for x = 1, W do spx(x, y, 0, 0, 0) end end

  -- y=1: Scales Row 1 (MAJ, MIN, PMA, PMI, DOR, LYD, CUS) x=1..7
  for x = 1, 7 do
    local on = (x == scale_mode)
    spx(x, 1, on and 212 or 36, on and 192 or 32, on and 42 or 8)
  end

  -- y=3: Black keys Row 3 (0 X X 0 X X X) x=1..7
  for x = 1, 7 do
    local s = SCALE_BLK_KEYS[x]
    if s >= 0 then
      local is_root, is_active = false, false
      if scale_mode == 7 then is_active = custom_scale[s+1]
      else
        is_root = (s == root_note)
        for i=1,SCALE_LEN do if (SCALE[i] % 12) == s then is_active = true break end end
      end
      if is_root then spx(x, 3, 16, 112, 242)
      elseif is_active then spx(x, 3, 200, 200, 200)
      else spx(x, 3, 16, 16, 36) end
    end
  end

  -- y=4: White keys Row 4 x=1..7
  for x = 1, 7 do
    local s = KB_WHITE[x]
    local is_root, is_active = false, false
    if scale_mode == 7 then is_active = custom_scale[s+1]
    else
      is_root = (s == root_note)
      for i=1,SCALE_LEN do if (SCALE[i] % 12) == s then is_active = true break end end
    end
    if is_root then spx(x, 4, 16, 132, 242)
    elseif is_active then spx(x, 4, 200, 200, 200)
    else spx(x, 4, 52, 52, 72) end
  end

  -- Row 6: Octaves x=1..4
  for x = 1, 4 do
    local on = (x+1 == oct_base)
    spx(x, 6, on and 72 or 10, on and 72 or 10, on and 232 or 36)
  end

  -- Row 7: Seasons x=1..4; Mono toggle x=6
  for x = 1, 4 do
    local on = (x == season)
    local c  = SCALE_SEA_DRAW[x]
    local v  = on and 1.0 or 0.15
    spx(x, 7, math.floor(c[1]*v), math.floor(c[2]*v), math.floor(c[3]*v))
  end
  -- Mono toggle
  spx(6, 7, mono_ui and 255 or 40, mono_ui and 255 or 40, mono_ui and 255 or 40)

  -- Row 8: Alt x=1; Dim x=3..5
  spx(1, 8, alt_on and 255 or 60, alt_on and 100 or 20, alt_on and 20 or 20)
  for x = 1, 3 do
    local on = (x-1 == dim_lvl)
    spx(x+2, 8, on and 200 or 50, on and 200 or 50, on and 200 or 50)
  end
  
  draw_hud()
end

-- ===========================================================================
-- REDRAW
-- ===========================================================================

local function redraw()
  if supports_multi_screen then
    -- Per-screen dirty flags: each screen only redraws when its own state changed.
    -- Live updates every physics tick; seq updates on step advance or input;
    -- scale updates only on user input. HUD and cycle events dirty all three.
    local any = false
    if is_dirty     then draw_live();  is_dirty     = false; any = true end
    if seq_dirty    then draw_seq();   seq_dirty    = false; any = true end
    if scale_dirty  then draw_scale(); scale_dirty  = false; any = true end
    if any then grid_refresh() end
  else
    if not is_dirty then return end
    if     cur_screen == "seq"   then draw_seq()
    elseif cur_screen == "scale" then draw_scale()
    else                              draw_live() end
    grid_refresh()
    is_dirty = false
  end
end

-- ===========================================================================
-- PHYSICS TICK
-- ===========================================================================

local release_cols = {}
for i = 1, W do release_cols[i] = 0 end  -- pre-size array part; prevents Lua resize on every canopy-release tick
local last_cc = -1

local function physics_tick()
  local phy_changed = false
  for i = 1, W * H do GMOVED[i] = false end

  -- ── Leaf physics (y=2..7; mud y=8 cogs here) ───────────────────────────
  for y = Y_DEEP, Y_AIR1, -1 do   -- bottom of deep water up to top of air
    for x = 1, W do
      local i = gidx(x, y)
      if GTYPE[i] ~= T_EMPTY and not GMOVED[i] then
        local t = GTYPE[i]
        
        -- Mud cogs: leaves in deep water have a chance to sink into mud (not during freeze)
        if not freeze and y == Y_DEEP and math.random(100) < 3 then
          local mi = gidx(x, Y_MUD)
          if GTYPE[mi] == T_EMPTY then
            GTYPE[mi] = T_MUD; GCOL[mi] = GCOL[i]
            GTYPE[i] = T_EMPTY; GCOL[i] = 1
            GMOVED[mi] = true; phy_changed = true
          end
        end

        local moved = false
        local fall_prob, drift_prob, wind_push_prob

        -- Freeze: water-zone leaves hold their position (air zone still active)
        local is_water_row = (y == Y_SURF or y == Y_MID or y == Y_DEEP)
        if freeze and is_water_row then
          -- Skip all movement for this leaf; sequencer still reads its position
          goto continue_leaf
        end

        if y <= Y_AIR2 then          -- air zone y=2..4
          fall_prob      = PROB_AIR
          drift_prob     = DRIFT_AIR
          wind_push_prob = WIND_DIR ~= 0 and WIND_PROB[WIND_STR] or 0
        elseif y == Y_SURF then      -- surface
          fall_prob      = PROB_SURF
          drift_prob     = DRIFT_SURF
          wind_push_prob = WIND_DIR ~= 0 and math.floor(WIND_PROB[WIND_STR]*0.38) or 0
        elseif y == Y_MID then       -- mid water
          fall_prob      = PROB_MID
          drift_prob     = DRIFT_MID
          wind_push_prob = WIND_DIR ~= 0 and math.floor(WIND_PROB[WIND_STR]*0.08) or 0
        else                         -- deep water y=7
          fall_prob      = PROB_DEEP
          drift_prob     = 0
          wind_push_prob = 0
        end

        -- 1. Wind push — horizontal AND occasionally upward in air
        if wind_push_prob > 0 and math.random(100) < wind_push_prob then
          -- 20% chance upward push (only in air zone, not at canopy ceiling)
          if y <= Y_AIR2 and y > Y_AIR1 and math.random(5) == 1 then
            local ny = y - 1   -- push up
            local ni = gidx(x, ny)
            if GTYPE[ni] == T_EMPTY then
              GTYPE[ni]=T_AIR; GCOL[ni]=GCOL[i]; GMOVED[ni]=true
              GTYPE[i]=T_EMPTY; GCOL[i]=1; moved=true; phy_changed=true
            end
          end
          -- Sideways push
          if not moved then
            local nx = x + WIND_DIR
            if nx >= 1 and nx <= W then
              local ni = gidx(nx, y)
              if GTYPE[ni] == T_EMPTY then
                GTYPE[ni]=t; GCOL[ni]=GCOL[i]; GMOVED[ni]=true
                GTYPE[i]=T_EMPTY; GCOL[i]=1; moved=true; phy_changed=true
              else
                -- Merge into neighbor (dominant note wins at sequencer)
                GTYPE[i]=T_EMPTY; GCOL[i]=1; moved=true; phy_changed=true
              end
            end
          end
        end

        -- 2. Passive brownian drift
        if not moved and drift_prob > 0 and math.random(100) < drift_prob then
          local dx = math.random(2)==1 and 1 or -1
          local nx = x + dx
          if nx >= 1 and nx <= W then
            local ni = gidx(nx, y)
            if GTYPE[ni] == T_EMPTY then
              GTYPE[ni]=t; GCOL[ni]=GCOL[i]; GMOVED[ni]=true
              GTYPE[i]=T_EMPTY; GCOL[i]=1; moved=true; phy_changed=true
            end
          end
        end

        -- 3. Gravity fall
        if not moved and math.random(100) < fall_prob then
          local ny = y + 1
          -- Freeze: prevent leaves from entering the water zone (tracks 1-3)
          if freeze and ny >= Y_SURF then
            -- Leave stays in air; no fall into water while frozen
          else
            local nt
            if ny == Y_SURF then nt = T_SURFACE
            elseif ny == Y_MID  then nt = T_UNDER
            elseif ny == Y_DEEP then nt = T_UNDER
            elseif ny == Y_MUD  then nt = T_MUD
            else                     nt = T_AIR end

            local ni = gidx(x, ny)
            if GTYPE[ni] == T_EMPTY then
              GTYPE[ni]=nt; GCOL[ni]=GCOL[i]; GMOVED[ni]=true
              GTYPE[i]=T_EMPTY; GCOL[i]=1; phy_changed=true
            elseif y <= Y_AIR2 then
              -- Blocked in air: try diagonal (only within air zone when frozen)
              local dx = math.random(2)==1 and 1 or -1
              local nx2 = x + dx
              if nx2 >= 1 and nx2 <= W then
                local ni2 = gidx(nx2, ny)
                if GTYPE[ni2] == T_EMPTY and not (freeze and ny >= Y_SURF) then
                  GTYPE[ni2]=nt; GCOL[ni2]=GCOL[i]; GMOVED[ni2]=true
                  GTYPE[i]=T_EMPTY; GCOL[i]=1; phy_changed=true
                end
              end
            end
          end
        end
        ::continue_leaf::
      end
    end
  end

  -- Mud layer: leaves slowly sink/decay and vanish
  for x = 1, W do
    local i = gidx(x, Y_MUD)
    if GTYPE[i] == T_MUD and math.random(100) < 4 then
      GTYPE[i] = T_EMPTY; GCOL[i] = 1; phy_changed = true
    end
  end

  -- ── Wind knocks canopy leaves loose ──────────────────────────────────────
  if WIND_DIR ~= 0 then
    local knock_prob = math.floor(WIND_PROB[WIND_STR] * 0.18)
    for x = 1, W do
      local ci = gidx(x, Y_CAN)
      if GTYPE[ci] == T_CANOPY and math.random(100) < knock_prob then
        -- Drop into first available air row
        for dy = Y_AIR1, Y_AIR2 do
          local di = gidx(x, dy)
          if GTYPE[di] == T_EMPTY then
            GTYPE[di]=T_AIR; GCOL[di]=GCOL[ci]
            GTYPE[ci]=T_EMPTY; GCOL[ci]=1
            phy_changed = true
            break
          end
        end
      end
    end
  end

  -- ── Triop lifecycle ───────────────────────────────────────────────────────
  if triop_strength > 0 then
    for i = 1, MAX_TR do
      local tr = TR[i]
      if tr.active then
        tr.timer = tr.timer - 1
        local prev_blink = tr.blink
        tr.blink = false
        if tr.timer <= 0 then
          if tr.state == TS_MUD_WAIT then
            tr.state = TS_RISING
            tr.timer = 3 -- rise speed
            tr.blink = true
          elseif tr.state == TS_RISING then
            tr.y = tr.y - 1
            tr.blink = true
            phy_changed = true  -- position changed
            -- Check for leaf to eat at or around new position
            local li = gidx(tr.x, tr.y)
            if GTYPE[li] ~= T_EMPTY then
              -- Trigger eating event: bass echo + soft upper octave unison
              local base_n = col_to_note(tr.x, -2, -2, -2) -- deep bass (MIDI ~36-48), strict clamp
              local hi_n   = col_to_note(tr.x, -1, -1, -1) -- one octave above bass, strict clamp
              local t_vol  = triop_strength == 1 and 40 or 75
              start_echo(base_n, tr.ch, t_vol)
              play_note(hi_n, math.floor(t_vol * 0.55), 4, tr.ch)  -- soft upper unison
              GTYPE[li] = T_EMPTY; GCOL[li] = 1
              tr.state = TS_SINKING
              tr.timer = 6 -- pause on eating
            elseif tr.y <= tr.peak_y then
              -- Reached peak without eating
              tr.state = TS_SINKING
              tr.timer = 3
            else
              tr.timer = 3 -- keep rising
            end
          elseif tr.state == TS_SINKING then
            tr.y = tr.y + 1
            tr.blink = true
            phy_changed = true  -- position changed
            if tr.y >= Y_MUD then
              tr.y = Y_MUD
              tr.active = false -- disappears
            else
              tr.timer = 4 -- sink speed
            end
          end
        end
        -- blink state change needs a redraw even without position change
        if tr.blink ~= prev_blink then phy_changed = true end
      end
    end

    -- Auto-spawn timer
    if triop_auto_spawn then
      triop_spawn_t = triop_spawn_t + 1
      if triop_spawn_t >= TRIOP_INT then
        triop_spawn_t = 0
        spawn_triop(math.random(W))
        phy_changed = true
      end
    end

  end
  
  -- ── MIDI CC Automation (Ramps) ──────────────────────────────────────────
  if season == 3 or season == 4 then -- Autumn/Winter variance
    cc_timer = cc_timer + 1
    if cc_timer > 30 then
      cc_timer = 0
      if season == 3 then -- Autumn: Slow, wide sweeps
        cc_target = math.random(40, 100); cc_slew = 0.04
      else               -- Winter: Faster, jittery drifts
        cc_target = math.random(20, 115); cc_slew = 0.12
      end
    end
    -- Slew: run every other tick to halve float-math cost; 3 Hz is still perceptually smooth
    if cc_timer % 2 == 0 then
      cc_val = cc_val + (cc_target - cc_val) * cc_slew
      local new_cc = math.floor(cc_val)
      if new_cc ~= last_cc then
        if midi_cc then midi_cc(CC_NUM, new_cc, 1) end
        last_cc = new_cc
      end
    end
  else
    -- Clean seasons: reset CC to 100
    if cc_val ~= 100 then
      cc_val = 100; cc_target = 100
      if midi_cc then midi_cc(CC_NUM, 100, 1) end
      last_cc = 100
    end
  end


  tick_echo()

  -- ── Auto-grow and Auto-release canopy ────────────────────────────────────
  -- grow_density: 0=off, 1=sparse, 2=medium, 3=busy
  auto_grow = grow_density > 0
  if auto_grow then
    grow_timer = grow_timer + 1
    if grow_timer >= GROW_INT[grow_density + 1] then  -- +1: Lua 1-indexed
      grow_timer = 0
      local tries = 5
      while tries > 0 do
        local cx = math.random(W)
        local ci = gidx(cx, Y_CAN)
        if GTYPE[ci] == T_EMPTY then
          GTYPE[ci]=T_CANOPY; GCOL[ci]=math.random(2)
          phy_changed = true; break
        end
        tries = tries - 1
      end
    end
    -- Auto-release: chance per density
    local rp = RELEASE_PROB[grow_density + 1]  -- +1: Lua 1-indexed
    if rp > 0 and math.random(100) <= rp then
      local c_idx = 0
      for rx=1,W do
        if GTYPE[gidx(rx, Y_CAN)] == T_CANOPY then
          c_idx = c_idx + 1
          release_cols[c_idx] = rx
        end
      end
      if c_idx > 0 then
        local dx = release_cols[math.random(c_idx)]
        local ci = gidx(dx, Y_CAN)
        for dy = Y_AIR1, Y_AIR2 do
          local di = gidx(dx, dy)
          if GTYPE[di] == T_EMPTY then
            GTYPE[di]=T_AIR; GCOL[di]=GCOL[ci]
            GTYPE[ci]=T_EMPTY; GCOL[ci]=1
            phy_changed = true
            break
          end
        end
      end
    end
  end

  -- ── Wind timer decay ─────────────────────────────────────────────────────
  if WIND_TIMER > 0 then
    WIND_TIMER = WIND_TIMER - 1
    if WIND_TIMER == 0 then WIND_DIR = 0; phy_changed = true end
  end

  if hud_timer > 0 then
    hud_timer = hud_timer - 1
    -- HUD appears on all screens; dirty all three when it expires so it clears everywhere
    if hud_timer == 0 then phy_changed = true; seq_dirty = true; scale_dirty = true end
  end

  if phy_changed then is_dirty = true end
  redraw()
end

-- ===========================================================================
-- NOTE TRIGGERING
-- ===========================================================================

local function trigger_water_note(ti, x)
  local tr = TRACKS[ti]

  -- Pick random octave in range as the base offset
  local o_min = math.min(tr.oct_min, tr.oct_max)
  local o_max = math.max(tr.oct_min, tr.oct_max)
  local oct_off = (o_min == o_max) and o_min or math.random(o_min, o_max)

  -- Season-based Note Character
  local v_base = 82 - ti * 14
  local dur = 3 + ti
  local s = season
  
  if s == 1 then -- Spring: short energetic
    dur = math.random(1, 2); v_base = v_base + 22
  elseif s == 2 then -- Summer: long energetic
    dur = math.random(12, 24); v_base = v_base + 18
  elseif s == 3 then -- Autumn: short low/energetic, chords
    dur = math.random(1, 4); v_base = v_base + math.random(-35, 15)
    -- Potential Chords (25% chance)
    if math.random(100) < 25 then
      local off = (math.random(2) == 1) and 2 or 4 -- third or fifth degree
      play_note(col_to_note(x + off, oct_off, o_min, o_max), v_base - 10, dur, tr.ch)
    end
  elseif s == 4 then -- Winter: long and short, potential echoes
    dur = math.random(1, 14); v_base = v_base - 12
    -- Potential Echoes (15% chance)
    if math.random(100) < 15 then
      start_echo(col_to_note(x, oct_off, o_min, o_max), tr.ch, v_base - 20)
    end
  end

  play_note(col_to_note(x, oct_off, o_min, o_max), math.random(v_base-12, v_base+10), dur, tr.ch)
end

-- ===========================================================================
-- SEQUENCER TICK
-- ===========================================================================
local m_seq   -- forward-declared

local function seq_tick()
  tick_notes()
  if not seq_running then return end
  beat_count = (beat_count + 1) % 65536  -- cap to prevent unbounded integer growth

  for ti = 1, 3 do
    local tr = TRACKS[ti]
    tr.accum = tr.accum + DIV_MULT[tr.div]
    local safety = 0
    while tr.accum >= 1.0 and safety < 16 do
      tr.accum = tr.accum - 1.0
      safety = safety + 1
      local ii = gidx(tr.step, tr.y)
      if GTYPE[ii] ~= T_EMPTY then
        trigger_water_note(ti, tr.step)
      end
      advance_track(tr)
    end
  end

  is_dirty = true; seq_dirty = true  -- playhead advanced on both live and seq screens
end

-- ===========================================================================
-- INPUT HANDLER
-- ===========================================================================

--- Handle seq-screen track tap for a given track based on current option.
local function seq_track_tap(tr, x)
  if seq_opt == 1 then   -- LOOP (also sets DIR implicitly)
    if tr.loop_input == 0 then
      tr.start_input = x; tr.loop_input = 1
      tr.start_step = x; tr.end_step = x; tr.dir = 1 -- Immediate 1-step loop
    else
      local start_x = tr.start_input
      local end_x = x
      if start_x <= end_x then
        tr.start_step = start_x; tr.end_step = end_x; tr.dir = 1
      else
        tr.start_step = end_x; tr.end_step = start_x; tr.dir = -1
      end
      tr.loop_input = 0
    end
    -- HUD numbers removed per user feedback
    
    -- ensure current step remains within bounds
    if tr.step < tr.start_step or tr.step > tr.end_step then
      tr.step = (tr.dir == 1) and tr.start_step or tr.end_step
    end
  elseif seq_opt == 2 and x <= 6 then  -- DIV
    tr.div = x
    local divs = {32, 16, 8, 4, 2, 1}
    show_hud("DIV", divs[x], 155, 45, 175)
  elseif seq_opt == 3 and x <= 16 then  -- CH
    tr.ch = x
    show_hud("CH", x, 185, 105, 18)
  elseif seq_opt == 4 and x <= 8 then  -- OCT Offset (-4 to +3)
    local off = x - 5
    if tr.oct_input == 0 then
      tr.oct_start_input = off; tr.oct_input = 1
      tr.oct_min = off; tr.oct_max = off
    else
      tr.oct_min = tr.oct_start_input; tr.oct_max = off
      tr.oct_input = 0
    end
    show_hud("OCT", off >= 0 and ("+" .. off) or off, 55, 100, 245)
  end
end

function event_grid(x, y, z)
  local screen = get_focused_screen and get_focused_screen() or "live"

  -- ALT: cycle screens on press
  if x == ALT_X and y == ALT_Y then
    if z == 1 then cycle_screen(); is_dirty = true end
    return
  end

  if z == 0 then return end

  local active_screen = supports_multi_screen and screen or cur_screen

  -- PLAY/STOP (Only Live View)
  if x == PLAY_X and y == PLAY_Y and active_screen == "live" then
    seq_running = not seq_running
    if not seq_running then
      notes_off(); echo_off()
      for ti = 1, 3 do TRACKS[ti].accum = 0 end
    end
    is_dirty = true; seq_dirty = true; return  -- running state reflected on both screens
  end
  
  -- GLOBAL: ALT SWITCH (Bottom-left in some views, but defined explicitly in Scale)
  -- We'll handle Alt specifically per page if needed, but the user requested y=8,x=1 in scale.

  -- ── SEQ SCREEN ───────────────────────────────────────────────────────────
  if active_screen == "seq" then
    -- Row 1: Selectors (1-4)
    if y == 1 then
      if x >= 1 and x <= 4 then
        seq_opt = x
        for ti = 1, 3 do TRACKS[ti].loop_input = 0; TRACKS[ti].oct_input = 0 end
        local lbls = {"LEN", "DIV", "CH", "OCT"}
        show_hud(lbls[x], "", 160, 160, 160)
      end
    -- Row 2: BPM (1-4)
    elseif y == 2 then
      if x >= 1 and x <= 4 then
        if     x==1 then bpm=math.max(20,bpm-10)
        elseif x==2 then bpm=math.max(20,bpm-1)
        elseif x==3 then bpm=math.min(200,bpm+1)
        elseif x==4 then bpm=math.min(200,bpm+10)
        end
        if m_seq then m_seq:stop(); m_seq:start(get_interval()) end
        show_hud("", bpm, 192, 112, 16)
      end
    -- Row 3: Wind (1-3) and Density (5-8)
    elseif y == 3 then
      if x >= 1 and x <= 3 then
        WIND_STR = x
        show_hud("WN" .. WIND_STR, "", 100, 140, 200)
      elseif x >= 5 and x <= 8 then
        local new_d = x - 5  -- 0, 1, 2, 3
        if new_d == grow_density then grow_density = 0 else grow_density = new_d end
        local lbl = grow_density == 0 and "DE0" or ("DE" .. grow_density)
        show_hud(lbl, "", grow_density == 0 and 60 or 32, grow_density == 0 and 60 or 185, grow_density == 0 and 60 or 100)
      end
    -- Row 4: Humanize (1-3) and Triops (5)
    elseif y == 4 then
      if x >= 1 and x <= 3 then
        humanize_level = x - 1 -- 0, 1, 2
        show_hud("HU" .. humanize_level, "", 200, 160, 40)
      elseif x == 5 then
        if triop_strength == 0 then triop_strength = 1; triop_auto_spawn = true
        elseif triop_strength == 1 then triop_strength = 2; triop_auto_spawn = true
        else triop_strength = 0; triop_auto_spawn = false end
        show_hud("TS" .. triop_strength, "", 220, 140, 20)
      end
    -- Tracks y=5,6,7
    elseif y == Y_SURF then seq_track_tap(t1, x)
    elseif y == Y_MID  then seq_track_tap(t2, x)
    elseif y == Y_DEEP then seq_track_tap(t3, x)
    end
    seq_dirty = true; is_dirty = true; return
  end

  -- ── SCALE SCREEN ─────────────────────────────────────────────────────────
  if active_screen == "scale" then
    -- Row 1: Scale selector
    if y == 1 then
      if x >= 1 and x <= 7 then 
        scale_mode = x
        local names = {"MAJ", "MIN", "PMA", "PMI", "DOR", "LYD", "CUS"}
        show_hud(names[scale_mode], "", 212, 192, 42)
        gen_scale() 
      end
    -- Row 3: Black Keys
    elseif y == 3 then
      if x >= 1 and x <= 7 then
        local s = SCALE_BLK_KEYS[x]
        if s >= 0 then
          if scale_mode == 7 then custom_scale[s+1] = not custom_scale[s+1]
          else root_note = s end
          gen_scale()
        end
      end
    -- Row 4: White Keys
    elseif y == 4 then
      if x >= 1 and x <= 7 then
        local s = KB_WHITE[x]
        if scale_mode == 7 then custom_scale[s+1] = not custom_scale[s+1]
        else root_note = s end
        gen_scale()
      end
    -- Row 6: Octaves
    elseif y == 6 then
      if x >= 1 and x <= 4 then
        oct_base = x + 1
        show_hud("OC" .. x, "", 72, 72, 232)
      end
    -- Row 7: Seasons and Mono
    elseif y == 7 then
      if x >= 1 and x <= 4 then
        season = x
        local snames = {"SP", "SU", "AU", "WI"}
        show_hud(snames[season], "", 150, 200, 50)
      elseif x == 6 then
        mono_ui = not mono_ui
        show_hud(mono_ui and "MON" or "COL", "", 240, 240, 240)
      end
    -- Row 8: Alt and Dim
    elseif y == 8 then
      if x == 1 then
        alt_on = not alt_on
      elseif x >= 3 and x <= 5 then
        dim_lvl = x - 3
        dim_f = DIM_VALS[dim_lvl+1]
        local dv = {32, 128, 255}
        if grid_brightness then grid_brightness(dv[dim_lvl+1]) end
        show_hud("DIM", "", 200, 200, 200)
      end
    end
    scale_dirty = true; is_dirty = true; return
  end

  -- ── LIVE SCREEN ──────────────────────────────────────────────────────────
  -- Freeze/Hold (Only Live View) — freezes water-zone leaves in place, seqr keeps running
  if x == FREEZE_X and y == FREEZE_Y and active_screen == "live" then
    freeze = not freeze
    show_hud(freeze and "HLD" or "RUN", "", freeze and 18 or 80, freeze and 200 or 200, freeze and 185 or 80)
    is_dirty = true; return
  end

  -- Wind buttons at y=2 (top of air zone)
  if y == Y_AIR1 and (x <= WIND_L_MAX or x >= WIND_R_MIN) then
    WIND_DIR   = x <= WIND_L_MAX and 1 or -1
    local str = (x <= WIND_L_MAX) and x or (17 - x)
    WIND_STR = str
    WIND_TIMER = WIND_TICKS[WIND_STR]
    is_dirty   = true; return
  end

  -- Canopy tap: knock loose or plant
  if y == Y_CAN then
    local ci = gidx(x, y)
    if GTYPE[ci] == T_CANOPY then
      for dy = Y_AIR1, Y_AIR2 do
        local di = gidx(x, dy)
        if GTYPE[di] == T_EMPTY then
          GTYPE[di]=T_AIR; GCOL[di]=GCOL[ci]; break
        end
      end
      GTYPE[ci]=T_EMPTY; GCOL[ci]=1
    else
      GTYPE[ci]=T_CANOPY; GCOL[ci]=math.random(2)
    end
    is_dirty = true; return
  end

  -- Mud tap: trigger new triop flash
  if y == Y_MUD then
    spawn_triop(x)
    is_dirty = true; return
  end

  -- Water note tap (Only Live View)
  if active_screen == "live" and y >= Y_SURF and y <= Y_DEEP then
    if GTYPE[gidx(x, y)] ~= T_EMPTY then
      local ti = y - Y_SURF + 1
      trigger_water_note(ti, x)
    end
    is_dirty = true; return
  end
end

-- ===========================================================================
-- KEYBOARD (BPM via 1/2/3/4 keys)
-- ===========================================================================
function event_key(key)
  if     key=="1" then bpm=math.max(20,bpm-10); if m_seq then m_seq:stop(); m_seq:start(get_interval()) end; show_hud("BPM", bpm, 192, 112, 16)
  elseif key=="2" then bpm=math.max(20,bpm-1);  if m_seq then m_seq:stop(); m_seq:start(get_interval()) end; show_hud("BPM", bpm, 192, 112, 16)
  elseif key=="3" then bpm=math.min(200,bpm+1); if m_seq then m_seq:stop(); m_seq:start(get_interval()) end; show_hud("BPM", bpm, 192, 112, 16)
  elseif key=="4" then bpm=math.min(200,bpm+10);if m_seq then m_seq:stop(); m_seq:start(get_interval()) end; show_hud("BPM", bpm, 192, 112, 16)
  end
end

-- ===========================================================================
-- METRO CLOCKS
-- ===========================================================================
local m_phys = metro.init(physics_tick, PHYS_INT)
m_phys:start()

m_seq = metro.init(seq_tick, get_interval())
m_seq:start()

-- ===========================================================================
-- INIT — seed canopy and a couple of triops
-- ===========================================================================
local seed_cols = {3, 6, 8, 11, 14}
for i = 1, #seed_cols do
  local ci = gidx(seed_cols[i], Y_CAN)
  GTYPE[ci]=T_CANOPY; GCOL[ci]=math.random(2)
end

spawn_triop(4)
spawn_triop(11)

redraw()
