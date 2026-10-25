# Grid key coordinates reaching Lua as garbage

Fixed in commit `46c8657`, first released in `neotrellis-iii-128-20261024-jonwtr-colorpicker.uf2`.

## Symptom

Running tehn's `select.lua` script picker lit up its slots, but pressing a slot never loaded a script. Key presses reached `event_grid(x, y, z)` in Lua with the wrong `x`/`y` values.

## Cause

Lua is built with `LUA_USE_C89`, which makes `lua_Integer` a 32-bit `long`. The iii VM is compiled without that flag, so there `lua_Integer` is a 64-bit `long long`. On ARM those two types are passed in different registers. So when C code built with the flag calls `lua_pushinteger` and the VM reads the value, it gets garbage.

`CMakeLists.txt` already removed the flag for `src/iii/vm.c`. `src/device_lua.c` also calls `lua_pushinteger` to pass the grid coordinates. Its header comment says it is compiled without `LUA_USE_C89`, but CMake never set that up.

## Fix

`CMakeLists.txt` now removes `LUA_USE_C89` from `src/device_lua.c` too:

```cmake
set_source_files_properties(${CMAKE_SOURCE_DIR}/src/iii/vm.c ${CMAKE_SOURCE_DIR}/src/device_lua.c PROPERTIES
    COMPILE_OPTIONS "-ULUA_USE_C89"
)
```

okyeron's upstream `neotrellis-monome` still has this bug as of 2026-10-24.

## Related

`select.lua` also loaded on key release as well as press. It needed a `z == 1` check. The script picker was later rewritten as [selector](../scripts/selector/), which reads the scripts on the device instead of using a hardcoded list.
