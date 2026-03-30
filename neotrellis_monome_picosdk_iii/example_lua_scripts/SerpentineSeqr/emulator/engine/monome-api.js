/**
 * monome-api.js
 * JS shim layer that maps the Monome/NeoTrellis hardware API to browser equivalents.
 * This module is injected into the Fengari Lua runtime as globals before script execution.
 *
 * API Contract (what a Lua script can call):
 *   grid_led(x, y, lum)            – set pad at (x,y) to mono brightness 0–15
 *   grid_led_rgb(x, y, r, g, b)    – set pad at (x,y) to RGB (0–255 each)
 *   grid_led_all(lum)              – set all pads to brightness
 *   grid_refresh()                 – flush frame buffer to DOM
 *   grid_color_intensity(val)      – set master brightness multiplier
 *   midi_note_on(note, vel)        – send MIDI note on + Web Audio fallback
 *   midi_note_off(note)            – send MIDI note off
 *   get_time()                     – seconds since page load (float)
 *   wrap(v, lo, hi)               – integer range wrapping utility
 *   metro.init(fn, interval)       – create a repeating timer object
 *   metro:start([interval])        – start/restart the metro timer
 *   metro:stop()                   – stop the metro timer
 *   event_grid(x, y, z)           – called BY the emulator when a pad is clicked
 */

export class MonomeAPI {
  /**
   * @param {Object} opts
   * @param {number} opts.cols   – grid width (default 16)
   * @param {number} opts.rows   – grid height (default 8)
   * @param {Function} opts.onLedUpdate – called after gridRefresh with the frame buffer
   * @param {Function} opts.onAltLedUpdate – optional separate channel for alt/settings layer
   */
  constructor(opts = {}) {
    this.cols = opts.cols || 16;
    this.rows = opts.rows || 8;
    this.onLedUpdate = opts.onLedUpdate || (() => {});

    // Frame buffer: flat array of {r,g,b} per cell, indexed (y-1)*cols + (x-1)
    this.frameBuffer = new Array(this.cols * this.rows).fill(null).map(() => ({ r: 0, g: 0, b: 0 }));
    this.masterBright = 12; // 1–15 scale

    // MIDI
    this.midiOut = null;
    this._activeNodes = new Map();
    this._audioCtx = null;
    this._masterGain = null;

    // Volume/attack/release controlled by emulator UI
    this.volume = 0.7;
    this.attack = 0.005;
    this.release = 0.08;

    // Metro registry
    this._metros = [];

    // Lua event function – set once the script is loaded
    this._luaEventGrid = null;
    this._startTime = performance.now();
  }

  // ─── GRID LED API ─────────────────────────────────────────────────────────

  /** Set single pad to monochrome brightness (0–15) */
  grid_led(x, y, lum) {
    const v = Math.max(0, Math.min(255, Math.floor((lum / 15) * 255)));
    this._setCell(x, y, v, v, v);
  }

  /** Set single pad to RGB color (0–255 each) */
  grid_led_rgb(x, y, r, g, b) {
    this._setCell(x, y, r, g, b);
  }

  /** Clear all pads to a brightness level (0–15), default 0 */
  grid_led_all(lum) {
    const v = Math.max(0, Math.min(255, Math.floor(((lum || 0) / 15) * 255)));
    for (let i = 0; i < this.frameBuffer.length; i++) {
      this.frameBuffer[i].r = v;
      this.frameBuffer[i].g = v;
      this.frameBuffer[i].b = v;
    }
  }

  /** Flush frame buffer to DOM via callback */
  grid_refresh() {
    const bs = this.masterBright / 12;
    const out = this.frameBuffer.map(cell => ({
      r: Math.min(255, Math.floor(cell.r * bs)),
      g: Math.min(255, Math.floor(cell.g * bs)),
      b: Math.min(255, Math.floor(cell.b * bs)),
    }));
    this.onLedUpdate(out, this.cols, this.rows);
  }

  /** Set master brightness multiplier (1–15) */
  grid_color_intensity(val) {
    this.masterBright = Math.max(1, Math.min(15, val));
  }

  _setCell(x, y, r, g, b) {
    if (x < 1 || x > this.cols || y < 1 || y > this.rows) return;
    const i = (y - 1) * this.cols + (x - 1);
    this.frameBuffer[i].r = r;
    this.frameBuffer[i].g = g;
    this.frameBuffer[i].b = b;
  }

  // ─── MIDI + AUDIO ──────────────────────────────────────────────────────────

  setMidiOut(midiOut) {
    this.midiOut = midiOut;
  }

  _ensureAudio() {
    if (this._audioCtx) return;
    this._audioCtx = new (window.AudioContext || window.webkitAudioContext)();
    this._masterGain = this._audioCtx.createGain();
    this._masterGain.gain.value = this.volume;
    this._masterGain.connect(this._audioCtx.destination);
  }

  midi_note_on(note, vel) {
    note = note & 0x7F;
    vel = vel & 0x7F;
    if (this.midiOut) this.midiOut.send([0x90, note, vel]);
    this._synthOn(note, vel);
  }

  midi_note_off(note) {
    note = note & 0x7F;
    if (this.midiOut) this.midiOut.send([0x80, note, 0]);
    this._synthOff(note);
  }

  _synthOn(note, vel) {
    this._ensureAudio();
    this._synthOff(note);
    const freq = 440 * Math.pow(2, (note - 69) / 12);
    const osc = this._audioCtx.createOscillator();
    const g = this._audioCtx.createGain();
    osc.type = 'triangle';
    osc.frequency.value = freq;
    g.gain.setValueAtTime(0, this._audioCtx.currentTime);
    g.gain.linearRampToValueAtTime((vel / 127) * 0.4, this._audioCtx.currentTime + this.attack);
    g.gain.exponentialRampToValueAtTime((vel / 127) * 0.15, this._audioCtx.currentTime + this.attack + 0.08);
    osc.connect(g);
    g.connect(this._masterGain);
    osc.start();
    const tid = setTimeout(() => this._synthOff(note), 3000);
    this._activeNodes.set(note, { osc, g, tid });
  }

  _synthOff(note) {
    const n = this._activeNodes.get(note);
    if (!n) return;
    clearTimeout(n.tid);
    const rel = this.release;
    n.g.gain.cancelScheduledValues(this._audioCtx.currentTime);
    n.g.gain.setValueAtTime(Math.max(0.0001, n.g.gain.value), this._audioCtx.currentTime);
    n.g.gain.exponentialRampToValueAtTime(0.0001, this._audioCtx.currentTime + rel);
    setTimeout(() => {
      try { n.osc.stop(); } catch (e) {}
      n.osc.disconnect();
      n.g.disconnect();
    }, (rel + 0.1) * 1000);
    this._activeNodes.delete(note);
  }

  // ─── METRO ────────────────────────────────────────────────────────────────

  /**
   * Create a metro (repeating timer) object.
   * Compatible with Norns metro.init() signature.
   * @param {Function} fn - callback on each tick
   * @param {number} interval - time between ticks in seconds
   * @returns {Metro} metro object with start() and stop() methods
   */
  createMetro(fn, interval) {
    const metro = {
      _fn: fn,
      _interval: interval || 1,
      _timerId: null,
      _api: this,
      start(newInterval) {
        if (newInterval !== undefined) this._interval = newInterval;
        this.stop();
        const ms = Math.max(8, Math.floor(this._interval * 1000));
        this._timerId = setInterval(() => {
          try { this._fn(); } catch (e) { console.error('[metro tick error]', e); }
        }, ms);
      },
      stop() {
        if (this._timerId !== null) {
          clearInterval(this._timerId);
          this._timerId = null;
        }
      }
    };
    this._metros.push(metro);
    return metro;
  }

  /** Stop all running metros (called on script unload/reload) */
  stopAllMetros() {
    for (const m of this._metros) m.stop();
    this._metros = [];
  }

  stopAllNotes() {
    for (const [note] of this._activeNodes) this._synthOff(note);
  }

  // ─── TIMING ───────────────────────────────────────────────────────────────

  /** Returns seconds elapsed since emulator start */
  get_time() {
    return (performance.now() - this._startTime) / 1000;
  }

  /** Integer range wrapping: wrap(v, lo, hi) */
  wrap(v, lo, hi) {
    const r = hi - lo + 1;
    return lo + (((v - lo) % r) + r) % r;
  }

  // ─── INPUT BRIDGE ─────────────────────────────────────────────────────────

  /**
   * Called by the emulator UI when a pad is pressed or released.
   * Routes to the Lua event_grid function if available.
   * @param {number} x
   * @param {number} y
   * @param {number} z  – 1 = press, 0 = release
   */
  handlePadEvent(x, y, z) {
    if (this._luaEventGrid) {
      try {
        this._luaEventGrid(x, y, z);
      } catch (e) {
        console.error('[event_grid error]', e);
      }
    }
  }

  /** Register the Lua event_grid callback (called by lua-loader after script init) */
  setEventGridHandler(fn) {
    this._luaEventGrid = fn;
  }

  // ─── CLEANUP ──────────────────────────────────────────────────────────────

  /** Full cleanup before reloading a script */
  reset() {
    this.stopAllMetros();
    this.stopAllNotes();
    this.grid_led_all(0);
    this._luaEventGrid = null;
    this._startTime = performance.now();
  }
}
