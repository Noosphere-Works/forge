## Summary

A release of a project with a large Rust dependency tree no longer runs out of
disk on GitHub's stock `ubuntu-latest` runner. The release jobs free disk
before Nix is installed.

## Changes

- `release-piece.yml`: the `build` and `binary` jobs start with a "Free runner
  disk" step, before `actions/checkout`, that runs only on Linux runners. It
  prints `df -h /` before and after and removes, with `sudo rm -rf`, the
  preinstalled toolchains no forge job uses: `/usr/share/dotnet`,
  `/usr/local/lib/android`, `/opt/ghc`, `/usr/local/.ghcup`,
  `/opt/hostedtoolcache`, `/usr/share/swift` and `/usr/local/share/boost`.
  macOS runners skip it.
- CONTRIBUTING.md mentions the cleanup next to the release workflows' secret.

## Validation

- `actionlint` (through `nix run nixpkgs#actionlint`) passes on
  `release-piece.yml`, `release.yml` and `check.yml`.
- Not yet run on a real runner: console's `nc` release is the proof still to
  come.

## Previous Release

v0.1.8
