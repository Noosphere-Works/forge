## Summary

A project whose flake fetches a private github.com repository, such as a cargo
git dependency crane vendors from `Cargo.lock`, can release. The release
workflows take one optional secret, `NP_GIT_TOKEN`.

## Changes

- `release.yml` and `release-piece.yml` declare `NP_GIT_TOKEN` as an optional
  `workflow_call` secret. `plan`, `build` and `binary` use it; `release.yml`
  passes only it to `release-piece.yml`; `publish` never receives it and keeps
  the run's own token.
- A step that runs Nix on the project sets it, when it is not empty, as git's
  `url.https://x-access-token:<token>@github.com/.insteadOf` rewrite (through
  `GIT_CONFIG_COUNT`) and as `NIX_CONFIG`'s `access-tokens`, for that step only.
  Without it, the jobs run as before.
- The README documents the token: fine-grained, read-only Contents on the
  private repositories, stored as an Actions secret.

## Validation

- In an isolated environment (fresh `HOME`, no system git config, no
  credential helper), crane's `builtins.fetchGit` of a private tag fails
  without the step's configuration and succeeds with it; `access-tokens` alone
  does not carry it, the git rewrite does. A `github:` fetch needs
  `access-tokens`. A scratch workspace depending on that tag builds through
  `lib.rust.cli` with it.

## Previous Release

v0.1.7
