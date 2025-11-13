{
  lib,
  pyproject,
  pkgs,
}:
let
  inherit (builtins)
    mapAttrs
    attrNames
    length
    substring
    stringLength
    ;
  inherit (lib) mapAttrs' toUpper fix;

  capitalise = s: toUpper (substring 0 1 s) + (substring 1 (stringLength s) s);

  mocks =
    let
      # Mock python derivations so we don't have to keep a pkgs reference
      mkPython =
        {
          pname ? "python",
          version,
          pythonVersion ? version,
          sourceVersion ? { },
          implementation ? "cpython",
          isLinux ? false,
          isDarwin ? false,
          linuxVersion ? "6.10",
          system,
        }:
        {
          inherit pname version;
          passthru = {
            inherit pythonVersion implementation sourceVersion;
          };

          # Generate a dummy package set based on the real python one
          # Note that inheriting from nixpkgs like this _will_ break tests
          # when updating nixpkgs.
          #
          # When that happens add another override to the attrset below.
          pkgs = mapAttrs (_n: drv: { inherit (drv) pname version; }) pkgs.python3.pkgs // {

            tox-pdm = {
              pname = "tox-pdm";
              version = "0.5.0";
            };

            pdm = {
              pname = "pdm";
              version = "2.10.0";
            };

            resolvelib = {
              pname = "resolvelib";
              version = "0.5.5";
            };

            matplotlib = {
              pname = "matplotlib";
              version = "3.9.0";
            };

            numba = {
              pname = "numba";
              version = "0.60.0";
            };

            cython = {
              pname = "cython";
              version = "3.0.10";
            };

            coverage = {
              pname = "coverage";
              version = "7.5.3";
            };

            oldest-supported-numpy = {
              pname = "oldest-supported-numpy";
              version = "1.0.0";
            };

            markdown-exec = {
              pname = "markdown-exec";
              version = "0.7.0";
            };

            copier = {
              pname = "copier";
              version = "0.7.0";
            };

            pycomplete = {
              pname = "pycomplete";
              version = "0.7.0";
            };

            pandas-gbq = {
              pname = "pandas-gbq";
              version = "0.7.0";
            };

            pytest-github-actions-annotate-failures = {
              pname = "pytest-github-actions-annotate-failures";
              version = "0.1.0";
            };

            types-jsonschema = {
              pname = "types-jsonschema";
              version = "0.1.0";
            };

            mike = {
              pname = "mike";
              version = "1.1.2";
            };

            unearth = {
              pname = "unearth";
              version = "0.9.1";
            };

            keyring = {
              pname = "keyring";
              version = "25.2.1";
            };

            pre-commit = {
              pname = "pre-commit";
              version = "3.3.3";
            };

            poetry-plugin-export = {
              pname = "poetry-plugin-export";
              version = "1.4.0";
            };

            python3 = {
              pname = "python3";
              inherit version;
            };
          };
          stdenv = {
            inherit isLinux isDarwin;

            targetPlatform =
              lib.systems.elaborate system // lib.optionalAttrs isDarwin { darwinSdkVersion = "11.0"; };

            cc =
              if isLinux then
                {
                  libc.pname = "glibc";
                  libc.version = "2.37";
                  libc.linuxHeaders.version = linuxVersion;
                }
              else if isDarwin then
                {
                  libc.pname = "libSystem";
                  libc.version = "11.0.0";
                }
              else
                throw "NO U";
          };
        };
    in
    {
      cpythonLinux38 = mkPython {
        version = "3.8.2";
        pythonVersion = "3.8";
        isLinux = true;
        sourceVersion.major = "3";
        sourceVersion.minor = "8";
        system = "x86_64-linux";
      };

      cpythonDarwin311 = mkPython {
        version = "3.11.4";
        pythonVersion = "3.11";
        isDarwin = true;
        sourceVersion.major = "3";
        sourceVersion.minor = "11";
        system = "x86_64-darwin";
      };

      cpythonDarwin311Aarch64 = mkPython {
        version = "3.11.4";
        pythonVersion = "3.11";
        isDarwin = true;
        sourceVersion.major = "3";
        sourceVersion.minor = "11";
        system = "aarch64-darwin";
      };

      pypy39Linux = mkPython {
        pname = "pypy";
        version = "7.3.11";
        pythonVersion = "3.9";
        isLinux = true;
        implementation = "pypy";
        sourceVersion.major = "7";
        sourceVersion.minor = "3";
        system = "x86_64-linux";
      };
    };

  importTests =
    path:
    import path (
      pyproject
      // {
        inherit lib mocks pkgs;
        fixtures = import ./fixtures;
      }
    );

in
# Work with the tests as a tree
# The attrpath is: module(file) -> symbol(function) -> test
fix (self: {
  pip = importTests ./test_pip.nix;
  pypa = importTests ./test_pypa.nix;
  project = importTests ./test_project.nix;
  renderers = importTests ./test_renderers.nix;
  validators = importTests ./test_validators.nix;
  scripts = importTests ./test_scripts.nix;
  poetry = importTests ./test_poetry.nix;
  eggs = importTests ./test_eggs.nix;
  util = importTests ./test_util.nix;

  pep440 = importTests ./test_pep440.nix;
  pep508 = importTests ./test_pep508.nix;
  pep518 = importTests ./test_pep518.nix;
  pep599 = importTests ./test_pep599.nix;
  pep600 = importTests ./test_pep600.nix;
  pep656 = importTests ./test_pep656.nix;
  pep621 = importTests ./test_pep621;
  pep723 = importTests ./test_pep723.nix;

  # Yo dawg, I heard you like tests...
  #
  # Check that all exported modules are covered by a test suite with at least one test.
  coverage = mapAttrs (
    moduleName:
    mapAttrs' (
      sym: _: {
        name = "test" + capitalise sym;
        value = {
          expected = true;
          expr = self ? ${moduleName}.${sym} && length (attrNames self.${moduleName}.${sym}) >= 1;
        };
      }
    )
  ) pyproject;
})
