/**
 * lua-loader.js
 * Handles Lua script discovery, loading, execution inside Fengari, and hot-reload.
 *
 * Responsibilities:
 *   - Fetch the scripts/manifest.json to populate the script browser
 *   - Fetch individual .lua files via HTTP (requires serve.js to be running)
 *   - Accept a user-picked .lua file via the File Picker API (works without server)
 *   - Execute Lua source inside Fengari with MonomeAPI globals injected
 *   - Connect to WebSocket hot-reload signal from serve.js
 *   - Extract and call event_grid from the Lua global scope
 */

import { DocExtractor } from './doc-extractor.js';

const extractor = new DocExtractor();

export class LuaLoader {
  /**
   * @param {Object} opts
   * @param {MonomeAPI} opts.api   – the monome-api instance
   * @param {Function} opts.onScriptLoad   – called after a script loads successfully: (name, docs)
   * @param {Function} opts.onScriptError  – called on runtime error: (errorMessage)
   * @param {Function} opts.onStatusChange – called with status text updates: (msg, level)
   * @param {string}   opts.wsUrl          – WebSocket URL for hot-reload (default: auto)
   */
  constructor(opts = {}) {
    this.api = opts.api;
    this.onScriptLoad = opts.onScriptLoad || (() => {});
    this.onScriptError = opts.onScriptError || (() => {});
    this.onStatusChange = opts.onStatusChange || (() => {});

    this._currentScriptName = null;
    this._currentSource = null;
    this._L = null;          // Fengari Lua state
    this._ws = null;
    this._wsUrl = opts.wsUrl || null;  // auto-detected from serve.js
    this._wsAutoReconnectTimer = null;

    // Fengari module refs (populated after init)
    this._fengari = null;
    this._lualib = null;
    this._lauxlib = null;
  }

  // ─── PUBLIC API ───────────────────────────────────────────────────────────

  /** Fetch the manifest and return array of script descriptors */
  async fetchManifest(baseUrl = '') {
    try {
      const res = await fetch(`${baseUrl}/scripts/manifest.json`);
      if (!res.ok) throw new Error(`manifest fetch failed: ${res.status}`);
      return await res.json();
    } catch (e) {
      this.onStatusChange('Manifest unavailable — use File Picker to load scripts', 'warn');
      return [];
    }
  }

  /** Load a named script from the server's scripts/ folder */
  async loadFromServer(filename, baseUrl = '') {
    this.onStatusChange(`Fetching ${filename}…`, 'info');
    try {
      const res = await fetch(`${baseUrl}/scripts/${filename}`);
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const source = await res.text();
      this._currentScriptName = filename;
      await this._execute(source, filename);
    } catch (e) {
      this.onStatusChange(`Load failed: ${e.message}`, 'error');
      this.onScriptError(e.message);
    }
  }

  /** Called when user picks a .lua file via <input type="file"> */
  async loadFromFile(file) {
    this.onStatusChange(`Loading ${file.name}…`, 'info');
    try {
      const source = await file.text();
      this._currentScriptName = file.name;
      await this._execute(source, file.name);
    } catch (e) {
      this.onStatusChange(`File load failed: ${e.message}`, 'error');
      this.onScriptError(e.message);
    }
  }

  /** Reload the currently loaded script (re-fetch + re-execute) */
  async reload(baseUrl = '') {
    if (!this._currentScriptName) return;
    // If it was loaded from file picker, we don't have the source again
    // so we try the server path; if unavailable, re-execute cached source
    if (this._currentSource) {
      await this._execute(this._currentSource, this._currentScriptName);
    } else {
      await this.loadFromServer(this._currentScriptName, baseUrl);
    }
  }

  // ─── WEBSOCKET HOT-RELOAD ─────────────────────────────────────────────────

  /**
   * Connect to the serve.js WebSocket for hot-reload.
   * @param {string} url – ws://localhost:PORT/ws
   * @param {string} baseUrl – base HTTP URL for re-fetching scripts
   */
  connectHotReload(url, baseUrl = '') {
    this._wsUrl = url;
    this._wsBaseUrl = baseUrl;
    this._connectWS();
  }

  _connectWS() {
    if (this._ws) {
      try { this._ws.close(); } catch (e) {}
    }
    try {
      this._ws = new WebSocket(this._wsUrl);
    } catch (e) {
      this._scheduleWSReconnect();
      return;
    }

    this._ws.onopen = () => {
      this.onStatusChange('🔥 Hot-reload connected', 'success');
      clearTimeout(this._wsAutoReconnectTimer);
    };

    this._ws.onmessage = async (evt) => {
      try {
        const msg = JSON.parse(evt.data);
        if (msg.type === 'file_changed') {
          // Only reload if the changed file is the currently loaded one
          if (!this._currentScriptName || msg.name === this._currentScriptName) {
            this.onStatusChange(`↻ Detected change: ${msg.name} — reloading`, 'info');
            await this.loadFromServer(msg.name, this._wsBaseUrl);
          }
        } else if (msg.type === 'connected') {
          this.onStatusChange(`🔥 Hot-reload ready (watching scripts/)`, 'success');
        }
      } catch (e) {}
    };

    this._ws.onerror = () => {
      this.onStatusChange('Hot-reload disconnected — retrying…', 'warn');
    };

    this._ws.onclose = () => {
      this._scheduleWSReconnect();
    };
  }

  _scheduleWSReconnect() {
    clearTimeout(this._wsAutoReconnectTimer);
    this._wsAutoReconnectTimer = setTimeout(() => this._connectWS(), 3000);
  }

  // ─── FENGARI EXECUTION ────────────────────────────────────────────────────

  async _execute(source, name) {
    this._currentSource = source;

    // Cleanup any previous script run
    this.api.reset();

    // Extract docs before execution (pure string parsing, no runtime needed)
    const docs = extractor.parse(source);

    // Ensure Fengari is available (loaded via <script> tag in HTML)
    if (!window.fengari) {
      this.onStatusChange('Fengari runtime not loaded — check <script> tag', 'error');
      this.onScriptError('Fengari not found');
      return;
    }

    // fengari-web exposes: fengari.lua, fengari.lauxlib, fengari.lualib
    // PLUS top-level helpers: fengari.to_luastring, fengari.to_jsstring
    const { lua, lualib, lauxlib, to_luastring } = window.fengari;
    this._lua = lua;
    this._lualib = lualib;
    this._lauxlib = lauxlib;

    // Create a fresh Lua state
    const L = lauxlib.luaL_newstate();
    this._L = L;
    lualib.luaL_openlibs(L);

    // ── Inject MonomeAPI globals into the Lua state ──────────────────────

    const api = this.api;
    const luaStr = (s) => to_luastring(s);

    const pushFn = (name, fn) => {
      lua.lua_pushstring(L, luaStr(name));
      lua.lua_pushcfunction(L, (L2) => {
        try {
          fn(L2);
        } catch (e) {
          lua.lua_pushstring(L2, luaStr(`[API error in ${name}]: ${e.message}`));
          lua.lua_error(L2);
        }
        return 0;
      });
      lua.lua_settable(L, lua.LUA_REGISTRYINDEX);
    };

    // Helper to get global (set at _G level)
    const setGlobal = (name, fn) => {
      lua.lua_pushcfunction(L, (L2) => {
        try { return fn(L2) || 0; } catch (e) {
          lua.lua_pushstring(L2, luaStr(String(e)));
          lua.lua_error(L2);
          return 0;
        }
      });
      lua.lua_setglobal(L, luaStr(name));
    };

    const getNum = (L2, idx) => lua.lua_tonumber(L2, idx);
    const getInt = (L2, idx) => Math.round(lua.lua_tonumber(L2, idx));

    // grid_led(x, y, lum)
    setGlobal('grid_led', (L2) => {
      api.grid_led(getInt(L2, 1), getInt(L2, 2), getInt(L2, 3)); return 0;
    });

    // grid_led_rgb(x, y, r, g, b)
    setGlobal('grid_led_rgb', (L2) => {
      api.grid_led_rgb(getInt(L2, 1), getInt(L2, 2), getInt(L2, 3), getInt(L2, 4), getInt(L2, 5)); return 0;
    });

    // grid_led_all(lum)
    setGlobal('grid_led_all', (L2) => {
      api.grid_led_all(getInt(L2, 1)); return 0;
    });

    // grid_refresh()
    setGlobal('grid_refresh', (_L2) => {
      api.grid_refresh(); return 0;
    });

    // grid_color_intensity(val)
    setGlobal('grid_color_intensity', (L2) => {
      api.grid_color_intensity(getInt(L2, 1)); return 0;
    });

    // midi_note_on(note, vel)
    setGlobal('midi_note_on', (L2) => {
      api.midi_note_on(getInt(L2, 1), getInt(L2, 2)); return 0;
    });

    // midi_note_off(note)
    setGlobal('midi_note_off', (L2) => {
      api.midi_note_off(getInt(L2, 1)); return 0;
    });

    // get_time() → number
    setGlobal('get_time', (L2) => {
      lua.lua_pushnumber(L2, api.get_time()); return 1;
    });

    // wrap(v, lo, hi) → number
    setGlobal('wrap', (L2) => {
      lua.lua_pushnumber(L2, api.wrap(getInt(L2, 1), getInt(L2, 2), getInt(L2, 3))); return 1;
    });

    // math.random / math.randomseed  (already in lualib, but ensure it's active)
    // metro table: metro.init(fn, interval)
    this._injectMetro(L, lua, lauxlib, api);

    // ── Execute the Lua source ──────────────────────────────────────────

    const encoded = luaStr(source);
    const chunkName = luaStr(`@${name}`);
    const loadStatus = lauxlib.luaL_loadbuffer(L, encoded, encoded.length, chunkName);

    if (loadStatus !== lua.LUA_OK) {
      const err = lua.lua_tojsstring(L, -1);
      this.onStatusChange(`Lua parse error: ${err}`, 'error');
      this.onScriptError(err);
      return;
    }

    const callStatus = lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0);
    if (callStatus !== lua.LUA_OK) {
      const err = lua.lua_tojsstring(L, -1);
      this.onStatusChange(`Lua runtime error: ${err}`, 'error');
      this.onScriptError(err);
      return;
    }

    // ── Wire up event_grid from Lua globals ────────────────────────────
    lua.lua_getglobal(L, luaStr('event_grid'));
    const hasEventGrid = lua.lua_isfunction(L, -1);
    lua.lua_pop(L, 1);

    if (hasEventGrid) {
      api.setEventGridHandler((x, y, z) => {
        lua.lua_getglobal(L, luaStr('event_grid'));
        lua.lua_pushnumber(L, x);
        lua.lua_pushnumber(L, y);
        lua.lua_pushnumber(L, z);
        lua.lua_pcall(L, 3, 0, 0);
      });
    }

    this.onStatusChange(`✓ ${name} loaded`, 'success');
    this.onScriptLoad(name, docs);
  }

  _injectMetro(L, lua, lauxlib, api) {
    const { to_luastring } = window.fengari;
    const luaStr = (s) => to_luastring(s);

    // Create a JS-backed metro table to inject at "metro" global
    // We use a Lua helper that stores metros in a Lua table,
    // but delegates start/stop to JS via closures.

    // Strategy: inject metro.init as a C function that returns a userdata-like table
    // with :start() and :stop() methods pointing to JS functions.

    // Build the `metro` global table
    lua.lua_newtable(L);

    // metro.init = function(fn, interval)  [C closure]
    lua.lua_pushstring(L, luaStr('init'));
    lua.lua_pushcfunction(L, (L2) => {
      // arg1: function, arg2: interval (optional)
      const interval = lua.lua_isnumber(L2, 2) ? lua.lua_tonumber(L2, 2) : 1;

      // We store the Lua function ref in a JS closure
      // by making a reference using the registry
      lua.lua_pushvalue(L2, 1); // copy fn to top
      const fnRef = lauxlib.luaL_ref(L2, lua.LUA_REGISTRYINDEX);

      const wrappedFn = () => {
        lua.lua_rawgeti(L2, lua.LUA_REGISTRYINDEX, fnRef);
        lua.lua_pcall(L2, 0, 0, 0);
      };

      const metro = api.createMetro(wrappedFn, interval);

      // Build and push back a Lua table with :start() and :stop()
      lua.lua_newtable(L2);

      // :start([interval])
      lua.lua_pushstring(L2, luaStr('start'));
      lua.lua_pushcfunction(L2, (L3) => {
        const newInterval = lua.lua_isnumber(L3, 2) ? lua.lua_tonumber(L3, 2) : undefined;
        metro.start(newInterval);
        return 0;
      });
      lua.lua_settable(L2, -3);

      // :stop()
      lua.lua_pushstring(L2, luaStr('stop'));
      lua.lua_pushcfunction(L2, (_L3) => {
        metro.stop();
        return 0;
      });
      lua.lua_settable(L2, -3);

      // Add __index metamethod so m:start() works (colon syntax)
      lua.lua_newtable(L2); // metatable
      lua.lua_pushstring(L2, luaStr('__index'));
      lua.lua_pushvalue(L2, -3); // the metro table itself
      lua.lua_settable(L2, -3);
      lua.lua_setmetatable(L2, -2);

      return 1; // returns the metro table
    });
    lua.lua_settable(L, -3); // metro.init = <cfn>

    lua.lua_setglobal(L, luaStr('metro'));
  }
}
