## Summary

Freeing runner disk is opt-in: forge no longer deletes a runner's toolchains
unless the project asks.

## Changes

- `release.yml` and `release-piece.yml` take an optional `free_runner_disk`
  input. The `build` and `binary` jobs delete the Linux runner's preinstalled
  toolchains only when it is `true`, for a large build on GitHub's stock
  runner (about 14 GB free). The check on the runner label is gone.
- np's emitted `release.yml` passes it from the `NP_FREE_RUNNER_DISK`
  variable; the README lists it beside the cache and runner settings.

## Validation

- actionlint passes on every workflow.
- v0.1.10's CI run fetched rustc, cargo, rust-std and clippy from
  nix-community.cachix.org on a real runner.

## Previous Release

v0.1.10
