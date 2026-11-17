## Summary

forge's SurrealDB and Surrealist tools now run under Nix on Linux, and forge's
checks build every prebuilt tool np pins on Linux and macOS.

## Changes

- `tools.surrealdb`: the SurrealDB Linux binary is a glibc executable that
  loads through `/lib64/ld-linux-x86-64.so.2` and links `libstdc++.so.6` and
  `libgcc_s.so.1`. On Linux, `autoPatchelfHook` points it at Nix's loader,
  with `stdenv.cc.cc.lib` providing the C++ runtime.
- `tools.surrealist`: the Linux AppImage needs FUSE and an FHS loader, so on
  Linux it is wrapped with `appimageTools.wrapType2`, which extracts it and
  runs it in an FHS environment as `bin/surrealist`. macOS is unchanged.
- New `surrealdb` and `surrealist` checks build both tools from np's pins
  (SurrealDB 3.3.4, Surrealist 3.9.13) on `x86_64-linux` and
  `aarch64-darwin`. The `surrealdb` check runs `surreal version`.
- The `supabase` check builds and runs Supabase CLI 3.2.0, which np now
  prescribes.

## Validation

- `nix flake check` passes on `aarch64-darwin` (12 checks), where
  `surreal version` prints `3.3.4 for macos on aarch64`.
- forge's CI passes on `x86_64-linux`: auto-patchelf satisfied every
  dependency of `surreal` and `supabase`, both ran, and Surrealist's AppImage
  was extracted and wrapped.

## Previous Release

v0.1.14
