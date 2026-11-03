## Summary

Release workflows live in forge and are reusable. A project dispatches a stub that calls this repository at the same tag as `inputs.forge`.

## Changes

- `release.yml` accepts `workflow_call` with `target_sha` and `releases`. `release-piece.yml` stays in this repository; a relative `uses:` resolves here at this tag.
- forge is a note-only flake piece (`piece/forge/`, empty `legacyPackages.npRelease.forge.targets`). The Git tag is `vX.Y.Z`.
- `lib.rust.cli { targets ? }` selects archives. `darwin-x86_64` is offered on `aarch64-darwin` (`x86_64-apple-darwin` rust-std).

## Validation

- `nix flake check` is clean on `aarch64-darwin`.
- `np release inspect` lists `forge` as a flake piece at 0.1.1.

## Previous Release

v0.1.0
