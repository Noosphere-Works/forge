# forge's library: np's project recipes. `inputs` are forge's own flake
# inputs (crane, fenix, bunix); every recipe builds with the `pkgs` its caller
# passes, never forge's own nixpkgs.
{ inputs }:
{
  rust = import ./rust.nix { inherit inputs; };
  typescript = import ./typescript.nix { inherit inputs; };
  postgres = import ./postgres.nix;
  tools = import ./tools.nix;
  image = import ./image.nix;
}
