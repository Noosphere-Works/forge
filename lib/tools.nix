# Prebuilt tools fetched from their release artefacts, one per system: np's
# `surrealdb/`, `surrealkit/` and `supabase/` fetched-package fragments.
let
  # A tool from the artefact `sources` names for the host system:
  # `sources = { "<system>" = { url; sha256; }; }`. `install` is its
  # `installPhase`, `stdenv` the builder (`pkgs.stdenv` unless given), and
  # every other attribute goes to the derivation as it is.
  fetched =
    {
      pkgs,
      pname,
      version,
      sources,
      install,
      stdenv ? pkgs.stdenv,
      ...
    }@args:
    let
      hostSystem = pkgs.stdenv.hostPlatform.system;
      source = sources.${hostSystem} or (throw "Unsupported system for ${pname}: ${hostSystem}");
    in
    stdenv.mkDerivation (
      builtins.removeAttrs args [
        "pkgs"
        "sources"
        "install"
        "stdenv"
      ]
      // {
        src = pkgs.fetchurl source;
        installPhase = install;
      }
    );
in
{
  inherit fetched;

  # SurrealDB's `surreal`, from its release tarball. The Linux build is a glibc
  # executable whose loader is the FHS `/lib64/ld-linux-x86-64.so.2`, which Nix
  # lacks, so its loader is patched to Nix's. It also links `libstdc++.so.6`
  # and `libgcc_s.so.1`, which `stdenv.cc.cc.lib` provides for the patch hook to
  # find.
  surrealdb =
    {
      pkgs,
      version,
      sources,
    }:
    fetched {
      inherit pkgs version sources;
      pname = "surrealdb";

      nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];

      buildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.stdenv.cc.cc.lib ];

      sourceRoot = ".";

      install = ''
        runHook preInstall
        mkdir -p $out/bin
        cp surreal $out/bin/
        chmod +x $out/bin/surreal
        runHook postInstall
      '';
    };

  # `surrealkit`, SurrealDB's schema-migration CLI, from its release tarball.
  surrealkit =
    {
      pkgs,
      version,
      sources,
    }:
    fetched {
      inherit pkgs version sources;
      pname = "surrealkit";
      stdenv = pkgs.stdenvNoCC;

      # The tarball holds the single `surrealkit` binary at its root. The Linux
      # build is static (musl), so there is nothing to patch.
      dontBuild = true;
      dontStrip = true;
      dontPatchELF = true;

      sourceRoot = ".";

      install = ''
        runHook preInstall
        mkdir -p $out/bin
        cp surrealkit $out/bin/
        chmod +x $out/bin/surrealkit
        runHook postInstall
      '';
    };

  # The Supabase CLI, `supabase`, from its release tarball. The Linux build is a
  # bun-compiled glibc executable, so its loader is patched to Nix's. The binary
  # stays unstripped so the `.bun` section that holds its payload is untouched.
  supabase =
    {
      pkgs,
      version,
      sources,
    }:
    fetched {
      inherit pkgs version sources;
      pname = "supabase";

      nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isLinux [ pkgs.autoPatchelfHook ];

      dontStrip = true;

      sourceRoot = ".";

      install = ''
        runHook preInstall
        mkdir -p $out/bin
        cp supabase $out/bin/
        chmod +x $out/bin/supabase
        runHook postInstall
      '';
    };
}
