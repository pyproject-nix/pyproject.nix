{ pkgs, pyproject-nix }:

let
  inherit (pkgs) lib;

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
  nixpkgsPrebuilt =
    let
      testSet = pythonSet.overrideScope (
        _final: prev: {
          # Arbitrary test package with a bin output we can run
          pip = hacks.nixpkgsPrebuilt {
            from = pkgs.python3Packages.pip;
            prev = prev.pip;
          };
        }
      );

      drv = testSet.pip;

      venv = testSet.mkVirtualEnv "nixpkgsPrebuilt-check-venv" {
        pip = [ ];
      };

    in
    pkgs.runCommand "nixpkgsPrebuilt-check" { } ''
      # Check that no wrapped files are in output
      ! ls -a ${drv}/bin | grep wrapped

      # Check that file does not contain any store references apart from shebang
      tail -n +2 ${drv}/bin/pip > script
      ! grep "${builtins.storeDir}" script

      # Test run binary
      ${venv}/bin/pip --help > /dev/null

      ln -s ${venv} $out
    '';

  importCargoLock =
    let
      testSet = pythonSet.overrideScope (
        lib.composeExtensions
          (final: _prev: {
            cryptography = final.callPackage (
              {
                stdenv,
                pyprojectHook,
              }:
              stdenv.mkDerivation {
                inherit (pkgs.python3Packages.cryptography) pname version src;

                nativeBuildInputs = [
                  pyprojectHook
                ];
              }
            ) { };
          })
          (
            final: prev: {
              cryptography =
                (hacks.importCargoLock {
                  prev = prev.cryptography;
                }).overrideAttrs
                  (old: {
                    nativeBuildInputs =
                      old.nativeBuildInputs
                      ++ final.resolveBuildSystem {
                        maturin = [ ];
                        setuptools = [ ];
                        cffi = [ ];
                        pycparser = [ ];
                      };
                    buildInputs = old.buildInputs or [ ] ++ [ pkgs.openssl ];
                  });
            }
          )
      );

      venv = testSet.mkVirtualEnv "nixpkgsPrebuilt-check-venv" {
        cryptography = [ ];
      };

    in
    pkgs.runCommand "importCargoLock-check" { } ''
      ${venv}/bin/python -c "import cryptography"
      ln -s ${venv} $out
    '';

  toNixpkgs =
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

      pythonEnv = python.withPackages (ps: [
        ps.urllib3
        ps.pip
      ]);
    in
    assert pkgs.python3.pkgs.urllib3 != python.pkgs.urllib3;
    assert pkgs.python3.pkgs.pip != python.pkgs.pip;
    pkgs.runCommand "toNixpkgs-check" { } ''
      ${pythonEnv}/bin/python -c 'import urllib3'
      ${pythonEnv}/bin/pip --version > $out
    '';
}
