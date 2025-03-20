{ lib, pyproject-nix }:
let
  inherit (builtins) mapAttrs;
  inherit (lib) fix;
in

fix (
  self:
  mapAttrs (_: path: import path ({ inherit pyproject-nix lib; } // self)) {
    renderers = ./renderers.nix;
    resolvers = ./resolvers.nix;
    query = ./query.nix;
  }
)
