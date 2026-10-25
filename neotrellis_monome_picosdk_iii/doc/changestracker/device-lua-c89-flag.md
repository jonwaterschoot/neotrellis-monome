# `-ULUA_USE_C89` on device_lua.c: a safeguard, not a fix

Added in commit `46c8657` (2026-10-24). On 2026-10-25 it was found to change nothing in the current build.

## What was changed

`CMakeLists.txt` already removed `LUA_USE_C89` when compiling `src/iii/vm.c`. The change extended that to `src/device_lua.c`, matching the header comment in that file, which says it is compiled without the flag:

```cmake
set_source_files_properties(${CMAKE_SOURCE_DIR}/src/iii/vm.c ${CMAKE_SOURCE_DIR}/src/device_lua.c PROPERTIES
    COMPILE_OPTIONS "-ULUA_USE_C89"
)
```

## Why it was thought to be a fix

tehn's `select.lua` script picker lit up its slots, but pressing a slot never loaded a script. The theory was a type mismatch. Without `LUA_32BITS`, `LUA_USE_C89` makes `lua_Integer` a 32-bit `long`, while code compiled without it uses a 64-bit `long long`. On ARM those are passed differently, so grid coordinates pushed by `device_lua.c` would arrive as garbage.

## Why it makes no difference

`src/lua/luaconf.h` sets `LUA_32BITS 1`, as iii has since v1.1.2. That makes `lua_Integer` an `int` and `lua_Number` a `float` whether or not `LUA_USE_C89` is set. Two checks confirmed it with the pico toolchain:

- The preprocessor gives `LUA_INTEGER int` and `LUA_NUMBER float` with and without the flag.
- `device_lua.c` compiles to identical machine code with and without `-ULUA_USE_C89`.

The flag stays as a safeguard. It keeps the file's comment true, and it would matter if `LUA_32BITS` were ever turned off. It is not worth an upstream PR.

## What did fix select.lua

That's unclear. The same round of changes added a `z == 1` check, so the script loads only on key press, not on release too. That is the likelier fix. The script picker was later rewritten as [selector](../scripts/selector/).
