## Summary

A CLI can declare its release targets in its own `Cargo.toml`.
`lib.rust.cli` reads `[package.metadata.np] targets` when no `targets`
argument is passed.

## Changes

- `lib.rust.cli { workspace, crate, targets ? }`: an explicit `targets`
  wins; otherwise the crate's `[package.metadata.np] targets`; with neither,
  every archive the build system offers.
- An empty list, or a value that is not a list of strings, stops evaluation
  and names the valid targets (`darwin-aarch64`, `darwin-x86_64`,
  `linux-x86_64`, `windows-x86_64`). An unknown name still stops it.
- `release.yml` takes the run title np dispatches (`title`), and names its run with it.

## Validation

- `rust-release-targets` asserts a fixture CLI's declared targets on the
  Linux and Darwin tables, an argument overriding them, and the refused
  declarations.

## Previous Release

v0.1.6
