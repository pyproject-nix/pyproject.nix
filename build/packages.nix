{
  lib,
  resolvers,
}:
let
  inherit (resolvers) resolveCyclic resolveNonCyclic;
  inherit (lib) makeScope concatStringsSep;

  mkResolveBuildSystem =
    set:
    let
      resolveNonCyclic' = resolveNonCyclic [ ] set;

      # Implement fallback behaviour in case of empty build-system
      fallbackSystems = map (name: set.${name}) (resolveNonCyclic' {
        setuptools = [ ];
        wheel = [ ];
      });
    in
    spec: if spec != { } then map (name: set.${name}) (resolveNonCyclic' spec) else fallbackSystems;

  mkResolveVirtualEnv = set: spec: map (name: set.${name}) (resolveCyclic set spec);

  mkPythonSet =
    {
      python,
      stdenv,
      pythonPkgsBuildHost,
      pkgsFinal,
      pkgs,
    }:
    {
      inherit
        python
        pkgs
        stdenv
        pythonPkgsBuildHost
        ;

      # Initialize dependency resolvers
      resolveBuildSystem = mkResolveBuildSystem pythonPkgsBuildHost;
      resolveVirtualEnv = mkResolveVirtualEnv pkgsFinal;

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
              map (path: "--skip ${path}") finalAttrs.venvSkip
              ++ map (pat: "--ignore-collisions ${pat}") finalAttrs.venvIgnoreCollisions
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
        pyprojectBuildEditableHook
        pyprojectFixupEditableHook
        pyprojectEditableHook
        ;
    };

in

{
  python,
  newScope,
  buildPackages,
  stdenv,
  pkgs,
}:
makeScope newScope (
  final:
  {
    # Create a dummy mkVirtualEnv function to make nixdoc happy

    /*
      Create a virtual environment from dependency specification

      ### Example

      ```nix
      mkVirtualEnv "foo-env" {
        foo = [ "extra" ];
      }
      ```

      ### Example (skip file)

      ```nix
      (mkVirtualEnv "foo-env" {
        foo = [ "extra" ];
      }).overrideAttrs(old: {
        # Skip LICENSE file from package root.
        venvSkip = [ "LICENSE" ];
      })
      ```

      ### Example (ignore collisions)

      ```nix
      (mkVirtualEnv "foo-env" {
        foo = [ "extra" ];
      }).overrideAttrs(old: {
        # You could also ignore all collisions with:
        # venvIgnoreCollisions = [ "*" ];
        venvIgnoreCollisions = [ "lib/python${python.pythonVersion}/site-packages/build_tools" ];
      })
      ```
    */
    mkVirtualEnv =
      # Venv name
      name:
      # Dependency specification
      spec:
      # Note: Funky throw construct is to satisfy deadnix not to get name -> _name formatting.
      throw "${name} ${spec}";
  }
  // (mkPythonSet {
    inherit python stdenv pkgs;
    pkgsFinal = final;
    pythonPkgsBuildHost = final.pythonPkgsHostHost;
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
            inherit pkgsFinal;
            pkgs = buildPackages;
          }
        ))
      else
        final;

    # Alias the host packages (this set) set as pythonPkgsHostHost
    pythonPkgsHostHost = final;
  }
)
