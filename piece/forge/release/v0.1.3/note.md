## Summary

The pack smoke keeps `HOME` when it clears the builder environment. `HOME`
is process identity, not a library path.

## Changes

- `release-piece.yml` smoke is `env -i HOME=… --help`. Clearing `HOME` made
  any binary that asks winpr (or the OS) for the home directory exit 255.

## Validation

- `env -i` without `HOME` makes `freerdp --help` exit 255; with `HOME` it
  prints help. Other packed CLIs still start.

## Previous Release

v0.1.2
