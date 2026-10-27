# The Rust recipes: a Cargo workspace built with crane and a fenix toolchain,
# and each crate's piece. np's `rust/` and `piece/rust-*.nix` flake fragments,
# with the crate's name as an argument.
{ inputs }:
let
  # A crate's own build arguments: `--package <crate>` from the whole
  # workspace source with the workspace's shared dependency artifacts.
  pieceArgs =
    workspace: crate:
    let
      manifest = builtins.fromTOML (
        builtins.readFile (workspace.root + "/${workspace.crateDir}/${crate}/Cargo.toml")
      );
      version = manifest.package.version or null;
    in
    workspace.commonArgs
    // {
      inherit (workspace) cargoArtifacts;
      pname = crate;
      # The crate's own version, read at evaluation time; `0.0.0` when it
      # inherits the workspace's.
      version = if builtins.isString version then version else "0.0.0";
      cargoExtraArgs = "--locked --package ${crate}";
      cargoTestExtraArgs = "--package ${crate}";
    };
in
{
  # The Cargo workspace at `root`, its crates under `crateDir`, built for
  # `system` with `pkgs`.
  workspace =
    {
      pkgs,
      system,
      root,
      crateDir ? "crate",
    }:
    let
      fenixPkgs = inputs.fenix.packages.${system};
      toolchain = fenixPkgs.combine [
        (fenixPkgs.stable.withComponents [
          "cargo"
          "clippy"
          "rust-analyzer"
          "rust-src"
          "rustc"
        ])
        fenixPkgs.complete.rustfmt
      ];
      craneLib = (inputs.crane.mkLib pkgs).overrideToolchain toolchain;
      src = pkgs.lib.cleanSourceWith {
        name = "source";
        src = pkgs.lib.cleanSource root;
        # Keep the sources and fixtures each crate embeds or reads (templates,
        # SurrealQL, guides) beside the cargo files: all of its `src/` and `tests/`.
        filter =
          path: type:
          craneLib.filterCargoSources path type
          || builtins.match ".*/${pkgs.lib.escapeRegex crateDir}/[^/]+/(src|tests)/.*" path != null;
      };
      commonArgs = {
        inherit src;
        strictDeps = true;
        # Packages build without running the tests; `checks.test` runs them.
        doCheck = false;
      };
      cargoArtifacts = craneLib.buildDepsOnly (
        commonArgs
        // {
          # The dependencies build for the tests too, so the checks reuse them.
          doCheck = true;
        }
      );
      # The cross targets import the nixpkgs `pkgs` comes from, as np's
      # fragments import the project's `nixpkgs` input.
      windowsPkgs = import pkgs.path {
        localSystem = system;
        crossSystem = {
          config = "x86_64-w64-mingw32";
          libc = "msvcrt";
        };
      };
      windows-toolchain = fenixPkgs.combine [
        fenixPkgs.stable.toolchain
        fenixPkgs.targets."x86_64-pc-windows-gnu".stable.rust-std
      ];
      muslPkgs = import pkgs.path {
        localSystem = system;
        crossSystem = {
          config = "x86_64-unknown-linux-musl";
          isStatic = true;
        };
      };
      musl-toolchain = fenixPkgs.combine [
        fenixPkgs.stable.toolchain
        fenixPkgs.targets."x86_64-unknown-linux-musl".stable.rust-std
      ];
    in
    {
      inherit
        pkgs
        system
        root
        crateDir
        fenixPkgs
        toolchain
        craneLib
        src
        commonArgs
        cargoArtifacts
        ;
      windows = {
        pkgs = windowsPkgs;
        toolchain = windows-toolchain;
        craneLib = (inputs.crane.mkLib windowsPkgs).overrideToolchain (_: windows-toolchain);
        commonArgs = {
          inherit src;
          CARGO_BUILD_TARGET = "x86_64-pc-windows-gnu";
          strictDeps = true;
          doCheck = false;
        };
      };
      musl = {
        pkgs = muslPkgs;
        toolchain = musl-toolchain;
        craneLib = (inputs.crane.mkLib muslPkgs).overrideToolchain (_: musl-toolchain);
        commonArgs = {
          inherit src;
          CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
          CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
          strictDeps = true;
          doCheck = false;
        };
      };
      defaultPackage = craneLib.buildPackage (
        commonArgs
        // {
          inherit cargoArtifacts;
        }
      );
    };

  # A command-line crate: its build, and the portable binaries released for
  # it on the build system.
  cli =
    { workspace, crate }:
    let
      inherit (workspace)
        pkgs
        system
        craneLib
        windows
        musl
        ;
      args = pieceArgs workspace crate;
      # The cross targets build the crate's own dependencies (crane's default
      # `cargoArtifacts`), so no other crate's dependencies need to cross.
      crossArgs = {
        inherit (args) pname version cargoExtraArgs;
      };
    in
    {
      package = craneLib.buildPackage args;
      # The portable binaries released for the CLI, per build system.
      release.targets =
        if system == "x86_64-linux" then
          {
            linux-x86_64 = musl.craneLib.buildPackage (musl.commonArgs // crossArgs);
            windows-x86_64 = windows.craneLib.buildPackage (windows.commonArgs // crossArgs);
          }
        else if system == "aarch64-darwin" then
          {
            darwin-aarch64 = craneLib.buildPackage (
              args
              // {
                nativeBuildInputs = [ pkgs.darwin.autoSignDarwinBinariesHook ];
                # Link macOS's own libiconv, not the store's, so the binary
                # runs without Nix; the hook re-signs it after the change.
                postFixup = ''
                  for library in $(otool -L "$out/bin/${crate}" | awk '/\/nix\/store\/.*\/libiconv/ { print $1 }'); do
                    install_name_tool -change "$library" /usr/lib/libiconv.2.dylib "$out/bin/${crate}"
                  done

                  if otool -L "$out/bin/${crate}" | tail -n +2 | grep -q /nix/store/; then
                    echo "$out/bin/${crate} still links a Nix store library:" >&2
                    otool -L "$out/bin/${crate}" >&2
                    exit 1
                  fi
                '';
              }
            );
          }
        else
          { };
    };

  # A server crate: built, released by no target.
  backend =
    { workspace, crate }:
    {
      package = workspace.craneLib.buildPackage (pieceArgs workspace crate);
    };

  # A library crate: built and tested, with nothing to install or release.
  library =
    { workspace, crate }:
    {
      package = workspace.craneLib.buildPackage (
        pieceArgs workspace crate
        // {
          # A library has nothing to install: the build compiles it and leaves
          # `$out` empty.
          installPhaseCommand = "mkdir -p $out";
        }
      );
    };

  # The workspace's checks. `devShell` is the project's own dev shell: the
  # tests run with its `nativeBuildInputs`. `defaultPackage` is what `build`
  # builds, the project's `packages.default`.
  checks =
    {
      workspace,
      devShell,
      defaultPackage ? workspace.defaultPackage,
    }:
    let
      inherit (workspace)
        craneLib
        commonArgs
        cargoArtifacts
        src
        ;
    in
    {
      build = defaultPackage;
      clippy = craneLib.cargoClippy (
        commonArgs
        // {
          inherit cargoArtifacts;
          cargoClippyExtraArgs = "--all-targets --all-features -- --deny warnings";
        }
      );
      fmt = craneLib.cargoFmt {
        inherit src;
      };
      test = craneLib.cargoTest (
        commonArgs
        // {
          inherit cargoArtifacts;
          # `commonArgs` skips the tests for the packages; this check runs them.
          doCheck = true;
          # Tests may shell out to what the dev shell provides, such as git and jj.
          nativeBuildInputs = devShell.nativeBuildInputs;
        }
      );
    };
}
