{
  description = "forge: np's project recipes for Nix";

  # `lib` builds with the `pkgs` its caller passes. It uses forge's own crane,
  # fenix and bunix, so a project declares none of them; nixpkgs here serves
  # the checks, the formatter and fenix.
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    crane.url = "github:ipetkov/crane";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    bunix = {
      url = "github:noosphere-works/bunix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-parts.follows = "flake-parts";
    };
  };

  outputs =
    inputs@{ flake-parts, nixpkgs, ... }:
    let
      lib = import ./lib { inherit inputs; };
    in
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];

      flake.lib = lib;

      perSystem =
        { pkgs, system, ... }:
        let
          inherit (lib)
            rust
            typescript
            postgres
            tools
            image
            ;

          # An assertion that names what it expected when it fails.
          expect =
            name: actual: expected:
            actual == expected
            || throw "forge check ${name}: expected ${builtins.toJSON expected}, got ${builtins.toJSON actual}";

          # An eval-only check: it holds when its assertions do, and builds
          # nothing else.
          evaluated = name: pkgs.runCommand name { } "touch $out";

          drvPaths = attrs: builtins.all (drv: builtins.isString drv.drvPath) (builtins.attrValues attrs);

          # `fixture/`, a Cargo workspace (`crate/tool`, a CLI; `crate/shared`,
          # a library) and a bun workspace (`package/api`, a backend;
          # `package/shared`, a library).
          root = ./fixture;

          workspace = rust.workspace { inherit pkgs system root; };
          tool = rust.cli {
            inherit workspace;
            crate = "tool";
          };
          shared = rust.library {
            inherit workspace;
            crate = "shared";
          };
          # The fixture's dev shell: `tool`'s test runs `git --version`, so the
          # `test` check passes only with the shell's inputs.
          devShell = pkgs.mkShell {
            packages = [
              workspace.toolchain
              pkgs.git
            ];
          };
          rustChecks = rust.checks { inherit workspace devShell; };
          # The release targets of `tool` on each build system.
          targets =
            {
              aarch64-darwin = [ "darwin-aarch64" ];
              aarch64-linux = [ ];
              x86_64-linux = [
                "linux-x86_64"
                "windows-x86_64"
              ];
            }
            .${system};

          bun = typescript.workspace { inherit pkgs root; };
          api = typescript.backend {
            workspace = bun;
            package = "api";
          };
          sharedLibrary = typescript.library {
            workspace = bun;
            package = "shared";
          };
          typescriptChecks = typescript.checks { inherit pkgs root; };
          # A web build of `api`, eval-only: the backend URLs reach the build as
          # environment attributes. One backend has a `fly.toml`, one has none.
          backendUrls = typescript.backendUrls {
            inherit pkgs;
            backends = [
              {
                key = "VITE_API_TOOL_URL";
                config = builtins.toFile "fly.toml" "app = \"forge-tool\"\n";
              }
              {
                key = "VITE_API_MISSING_URL";
                config = root + "/crate/tool/deploy/fly.toml";
              }
            ];
          };
          web = typescript.web {
            workspace = bun;
            package = "api";
            inherit backendUrls;
          };

          fake = {
            url = "https://example.invalid/probe-${system}.tar.gz";
            sha256 = pkgs.lib.fakeHash;
          };
          probe =
            sources:
            tools.fetched {
              inherit pkgs sources;
              pname = "probe";
              version = "0.0.0";
              install = "mkdir -p $out";
            };
          missing = builtins.tryEval (probe { not-a-system = fake; }).drvPath;
          toolsFor =
            sources:
            builtins.mapAttrs
              (
                _: tool:
                tool {
                  inherit pkgs sources;
                  version = "0.0.0";
                }
              )
              {
                inherit (tools)
                  surrealdb
                  surrealist
                  surrealkit
                  supabase
                  ;
              };

          # What `image` reads of a flake: `inputs.nixpkgs` and
          # `packages.x86_64-linux`. `site` stands in for a web's build.
          imageFlake = {
            inputs = { inherit nixpkgs; };
            packages.x86_64-linux = {
              tool = tool.package;
              api = api.package;
              site = pkgs.runCommand "site" { } "mkdir -p $out/client";
            };
          };
          images = {
            rust-backend = image {
              flake = imageFlake;
              piece = "tool";
              kind = "rust-backend";
              port = "3000";
            };
            rust-backend-with-site = image {
              flake = imageFlake;
              piece = "tool";
              kind = "rust-backend";
              port = "3000";
              site = "site";
            };
            typescript-backend = image {
              flake = imageFlake;
              piece = "api";
              kind = "typescript-backend";
              port = 3000;
            };
            web = image {
              flake = imageFlake;
              piece = "site";
              kind = "web";
              port = "8080";
            };
          };
          unknownKind =
            builtins.tryEval
              (image {
                flake = imageFlake;
                piece = "tool";
                kind = "cli";
                port = "3000";
              }).drvPath;
        in
        {
          checks = {
            # `tool` builds at its manifest's version and runs.
            rust-tool =
              assert expect "rust-tool version" tool.package.version "0.1.0";
              pkgs.runCommand "rust-tool" { } ''
                version=$(${tool.package}/bin/tool --version)
                [ "$version" = "tool 0.1.0" ] || { echo "tool --version printed: $version" >&2; exit 1; }
                touch $out
              '';

            # The library builds and installs nothing.
            rust-shared = shared.package;

            # The workspace's `build`, `clippy`, `fmt` and `test`; `test` needs
            # git from the dev shell.
            rust-checks =
              assert expect "rust-checks names" (builtins.attrNames rustChecks) [
                "build"
                "clippy"
                "fmt"
                "test"
              ];
              pkgs.linkFarm "rust-checks" rustChecks;

            # Eval-only: `tool`'s release targets for this system.
            rust-release-targets =
              assert expect "rust-release-targets" (builtins.attrNames tool.release.targets) targets;
              assert drvPaths tool.release.targets;
              evaluated "rust-release-targets";

            # The backend's bundle runs under bun and prints the greeting it
            # imports from the `shared` workspace member.
            typescript-api =
              assert expect "typescript-api name" api.package.name "api-0.2.0";
              pkgs.runCommand "typescript-api" { nativeBuildInputs = [ pkgs.bun ]; } ''
                export HOME=$TMPDIR
                output=$(bun ${api.package}/index.js)
                [ "$output" = "hello" ] || { echo "the api bundle printed: $output" >&2; exit 1; }
                touch $out
              '';

            # `tsc --build` type-checks the library. `crate/shared` also
            # exists, so its package is `typescript-shared`; `api` has no
            # crate and keeps its plain name.
            typescript-shared =
              assert expect "typescript-shared name" sharedLibrary.name "typescript-shared";
              assert expect "typescript library plain name"
                (typescript.library {
                  workspace = bun;
                  package = "api";
                }).name
                "api";
              sharedLibrary.package;

            # Eval-only: a web build carries each backend URL in its
            # environment, and leaves out a backend without `deploy/fly.toml`.
            typescript-web =
              assert expect "typescript-web backendUrls" backendUrls {
                VITE_API_TOOL_URL = "https://forge-tool.fly.dev";
              };
              assert expect "typescript-web environment" web.package.VITE_API_TOOL_URL
                "https://forge-tool.fly.dev";
              assert builtins.isString web.package.drvPath;
              evaluated "typescript-web";

            # Eval-only: the lint and format checks need the network.
            typescript-checks =
              assert expect "typescript-checks names" (builtins.attrNames typescriptChecks) [
                "typescript-build"
                "typescript-check"
              ];
              assert drvPaths typescriptChecks;
              evaluated "typescript-checks";

            # Eval-only: `fetched` picks this system's artefact and refuses a
            # system without one; each tool, and postgres, evaluates.
            tools =
              assert expect "tools url" (probe { ${system} = fake; }).src.url fake.url;
              assert expect "tools missing system" missing.success false;
              assert drvPaths (toolsFor {
                ${system} = fake;
              });
              assert builtins.isString (postgres { inherit pkgs; }).drvPath;
              evaluated "tools";
          }
          // pkgs.lib.optionalAttrs (system == "x86_64-linux") {
            # Eval-only: the image of each kind, and a refused kind.
            image =
              assert drvPaths images;
              assert expect "image unknown kind" unknownKind.success false;
              evaluated "image";
          };

          formatter = pkgs.nixfmt;
        };
    };
}
