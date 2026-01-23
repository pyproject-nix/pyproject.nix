{
  pkgs,
  lib,
  pyproject-nix,
}:
let
  hacks = pkgs.callPackages pyproject-nix.build.hacks { };

  python = pkgs.python3;

  buildSystems = import ../checks/build-systems.nix {
    inherit lib;
  };

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      buildSystems;

in
{
  toNixpkgs = {
    testList =
      let
        overlay = hacks.toNixpkgs {
          inherit pythonSet;
          packages = [
            "pip" # Testing dependencies
            "urllib3" # Testing optional-dependencies
          ];
        };
        python = pkgs.python3.override {
          packageOverrides = overlay;
          self = python;
        };

      in
      {
        expr = {
          urllib3 = python.pkgs.urllib3.version;
          pip = python.pkgs.pip.version;
        };
        expected = {
          urllib3 = pythonSet.urllib3.version;
          pip = pythonSet.pip.version;
        };
      };

    testPredicate =
      let
        overlay = hacks.toNixpkgs {
          inherit pythonSet;
          packages = lib.flip lib.elem [
            "pip"
            "urllib3"
          ];
        };
        python = pkgs.python3.override {
          packageOverrides = overlay;
          self = python;
        };
      in
      {
        expr = {
          urllib3 = python.pkgs.urllib3.version;
          pip = python.pkgs.pip.version;
        };
        expected = {
          urllib3 = pythonSet.urllib3.version;
          pip = pythonSet.pip.version;
        };
      };

    testNull =
      let
        overlay = hacks.toNixpkgs {
          inherit pythonSet;
        };
        python = pkgs.python3.override {
          packageOverrides = overlay;
          self = python;
        };

      in
      {
        expr = {
          urllib3 = python.pkgs.urllib3.version;
          pip = python.pkgs.pip.version;
        };
        expected = {
          urllib3 = pythonSet.urllib3.version;
          pip = pythonSet.pip.version;
        };
      };
  };
}
