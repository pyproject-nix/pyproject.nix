{
  pyproject-nix,
  lib,
  pkgs,
}:

let
  inherit (pyproject-nix.build.lib.renderers) mkDerivation;
  inherit (pyproject-nix.lib.project) loadPyproject;

  libFixtures = import ../../lib/fixtures;

  python = pkgs.python312;

  buildSystems = import ../checks/build-systems.nix {
    inherit lib;
  };

  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope
      buildSystems;

in

{
  mkDerivation =
    let
      environ = pyproject-nix.lib.pep508.mkEnviron pkgs.python312;

      renderFixture =
        fixture:
        let
          rendered =
            (mkDerivation {
              project = loadPyproject {
                pyproject = libFixtures.${fixture};
              };
              inherit environ;
            })
              {
                pyprojectHook = null;
                inherit (pythonSet.pythonPkgsHostHost) resolveBuildSystem;
              };
        in
        rendered
        // {
          nativeBuildInputs = map (
            input: if input == null then null else input.pname
          ) rendered.nativeBuildInputs;
        };

    in
    {
      testUv = {
        expr = renderFixture "uv.toml";
        expected = {
          meta = {
            description = "Add your description here";
          };
          nativeBuildInputs = [
            null
            "hatchling"
            "packaging"
            "pathspec"
            "pluggy"
            "trove-classifiers"
          ];
          passthru = {
            dependencies = { };
            optional-dependencies = { };
            dependency-groups = { };
          };
          pname = "uv-fixture";
          version = "0.1.0";
        };
      };
    };
}
