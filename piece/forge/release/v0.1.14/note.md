## Summary

`tools.supabase` installs the Supabase CLI release that np prescribes. The
3.1.0 release tarballs hold only `supabase`, and forge still copied
`supabase-go`, so a dev shell with Supabase 3.1.0 failed to build.

## Changes

- `tools.supabase` installs only the `supabase` binary.
- A new `supabase` check builds the CLI from np's 3.1.0 pins and requires
  `supabase --version` to print `3.1.0`, on `x86_64-linux` and
  `aarch64-darwin`. A change to the tarball's layout now fails forge's checks.

## Validation

- `nix flake check` passes on `aarch64-darwin`, including the new check,
  which built the macOS tarball and ran it.
- forge's CI runs the same check on `x86_64-linux`.

## Previous Release

v0.1.13
