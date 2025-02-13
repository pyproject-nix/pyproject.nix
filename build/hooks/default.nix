{
  callPackage,
  makeSetupHook,
  python,
  pkgs,
  lib,
  stdenv,
  hooks,
  runCommand,
  substituteAll,
}:
let
  inherit (python) pythonOnBuildForHost;
  inherit (pkgs) buildPackages;
  pythonSitePackages = python.sitePackages;

  isCross = stdenv.buildPlatform != stdenv.hostPlatform;

  # When cross compiling create a virtual environment for the build.
  #
  # Because Nixpkgs builds cross compiled Python in a separate
  # prefix from the native Python, where the native Python doesn't contain
  # the sysconfigdata files for the cross Python.
  # This trips up UV's interpreter discovery scripts which is invoked in isolated mode (-I).
  #
  # Make the build-host aware of the build-target by aggregating them into a venv.
  crossPython = runCommand "${python.name}-cross-env" { } ''
    ${pythonOnBuildForHost.interpreter} -m venv --without-pip $out
    cat > $out/${pythonSitePackages}/sitecustomize.py<<EOF
    import sys; sys.path.append('${python}/${pythonSitePackages}')
    EOF
  '';

  pythonInterpreter =
    if isCross then
      "${crossPython}/bin/${baseNameOf pythonOnBuildForHost.interpreter}"
    else
      pythonOnBuildForHost.interpreter;

  # Builder commands for editable packages
  editableHook' = callPackage ./editable_hook { };

in
{
  /*
    Undo any `$PYTHONPATH` changes done by nixpkgs Python infrastructure dependency propagation.

    Used internally by `pyprojectHook`.
  */
  pyprojectConfigureHook = callPackage (
    { python }:
    makeSetupHook {
      name = "pyproject-configure-hook";
      substitutions = {
        inherit pythonInterpreter;
        pythonPath = lib.concatStringsSep ":" (
          lib.optional isCross "${python.pythonOnBuildForHost}/${python.sitePackages}"
          ++ [
            "${python}/${python.sitePackages}"
          ]
        );
      };
    } ./pyproject-configure-hook.sh
  ) { };

  /*
    Build a pyproject.toml/setuptools project.

    Used internally by `pyprojectHook`.
  */
  pyprojectBuildHook =
    callPackage
      (
        { uv }:
        makeSetupHook {
          name = "pyproject-build-hook";
          substitutions = {
            inherit pythonInterpreter uv;
          };
        } ./pyproject-build-hook.sh
      )
      {
        inherit (buildPackages) uv;
      };

  /*
    Symlink prebuilt wheel sources.

    Used internally by `pyprojectWheelHook`.
  */
  pyprojectWheelDistHook = callPackage (
    _:
    makeSetupHook {
      name = "pyproject-wheel-dist-hook";
    } ./pyproject-wheel-dist-hook.sh
  ) { };

  /*
    Install built projects from dist/*.whl.

    Used internally by `pyprojectHook`.
  */
  pyprojectInstallHook =
    callPackage
      (
        { uv }:
        makeSetupHook {
          name = "pyproject-install-hook";
          substitutions = {
            inherit pythonInterpreter uv;
          };
        } ./pyproject-install-hook.sh
      )
      {
        inherit (buildPackages) uv;
      };

  /*
    Create `pyproject.nix` setup hook in package output.

    Used internally by `pyprojectHook`.
  */
  pyprojectOutputSetupHook = callPackage (
    _:
    makeSetupHook {
      name = "pyproject-output-setup-hook";
      substitutions = {
        inherit pythonInterpreter pythonSitePackages;
      };
    } ./pyproject-output-setup-hook.sh
  ) { };

  /*
    Rewrite shebangs for cross compiled Python programs.

    When cross compiling & installing a Python program the shebang gets written
    for the install-time Pythhon, which for cross compilation is for the _build host_.

    This hook rewrites any shebangs pointing to the build host Python to the target host Python.
  */
  pyprojectCrossShebangHook = callPackage (
    _:
    makeSetupHook {
      name = "pyproject-cross-shebang-hook";
      substitutions = {
        script = ./patch-cross-shebangs.py;
        inherit pythonInterpreter;
        hostInterpreter = python.interpreter;
      };
    } ./pyproject-cross-shebang-hook.sh
  ) { };

  /*
    Create a virtual environment from buildInputs

    Used internally by `mkVirtualEnv`.
  */
  pyprojectMakeVenvHook = callPackage (
    { python }:
    makeSetupHook {
      name = "pyproject-make-venv-hook";
      substitutions = {
        inherit pythonInterpreter python;
        hostInterpreter = python.interpreter;
        makeVenvScript = ./make-venv/make_venv.py;
      };
    } ./pyproject-make-venv-hook.sh
  ) { };

  /*
    Meta hook aggregating the default pyproject.toml/setup.py install behaviour and adds Python.

    This is the default choice for both pyproject.toml & setuptools projects.
  */
  pyprojectHook =
    callPackage
      (
        {
          pyprojectConfigureHook,
          pyprojectBuildHook,
          pyprojectInstallHook,
          pyprojectOutputSetupHook,
          pyprojectCrossShebangHook,
          python,
          extraHooks ? [ ],
        }:
        makeSetupHook {
          name = "pyproject-hook";
          passthru.python = python;
          propagatedBuildInputs =
            [
              python
              pyprojectConfigureHook
              pyprojectBuildHook
              pyprojectInstallHook
              pyprojectOutputSetupHook
            ]
            ++ lib.optional isCross pyprojectCrossShebangHook
            ++ extraHooks;
        } ./meta-hook.sh
      )
      (
        {
          python = pythonOnBuildForHost;
        }
        // lib.optionalAttrs isCross {
          pyprojectInstallHook = hooks.pyprojectPypaInstallHook;
        }
      );

  /*
    Hook used to build prebuilt wheels.

    Use instead of pyprojectHook.
  */
  pyprojectWheelHook = hooks.pyprojectHook.override {
    pyprojectBuildHook = hooks.pyprojectWheelDistHook;
  };

  /*
    Hook used to build editable packages.

    Use instead of pyprojectHook.
  */
  pyprojectEditableHook = hooks.pyprojectHook.override {
    pyprojectBuildHook = hooks.pyprojectBuildEditableHook;
    extraHooks = [
      hooks.pyprojectFixupEditableHook
    ];
  };

  /*
    Build an editable package
    .
  */
  pyprojectBuildEditableHook = callPackage (
    { python }:
    makeSetupHook {
      name = "pyproject-editable-hook";
      substitutions = {
        editableHook = editableHook';
      };
    } ./pyproject-build-editable-hook.sh
  ) { };

  /*
    Fixup path references in an editable package
    .
  */
  pyprojectFixupEditableHook = callPackage (
    { python }:
    makeSetupHook {
      name = "pyproject-fixup-editable-hook";
      substitutions = {
        editableHook = editableHook';
      };
    } ./pyproject-fixup-editable-hook.sh
  ) { };

  /*
    Install hook using pypa/installer.

    Used instead of `pyprojectInstallHook` for cross compilation support.
  */
  pyprojectPypaInstallHook = callPackage (
    { pythonPkgsBuildHost }:
    makeSetupHook {
      name = "pyproject-pypa-install-hook";
      substitutions = {
        inherit (pythonPkgsBuildHost) installer;
        inherit pythonInterpreter pythonSitePackages;
        wrapper = ./pypa-install-hook/wrapper.py;
      };
    } ./pypa-install-hook/pyproject-pypa-install-hook.sh
  ) { };

  /*
    Install dist directory with wheels into output
    .
  */
  pyprojectInstallDistHook =
    callPackage
      (
        { ugrep }:
        makeSetupHook {
          name = "pyproject-install-dist-hook";
          substitutions = {
            inherit pythonInterpreter;
            script = substituteAll {
              src = ./dist-hook/install-wheels.py;
              ugrep = lib.getExe ugrep;
              store_dir = builtins.storeDir;
            };
          };
        } ./dist-hook/pyproject-install-dist-hook.sh
      )
      {
        inherit (buildPackages) ugrep;
      };

  /*
    Hook used to build a wheel file and install it into the output directory.

    Use instead of pyprojectHook.
  */
  pyprojectDistHook = hooks.pyprojectHook.override {
    pyprojectInstallHook = hooks.pyprojectInstallDistHook;
    pyprojectOutputSetupHook = null;
  };
}
