# Contributing

forge's product is `flake.lib` (`lib/`). The root `flake.nix` is the check harness: it instantiates the recipes against `fixture/` and asserts names, versions and `drvPath`s.

## Layout

- `lib/` — the recipes a project calls as `forge.lib`.
- `fixture/` — a Cargo workspace (`crate/tool`, a CLI whose test runs `git --version`; `crate/shared`, a library) and a bun workspace (`package/api`, a backend; `package/shared`, a library).
- `flake.nix` — `checks` for each system in `systems`. `nixpkgs` here serves the checks, the formatter and fenix; a project passes its own `pkgs`.

## Checks

`nix flake check` builds `fixture/` through the recipes on the runner's system: the CLI runs, the libraries build, the four Rust checks pass with a dev shell that provides git, and the backend's bundle prints its greeting. The release targets, the TypeScript lint checks, a web's backend URLs, the tools and (on `x86_64-linux`) the images are evaluated, not built.

CI is Ubuntu. After `nix flake check` it evaluates `checks.<system>.rust-release-targets` for every system the flake names, so the Linux table (`linux-x86_64`, `windows-x86_64`) and the Darwin table (`darwin-aarch64`, `darwin-x86_64`) both instantiate. Packing and smoking those archives is `np release` on a consumer. `x86_64-darwin` is not a system: nixpkgs unstable no longer instantiates it; the Intel Mac archive is `darwin-x86_64` on Apple Silicon.

## Versions

This is `v0.1.0`. np pins forge by tag in the input it emits (`github:noosphere-works/forge/v0.1.0`). A change to a recipe is a new forge tag that the np release emitting it pins.

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
