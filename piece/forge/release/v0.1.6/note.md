## Summary

The pack job inspects the archive. It does not run the packed binary.

## Changes

- `release-piece.yml` builds, inspects and packs `$out/bin`. Linux stays
  static and free of `/nix/store`. Darwin stays signed, the right ISA, and
  free of `/nix/store` links. The job no longer executes the packed binary.

## Validation

- The binary job has no `env -i` and no `--help` invocation.

## Previous Release

v0.1.5
