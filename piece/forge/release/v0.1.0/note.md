## Summary

First published release of forge: np's project recipes for Nix, so a project flake calls `forge.lib` instead of carrying crane, fenix, bunix, and the portable-binary and image recipes inline.

## Changes

- `lib.rust`: Cargo workspace, CLI (`linux-x86_64`, `windows-x86_64` on `x86_64-linux`; `darwin-aarch64` on `aarch64-darwin`), backend, library, and workspace checks.
- `lib.typescript`: bun workspace, web, backend, library, `backendUrls`, and oxlint/oxfmt checks.
- `lib.tools` and `lib.postgres`: fetched prebuilt tools and PostgreSQL 17.
- `lib.image`: OCI images for `rust-backend`, `typescript-backend`, and `web` on `x86_64-linux`.
- A project pins `github:noosphere-works/forge/v0.1.0`. np moves that tag when it moves a recipe.

## Validation

- `nix flake check` on `x86_64-linux` is clean at this tag.

## Previous Release

None
