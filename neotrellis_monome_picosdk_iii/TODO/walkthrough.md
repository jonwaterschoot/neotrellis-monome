# Walkthrough - Fixing Script Selection

I have implemented fixes for the script loading issue in `select.lua` and addressed a critical ABI mismatch in the build system.

## Changes Made

### Lua Scripts
- **[select.lua](file:///c:/Users/jonwa/Documents/GitHub/neotrellis-monome/neotrellis_monome_picosdk_iii/doc/scripts/tehn_temp/select.lua)**:
    - Added `z == 1` check to ensure the script only loads once per button press (ignoring the release event).
    - Added a `print` statement for serial console feedback.
    - Added a visual cue by dimming the selected LED before loading.

### Build System
- **[CMakeLists.txt](file:///c:/Users/jonwa/Documents/GitHub/neotrellis-monome/neotrellis_monome_picosdk_iii/CMakeLists.txt)**:
    - Extended the `-ULUA_USE_C89` property override to include `src/device_lua.c`. This ensures that the code responsible for passing grid coordinates to Lua uses the same 64-bit `lua_Integer` as the rest of the VM, preventing coordinate corruption.

## Verification

Please re-flash your device with the updated firmware. You should now see:
1. Correct coordinates being hit (confirmed if the button press actually triggers the load).
2. "loading: [scriptname]" in your serial console.
3. The selected button dimming briefly before the new script takes over.
