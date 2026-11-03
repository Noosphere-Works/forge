## Summary

The release pack job ships `$out/bin` as the archive: one binary, or a
binary plus libraries, including `darwin-x86_64` on Apple Silicon.

## Changes

- `release-piece.yml` packs every file in the target's `$out/bin`. Darwin
  accepts `darwin-x86_64`, checks the binary architecture, and signs every
  Mach-O under `bin` (and refuses `/nix/store` links). An x86_64 smoke on
  Apple Silicon runs only when Rosetta is there.
- `check.yml` quotes the `nix eval` step so the workflow is valid YAML.

## Validation

- The `check.yml` `nix eval` line is a block scalar: `s: v:` is not YAML
  syntax.
- Packing and smoking consumer archives is `np release` on a project that
  lists those targets.

## Previous Release

v0.1.1
