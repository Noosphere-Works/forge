## Summary

forge's TypeScript recipes use bunix v0.3.0, which builds a bun workspace's
`node_modules` with bun's own installer, so the tree is the one `bun install`
writes on a developer's machine.

## Changes

- The `node_modules` tree is written by `bun install --frozen-lockfile
  --linker hoisted --ignore-scripts`. Nix still fetches every tarball by the
  lock's integrity hash, and the build serves them to bun on 127.0.0.1; it
  needs no network.
- A web package no longer gets the `@emnapi`, `@napi-rs` and `@tybys`
  packages that only the wasm32-wasi Tailwind bindings use; bun leaves them
  out too.
- A lock entry pinned to a registry other than `registry.npmjs.org` now stops
  evaluation with a `bunix:` message.

## Validation

- bunix's checks pass in Nix's sandbox on Ubuntu and macOS.
- A web package with `@playwright/test` built through bunix v0.3.0, and its
  `node_modules` matched bun 1.4.2's hoisted install of the same lock file
  for file, apart from the patched `#!` lines of its 22 bin files.
- forge's `nix flake check` passes with bunix v0.3.0.

## Previous Release

v0.1.12
