{
  lib,
  resolvers,
  pyproject-nix,
}:
let
  inherit (resolvers) resolveCyclic resolveNonCyclic;
  inherit (lib) makeScope concatStringsSep escapeShellArg;

  mkPkgs' = import ./pkgs { inherit pyproject-nix lib; };

  # Build-system package names to memoise
  memoNames = lib.attrNames (mkPkgs' {
    # Hack: We only need attrNames
    callPackage = null;
  });

  mkResolveBuildSystem =
    set:
    let
      resolveNonCyclic' = resolveNonCyclic memoNames set;

      # Implement fallback behaviour in case of empty build-system
      fallbackSystems = map (name: set.${name}) (resolveNonCyclic' {
        setuptools = [ ];
        wheel = [ ];
      });
    in
    spec: if spec != { } then map (name: set.${name}) (resolveNonCyclic' spec) else fallbackSystems;

  mkResolveVirtualEnv = set: spec: map (name: set.${name}) (resolveCyclic set spec);

  deprecatedBuild = name: ''
    You are using '${name}' from the pyproject.nix base package set, which is deprecated and will be removed shortly.

    Build-system packages have been moved into their own repository which can be found at
    https://github.com/pyproject-nix/build-system-pkgs
  '';
  pkgsFun =
    final:
    lib.mapAttrs (name: drv: builtins.trace (deprecatedBuild name) drv) (mkPkgs' {
      inherit (final) callPackage;
    });

  mkPythonSet =
    {
      python,
      stdenv,
      pythonPkgsBuildHost,
      pythonPkgsFun,
      pkgsFinal,
    }:
    {
      inherit python stdenv pythonPkgsBuildHost;

      # Initialize dependency resolvers
      resolveBuildSystem = mkResolveBuildSystem pythonPkgsBuildHost;
      resolveVirtualEnv = mkResolveVirtualEnv pkgsFinal;

      # Make a virtual env from resolved dependencies
      mkVirtualEnv =
        name: spec:
        pkgsFinal.stdenv.mkDerivation (finalAttrs: {
          inherit name;

          dontConfigure = true;
          dontUnpack = true;
          dontBuild = true;

          # Skip linking files into venv
          venvSkip = [ ];

          # Ignore collisions for paths
          venvIgnoreCollisions = [ ];

          nativeBuildInputs = [
            pkgsFinal.pyprojectMakeVenvHook
          ];

          env = {
            NIX_PYPROJECT_DEPS = concatStringsSep ":" (pkgsFinal.resolveVirtualEnv spec);
            dontMoveLib64 = true;
            mkVirtualenvFlags = concatStringsSep " " (
              map (path: "--skip ${escapeShellArg path}") finalAttrs.venvSkip
              ++ map (pat: "--ignore-collisions ${escapeShellArg pat}") finalAttrs.venvIgnoreCollisions
            );
          };

          buildInputs = pkgsFinal.resolveVirtualEnv spec;
        });

      hooks = pkgsFinal.callPackage ./hooks { };
      inherit (pkgsFinal.hooks)
        pyprojectConfigureHook
        pyprojectBuildHook
        pyprojectInstallHook
        pyprojectBytecodeHook
        pyprojectOutputSetupHook
        pyprojectCrossShebangHook
        pyprojectMakeVenvHook
        pyprojectHook
        pyprojectWheelHook
        ;
    }
    // pythonPkgsFun pkgsFinal;

in

{
  python,
  newScope,
  buildPackages,
  stdenv,
}:
makeScope newScope (
  final:
  (mkPythonSet {
    inherit python stdenv;
    pkgsFinal = final;
    pythonPkgsBuildHost = final.pythonPkgsHostHost;
    pythonPkgsFun = pkgsFun;
  })
  // {
    # Python packages for the build host.
    # In case of cross compilation this set is instantiated with host packages, otherwise
    # it's aliasing pythonPkgsHostHost
    pythonPkgsBuildHost =
      if stdenv.buildPlatform != stdenv.hostPlatform then
        (makeScope buildPackages.newScope (
          pkgsFinal:
          mkPythonSet {
            inherit (buildPackages) stdenv;
            python = python.pythonOnBuildForHost;
            inherit (final) pythonPkgsBuildHost;
            pythonPkgsFun = pkgsFun;
            inherit pkgsFinal;
          }
        ))
      else
        final;

    # Alias the host packages (this set) set as pythonPkgsHostHost
    pythonPkgsHostHost = final;
  }
)
