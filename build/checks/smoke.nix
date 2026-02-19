# "Smoke tests" meaning only nominal tests
#
# This is used with older nixpkgs version where running the full gamut of tests in CI would be too expensive.
{ name, pyproject-nix, lib, runCommand, python3, callPackage }:
let
  buildSystems = import ./build-systems.nix {
    inherit lib;
  };

  python = python3;

  pythonSet =
    (callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      buildSystems;
in
  # Flit-core is a tiny dependency but is enough to trigger all relevant code paths in build hooks
  pythonSet.hatchling
