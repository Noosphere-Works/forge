## Summary

A release builds little but what changed. The Rust toolchain comes prebuilt,
the dependency build survives version bumps, and a project can give the jobs
its own Nix binary cache and runners.

## Changes

- fenix keeps its own nixpkgs, pinned at a revision nix-community.cachix.org
  has built, and the release jobs and `check.yml` trust that cache, so cargo,
  clippy, rustc and rust-std are fetched instead of assembled. Release builds
  use only those components; the cross targets add their `rust-std`.
- The dependency build (`cargoArtifacts`, and each cross target's) sees every
  workspace member at version 0.0.0, at evaluation time, and is vendored from
  the real source: a version bump leaves its derivation unchanged.
- `release.yml` and `release-piece.yml` take optional `nix_cache`,
  `nix_cache_public_key`, `linux_runner` and `macos_runner` inputs and the
  optional `NP_NIX_CACHE_ACCESS_KEY_ID`, `NP_NIX_CACHE_SECRET_ACCESS_KEY` and
  `NP_NIX_CACHE_SIGNING_KEY` secrets. With them the jobs read the cache, and a
  post-build hook signs and uploads what they build. A `blacksmith-` runner
  skips freeing runner disk. Without them, nothing changes.

## Validation

- Station's releases `8b9f324d` and `fd1aeb3a`, which differ only in
  versions, give the same dependency derivation for x86_64-linux, the static
  musl target and aarch64-darwin. A local build at one reuses the other's
  dependencies and compiles only the workspace's own crates.
- The toolchain components forge's lock selects answer 200 from
  nix-community.cachix.org for x86_64-linux and aarch64-darwin.
- The cache step, run outside Actions with and without the settings, writes
  the expected Nix configuration, credentials and upload hook.
- `nix flake check` and actionlint pass. Not yet run on a real runner: the
  first release that uses it is the proof.

## Previous Release

v0.1.9
