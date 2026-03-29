-- serpentine.lua ─────────────────────────────────────────────────────────
-- Snake sequencer for NeoTrellis iii  (16×8 grid, Pico)
--
-- HOW TO PLAY
--   Press any pad  →  steers snake toward that pad (dominant axis)
--   D-pad (bottom-right)  →  direct cardinal direction:
--               (15,7) = ^
--       (14,8) = <   (15,8) = v   (16,8) = >
--   Wraps at edges — no walls
--   Self-collision →  wipe animation → respawn  (sequencer keeps playing)
--
-- DEATH ANIMATION
--   A light-orange bar sweeps left→right wiping the screen dark,
--   sounding a note for each column it passes (ascending glissando).
--   Snake respawns; a second bar sweeps left→right revealing the new state.
--
-- MUSIC
--   Every fruit eaten records the grid cell as a MIDI note
--   Notes play back in a looping sequence, tempo follows game speed
--   Cyan fruits add an arpeggio chord + leave a permanent dim halo ring
--
-- FRUIT COLOURS / EFFECTS
--   Red      →  note (upper pitch zone)
--   Blue     →  note (lower pitch zone)
--   Yellow   →  note  +  slight tempo increase
--   Cyan     →  chord note (root + maj3 + P5)  +  visible halo
--   Magenta  →  note  +  instant direction reversal (chaos)
--
-- ALT MODE  (hold pad 1,8 — bottom-left corner)
--   (8,4)  lime   ▲  →  FASTER
--   (8,6)  coral  ▼  →  SLOWER
--   (7,5)  blue   ◄  →  fewer fruits   (teal bar row 3 shows count)
--   (9,5)  blue   ►  →  more fruits
--   (15,5) toggle    →  3-color auto mode:
--                          dim-red  = off (manual)
--                          amber    = auto-fetch (tap target on grid)
--                          green    = full-auto (snake hunts on its own)
--   Amber bar row 2  →  current speed
--   Teal  bar row 3  →  current fruit count
--
-- AUTO MODES  (zero heap allocation per tick)
--   auto-fetch  →  tap any pad to set a target; snake BFS-navigates there
--   full-auto   →  snake hunts nearest reachable fruit automatically
-- ─────────────────────────────────────────────────────────────────────────

local W, H   = 16, 8
local ALT_X  = 1
local ALT_Y  = 8

-- ── Arrow D-pad (bottom-right)  ^(15,7)  <(14,8)  v(15,8)  >(16,8) ──────
local DPAD = {
  {x=15, y=7,  dx=0,  dy=-1},  -- up
  {x=14, y=8,  dx=-1, dy=0 },  -- left
  {x=15, y=8,  dx=0,  dy=1 },  -- down
  {x=16, y=8,  dx=1,  dy=0 },  -- right
}

-- ── Food count (mutable) ──────────────────────────────────────────────────
local num_fruits  = 3
local NUM_FRU_MIN = 1
local NUM_FRU_MAX = 8

-- ── Auto mode  0=manual  1=auto-fetch  2=full-auto ────────────────────────
local auto_mode      = 0
-- Pre-allocated target (no heap alloc per tap)
local auto_target    = {x=0, y=0}
local auto_has_target = false

-- ── Fruit colours  (r,g,b  in 0..255) ───────────────────────────────────
local FRUIT_COL = {
  {r=220, g=80,  b=50 },
  {r=125, g=90,  b=200},
  {r=225, g=155, b=22 },
  {r=40,  g=178, b=130},
  {r=205, g=62,  b=115},
}
local FRUIT_W = {40, 25, 15, 12, 8}   -- must sum to 100

-- ── Scale: pentatonic major  (semitones from root) ───────────────────────
local SCALE = {0, 2, 4, 7, 9}
local BASE  = 48   -- C3

-- ── Snake ring buffer ────────────────────────────────────────────────────
-- Pre-allocate W*H segment tables once at load; push/pop via pointer math.
-- head insertion = pointer decrement + field mutate  (zero allocation)
-- tail removal   = length decrement                  (zero allocation)
local SNAKE_MAX = W * H   -- 128
local SNAKE_BUF = {}
for i = 1, SNAKE_MAX do SNAKE_BUF[i] = {x=0, y=0} end
local snake_head = 1   -- SNAKE_BUF index of current head
local snake_len  = 0   -- current live length
local snk_len    = 4   -- target length (grows on eat)

-- O(1) ring-indexed access: snk(1)=head … snk(snake_len)=tail
local function snk(i) return SNAKE_BUF[(snake_head + i - 2) % SNAKE_MAX + 1] end

-- ── Direction ─────────────────────────────────────────────────────────────
local dir    = {x=1, y=0}    -- always mutated in-place
local queued = {x=1, y=0}    -- always mutated in-place

-- ── Death wipe state ──────────────────────────────────────────────────────
local death_phase = 0   -- 0=alive  1=wipe-out  2=wipe-in
local death_col   = 1
local DEATH_SPD   = 0.08   -- seconds per column

-- ── Fruits ────────────────────────────────────────────────────────────────
local fruits = {}

-- ── Sequencer ─────────────────────────────────────────────────────────────
local seq         = {}
local seq_i       = 1
local on_note     = nil
local on_chord    = false
local chord_notes = {0, 0, 0}   -- pre-allocated; reused every chord event

-- ── Game speed ────────────────────────────────────────────────────────────
local spd     = 0.28
local SPD_MIN = 0.08
local SPD_MAX = 0.70

-- ── Alt mode ──────────────────────────────────────────────────────────────
local alt_held = false

local m_game, m_seq_m, m_death

-- ════════════════════════════════════════════════════════════════════════
-- PRE-ALLOCATED BFS STATE
-- All arrays are allocated once at module load and reused every call.
-- This keeps heap allocations per game tick at ZERO during auto modes.
-- ════════════════════════════════════════════════════════════════════════

local BFS_SZ = W * H          -- 128

-- BFS_S[k]: 0=free, 1-4=visited (first-dir index), 5=wall
local BFS_S = {}
-- BFS_Q[k]: integer cell-key queue
local BFS_Q = {}
-- BFS_T[k]: boolean target flags for multi-target (full-auto) BFS
local BFS_T = {}

for i = 1, BFS_SZ do BFS_S[i] = 0; BFS_Q[i] = 0; BFS_T[i] = false end

-- Cardinal direction tables (1=right 2=left 3=down 4=up)
local DIR_DX = {1, -1, 0,  0}
local DIR_DY = {0,  0, 1, -1}

-- bfs_run: first-step direction from snake head toward target(s).
-- use_tgt_flags=true  → uses BFS_T[] for multi-target (populate before call)
-- use_tgt_flags=false → uses scalar (tx,ty)
-- Returns direction index 1-4, or 0 if unreachable. Allocates: NOTHING.
local function bfs_run(use_tgt_flags, tx, ty)
  if snake_len == 0 then return 0 end
  local h  = snk(1)
  local sx, sy = h.x, h.y

  -- Clear visited state
  for i = 1, BFS_SZ do BFS_S[i] = 0 end

  -- Mark body as walls (skip tail tip — it vacates this tick)
  for i = 1, snake_len - 1 do
    local s = snk(i)
    BFS_S[(s.y - 1) * W + s.x] = 5
  end
  BFS_S[(sy - 1) * W + sx] = 5   -- head = visited

  local qi, qe = 1, 0
  for d = 1, 4 do
    local nx = wrap(sx + DIR_DX[d], 1, W)
    local ny = wrap(sy + DIR_DY[d], 1, H)
    local k  = (ny - 1) * W + nx
    if BFS_S[k] == 0 then
      BFS_S[k] = d; qe = qe + 1; BFS_Q[qe] = k
    end
  end

  local tk = (ty - 1) * W + tx   -- scalar target key (use_tgt_flags=false)

  while qi <= qe do
    local ck = BFS_Q[qi]; qi = qi + 1
    if use_tgt_flags then
      if BFS_T[ck] then return BFS_S[ck] end
    else
      if ck == tk then return BFS_S[ck] end
    end
    local cx = ((ck - 1) % W) + 1
    local cy = math.floor((ck - 1) / W) + 1
    local fd = BFS_S[ck]
    for d = 1, 4 do
      local nx = wrap(cx + DIR_DX[d], 1, W)
      local ny = wrap(cy + DIR_DY[d], 1, H)
      local k  = (ny - 1) * W + nx
      if BFS_S[k] == 0 then
        BFS_S[k] = fd; qe = qe + 1; BFS_Q[qe] = k
      end
    end
  end
  return 0
end

-- ════════════════════════════════════════════════════════════════════════
-- HELPERS
-- ════════════════════════════════════════════════════════════════════════

local function note_for(x, y)
  local deg     = ((x - 1) % #SCALE) + 1
  local col_oct = math.floor((x - 1) / #SCALE)
  local row_oct = math.floor((H - y) / 3)
  return BASE + SCALE[deg] + (col_oct + row_oct) * 12
end

local function spx(x, y, r, g, b)
  if x < 1 or x > W or y < 1 or y > H then return end
  if grid_led_rgb then
    grid_led_rgb(x, y, r, g, b)
  else
    grid_led(x, y, math.floor(math.max(r, g, b) / 17))
  end
end

local function clr() grid_led_all(0) end

-- ════════════════════════════════════════════════════════════════════════
-- DRAW
-- ════════════════════════════════════════════════════════════════════════

-- Draw full game state without clr() or grid_refresh() — used by wipe-in.
local function draw_scene_raw()
  for _, s in ipairs(seq) do
    if s.chord then
      for ddx = -1, 1 do for ddy = -1, 1 do
        if not (ddx==0 and ddy==0) then spx(s.sx+ddx, s.sy+ddy, 42, 35, 12) end
      end end
      spx(s.sx, s.sy, 18, 70, 52)
    end
  end

  if auto_has_target then spx(auto_target.x, auto_target.y, 200, 100, 15) end

  for _, f in ipairs(fruits) do
    local c = FRUIT_COL[f.kind]
    spx(f.x, f.y, c.r, c.g, c.b)
  end

  local n = snake_len
  for i = n, 2, -1 do
    local s      = snk(i)
    local bright = math.max(34, math.floor((1 - i/n) * 187) + 34)
    spx(s.x, s.y, math.floor(bright * 0.18), bright, 0)
  end
  if n > 0 then local h = snk(1); spx(h.x, h.y, 95, 210, 28) end

  if alt_held then spx(ALT_X, ALT_Y, 232, 112, 18)
  else             spx(ALT_X, ALT_Y, 50,  18,  5) end

  for _, a in ipairs(DPAD) do spx(a.x, a.y, 12, 12, 28) end
end

local function draw_game()
  clr()
  draw_scene_raw()
  grid_refresh()
end

local function draw_alt()
  clr()

  local slots  = 13
  local filled = clamp(
    math.floor((SPD_MAX - spd) / (SPD_MAX - SPD_MIN) * slots + 0.5),
    0, slots)
  for x = 2, 1 + filled do spx(x, 2, 168, 80, 10) end

  for x = 2, 1 + num_fruits do spx(x, 3, 20, 140, 110) end

  spx(8, 4, 58,  188, 18 )   -- ▲ FASTER
  spx(7, 5, 52,  62,  158)   -- ◄ fewer fruits
  spx(8, 5, 188, 168, 132)   -- ● centre
  spx(9, 5, 52,  62,  158)   -- ► more fruits
  spx(8, 6, 215, 48,  25 )   -- ▼ SLOWER

  if     auto_mode == 0 then spx(15, 5, 90,  18,  12)
  elseif auto_mode == 1 then spx(15, 5, 200, 120, 15)
  else                       spx(15, 5, 20,  200, 40) end

  spx(ALT_X, ALT_Y, 232, 112, 18)
  grid_refresh()
end

-- ════════════════════════════════════════════════════════════════════════
-- GAME LOGIC
-- ════════════════════════════════════════════════════════════════════════

local function is_dpad(x, y)
  for _, a in ipairs(DPAD) do
    if a.x==x and a.y==y then return true end
  end
  return false
end

local function occupied(x, y)
  for i = 1, snake_len do
    local s = snk(i)
    if s.x==x and s.y==y then return true end
  end
  for _, f in ipairs(fruits) do
    if f.x==x and f.y==y then return true end
  end
  return (x == ALT_X and y == ALT_Y) or is_dpad(x, y)
end

local function spawn_fruit()
  if #fruits >= num_fruits then return end
  for _ = 1, 100 do
    local x = math.random(W)
    local y = math.random(H)
    if not occupied(x, y) then
      local roll, acc, k = math.random(100), 0, #FRUIT_W
      for i, w in ipairs(FRUIT_W) do
        acc = acc + w
        if roll <= acc then k = i; break end
      end
      table.insert(fruits, {x=x, y=y, kind=k})
      return
    end
  end
end

local function reset_snake()
  -- Reuse SNAKE_BUF; just reset head pointer and fill first 4 slots in-place.
  snake_head = 1
  snake_len  = 4
  for i = 1, 4 do
    local s = SNAKE_BUF[(snake_head + i - 2) % SNAKE_MAX + 1]
    s.x = 10 - i   -- i=1→9, i=2→8, i=3→7, i=4→6
    s.y = 4
  end
  dir.x = 1;    dir.y = 0
  queued.x = 1; queued.y = 0
  snk_len          = 4
  auto_has_target  = false
end

-- ── Death wipe animation ──────────────────────────────────────────────────
local function death_tick()
  if death_phase == 1 then
    -- Phase 1: bar sweeps L→R, one note per column, screen goes dark
    if on_note then midi_note_off(on_note); on_note = nil end
    local note = note_for(death_col, 4)
    midi_note_on(note, 72)
    on_note = note

    clr()
    for y = 1, H do spx(death_col, y, 210, 90, 20) end
    grid_refresh()

    death_col = death_col + 1
    if death_col > W then
      if on_note then midi_note_off(on_note); on_note = nil end
      reset_snake()
      while #fruits < num_fruits do spawn_fruit() end
      death_phase = 2
      death_col   = 1
    end

  elseif death_phase == 2 then
    -- Phase 2: bar sweeps L→R revealing new game state
    clr()
    draw_scene_raw()
    -- Black out columns at and right of the bar
    for bx = death_col, W do
      for by = 1, H do spx(bx, by, 0, 0, 0) end
    end
    for y = 1, H do spx(death_col, y, 210, 90, 20) end
    grid_refresh()

    death_col = death_col + 1
    if death_col > W then
      death_phase = 0
      m_death:stop()
      m_seq_m:start(spd * 1.07)
      draw_game()
    end
  end
end

-- ── Sequencer tick ────────────────────────────────────────────────────────
local function seq_tick()
  if on_note then midi_note_off(on_note); on_note = nil end
  if on_chord then
    midi_note_off(chord_notes[1])
    midi_note_off(chord_notes[2])
    midi_note_off(chord_notes[3])
    on_chord = false
  end

  if #seq == 0 then return end
  local s = seq[seq_i]

  if s.chord then
    chord_notes[1] = s.note
    chord_notes[2] = s.note + 4
    chord_notes[3] = s.note + 7
    midi_note_on(chord_notes[1], 85)
    midi_note_on(chord_notes[2], 70)
    midi_note_on(chord_notes[3], 55)
    on_chord = true
  else
    midi_note_on(s.note, 95)
    on_note = s.note
  end

  seq_i = (seq_i % #seq) + 1
end

-- ── Game tick ─────────────────────────────────────────────────────────────
local function game_tick()
  if death_phase > 0 then return end
  if alt_held        then return end

  -- ── Auto-steering (zero heap allocations) ────────────────────────────
  if auto_mode == 2 then
    -- Multi-target BFS: find nearest reachable fruit in one pass
    for i = 1, BFS_SZ do BFS_T[i] = false end
    for _, f in ipairs(fruits) do
      BFS_T[(f.y - 1) * W + f.x] = true
    end
    local d = bfs_run(true, 0, 0)
    if d > 0 then queued.x = DIR_DX[d]; queued.y = DIR_DY[d] end

  elseif auto_mode == 1 and auto_has_target then
    local h = snk(1)
    if h.x == auto_target.x and h.y == auto_target.y then
      auto_has_target = false
    else
      local d = bfs_run(false, auto_target.x, auto_target.y)
      if d > 0 then queued.x = DIR_DX[d]; queued.y = DIR_DY[d] end
    end
  end

  -- Commit queued direction — no 180-degree reversals
  if not (queued.x == -dir.x and dir.x ~= 0) and
     not (queued.y == -dir.y and dir.y ~= 0) then
    dir.x = queued.x; dir.y = queued.y
  end

  local h  = snk(1)
  local hx = wrap(h.x + dir.x, 1, W)
  local hy = wrap(h.y + dir.y, 1, H)

  -- Self-collision (skip tail tip — it vacates this tick)
  for i = 1, snake_len - 1 do
    local s = snk(i)
    if s.x==hx and s.y==hy then
      death_phase = 1
      death_col   = 1
      m_seq_m:stop()
      m_death:start(DEATH_SPD)
      return
    end
  end

  -- Push new head into ring buffer (zero allocation — mutate pre-alloc cell)
  snake_head = (snake_head - 2) % SNAKE_MAX + 1
  local nh = SNAKE_BUF[snake_head]
  nh.x = hx; nh.y = hy
  snake_len = snake_len + 1

  -- Fruit collision
  for i, f in ipairs(fruits) do
    if f.x==hx and f.y==hy then
      table.remove(fruits, i)
      snk_len = snk_len + 3
      local note = note_for(hx, hy)
      local is_c = (f.kind == 4)
      table.insert(seq, {note=note, chord=is_c, sx=hx, sy=hy})

      if f.kind == 3 then
        spd = math.max(SPD_MIN, spd - 0.03)
        m_game:start(spd); m_seq_m:start(spd * 1.07)
      elseif f.kind == 5 then
        dir.x = -dir.x; dir.y = -dir.y
        queued.x = dir.x; queued.y = dir.y
      end
      spawn_fruit()
      break
    end
  end

  -- Trim tail (zero allocation — just decrement length)
  while snake_len > snk_len do snake_len = snake_len - 1 end

  draw_game()
end

-- ════════════════════════════════════════════════════════════════════════
-- INPUT
-- ════════════════════════════════════════════════════════════════════════

function event_grid(x, y, z)
  if x == ALT_X and y == ALT_Y then
    if z == 1 then alt_held = true;  draw_alt()
    else           alt_held = false; draw_game() end
    return
  end

  if z == 0 then return end

  -- D-pad: mutate queued in-place (no table allocation)
  for _, a in ipairs(DPAD) do
    if a.x==x and a.y==y then
      queued.x = a.dx; queued.y = a.dy
      if auto_mode == 1 then auto_has_target = false end
      return
    end
  end

  if alt_held then
    if     x==8 and y==4 then
      spd = math.max(SPD_MIN, spd - 0.04)
      m_game:start(spd); m_seq_m:start(spd * 1.07); draw_alt()
    elseif x==8 and y==6 then
      spd = math.min(SPD_MAX, spd + 0.04)
      m_game:start(spd); m_seq_m:start(spd * 1.07); draw_alt()
    elseif x==7 and y==5 then
      if num_fruits > NUM_FRU_MIN then num_fruits = num_fruits - 1 end
      draw_alt()
    elseif x==9 and y==5 then
      if num_fruits < NUM_FRU_MAX then num_fruits = num_fruits + 1; spawn_fruit() end
      draw_alt()
    elseif x==15 and y==5 then
      auto_mode = (auto_mode + 1) % 3
      if auto_mode ~= 1 then auto_has_target = false end
      draw_alt()
    end
    return
  end

  if snake_len == 0 then return end

  if auto_mode == 1 then
    -- Mutate pre-allocated target in-place (no table allocation)
    auto_target.x = x; auto_target.y = y
    auto_has_target = true
    return
  end

  -- Default: steer toward pressed pad (dominant axis), mutate queued in-place
  local h  = snk(1)
  local dx = x - h.x
  local dy = y - h.y
  if dx == 0 and dy == 0 then return end

  if math.abs(dx) >= math.abs(dy) then
    queued.x = (dx > 0) and 1 or -1; queued.y = 0
  else
    queued.x = 0; queued.y = (dy > 0) and 1 or -1
  end
end

-- ════════════════════════════════════════════════════════════════════════
-- STARTUP
-- ════════════════════════════════════════════════════════════════════════

math.randomseed(math.floor(get_time() * 1e6) % 999983)

reset_snake()
for _ = 1, num_fruits do spawn_fruit() end
draw_game()

m_game  = metro.init(game_tick,  spd)
m_seq_m = metro.init(seq_tick,   spd * 1.07)
m_death = metro.init(death_tick, DEATH_SPD)

m_game:start()
m_seq_m:start()
-- m_death only starts on self-collision
