Uploading leaveseqr.lua...
-- receiving data
-- script buffer full!
-- lua error:
[string "    elseif cur_screen == "scale" then dr
aw_sc..."]:1: <eof> expected near 'elseif'-- lua error:
[string "    else                              draw_li..."]:1: <eof> expected near 'else'-- lua error:
[string "  end"]:1: <eof> expected near 'end'-- lua error:
[string "end"]:1: <eof> expected near 'end'-- lua error:
[string "for i = 1, W do release_cols[i] = 0 end  -- p..."]:1: bad 'for' limit (number expected, got nil)-- lua error:
[string "local function physics_tick()"]:1: 'end' expected near <eof>-- lua error:
[string "  for i = 1, W * H do GMOVED[i] = false end"]:1: attempt to perform arithmetic on a nil value (global 'W')-- lua error:
[string "  for y = Y_DEEP, Y_AIR1, -1 do   -- bottom o..."]:1: 'end' expected near <eof>
-- lua error:
[string "    for x = 1, W do"]:1: 'end' expected near <eof>-- lua error:
[string "      local i = gidx(x, y)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "      if GTYPE[i] ~= T_EMPTY and not GMOVED[i..."]:1: 'end' expected near <eof>-- lua error:
[string "        local t = GTYPE[i]"]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "        if not freeze and y == Y_DEEP and mat..."]:1: 'end' expected near <eof>-- lua error:
[string "          local mi = gidx(x, Y_MUD)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "          if GTYPE[mi] == T_EMPTY then"]:1: 'end' expected near <eof>-- lua error:
[string "            GTYPE[mi] = T_MUD; GCOL[mi] = GCO..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "            GTYPE[i] = T_EMPTY; GCOL[i] = 1"]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "            GMOVED[mi] = true; phy_changed = ..."]:1: attempt to index a nil value (global 'GMOVED')-- lua error:
[string "          end"]:1: <eof> expected near 'end'-- lua error:
[string "        end"]:1: <eof> expected near 'end'-- lua error:
[string "        if freeze and is_water_row then"]:1: 'end' expected near <eof>-- lua error:
[string "          goto continue_leaf"]:1: no visible label 'continue_leaf' for <goto> at line 1-- lua error:
[string "        end"]:1: <eof> expected near 'end'-- lua error:
[string "        if y <= Y_AIR2 then          -- air z..."]:1: 'end' expected near <eof>-- lua error:
[string "          wind_push_prob = WIND_DIR ~= 0 and ..."]:1: attempt to index a nil value (global 'WIND_PROB')-- lua error:
[string "        elseif y == Y_SURF then      -- surfa..."]:1: <eof> expected near 'elseif'-- lua error:
[string "          wind_push_prob = WIND_DIR ~= 0 and ..."]:1: attempt to index a nil value (global 'WIND_PROB')-- lua error:
[string "        elseif y == Y_MID then       -- mid w..."]:1: <eof> expected near 'elseif'-- lua error:
[string "          wind_push_prob = WIND_DIR ~= 0 and ..."]:1: attempt to index a nil value (global 'WIND_PROB')-- lua error:
[string "        else                         -- deep ..."]:1: <eof> expected near 'else'-- lua error:
[string "        end"]:1: <eof> expected near 'end'-- lua error:
[string "        if wind_push_prob > 0 and math.random..."]:1: 'end' expected near <eof>
-- lua error:
[string "          if y <= Y_AIR2 and y > Y_AIR1 and m..."]:1: 'end' expected near <eof>-- lua error:
[string "            local ny = y - 1   -- push up"]:1: attempt to perform arithmetic on a nil value (global 'y')-- lua error:
[string "            local ni = gidx(x, ny)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "            if GTYPE[ni] == T_EMPTY then"]:1: 'end' expected near <eof>-- lua error:
[string "              GTYPE[ni]=T_AIR; GCOL[ni]=GCOL[..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "              GTYPE[i]=T_EMPTY; GCOL[i]=1; mo..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "            end"]:1: <eof> expected near 'end'-- lua error:
[string "          end"]:1: <eof> expected near 'end'-- lua error:
[string "          if not moved then"]:1: 'end' expected near <eof>-- lua error:
[string "            local nx = x + WIND_DIR"]:1: attempt to perform arithmetic on a nil value (global 'x')-- lua error:
[string "            if nx >= 1 and nx <= W then"]:1: 'end' expected near <eof>-- lua error:
[string "              local ni = gidx(nx, y)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "              if GTYPE[ni] == T_EMPTY then"]:1: 'end' expected near <eof>-- lua error:
[string "                GTYPE[ni]=t; GCOL[ni]=GCOL[i]..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "                GTYPE[i]=T_EMPTY; GCOL[i]=1; ..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "              else"]:1: <eof> expected near 'else'-- lua error:
[string "                GTYPE[i]=T_EMPTY; GCOL[i]=1; ..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "              end"]:1: <eof> expected near 'end'-- lua error:
[string "            end"]:1: <eof> expected near 'end'-- lua error:
[string "          end"]:1: <eof> expected near 'end'-- lua error:
[string "        end"]:1: <eof> expected near 'end'-- lua error:
[string "        if not moved and drift_prob > 0 and m..."]:1: 'end' expected near <eof>-- lua error:
[string "          local nx = x + dx"]:1: attempt to perform arithmetic on a nil value (global 'x')-- lua error:
[string "          if nx >= 1 and nx <= W then"]:1: 'end' expected near <eof>-- lua error:
[string "            local ni = gidx(nx, y)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "            if GTYPE[ni] == T_EMPTY then"]:1: 'end' expected near <eof>-- lua error:
[string "              GTYPE[ni]=t; GCOL[ni]=GCOL[i]; ..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "              GTYPE[i]=T_EMPTY; GCOL[i]=1; mo..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "            end"]:1: <eof> expected near 'end'-- lua error:
[string "          end"]:1: <eof> expected near 'end'-- lua error:
[string "        end"]:1: <eof> expected near 'end'-- lua error:
[string "        if not moved and math.random(100) < f..."]:1: 'end' expected near <eof>-- lua error:
[string "          local ny = y + 1"]:1: attempt to perform arithmetic on a nil value (global 'y')-- lua error:
[string "          if freeze and ny >= Y_SURF then"]:1: 'end' expected near <eof>-- lua error:
[string "          else"]:1: <eof> expected near 'else'-- lua error:
[string "            if ny == Y_SURF then nt = T_SURFA..."]:1: 'end' expected near <eof>-- lua error:
[string "            elseif ny == Y_MID  then nt = T_U..."]:1: <eof> expected near 'elseif'-- lua error:
[string "            elseif ny == Y_DEEP then nt = T_U..."]:1: <eof> expected near 'elseif'-- lua error:
[string "            elseif ny == Y_MUD  then nt = T_M..."]:1: <eof> expected near 'elseif'-- lua error:
[string "            else                     nt = T_A..."]:1: <eof> expected near 'else'-- lua error:
[string "            local ni = gidx(x, ny)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "            if GTYPE[ni] == T_EMPTY then"]:1: 'end' expec
ted near <eof>-- lua error:
[string "              GTYPE[ni]=nt; GCOL[ni]=GCOL[i];..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "              GTYPE[i]=T_EMPTY; GCOL[i]=1; ph..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "            elseif y <= Y_AIR2 then"]:1: <eof> expected near 'elseif'-- lua error:
[string "              local nx2 = x + dx"]:1: attempt to perform arithmetic on a nil value (global 'x')-- lua error:
[string "              if nx2 >= 1 and nx2 <= W then"]:1: 'end' expected near <eof>-- lua error:
[string "                local ni2 = gidx(nx2, ny)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "                if GTYPE[ni2] == T_EMPTY and ..."]:1: 'end' expected near <eof>-- lua error:
[string "                  GTYPE[ni2]=nt; GCOL[ni2]=GC..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "                  GTYPE[i]=T_EMPTY; GCOL[i]=1..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "                end"]:1: <eof> expected near 'end'-- lua error:
[string "              end"]:1: <eof> expected near 'end'-- lua error:
[string "            end"]:1: <eof> expected near 'end'-- lua error:
[string "          end"]:1: <eof> expected near 'end'-- lua error:
[string "        end"]:1: <eof> expected near 'end'-- lua error:
[string "      end"]:1: <eof> expected near 'end'-- lua error:
[string "    end"]:1: <eof> expected near 'end'-- lua error:
[string "  end"]:1: <eof> expected near 'end'-- lua error:
[string "  for x = 1, W do"]:1: 'end' expected near <eof>-- lua error:
[string "    local i = gidx(x, Y_MUD)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "    if GTYPE[i] == T_MUD and math.random(100)..."]:1: 'end' expected near <eof>-- lua error:
[string "      GTYPE[i] = T_EMPTY; GCOL[i] = 1; phy_ch..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "    end"]:1: <eof> expected near 'end'-- lua error:
[string "  end"]:1: <eof> expected near 'end'-- lua error:
[string "  if WIND_DIR ~= 0 then"]:1: 'end' expected near <eof>-- lua error:
[string "    local knock_prob = math.floor(WIND_PROB[W..."]:1: attempt to index a nil value (global 'WIND_PROB')-- lua error:
[string "    for x = 1, W do"]:1: 'end' expected near <eof>-- lua error:
[string "      local ci = gidx(x, Y_CAN)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "      if GTYPE[ci] == T_CANOPY and math.rando..."]:1: 'end' expected near <eof>-- lua error:
[string "        for dy = Y_AIR1, Y_AIR2 do"]:1: 'end' expected near <eof>-- lua error:
[string "          local di = gidx(x, dy)"]:1: attempt to call a nil value (global 'gidx')-- lua error:
[string "          if GTYPE[di] == T_EMPTY then"]:1: 'end' expected near <eof>-- lua error:
[string "            GTYPE[di]=T_AIR; GCOL[di]=GCOL[ci..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "            GTYPE[ci]=T_EMPTY; GCOL[ci]=1"]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "            break"]:1: break outside loop at line 1-- lua error:
[string "          end"]:1: <eof> expected near 'end'-- lua error:
[string "        end"]:1: <eof> expected near 'end'-- lua error:
[string "      end"]:1: <eof> expected near 'end'-- lua error:
[string "    end"]:1: <eof> expected near 'end'-- lua error:
[string "  end"]:1: <eof> expected near 'end'-- lua error:
[string "  if triop_strength > 0 then"]:1: 'end' expected near <eof>-- lua error:
[string "    for i = 1, MAX_TR do"]:1: 'end' expected near <eof>-- lua error:
[string "      local tr = TR[i]"]:1: attempt to index a nil value (global 'TR')-- lua error:
[string "      if tr.active then"]:1: 'end' expected near <eof>-- lua error:
[string "        tr.timer = tr.timer - 1"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "        local prev_blink = tr.blink"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "        tr.blink = false"]:1: a
ttempt to index a nil value (global 'tr')-- lua error:
[string "        if tr.timer <= 0 then"]:1: 'end' expected near <eof>-- lua error:
[string "          if tr.state == TS_MUD_WAIT then"]:1: 'end' expected near <eof>-- lua error:
[string "            tr.state = TS_RISING"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            tr.timer = 3 -- rise speed"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            tr.blink = true"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "          elseif tr.state == TS_RISING then"]:1: <eof> expected near 'elseif'-- lua error:
[string "            tr.y = tr.y - 1"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            tr.blink = true"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            local li = gidx(tr.x, tr.y)"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            if GTYPE[li] ~= T_EMPTY then"]:1: 'end' expected near <eof>-- lua error:
[string "              local base_n = col_to_note(tr.x..."]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "              local hi_n   = col_to_note(tr.x..."]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "              start_echo(base_n, tr.ch, t_vol..."]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "              play_note(hi_n, math.floor(t_vo..."]:1: attempt to perform arithmetic on a nil value (global 't_vol')-- lua error:
[string "              GTYPE[li] = T_EMPTY; GCOL[li] =..."]:1: attempt to index a nil value (global 'GTYPE')-- lua error:
[string "              tr.state = TS_SINKING"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "              tr.timer = 6 -- pause on eating..."]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            elseif tr.y <= tr.peak_y then"]:1: <eof> expected near 'elseif'-- lua error:
[string "              tr.state = TS_SINKING"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "              tr.timer = 3"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            else"]:1: <eof> expected near 'else'-- lua error:
[string "              tr.timer = 3 -- keep rising"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            end"]:1: <eof> expected near 'end'-- lua error:
[string "          elseif tr.state == TS_SINKING then"]:1: <eof> expected near 'elseif'-- lua error:
[string "            tr.y = tr.y + 1"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            tr.blink = true"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            if tr.y >= Y_MUD then"]:1: 'end' expected near <eof>-- lua error:
[string "              tr.y = Y_MUD"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "              tr.active = false -- disappears..."]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            else"]:1: <eof> expected near 'else'-- lua error:
[string "              tr.timer = 4 -- sink speed"]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "            end"]:1: <eof> expected near 'end'-- lua error:
[string "          end"]:1: <eof> expected near 'end'-- lua error:
[string "        end"]:1: <eof> expected near 'end'-- lua error:
[string "        if tr.blink ~= prev_blink then phy_ch..."]:1: attempt to index a nil value (global 'tr')-- lua error:
[string "      end"]:1: <eof> expected near 'end'-- lua error:
[string "    end"]:1: <eof> expected near 'end'-- lua error:
[string "    if triop_auto_spawn then"]:1: 'end' expected near <eof>-- lua error:
[string "      triop_spawn_t = triop_spawn_t + 1"]:1: attempt to perform arithmetic on a nil value (global 'triop_spawn_t')-- lua error:
[string "      if triop_spawn_t >= TRIOP_INT then"]:1: 'end' expected near <eof>-- lua error:
[string "        spawn_triop(math.random(W))"]:1: bad argument #1 to 'random' 