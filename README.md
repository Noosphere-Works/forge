# forge

forge holds np's project recipes for Nix: how a project np emits builds its
Rust crates, its TypeScript packages, its release binaries, its dev-shell
tools and its deploy images. The `flake.nix` np emits calls `forge.lib`
instead of carrying the recipes inline, so every project builds the same way
and a fix lands in one place.

forge moves with np. np pins forge by tag in the input it emits, and a change
to a recipe is a new forge tag that the np release emitting it pins.

## Usage

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    forge = {
      url = "github:noosphere-works/forge/v0.1.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ flake-parts, forge, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem =
        {
          pkgs,
          self',
          system,
          ...
        }:
        let
          inherit (forge.lib) rust typescript;

          # The Cargo workspace: `Cargo.toml` at the root, crates in `crate/`.
          workspace = rust.workspace {
            inherit pkgs system;
            root = ./.;
          };
          cli = rust.cli {
            inherit workspace;
            crate = "cli";
          };
          agnostic = rust.library {
            inherit workspace;
            crate = "agnostic";
          };

          # The bun workspace: `bun.lock` at the root, packages in `package/`.
          bun = typescript.workspace {
            inherit pkgs;
            root = ./.;
          };
          site = typescript.web {
            workspace = bun;
            package = "site";
            backendUrls = typescript.backendUrls {
              inherit pkgs;
              backends = [
                {
                  key = "VITE_SITE_API_URL";
                  config = ./crate/api/deploy/fly.toml;
                }
              ];
            };
          };
          # `typescript-agnostic`: the Rust crate `agnostic` owns the plain name.
          typescriptAgnostic = typescript.library {
            workspace = bun;
            package = "agnostic";
          };
        in
        {
          packages = {
            default = workspace.defaultPackage;
            cli = cli.package;
            agnostic = agnostic.package;
            site = site.package;
            ${typescriptAgnostic.name} = typescriptAgnostic.package;
          };
          legacyPackages.npRelease.cli = cli.release;

          checks = rust.checks {
            inherit workspace;
            # The tests run with the dev shell's inputs, such as git and jj.
            devShell = self'.devShells.default;
            defaultPackage = self'.packages.default;
          };

          # The dev shell is the project's own; forge gives it the toolchains.
          devShells.default = pkgs.mkShell {
            packages = [
              workspace.toolchain
              bun.toolchain
              pkgs.git
              pkgs.jujutsu
            ];
          };

          formatter = pkgs.nixfmt;
        };
    };
}
```

Every recipe builds with the `pkgs` you pass, for the `system` you pass. forge
brings its own crane, fenix and bunix, so a project declares none of them;
forge's `flake.lock` pins them, and with them the Rust toolchain. A project
can still override one, as `forge.inputs.fenix.follows = "fenix"`.

## Rust

`lib.rust.workspace { pkgs, system, root, crateDir ? "crate" }` is the Cargo
workspace at `root`:

- `toolchain`: fenix's stable `cargo`, `clippy`, `rust-analyzer`, `rust-src`
  and `rustc`, with nightly `rustfmt`. Put it in the dev shell.
- `craneLib`: crane with `toolchain`.
- `src`: `root` cleaned, keeping crane's Cargo sources and everything under
  `<crateDir>/<crate>/src/` and `<crateDir>/<crate>/tests/` (the templates
  and fixtures a crate embeds or reads).
- `commonArgs`: `{ src; strictDeps = true; doCheck = false; }`. Packages build
  without running the tests; the `test` check runs them.
- `cargoArtifacts`: the workspace's dependencies, built with `doCheck = true`
  so the checks reuse them.
- `defaultPackage`: the whole workspace, `craneLib.buildPackage`.
- `windows` and `musl`: `{ pkgs, toolchain, craneLib, commonArgs }` for the
  `x86_64-pc-windows-gnu` (mingw, msvcrt) and static `x86_64-unknown-linux-musl`
  cross builds. The cross `pkgs` import the nixpkgs your `pkgs` comes from.
- `pkgs`, `system`, `root`, `crateDir`, `fenixPkgs`: what the pieces below read.

Each piece builds `--locked --package <crate>` from the whole workspace with
`cargoArtifacts`, versioned from `<crateDir>/<crate>/Cargo.toml` at evaluation
time (`0.0.0` when the crate inherits the workspace's version):

- `lib.rust.cli { workspace, crate }` returns `{ package, release.targets }`.
  `release.targets` are the portable binaries for the build system:
  `linux-x86_64` (static musl) and `windows-x86_64` (mingw) on
  `x86_64-linux`, `darwin-aarch64` on `aarch64-darwin` (the store's libiconv
  relinked to macOS's own and the binary re-signed, so it runs without Nix),
  none elsewhere. Expose them under `legacyPackages`, which `nix flake check`
  neither builds nor recurses into.
- `lib.rust.backend { workspace, crate }` returns `{ package }`.
- `lib.rust.library { workspace, crate }` returns `{ package }`, which
  installs nothing.

`lib.rust.checks { workspace, devShell, defaultPackage ? workspace.defaultPackage }`
returns `{ build, clippy, fmt, test }`: `build` is `defaultPackage`, `clippy`
runs `--all-targets --all-features -- --deny warnings`, `fmt` runs
`cargo fmt --check`, and `test` runs the tests with
`devShell.nativeBuildInputs`.

## TypeScript

`lib.typescript.workspace { pkgs, root, exclude ? [ ".types" ], packageDir ? "package" }`
is [bunix](https://github.com/noosphere-works/bunix)'s
`lib.workspace { pkgs, root, exclude }` (`nodeModules`, `members`, `src`,
`mkDerivation`, `bunArgs`, `copyNodeModules`) plus:

- `toolchain`: `bun`, `nodejs` (for the `#!/usr/bin/env node` shims) and
  `typescript-language-server`. Put it in the dev shell.
- `pkgs`, `root`, `packageDir`: what the pieces below read. A package's
  directory is `<packageDir>/<package>`, and it must be a workspace member.

Each piece builds in its own copy of the workspace with the `node_modules`
tree `bun.lock` names copied in, versioned from its `package.json` at
evaluation time (`0.0.0` when it declares none):

- `lib.typescript.web { workspace, package, backendUrls ? { } }` returns
  `{ package }`: the Vite production build (Vite's own
  `node_modules/vite/bin/vite.js`, as Vike expects), `dist` as `$out` without
  `client/.vite` and `assets.json`. Each `backendUrls` attribute is set in the
  build's environment.
- `lib.typescript.backend { workspace, package }` returns `{ package }`:
  `bun build <dir>/src/index.ts --target=bun`, the bundle in `$out`.
- `lib.typescript.library { workspace, package, root ? workspace.root, crateDir ? "crate" }`
  returns `{ name, package }`: a `tsc --build` type check that installs
  nothing. `name` is `typescript-<package>` where
  `<root>/<crateDir>/<package>/Cargo.toml` exists, so the Rust crate keeps the
  plain name, and `<package>` otherwise.
- `lib.typescript.backendUrls { pkgs, backends }`, with `backends` a list of
  `{ key; config; }`, returns `{ <key> = "https://<app>.fly.dev"; }` for each
  backend whose `config` (its committed `deploy/fly.toml`) names an `app`. A
  backend without one is left out.
- `lib.typescript.checks { pkgs, root }` returns `{ typescript-build,
  typescript-check }`: oxlint with type checking, and oxfmt. They run
  `bun install --frozen-lockfile`, so they need the network.

## Tools

`lib.postgres { pkgs }` is PostgreSQL 17 with pgTAP and plpgsql_check.

`lib.tools.fetched { pkgs, pname, version, sources, install, stdenv ? pkgs.stdenv, ... }`
fetches the artefact `sources` names for the host system and runs `install`
as its `installPhase`. `sources` is `{ "<system>" = { url; sha256; }; }`; a
host without an entry stops evaluation with
`Unsupported system for <pname>: <system>`. Every other attribute goes to the
derivation.

On top of it, each with `{ pkgs, version, sources }`:

- `lib.tools.surrealdb`: `bin/surreal`.
- `lib.tools.surrealist`: the app (macOS) or AppImage (Linux) as
  `bin/surrealist`.
- `lib.tools.surrealkit`: `bin/surrealkit`.
- `lib.tools.supabase`: `bin/supabase` and `bin/supabase-go`.

```nix
surrealdb = forge.lib.tools.surrealdb {
  inherit pkgs;
  version = "3.3.4";
  sources = {
    aarch64-darwin = {
      url = "https://github.com/surrealdb/surrealdb/releases/download/v3.3.4/surreal-v3.3.4.darwin-arm64.tgz";
      sha256 = "sha256-0LCvxHlIpGzqydsXjSoQp+sh4cTyGadLNXPIUBIu2fs=";
    };
    x86_64-linux = {
      url = "https://github.com/surrealdb/surrealdb/releases/download/v3.3.4/surreal-v3.3.4.linux-amd64.tgz";
      sha256 = "sha256-ZZMHGDOtnIXPUzz3CxZD6wiWbIaPhiQAHjCDnqKaJok=";
    };
  };
};
```

## Image

`lib.image { flake, piece, kind, port, site ? null }` is the OCI image Fly
runs for a piece, built for `x86_64-linux` with
`dockerTools.streamLayeredImage`:

- `flake`: the project's flake. `image` reads only `flake.inputs.nixpkgs`
  and `flake.packages.x86_64-linux.<name>`, so any attribute set of that
  shape will do.
- `piece`: the package to run.
- `kind`: `rust-backend` (runs `bin/<piece>`), `typescript-backend` (runs
  `index.js` with bun) or `web` (static-web-server on the package's
  `client`).
- `port`: the port, set as `<PIECE>_PORT`.
- `site`: for a backend, the web package it serves from its own origin, set
  as `<PIECE>_SITE_ROOT`. `null` or `""` for none.

np's image workflow builds it from the released commit, with the forge its
project pins:

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

## Versions

This is `v0.1.0`. np pins forge by tag in the input it emits
(`github:noosphere-works/forge/v0.1.0`), and moves the tag when it moves a
recipe.

## Checks

`nix flake check` builds `fixture/`, a Cargo workspace (`crate/tool`, a CLI
whose test runs `git --version`; `crate/shared`, a library) and a bun
workspace (`package/api`, a backend; `package/shared`, a library), through
the recipes: the CLI runs, the libraries build, the four Rust checks pass
with a dev shell that provides git, and the backend's bundle prints its
greeting. The release targets, the TypeScript lint checks, a web's backend
URLs, the tools and (on `x86_64-linux`) the images are evaluated, not built.

## License

MIT, see [LICENSE.md](LICENSE.md).
