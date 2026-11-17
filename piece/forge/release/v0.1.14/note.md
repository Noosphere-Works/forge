## Summary

`tools.supabase` installs the Supabase CLI release that np prescribes. The
3.1.0 release tarballs hold only `supabase`, and forge still copied
`supabase-go`, so a dev shell with Supabase 3.1.0 failed to build. On Linux
the binary also now runs under Nix's glibc.

## Changes

- `tools.supabase` installs only the `supabase` binary.
- On Linux, `autoPatchelfHook` points the binary (a bun-compiled glibc
  executable) at Nix's loader instead of `/lib64/ld-linux-x86-64.so.2`, which
  Nix's build sandbox and NixOS lack. The binary stays unstripped.
- A new `supabase` check builds the CLI from np's 3.1.0 pins and requires
  `supabase --version` to print `3.1.0`, on `x86_64-linux` and
  `aarch64-darwin`. A change to the tarball's layout now fails forge's checks.

## Validation

- `nix flake check` passes on `aarch64-darwin`, including the new check,
  which built the macOS tarball and ran it.
- forge's CI passes on `x86_64-linux`, where the check built the Linux
  tarball, patched its loader and ran it.

## Previous Release

v0.1.13
