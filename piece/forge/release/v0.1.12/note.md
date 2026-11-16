## Summary

forge's TypeScript recipes use bunix v0.2.1, which installs a bun lock's
packages as bun's hoisted installer does. A web package that depends on
`@playwright/test` now builds instead of failing on its `playwright` bin.

## Changes

- When packages in one `node_modules` declare the same bin name, the link
  goes to the package whose folder name sorts first, as bun does. Before,
  the node-modules build stopped with "two packages install bin".
- A package's bins keep the lock's order. A string `bin` is named after the
  dependency's folder (the alias, unscoped). Keys are cut after their last
  `/`, `\` or `:`. A target that leaves the package is dropped silently.
- A bin whose target is a directory is linked.
- Tarballs are extracted as bun extracts them: only regular files are
  written, so symlinks, devices and empty directories in a tarball are
  left out.

## Validation

- bunix's checks compare each rule against real `bun install --linker
  hoisted` output from bun 1.4.2.
- A web package with `@playwright/test` built through bunix v0.2.1, and its
  `.bin` links matched bun's install of the same lock.
- forge's `nix flake check` passes with bunix v0.2.1.

## Previous Release

v0.1.11
