## Summary

forge's SurrealDB check moves to 4.0.1, the version np now prescribes. forge no
longer provides `lib.tools.surrealist`; a flake that calls it must drop that
call before updating its forge input.

## Changes

- The `surrealdb` check builds SurrealDB 4.0.1 from np's pins and asserts that
  `surreal version` prints 4.0.1. The README example uses the same pins.
- `lib.tools.surrealist` and the `surrealist` check are removed.

## Validation

- `nix flake check` passes on `aarch64-darwin` (11 checks), where
  `surreal version` prints `4.0.1 for macos on aarch64`.

## Previous Release

v0.1.15
