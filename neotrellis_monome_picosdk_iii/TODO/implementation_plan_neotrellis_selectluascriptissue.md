# Fix Script Loading in select.lua

The user reports that `select.lua` displays pixels but does not trigger script loading upon button press. This is likely caused by a combination of incorrect event handling (triggering on both press and release) and a potential ABI mismatch in the custom build that corrupts grid coordinates.

## User Review Required

> [!IMPORTANT]
> The "custom build" issue might be related to how `device_lua.c` is compiled. If you see incorrect coordinates in your serial console, the compiler flag fix in `CMakeLists.txt` is likely required.

## Proposed Changes

### Lua Scripts

#### [MODIFY] select.lua (tehn's script; no longer kept in this repo, replaced by [selector](../doc/scripts/selector/))
- Add `z == 1` check to only trigger on button press.
- Add visual feedback (dimming the LED) when a script is selected.
- Add a print statement to verify loading action on serial.

### Build System

#### [MODIFY] [CMakeLists.txt](file:///c:/Users/jonwa/Documents/GitHub/neotrellis-monome/neotrellis_monome_picosdk_iii/CMakeLists.txt)
- Apply the `-ULUA_USE_C89` flag to `src/device_lua.c` to ensure consistent 64-bit `lua_Integer` ABI, matching the fix already present for `vm.c`.

## Verification Plan

### Manual Verification
1. Flash the updated firmware with the `CMakeLists.txt` fix.
2. Run `select.lua`.
3. Press a button in the top row.
4. Observe if the LED dims and the selected script loads.
5. Check the serial console for "loading: [scriptname]" messages.
