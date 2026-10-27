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

  # SurrealDB's `surreal`, from its release tarball.
  surrealdb =
    {
      pkgs,
      version,
      sources,
    }:
    fetched {
      inherit pkgs version sources;
      pname = "surrealdb";

      sourceRoot = ".";

      install = ''
        mkdir -p $out/bin
        cp surreal $out/bin/
        chmod +x $out/bin/surreal
      '';
    };

  # Surrealist, SurrealDB's GUI: the app bundle on macOS, the AppImage on
  # Linux.
  surrealist =
    {
      pkgs,
      version,
      sources,
    }:
    fetched {
      inherit pkgs version sources;
      pname = "surrealist";
      stdenv = pkgs.stdenvNoCC;

      nativeBuildInputs = pkgs.lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ pkgs.makeWrapper ];

      dontBuild = true;
      dontUnpack = pkgs.stdenv.hostPlatform.isLinux;
      sourceRoot = pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin "Surrealist.app";

      install = ''
        runHook preInstall
        mkdir -p $out/bin

        ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isDarwin ''
          mkdir -p $out/Applications
          cp -r . $out/Applications/Surrealist.app
          makeWrapper "$out/Applications/Surrealist.app/Contents/MacOS/surrealist" $out/bin/surrealist
        ''}

        ${pkgs.lib.optionalString pkgs.stdenv.hostPlatform.isLinux ''
          cp "$src" $out/bin/surrealist
          chmod +x $out/bin/surrealist
        ''}

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

  # The Supabase CLI, `supabase` and `supabase-go`, from its release tarball.
  supabase =
    {
      pkgs,
      version,
      sources,
    }:
    fetched {
      inherit pkgs version sources;
      pname = "supabase";

      dontStrip = true;
      dontPatchELF = true;

      sourceRoot = ".";

      install = ''
        mkdir -p $out/bin
        cp supabase $out/bin/
        cp supabase-go $out/bin/
        chmod +x $out/bin/supabase $out/bin/supabase-go
      '';
    };
}
