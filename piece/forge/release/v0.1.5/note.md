## Summary

The pack smoke is `env -i binary --help`. The packed binary must start
with an empty environment.

## Changes

- `release-piece.yml` smoke no longer sets `HOME`. A binary that needs
  `HOME` supplies it itself.

## Validation

- `env -i` has no `HOME`. A packed CLI that does not read `HOME` still
  starts.

## Previous Release

v0.1.4
