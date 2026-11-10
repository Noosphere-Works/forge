# Contributing

forge's product is `flake.lib` (`lib/`). The root `flake.nix` is the check harness: it instantiates the recipes against `fixture/` and asserts names, versions and `drvPath`s.

## Layout

- `lib/` — the recipes a project calls as `forge.lib`.
- `fixture/` — a Cargo workspace (`crate/tool`, a CLI whose test runs `git --version`; `crate/declared`, a CLI that declares `linux-x86_64` and `darwin-aarch64` under `[package.metadata.np] targets` in its `Cargo.toml`; `crate/shared`, a library) and a bun workspace (`package/api`, a backend; `package/shared`, a library). `fixture/invalid/crate/` holds manifests outside the workspace whose declarations `lib.rust.cli` refuses.
- `piece/forge/` — the releasable piece: `piece.toml`, and notes under `release/`.
- `flake.nix` — `checks` for each system in `systems`, plus `packages.forge` and empty `legacyPackages.npRelease.forge.targets` so `np release` can publish the note. `nixpkgs` here serves the checks, the formatter and fenix; a project passes its own `pkgs`.
- `.github/workflows/` — `check.yml` for the harness; `release.yml` and `release-piece.yml` are the reusable release workflows a project calls at the forge tag it pins. This repository dispatches `release.yml` locally.

## Checks

`nix flake check` builds `fixture/` through the recipes on the runner's system: the CLI runs, the libraries build, the four Rust checks pass with a dev shell that provides git, and the backend's bundle prints its greeting. The release targets (every target for `tool`, the manifest's for `declared`, an explicit `targets` argument over the manifest's, and the refused declarations), the TypeScript lint checks, a web's backend URLs, the tools and (on `x86_64-linux`) the images are evaluated, not built.

CI is Ubuntu. After `nix flake check` it evaluates `checks.<system>.rust-release-targets` for every system the flake names, so the Linux table (`linux-x86_64`, `windows-x86_64`) and the Darwin table (`darwin-aarch64`, `darwin-x86_64`) both instantiate. Packing those archives is `np release` on a consumer: the job inspects ISA, static linking, `/nix/store` links and Darwin signatures, and does not run the packed binary. `x86_64-darwin` is not a system: nixpkgs unstable no longer instantiates it; the Intel Mac archive is `darwin-x86_64` on Apple Silicon.

## Versions

The releasable piece is `piece/forge/piece.toml`. `np release draft forge <level>` bumps that version and writes `piece/forge/release/vX.Y.Z/note.md`. The Git tag is `vX.Y.Z`. A release publishes that note; it ships no archives. np pins the tag in the input it emits. A project's `.github/workflows/release.yml` calls this repository's `release.yml` at that same tag (`uses: noosphere-works/forge/.github/workflows/release.yml@<tag>`). `release-piece.yml` stays here: a relative `uses:` inside the called workflow resolves to this repository at that ref. `actions/checkout` in those jobs checks out the calling project.

The release workflows take one secret, `NP_GIT_TOKEN`, optional (README, Release). `release.yml` declares it, uses it in `plan` and passes only it to `release-piece.yml`, which uses it in `build` and `binary` and never in `publish`. A step that runs Nix on the project sets it, when it is not empty, as git's env config (`GIT_CONFIG_COUNT`, a `url.<token URL>.insteadOf` rewrite) and as `NIX_CONFIG`'s `access-tokens`, then unsets the variable. Both are needed: Nix's git fetcher (crane's `builtins.fetchGit` of a cargo git dependency) ignores `access-tokens`, and the `github:` fetcher ignores git's config. This repository has no such secret, so its own dispatch runs without it. On Linux runners, the `build` and `binary` jobs first delete preinstalled toolchains no forge job uses (dotnet, Android, GHC, Swift, Boost, the hosted tool cache) so crane's dependency build has the disk to finish; macOS runners skip that step.

## Image workflow

np's image workflow builds `lib.image` from the released commit, with the forge its project pins:

```sh
nix build --impure --expr '
  let flake = builtins.getFlake (builtins.getEnv "FLAKE"); in
  flake.inputs.forge.lib.image {
    inherit flake;
    piece = builtins.getEnv "PIECE";
    kind = builtins.getEnv "KIND";
    port = builtins.getEnv "PORT";
    site = builtins.getEnv "SITE";
  }'
```
