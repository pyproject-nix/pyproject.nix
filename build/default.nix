{ lib, pyproject-nix }:

lib.fix (self: {
  packages = import ./packages.nix {
    inherit (self.lib) resolvers;
    inherit lib pyproject-nix;
  };
  lib = import ./lib { inherit lib pyproject-nix; };
  hacks = import ./hacks;
  util = import ./util;
})
