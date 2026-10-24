/*
 * device.cpp - NeoTrellis device implementation for iii
 *
 * Implements device.h interface for the dinkii-neotrellis hardware.
 * Supports two modes stored in flash:
 *   mode 0 (iii)    - Lua scripting via iii, grid events dispatched to event_grid()
 *   mode 1 (monome) - standard monome serial protocol over USB CDC
 *
 * Lua API calls (lua_pushinteger, lua_tointeger, etc.) live in device_lua.c,
 * which is compiled WITHOUT LUA_USE_C89.  This file contains only hardware
 * interaction and a plain-C LED API that device_lua.c calls back into.
 */

// C++ headers first (cannot be inside extern "C")
#include "MonomeSerialDevice.h"
#include "Adafruit_seesaw/Adafruit_NeoTrellis.h"

#include "config.h"
#include "pico/time.h"
#include "pico/stdlib.h"
#include "hardware/flash.h"
#include "hardware/sync.h"
#include "tusb.h"
#include <string.h>

// C headers from iii — wrap in extern "C" so C++ sees them with C linkage
extern "C" {
#include "device.h"
#include "device_ext.h"
#include "serial.h"
#include "util.h"
#include "flash.h"
}

// ---------------------------------------------------------------------------
// mode — defined in dinkii-neotrellis.cpp, set before device_init() is called
// ---------------------------------------------------------------------------
extern uint8_t mode;
extern uint8_t g_monome_mode;

// ---------------------------------------------------------------------------
// NeoTrellis objects
// ---------------------------------------------------------------------------

#if GRIDCOUNT == SIXTEEN
Adafruit_NeoTrellis trellis_array[NUM_ROWS / 4][NUM_COLS / 4] = {
    {Adafruit_NeoTrellis(addrRowOne[0])}};
#endif

#if GRIDCOUNT == SIXTYFOUR
Adafruit_NeoTrellis trellis_array[NUM_ROWS / 4][NUM_COLS / 4] = {
    {Adafruit_NeoTrellis(addrRowOne[0]), Adafruit_NeoTrellis(addrRowOne[1])},
    {Adafruit_NeoTrellis(addrRowTwo[0]), Adafruit_NeoTrellis(addrRowTwo[1])}};
#endif

#if GRIDCOUNT == ONETWENTYEIGHT
Adafruit_NeoTrellis trellis_array[NUM_ROWS / 4][NUM_COLS / 4] = {
    {Adafruit_NeoTrellis(addrRowOne[0]), Adafruit_NeoTrellis(addrRowOne[1]),
     Adafruit_NeoTrellis(addrRowOne[2]), Adafruit_NeoTrellis(addrRowOne[3])},
    {Adafruit_NeoTrellis(addrRowTwo[0]), Adafruit_NeoTrellis(addrRowTwo[1]),
     Adafruit_NeoTrellis(addrRowTwo[2]), Adafruit_NeoTrellis(addrRowTwo[3])}};
#endif

Adafruit_MultiTrellis trellis((Adafruit_NeoTrellis *)trellis_array,
                              NUM_ROWS / 4, NUM_COLS / 4);

// ---------------------------------------------------------------------------
// MonomeSerialDevice — used in mode 1 (monome protocol)
// ---------------------------------------------------------------------------
MonomeSerialDevice mdp;
static int prevLedBuffer[MonomeSerialDevice::MAXLEDCOUNT];

// ---------------------------------------------------------------------------
// Grid LED state for mode 0 (iii) — 0–15 intensity per cell
// ---------------------------------------------------------------------------
static uint8_t local_leds[NUM_ROWS * NUM_COLS];
static uint8_t mmap[NUM_ROWS * NUM_COLS];
static bool    grid_dirty = false;

// Per-pixel RGB override. When px_override[i] is true, px_rgb[i] is used
// directly instead of the global tint × brightness calculation.
static bool     px_override[NUM_ROWS * NUM_COLS];
static uint32_t px_rgb[NUM_ROWS * NUM_COLS];

// ---------------------------------------------------------------------------
// Key event buffer — populated by keyCallback, drained in device_task()
// ---------------------------------------------------------------------------
#define GRID_EVENTS_MAX 64
static uint8_t grid_event_count = 0;
static struct {
    uint8_t x;
    uint8_t y;
    uint8_t z;
} grid_events[GRID_EVENTS_MAX];

static void grid_add_event(uint8_t x, uint8_t y, uint8_t z) {
    if (grid_event_count < GRID_EVENTS_MAX) {
        grid_events[grid_event_count].x = x;
        grid_events[grid_event_count].y = y;
        grid_events[grid_event_count].z = z;
        grid_event_count++;
    }
}

// ---------------------------------------------------------------------------
// LED update helpers
// ---------------------------------------------------------------------------

static uint8_t led_r = R;
static uint8_t led_g = G;
static uint8_t led_b = B;

static uint8_t px_gain = 255;
extern "C" void device_color_intensity(int z) {
    if (z > 15) z = 15;
    if (z < 0) z = 0;
    px_gain = (uint8_t)((z * 255) / 15);
    grid_dirty = true;
}

static inline uint32_t level_to_rgb(uint8_t val, uint8_t tr, uint8_t tg, uint8_t tb) {
    uint8_t gval = (uint8_t)((uint16_t)gammaTable[val] * gammaAdj);
    if (gval == 0) return 0;

    auto calc = [gval](uint8_t tint) -> uint32_t {
        if (tint == 0) return 0;
        uint32_t out = ((uint32_t)gval * tint + 128) >> 8;
        return (out > 0) ? out : 1;
    };

    return (calc(tr) << 16) | (calc(tg) << 8) | calc(tb);
}

static inline uint32_t level_to_color(uint8_t val) {
    return level_to_rgb(val, led_r, led_g, led_b);
}

static void sendLeds_iii() {
    uint32_t total_requested = 0;
    static uint32_t colors[NUM_ROWS * NUM_COLS];

    // Pass 1: calculate colors and sum brightness
    for (int y = 0; y < NUM_ROWS; y++) {
        for (int x = 0; x < NUM_COLS; x++) {
            int i = y * NUM_COLS + x;
            uint32_t c;
            if (px_override[i]) {
                auto apply_gain = [](uint8_t c8, uint8_t gain) -> uint32_t {
                    if (c8 == 0 || gain == 0) return 0;
                    uint32_t out = ((uint32_t)c8 * gain + 128) >> 8;
                    return (out > 0) ? out : 1;
                };
                uint32_t r = apply_gain((px_rgb[i] >> 16) & 0xFF, px_gain);
                uint32_t g = apply_gain((px_rgb[i] >> 8)  & 0xFF, px_gain);
                uint32_t b = apply_gain( px_rgb[i]        & 0xFF, px_gain);
                c = (r << 16) | (g << 8) | b;
            } else {
                c = level_to_color(local_leds[i]);
            }
            colors[i] = c;
            total_requested += ((c >> 16) & 0xFF) + ((c >> 8) & 0xFF) + (c & 0xFF);
        }
    }

    // Pass 2: scale to power limit and send
    uint32_t max_safe = (uint32_t)NUM_ROWS * NUM_COLS * (gammaTable[15] * gammaAdj) * 3;
    if (total_requested > max_safe && total_requested > 0) {
        uint32_t scale_fp = (max_safe << 16) / total_requested;
        auto apply_scale = [scale_fp](uint8_t c8) -> uint32_t {
            if (c8 == 0 || scale_fp == 0) return 0;
            uint32_t out = ((uint32_t)c8 * scale_fp + 32768) >> 16;
            return (out > 0) ? out : 1;
        };
        for (int y = 0; y < NUM_ROWS; y++) {
            for (int x = 0; x < NUM_COLS; x++) {
                int i = y * NUM_COLS + x;
                uint32_t c = colors[i];
                uint32_t r = apply_scale((c >> 16) & 0xFF);
                uint32_t g = apply_scale((c >> 8)  & 0xFF);
                uint32_t b = apply_scale( c         & 0xFF);
                trellis.setPixelColor(x, y, (r << 16) | (g << 8) | b);
            }
        }
    } else {
        for (int y = 0; y < NUM_ROWS; y++) {
            for (int x = 0; x < NUM_COLS; x++) {
                trellis.setPixelColor(x, y, colors[y * NUM_COLS + x]);
            }
        }
    }
    trellis.show();
}

static void sendLeds_monome() {
    bool dirty = false;
    for (int y = 0; y < NUM_ROWS; y++) {
        for (int x = 0; x < NUM_COLS; x++) {
            int i = y * NUM_COLS + x;
            uint8_t val = mdp.leds[i];
            if (val != (uint8_t)prevLedBuffer[i]) {
                trellis.setPixelColor(x, y, level_to_color(val));
                prevLedBuffer[i] = val;
                dirty = true;
            }
        }
    }
    if (dirty) trellis.show();
}

// ---------------------------------------------------------------------------
// Serial-mode color — saved in the second sector of the flash status block.
// iii only uses the first sector (mode byte); LittleFS starts one block later.
// The status block follows the firmware binary, so flashing a build of a
// different size resets the color to the R/G/B default in config.h.
// ---------------------------------------------------------------------------
static_assert(FLASH_BLOCK_SIZE >= 2 * FLASH_SECTOR_SIZE,
              "color sector must fit inside the flash status block");

#define COLOR_MAGIC 0xC0

static uint32_t color_flash_offset() {
    return flash_get_status_offset() + FLASH_SECTOR_SIZE;
}

static void color_load() {
    const uint8_t *v = (const uint8_t *)(XIP_BASE + color_flash_offset());
    if (v[0] == COLOR_MAGIC) {
        led_r = v[1];
        led_g = v[2];
        led_b = v[3];
    }
}

static void color_save() {
    const uint8_t *v = (const uint8_t *)(XIP_BASE + color_flash_offset());
    if (v[0] == COLOR_MAGIC && v[1] == led_r && v[2] == led_g && v[3] == led_b)
        return; // unchanged — skip the erase

    // must run before core 1 is launched (same constraint as flash_write_mode)
    uint8_t b[FLASH_PAGE_SIZE];
    memset(b, 0xFF, sizeof(b));
    b[0] = COLOR_MAGIC;
    b[1] = led_r;
    b[2] = led_g;
    b[3] = led_b;
    uint32_t ints = save_and_disable_interrupts();
    flash_range_erase(color_flash_offset(), FLASH_SECTOR_SIZE);
    flash_range_program(color_flash_offset(), b, FLASH_PAGE_SIZE);
    restore_interrupts(ints);
}

// ---------------------------------------------------------------------------
// Boot-time color picker (hold the top-right key at power-on).
// Column 0 is white, the other columns are hues; rows fade from full
// saturation to pastel. The bottom row previews levels 1–15 in the chosen
// color. Press the top-right key to save and continue into serial mode.
// ---------------------------------------------------------------------------
#define PICKER_DONE_X (NUM_COLS - 1)
#define PICKER_DONE_Y 0
#define PICKER_ROWS   (NUM_ROWS - 1) // last row is the level preview

static bool    picker_active = false;
static int16_t picker_key    = -1; // last key pressed while picker is active

static uint32_t hue_to_rgb(uint16_t h, uint8_t s) {
    uint8_t  region = h / 60;
    uint16_t f = (uint16_t)((h % 60) * 255 / 60);
    uint8_t  p = 255 - s;
    uint8_t  q = 255 - (uint8_t)((s * f) / 255);
    uint8_t  t = 255 - (uint8_t)((s * (255 - f)) / 255);
    uint8_t  r, g, b;
    switch (region) {
        case 0:  r = 255; g = t;   b = p;   break;
        case 1:  r = q;   g = 255; b = p;   break;
        case 2:  r = p;   g = 255; b = t;   break;
        case 3:  r = p;   g = q;   b = 255; break;
        case 4:  r = t;   g = p;   b = 255; break;
        default: r = 255; g = p;   b = q;   break;
    }
    return ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
}

static uint32_t picker_tint(uint8_t x, uint8_t y) {
    if (x == 0) return 0xFFFFFF;
    uint16_t h = (uint16_t)((x - 1) * 360 / (NUM_COLS - 1));
    uint8_t  s = (uint8_t)(255 * (PICKER_ROWS - y) / PICKER_ROWS);
    return hue_to_rgb(h, s);
}

static void color_picker() {
    picker_active = true;
    int sel_x = -1, sel_y = -1;
    bool done = false;

    while (!done) {
        trellis.read();
        if (picker_key >= 0) {
            uint8_t x = picker_key % NUM_COLS;
            uint8_t y = picker_key / NUM_COLS;
            picker_key = -1;
            if (x == PICKER_DONE_X && y == PICKER_DONE_Y) {
                done = true;
            } else if (y < PICKER_ROWS) {
                uint32_t t = picker_tint(x, y);
                led_r = (t >> 16) & 0xFF;
                led_g = (t >> 8) & 0xFF;
                led_b = t & 0xFF;
                sel_x = x;
                sel_y = y;
            }
        }

        bool blink = (to_ms_since_boot(get_absolute_time()) / 250) & 1;
        for (int y = 0; y < NUM_ROWS; y++) {
            for (int x = 0; x < NUM_COLS; x++) {
                uint32_t c;
                if (y == PICKER_ROWS) {
                    c = level_to_color(1 + x * 14 / (NUM_COLS - 1));
                } else if (x == PICKER_DONE_X && y == PICKER_DONE_Y) {
                    c = level_to_color(15);
                } else {
                    uint32_t t = picker_tint(x, y);
                    uint8_t lvl = (x == sel_x && y == sel_y && blink) ? 4 : 10;
                    c = level_to_rgb(lvl, (t >> 16) & 0xFF, (t >> 8) & 0xFF, t & 0xFF);
                }
                trellis.setPixelColor(x, y, c);
            }
        }
        trellis.show();
        sleep_ms(20);
    }

    picker_active = false;
    color_save();
    for (int y = 0; y < NUM_ROWS; y++)
        for (int x = 0; x < NUM_COLS; x++)
            trellis.setPixelColor(x, y, 0);
    trellis.show();
}

// ---------------------------------------------------------------------------
// NeoTrellis key callback — dispatches based on current mode
// ---------------------------------------------------------------------------
static TrellisCallback keyCallback(keyEvent evt) {
    // Only process RISING and FALLING edges. EDGE_HIGH (0) and EDGE_LOW (1)
    // are never enabled in normal operation; 0x00 garbage bytes from the
    // library's "count+2" over-read decode to EDGE_HIGH for key 0, causing
    // phantom key-up events.
    if (evt.bit.EDGE != SEESAW_KEYPAD_EDGE_RISING &&
        evt.bit.EDGE != SEESAW_KEYPAD_EDGE_FALLING)
        return 0;

    uint8_t x = evt.bit.NUM % NUM_COLS;
    uint8_t y = evt.bit.NUM / NUM_COLS;
    uint8_t z = (evt.bit.EDGE == SEESAW_KEYPAD_EDGE_RISING) ? 1 : 0;

    if (picker_active) {
        if (z) picker_key = evt.bit.NUM;
    } else if (mode == 0) {
        grid_add_event(x, y, z);
    } else {
        mdp.sendGridKey(x, y, z);
    }
    return 0;
}
static TrellisCallback keyCheck(keyEvent evt) {
    uint8_t x = evt.bit.NUM % NUM_COLS;
    uint8_t y = evt.bit.NUM / NUM_COLS;
    uint8_t z = (evt.bit.EDGE == SEESAW_KEYPAD_EDGE_RISING) ? 1 : 0;
    if (x == 0 && y == 0 && z == 1) {
        mode = 1; // (mode == 0) ? 1 : 0;
    }
    return 0;
}


// ---------------------------------------------------------------------------
// device.h implementations (extern "C" so C code in iii can link against them)
// ---------------------------------------------------------------------------

static uint8_t first_tile_addr() {
#if GRIDCOUNT == SIXTYFOUR || GRIDCOUNT == ONETWENTYEIGHT
    return addrRowOne[0];
#else
    return NEO_TRELLIS_ADDR;
#endif
}

// Keys checked at power-on: top-left toggles mode, top-right opens the
// serial-mode color picker.
#define BOOT_KEY_MODE  0x01
#define BOOT_KEY_COLOR 0x02

static const uint8_t boot_keys[2][2] = {{0, 0}, {NUM_COLS - 1, 0}};

static Adafruit_NeoTrellis &boot_key_tile(int k) {
    return trellis_array[boot_keys[k][1] / 4][boot_keys[k][0] / 4];
}

static uint8_t boot_key_local(int k) {
    return NEO_TRELLIS_XY(boot_keys[k][0] % 4, boot_keys[k][1] % 4);
}

// Polls ~500 ms and returns a BOOT_KEY_* mask of the keys held.
static uint8_t poll_boot_keys() {
    // EDGE_HIGH is a level trigger: fires each seesaw scan while the key is
    // held, so it works even if the key was already pressed before boot.
    for (int k = 0; k < 2; k++)
        boot_key_tile(k).setKeypadEvent(NEO_TRELLIS_KEY(boot_key_local(k)),
                                        SEESAW_KEYPAD_EDGE_HIGH, true);

    uint8_t held = 0;
    for (int i = 0; i < 50 && !held; i++) {
        sleep_ms(10);
        for (int k = 0; k < 2; k++) {
            Adafruit_NeoTrellis &tile = boot_key_tile(k);
            uint8_t count = tile.getKeypadCount();
            sleep_us(500);
            if (count == 0) continue;
            keyEventRaw e[count];
            tile.readKeypad(e, count);
            for (int j = 0; j < count; j++) {
                if (e[j].bit.EDGE != SEESAW_KEYPAD_EDGE_HIGH) continue;
                uint8_t key = NEO_TRELLIS_SEESAW_KEY(e[j].bit.NUM);
                // both keys may share a tile (4x4 grid), so match against each
                for (int m = 0; m < 2; m++)
                    if (&boot_key_tile(m) == &tile && key == boot_key_local(m))
                        held |= (1 << m);
            }
        }
    }

    for (int k = 0; k < 2; k++) {
        // Disable HIGH, restore RISING/FALLING for normal key operation.
        Adafruit_NeoTrellis &tile = boot_key_tile(k);
        uint8_t key = NEO_TRELLIS_KEY(boot_key_local(k));
        tile.setKeypadEvent(key, SEESAW_KEYPAD_EDGE_HIGH, false);
        tile.setKeypadEvent(key, SEESAW_KEYPAD_EDGE_RISING, true);
        tile.setKeypadEvent(key, SEESAW_KEYPAD_EDGE_FALLING, true);
        // Drain stale EDGE_HIGH events left in the FIFO so they don't get
        // processed as phantom key-up events by the first device_task() calls.
        uint8_t stale = tile.getKeypadCount();
        sleep_us(500);
        if (stale > 0) {
            keyEventRaw tmp[stale + 2];
            tile.readKeypad(tmp, stale + 2);
        }
    }
    return held;
}

extern "C" bool check_device_key() {
    bool detected = poll_boot_keys() & BOOT_KEY_MODE;
    if (detected) mode = (mode == 0) ? 1 : 0;
    return detected;
}


extern "C" void mode_check() {
    uint8_t saved = flash_read_mode();
    mode = saved;
    uint8_t held = poll_boot_keys();   // polls 500 ms

    if (held & BOOT_KEY_COLOR) {
        mode = 1;   // the picker sets the serial-mode color, so boot into serial
    } else if (held & BOOT_KEY_MODE) {
        mode = (mode == 0) ? 1 : 0;
    }

    if (mode != saved) {
        flash_write_mode(mode);
        g_monome_mode = mode;
    }

    if (mode == 1) {
        color_load();
        if (held & BOOT_KEY_COLOR) color_picker();
    }
}

extern "C" void device_init() {
    trellis.begin();

    for (uint8_t x = 0; x < NUM_COLS; x++) {
        for (uint8_t y = 0; y < NUM_ROWS; y++) {
            trellis.activateKey(x, y, SEESAW_KEYPAD_EDGE_RISING, true);
            trellis.activateKey(x, y, SEESAW_KEYPAD_EDGE_FALLING, true);
            trellis.registerCallback(x, y, keyCallback);
        }
    }
    for (uint8_t x = 0; x < NUM_COLS / 4; x++) {
        for (uint8_t y = 0; y < NUM_ROWS / 4; y++) {
            trellis_array[y][x].pixels.setBrightness(BRIGHTNESS);
        }
    }

    memset(local_leds,   0, sizeof(local_leds));
    memset(mmap,         0, sizeof(mmap));
    memset(prevLedBuffer, 0, sizeof(prevLedBuffer));
    memset(px_override,  0, sizeof(px_override));
    memset(px_rgb,       0, sizeof(px_rgb));
    sendLeds_iii();

    gpio_put(LED_PIN, 0);

    mode_check();

    if (mode == 0){
        trellis.setPixelColor(0, 0xFFFFFF);
        trellis.setPixelColor(7, 0xFFFFFF);
        trellis.setPixelColor(15, 0xFFFFFF);
        trellis.show();
        sleep_ms(100);
        trellis.setPixelColor(0, 0x000000);
        trellis.setPixelColor(7, 0x000000);
        trellis.setPixelColor(15, 0x000000);
        trellis.show();
    }else{
        trellis.setPixelColor(0, 0xFFFFFF);
        trellis.show();
        sleep_ms(100);
        trellis.setPixelColor(0, 0x000000);
        trellis.show();   
    }

}

extern "C" void device_task() {
    trellis.read();

    uint8_t ewr = 0;
    while (grid_event_count > 0) {
        vm_handle_grid_key(grid_events[ewr].x, grid_events[ewr].y, grid_events[ewr].z);
        ewr++;
        if (ewr == grid_event_count) {
            grid_event_count = 0;
            ewr = 0;
        }
    }

    if (grid_dirty) {
        sendLeds_iii();
        grid_dirty = false;
    }
    tud_cdc_n_write_flush(0);
}

extern "C" void device_handle_serial(uint8_t *data, uint32_t len) {
    (void)data;
    (void)len;
}

// ---------------------------------------------------------------------------
// LED C API — called from device_lua.c (compiled without LUA_USE_C89)
// ---------------------------------------------------------------------------

extern "C" void device_led_set(int x, int y, int z, int rel) {
    if (x < 0 || x >= NUM_COLS || y < 0 || y >= NUM_ROWS) return;
    int idx = y * NUM_COLS + x;
    int8_t z8 = (int8_t)(rel ? clamp(z + (int)mmap[idx], 0, 15)
                              : clamp(z, 0, 15));
    local_leds[idx]  = (uint8_t)z8;
    mmap[idx]        = (uint8_t)z8;
    px_override[idx] = false;
    grid_dirty = true;
}

extern "C" int device_led_get(int x, int y) {
    x = ((x % NUM_COLS) + NUM_COLS) % NUM_COLS;
    y = ((y % NUM_ROWS) + NUM_ROWS) % NUM_ROWS;
    return (int)mmap[y * NUM_COLS + x];
}

extern "C" void device_led_all(int z, int rel) {
    if (rel) {
        for (int i = 0; i < NUM_ROWS * NUM_COLS; i++) {
            int8_t zz = (int8_t)clamp(z + (int)mmap[i], 0, 15);
            mmap[i]       = (uint8_t)zz;
            local_leds[i] = (uint8_t)zz;
        }
    } else {
        uint8_t z8 = (uint8_t)clamp(z, 0, 15);
        memset(mmap,       z8, sizeof(mmap));
        memset(local_leds, z8, sizeof(local_leds));
    }
    memset(px_override, 0, sizeof(px_override));
    grid_dirty = true;
}

extern "C" void device_led_rgb_set(int x, int y, int r, int g, int b) {
    if (x < 0 || x >= NUM_COLS || y < 0 || y >= NUM_ROWS) return;
    r = r < 0 ? 0 : (r > 255 ? 255 : r);
    g = g < 0 ? 0 : (g > 255 ? 255 : g);
    b = b < 0 ? 0 : (b > 255 ? 255 : b);
    int idx = y * NUM_COLS + x;
    px_rgb[idx]      = ((uint32_t)r << 16) | ((uint32_t)g << 8) | (uint32_t)b;
    px_override[idx] = true;
    grid_dirty = true;
}

extern "C" void device_intensity(int z) {
    if (z > 15) z = 15;
    uint8_t brightness = (uint8_t)((z * 255) / 15);
    for (uint8_t xi = 0; xi < NUM_COLS / 4; xi++) {
        for (uint8_t yi = 0; yi < NUM_ROWS / 4; yi++) {
            trellis_array[yi][xi].pixels.setBrightness(brightness);
        }
    }
    grid_dirty = true;
}

extern "C" void device_mark_dirty(void) { grid_dirty = true; }
extern "C" int  device_cols(void)       { return NUM_COLS; }
extern "C" int  device_rows(void)       { return NUM_ROWS; }
extern "C" void device_color_set(int r, int g, int b) {
    led_r = (uint8_t)r;
    led_g = (uint8_t)g;
    led_b = (uint8_t)b;
    grid_dirty = true;
}

// ---------------------------------------------------------------------------
// Device info strings
// ---------------------------------------------------------------------------

static const char *device_help_str =
    "grid\n"
    "  event_grid(x,y,z)  (alias: grid)\n"
    "  grid_led(x,y,z,rel)\n"
    "  grid_led_get(x,y)\n"
    "  grid_led_all(z,rel)\n"
    "  grid_led_rgb(x,y,r,g,b)\n"
    "  grid_intensity(z)\n"
    "  grid_color(r,g,b)\n"
    "  grid_refresh()\n"
    "  grid_size_x()\n"
    "  grid_size_y()\n";

extern "C" const char *device_help_txt() { return device_help_str; }
extern "C" const char *device_id()       { return "neotrellis-grid"; }
extern "C" const char *device_str1()     { return "monome"; }
extern "C" const char *device_str2()     { return (mode == 0) ? "iii grid" : "grid"; }
extern "C" const char *device_version()  { return DEVICE_VERSION; }

// ---------------------------------------------------------------------------
// Monome mode main loop
// ---------------------------------------------------------------------------
extern "C" void device_monome_loop() {
    mdp.isMonome = true;
    mdp.deviceID = deviceID;
    mdp.setupAsGrid(NUM_ROWS, NUM_COLS);

    for (int i = 0; i < 8; i++) {
        tud_task();
        mdp.poll();
        sleep_ms(100);
    }
    mdp.getDeviceInfo();

    mdp.setAllLEDs(0);
    sendLeds_monome();

    uint32_t last_refresh = to_ms_since_boot(get_absolute_time());

    while (true) {
        tud_task();
        mdp.poll();

        uint32_t now = to_ms_since_boot(get_absolute_time());
        if (now - last_refresh >= 16) {
            trellis.read();
            sendLeds_monome();
            last_refresh = now;
        }
        tud_cdc_write_flush();
    }
}
