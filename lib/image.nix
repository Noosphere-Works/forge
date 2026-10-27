# The OCI image Fly runs for a piece: the piece's flake package for
# x86_64-linux, wrapped by `dockerTools.streamLayeredImage`. np's image
# recipe (`deploy/template/image.nix`) as a pure function; the caller reads
# the workflow's inputs and passes them.
#
#   flake  the project's flake at the released commit (`builtins.getFlake …`).
#          `image` reads only `flake.inputs.nixpkgs` and
#          `flake.packages.x86_64-linux.<name>`, so any attribute set of that
#          shape will do.
#   piece  the piece: a package of the flake for x86_64-linux
#   kind   "rust-backend", "typescript-backend" or "web"
#   port   the port the piece listens on
#   site   optional: the web package a backend serves from its own origin
#          (`null` or "" for none)
{
  flake,
  piece,
  kind,
  port,
  site ? null,
}:
let
  system = "x86_64-linux";
  pkgs = import flake.inputs.nixpkgs { inherit system; };
  packages = flake.packages.${system};
  packageOf = name: packages.${name} or (throw "the flake has no package ${name} for ${system}");
  package = packageOf piece;
  portString = toString port;
  # The keys the piece reads, as np names them: `<PIECE>_PORT`.
  upper = pkgs.lib.toUpper piece;
  portKey = "${upper}_PORT";
  siteRootKey = "${upper}_SITE_ROOT";
  web = if site == null || site == "" then null else packageOf site;

  backend =
    entrypoint:
    pkgs.dockerTools.streamLayeredImage {
      name = piece;
      contents = [ pkgs.cacert ];
      extraCommands = ''
        mkdir -p tmp
        chmod 1777 tmp
      '';
      config = {
        Entrypoint = entrypoint;
        Env = [
          "${portKey}=${portString}"
          "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
        ]
        ++ pkgs.lib.optional (web != null) "${siteRootKey}=${web}/client";
        ExposedPorts."${portString}/tcp" = { };
      };
    };

  # A web's package is its built site: `dist`, whose `client` holds the pages.
  serverConfig = pkgs.writeText "${piece}-static-web-server.toml" ''
    [general]
    host = "::"
    port = ${portString}
    root = "${package}/client"
    page-fallback = "${package}/client/index.html"
    health = true
    compression = true
    cache-control-headers = false

    # Later rules win: hashed assets are immutable, everything else revalidates.
    [[advanced.headers]]
    source = "**"
    headers = { Cache-Control = "no-cache" }

    [[advanced.headers]]
    source = "/assets/**"
    headers = { Cache-Control = "public, max-age=31536000, immutable" }
  '';

  static = pkgs.dockerTools.streamLayeredImage {
    name = piece;
    config = {
      Entrypoint = [
        "${pkgs.static-web-server}/bin/static-web-server"
        "--config-file"
        "${serverConfig}"
      ];
      ExposedPorts."${portString}/tcp" = { };
    };
  };
in
if kind == "rust-backend" then
  backend [ "${package}/bin/${piece}" ]
else if kind == "typescript-backend" then
  backend [
    "${pkgs.bun}/bin/bun"
    "${package}/index.js"
  ]
else if kind == "web" then
  static
else
  throw "kind must be rust-backend, typescript-backend or web, not ${kind}"
