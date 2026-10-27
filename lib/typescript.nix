# The TypeScript recipes: a bun workspace through bunix, and each package's
# piece. np's `typescript/` and `piece/typescript-*.nix` flake fragments, with
# the package's name as an argument.
{ inputs }:
let
  # A package's directory, relative to the workspace root.
  directory = workspace: package: "${workspace.packageDir}/${package}";

  # A package's own derivation arguments, versioned from its `package.json`.
  pieceArgs =
    workspace: package:
    let
      manifest = builtins.fromJSON (
        builtins.readFile (workspace.root + "/${directory workspace package}/package.json")
      );
      version = manifest.version or null;
    in
    {
      pname = package;
      # The package's own version, read at evaluation time; `0.0.0` when it
      # declares none.
      version = if builtins.isString version then version else "0.0.0";
    };
in
{
  # The bun workspace at `root`, its packages under `packageDir`: bunix's
  # `lib.workspace` (`nodeModules`, `members`, `src`, `mkDerivation`,
  # `bunArgs`, `copyNodeModules`), plus the dev shell's `toolchain`. Every
  # piece builds in its own copy of `src` with the `node_modules` tree
  # `bun.lock` names copied in.
  workspace =
    {
      pkgs,
      root,
      exclude ? [ ".types" ],
      packageDir ? "package",
    }:
    inputs.bunix.lib.workspace { inherit pkgs root exclude; }
    // {
      inherit pkgs root packageDir;
      toolchain = pkgs.buildEnv {
        name = "typescript-toolchain";
        paths = with pkgs; [
          bun
          # Many package `.bin` shims use `#!/usr/bin/env node`; bun alone is not enough.
          nodejs
          typescript-language-server
        ];
      };
    };

  # A Vite web: its production build, `dist` as `$out`. `backendUrls` (see
  # `backendUrls` below) go into the build's environment.
  web =
    {
      workspace,
      package,
      backendUrls ? { },
    }:
    let
      inherit (workspace.pkgs) lib;
      dir = directory workspace package;
      # From the package's directory back to the workspace root.
      up = lib.concatMapStringsSep "/" (_: "..") (lib.splitString "/" dir);
    in
    {
      package = workspace.mkDerivation (
        pieceArgs workspace package
        // backendUrls
        // {
          # Vite's own script, not `.bin/vite`: Vike recognises a Vite CLI run
          # by `node_modules/vite/` in its path, and otherwise loads the config
          # a second time, as the dev server's.
          buildPhase = ''
            runHook preBuild
            cd ${lib.escapeShellArg dir}
            node ${up}/node_modules/vite/bin/vite.js build
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            cp -R dist "$out"
            # Vite's build manifest (Vike moves it to `assets.json`); the site is `client`.
            rm -rf "$out/client/.vite" "$out/assets.json"
            runHook postInstall
          '';
        }
      );
    };

  # A server: `src/index.ts` bundled for bun, the bundle written to `$out`.
  backend =
    { workspace, package }:
    let
      inherit (workspace.pkgs) lib;
    in
    {
      package = workspace.mkDerivation (
        pieceArgs workspace package
        // {
          buildPhase = ''
            runHook preBuild
            bun build ${lib.escapeShellArg "${directory workspace package}/src/index.ts"} --target=bun --outdir "$out"
            runHook postBuild
          '';
        }
      );
    };

  # A shared package: a type check that installs nothing. `name` is the
  # package's name, or `typescript-<name>` where the Rust crate of that name
  # (`<root>/<crateDir>/<name>/Cargo.toml`) also exists and owns the plain
  # name.
  library =
    {
      workspace,
      package,
      root ? workspace.root,
      crateDir ? "crate",
    }:
    let
      inherit (workspace.pkgs) lib;
    in
    {
      name =
        if builtins.pathExists (root + "/${crateDir}/${package}/Cargo.toml") then
          "typescript-${package}"
        else
          package;
      package = workspace.mkDerivation (
        pieceArgs workspace package
        // {
          # A type check that installs nothing. `--build`, because a package
          # that references another as a composite project needs its
          # declarations; they land in this build's own copy of the workspace.
          buildPhase = ''
            runHook preBuild
            node node_modules/typescript/bin/tsc --build ${lib.escapeShellArg (directory workspace package)}
            runHook postBuild
          '';
          installPhase = ''
            runHook preInstall
            mkdir -p "$out"
            runHook postInstall
          '';
        }
      );
    };

  # The workspace's lint and format checks: oxlint with type checking, and
  # oxfmt. They run `bun install --frozen-lockfile`, so they need the network.
  checks =
    { pkgs, root }:
    let
      check =
        name: commands:
        pkgs.runCommand name { nativeBuildInputs = with pkgs; [ bun ]; } ''
          cp -R ${root} source
          chmod -R u+w source
          cd source
          bun install --frozen-lockfile
          export PATH="$PWD/node_modules/.bin:$PATH"
          ${commands}
          touch $out
        '';
    in
    {
      typescript-build = check "typescript-build" ''
        bun oxlint --format agent --type-aware --type-check
      '';
      typescript-check = check "typescript-check" ''
        bun oxlint --format agent --type-aware --type-check
        bun oxfmt --check
      '';
    };

  # The URL of each backend a web calls from another origin, under its key
  # (`VITE_<WEB>_<BACKEND>_URL`): the Fly app its committed `deploy/fly.toml`
  # names, read at evaluation time, as `https://<app>.fly.dev`. A backend
  # without one leaves its key unset. `backends` is a list of
  # `{ key; config; }`, `config` the path of the backend's `deploy/fly.toml`.
  backendUrls =
    { pkgs, backends }:
    builtins.listToAttrs (
      builtins.concatMap (
        backend:
        let
          config =
            if builtins.pathExists backend.config then
              builtins.fromTOML (builtins.readFile backend.config)
            else
              { };
          app = config.app or null;
        in
        pkgs.lib.optional (builtins.isString app) {
          name = backend.key;
          value = "https://${app}.fly.dev";
        }
      ) backends
    );
}
