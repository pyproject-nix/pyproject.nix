# Integration tests are build tests i.e. construction of environment with
# assertions that imports works as expected.
{
  pyproject,
  pkgs,
  lib,
  src,
}:
let
  fixtures = import ./fixtures { inherit lib; };

  projects = {
    pdm-2_8_1 = {
      project = pyproject.lib.project.loadPyproject { pyproject = fixtures."pdm-2_8_1.toml"; };

      src = pkgs.fetchFromGitHub {
        owner = "pdm-project";
        repo = "pdm";
        rev = "2.8.1";
        sha256 = "sha256-/w74XmP1Che6BOE82klgzhwBx0nzAcw2aVyeWs+o3MA=";
      };

      buildPythonPackage.version = "2.8.1";

      # Assert these imports
      withPackages.imports = [
        "unearth"
        "findpython"
        "tomlkit"
        "installer"
        "pdm.backend" # PEP-518 build system
      ];
    };

    pep735 = {
      project = pyproject.lib.project.loadPyproject { pyproject = fixtures."pep735.toml"; };
      src = pkgs.runCommand "source" { } ''
        mkdir -p $out/src/pep735
        touch $out/src/pep735/__init__.py $out/README.md
        cp ${./fixtures/pep735.toml} $out/pyproject.toml
      '';
      groups = [ "group-a" ];
      withPackages.imports = [ "urllib3" ];
    };

    poetry-1_5_1 = {
      project = pyproject.lib.project.loadPoetryPyproject { pyproject = fixtures."poetry-1_5_1.toml"; };

      src = pkgs.fetchFromGitHub {
        owner = "python-poetry";
        repo = "poetry";
        rev = "1.5.1";
        sha256 = "sha256-1zqfGzSI5RDACSNcz0tLA4VKMFwE5uD/YqOkgpzg2nQ=";
      };

      buildPythonPackage.pipInstallFlags = "--no-deps";

      # Assert these imports
      withPackages.imports = [
        "tomlkit"
        "installer"
        "poetry.core" # PEP-518 build system
      ];
    };
  };

  python = pkgs.python3.override {
    self = python;
    # Poetry plugins aren't exposed in the Python set
    packageOverrides =
      _self: super:
      let
        poetry' = pkgs.poetry.override { python3 = python; };
      in
      {
        inherit (poetry'.plugins) poetry-plugin-export;
        pdm = null;

        # These are integration build tests; we don't need to run upstream
        # package test suites here. unearth 0.18.2's suite fails against newer
        # nixpkgs (changed packaging prerelease semantics), so just skip checks.
        unearth = super.unearth.overridePythonAttrs (_: {
          doCheck = false;
          doInstallCheck = false;
        });
      };
  };
in
# Construct withPackages environments and assert modules can be imported
lib.mapAttrs' (n: project: {
  name = "withPackages-${n}";
  value =
    let
      withFunc = pyproject.lib.renderers.withPackages {
        inherit python;
        inherit (project) project;
        groups = project.groups or [ ];
      };
      pythonEnv = python.withPackages withFunc;
    in
    pkgs.runCommand "withPackages-${n}" { } (
      lib.concatStringsSep "\n" (
        map (mod: "${pythonEnv.interpreter} -c 'import ${mod}'") project.withPackages.imports
      )
      + "\n"
      + "touch $out"
    );
}) projects
// (lib.mapAttrs' (n: project: {
  name = "buildPythonPackage-${n}";
  value =
    let
      attrs = pyproject.lib.renderers.buildPythonPackage {
        inherit python;
        inherit (project) project;
        groups = project.groups or [ ];
      };
    in
    python.pkgs.buildPythonPackage (
      attrs
      // {
        inherit (project) src;
        # Add relax deps since we don't assert versions
        nativeBuildInputs = attrs.nativeBuildInputs or [ ] ++ [ python.pkgs.pythonRelaxDepsHook ];

        dontCheckRuntimeDeps = true;

        # HACK: Relax deps hook is not sufficient
        postPatch = ''
          substituteInPlace pyproject.toml \
            --replace '"unearth>=0.10.0"' '"unearth"' \
            --replace '"resolvelib>=1.0.1"' '"resolvelib"' \
            --replace 'poetry-core = "1.6.1"' 'poetry-core = "^1.5.0"' \
            --replace 'cachecontrol = { version = "^0.12.9", extras = ["filecache"] }' 'cachecontrol = { version = "*", extras = ["filecache"] }' \
            --replace 'virtualenv = "^20.22.0"' 'virtualenv = "*"'
        '';
      }
      // project.buildPythonPackage or { }
    );
}) projects)
// {
  # Construct a withPackages environment with extras enabled
  withPackagesWithExtras =
    let
      inherit (projects.pdm-2_8_1) project;
    in
    pkgs.runCommand "withPackagesWithExtras"
      {
        nativeBuildInputs = [
          (python.withPackages (
            pyproject.lib.renderers.withPackages {
              inherit python project;
              extras = [ "keyring" ];
            }
          ))
        ];
      }
      ''
        python -c 'import keyring'
        touch $out
      '';
}
