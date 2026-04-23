{ stdenv, python3 }:

{

  /**
    Build applications without venv cruft.

    Virtual environments contains many files that are not relevant when
    distributing applications.
    This includes, but is not limited to
    - Python interpreter
    - Activation scripts
    - `pyvenv.cfg`

    This helper creates a new derivation, only symlinking venv files relevant for the application.

    # Example

    ```nix
    let
        util = pkgs.callPackage pyproject-nix.build.util { };
    in util.mkApplication {
      venv = pythonSet.mkVirtualEnv "mkApplication-check-venv" {
        pip = [ ];
      };
      package = pythonSet.pip;
    }
    =>
    «derivation /nix/store/i60rydd6sagcgrsz9cx0la30djzpa8k9-pip-24.0.drv»
    ```

    # Type

    ```
    mkApplication :: AttrSet -> derivation
    ```

    # Arguments

    venv
    : Virtualenv derivation created using `mkVirtualEnv`

    package
    : Python set package
  */
  mkApplication =
    {
      venv,
      package,
      pname ? package.pname,
      version ? package.version,
    }:
    stdenv.mkDerivation {
      inherit pname version;
      inherit (package)
        name
        meta
        passthru
        ;
      dontConfigure = true;
      dontBuild = true;
      dontUnpack = true;
      nativeBuildInputs = [
        python3
      ];

      installPhase = ''
        runHook preInstall
        python3 ${./mk-application.py} --venv ${venv} --base ${package} --out "$out"
        runHook postInstall
      '';
    };

}
