{
  pyproject-nix,
  lib,
  pkgs,
}:

let
  inherit (pyproject-nix.build.lib) renderers;
  inherit (lib)
    filterAttrs
    listToAttrs
    concatMap
    mapAttrsToList
    nameValuePair
    attrNames
    ;

  buildSystems = import ./build-systems.nix {
    inherit lib;
  };

  pythonInterpreters =
    let
      # Filter out Python pre-releases from testing
      isPre = version: (pyproject-nix.lib.pep440.parseVersion version).pre != null;
    in
    filterAttrs (
      n: drv: lib.hasPrefix "python3" n && n != "python3Minimal" && !isPre drv.version
    ) pkgs.pythonInterpreters;

  mkChecks =
    python:
    let
      # Inject your own packages on top with overrideScope
      pythonSet =
        (pkgs.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope
          buildSystems;

      testVenv = pythonSet.pythonPkgsHostHost.mkVirtualEnv "test-venv" {
        build = [ ];
      };

      # Test fixture
      myapp = pyproject-nix.lib.project.loadPyproject {
        projectRoot = ./fixtures/myapp;
      };

      testEnviron = pyproject-nix.lib.pep508.mkEnviron python;

    in

    {
      make-venv =
        pkgs.runCommand "venv-run-build-test"
          {
            nativeBuildInputs = [ testVenv ];
          }
          ''
            pyproject-build --help > /dev/null
            touch $out
          '';

      # Test that glob isn't treated strangely by bash and command doesn't explode
      make-venv-flags =
        pkgs.runCommand "venv-run-build-flags-test"
          {
            nativeBuildInputs = [
              (testVenv.overrideAttrs (_old: {
                venvIgnoreCollisions = [ "*" ];
              }))
            ];
          }
          ''
            pyproject-build --help > /dev/null
            touch $out
          '';

      make-venv-unittest =
        pkgs.runCommand "venv-unittest"
          {
            nativeBuildInputs = [ python ];
          }
          ''
            cd ${../hooks/make-venv} && python -m unittest -v
            touch $out
          '';

      symlinked-venv =
        let
          # Create a derivation with a symlink to interpreter.
          # This would break the vanilla venv module.
          sym = pkgs.runCommand "symlinked-venv" { } ''
            mkdir -p $out/bin
            ln -s ${testVenv}/bin/python $out/bin/python
          '';
        in
        pkgs.runCommand "symlinked-venv-test"
          {
            nativeBuildInputs = [ sym ];
          }
          ''
            python -c 'import packaging'
            touch $out
          '';

      prebuilt-wheel = pythonSet.pythonPkgsHostHost.callPackage (
        {
          stdenv,
          fetchurl,
          pyprojectWheelHook,
        }:
        stdenv.mkDerivation {
          pname = "arpeggio";
          version = "2.0.2";

          src = fetchurl {
            url = "https://files.pythonhosted.org/packages/f7/4f/d28bf30a19d4649b40b501d531b44e73afada99044df100380fd9567e92f/Arpeggio-2.0.2-py2.py3-none-any.whl";
            hash = "sha256-98iuT0BWqJ4CDCTHICrI3z4ryE5BZ0byCw2jW7HeAlA=";
          };

          nativeBuildInputs = [ pyprojectWheelHook ];
        }
      ) { };

      mkderivation =
        let
          testSet = pythonSet.pythonPkgsHostHost.overrideScope (
            final: _prev: {
              myapp = final.callPackage (
                {
                  stdenv,
                  pyprojectHook,
                  resolveBuildSystem,
                }:
                stdenv.mkDerivation (
                  renderers.mkDerivation
                    {
                      project = myapp;
                      environ = testEnviron;
                    }
                    {
                      inherit pyprojectHook resolveBuildSystem;
                    }
                )
              ) { };
            }
          );

          venv = testSet.mkVirtualEnv "render-mkderivation-env" {
            myapp = [
              "toml" # Extra
              "round" # PEP-735 dependency group
            ];
          };
        in
        pkgs.runCommand "render-mkderivation-test" { nativeBuildInputs = [ venv ]; } ''
          # Assert that extra was enabled
          python -c "import tomli_w"

          # Assert that dependency group was enabled
          python -c "import wheel"

          # Script from myapp
          hello

          touch $out
        '';

      mkderivation-editable =
        let
          testSet = pythonSet.pythonPkgsHostHost.overrideScope (
            final: _prev: {
              myapp = final.callPackage (
                {
                  stdenv,
                  pyprojectEditableHook,
                  resolveBuildSystem,
                }:
                stdenv.mkDerivation (
                  renderers.mkDerivationEditable
                    {
                      project = myapp;
                      environ = testEnviron;
                      root = "$NIX_BUILD_TOP";
                    }
                    {
                      inherit
                        pyprojectEditableHook
                        resolveBuildSystem
                        ;
                    }
                )
              ) { };
            }
          );

          venv = testSet.mkVirtualEnv "render-mkderivation-editable-env" {
            myapp = [ ];
          };

        in
        pkgs.runCommand "render-mkeditable" { nativeBuildInputs = [ venv ]; } ''
          # Unpack sources into build
          cp -r ${./fixtures/myapp}/* .
          chmod +w -R src

          hello | grep "Hello from myapp"

          cat > src/myapp/__init__.py <<EOF
          def hello() -> None:
              print("Hello from editable!")
          EOF

          hello | grep "Hello from editable"

          touch $out
        '';
    };

in

# Run checks for all python interpreters supported by nixpkgs except for pre-releases
listToAttrs (
  concatMap (
    pythonPrefix:
    let
      python = pythonInterpreters.${pythonPrefix};
      checks = mkChecks python;
    in
    mapAttrsToList (name: check: nameValuePair "${pythonPrefix}-${name}" check) checks
  ) (attrNames pythonInterpreters)
)
// {
  # Tests that don't need to run on every supported interpreter

  make-venv-cross =
    let
      pkgs' = pkgs.pkgsCross.aarch64-multiplatform;
      python = pkgs'.python312;
      crossSet =
        (pkgs'.callPackage pyproject-nix.build.packages {
          inherit python;
        }).overrideScope
          buildSystems;
    in
    crossSet.mkVirtualEnv "cross-venv" {
      build = [ ];
      cffi = [ ];
    };

}
