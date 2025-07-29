{
  python,
  callPackage,
  pyproject-nix,
  lib,
}:
let
  # Pyproject.nix packages quite a few, but not all build-system dependencies.
  #
  # We only package PyPI packages because lock file generators often miss this metadata, so it's required to help kickstart a Python set.
  # This set is incomplete, and much smaller in both package count and scope than nixpkgs is.
  baseSet = callPackage pyproject-nix.build.packages {
    inherit python;
  };

  # A hypothetical over-simplified "lock file" format to demonstrate what typical usage would look like.
  # This format is absent of important data such as PEP-508 markers and more.
  #
  # Also note that all sources are the same. In a real-world file these would of course all be different.
  lock =
    let
      src = {
        type = "pypi";
        url = "https://files.pythonhosted.org/packages/63/70/2bf7780ad2d390a8d301ad0b550f1581eadbd9a20f896afe06353c2a2913/requests-2.32.3.tar.gz";
        hash = "sha256:55365417734eb18255590a9ff9eb97e9e1da868d4ccd6402399eaf68af20a760";
      };
    in
    {
      package-a = {
        name = "a";
        version = "1.0.0";
        dependencies = { };
        optional-dependencies = { };
        inherit src;
        build-system = {
          flit-core = [ ];
        };
      };

      package-b = {
        name = "b";
        version = "1.0.0";
        # Depend on a with no optionals
        dependencies = {
          a = [ ];
        };
        inherit src;
        build-system = {
          flit-core = [ ];
        };
      };

      package-c = {
        name = "c";
        version = "1.0.0";
        dependencies = {
          a = [ ];
        };
        # Has an optional dependency on b when cool_feature is activated
        optional-dependencies = {
          cool_feature = {
            b = [ ];
          };
        };
        inherit src;
        build-system = {
          flit-core = [ ];
        };
      };

      package-d = {
        name = "d";
        version = "1.0.0";
        dependencies = {
          c = [ "cool_feature" ];
        };
        # A local package dependend on by it's path
        src = {
          type = "path";
          path = ./packages/d;
        };
        build-system = {
          flit-core = [ ];
        };
      };
    };

  # Create a PEP-508 marker environment for marker evaluation
  environ = pyproject-nix.lib.pep508.mkEnviron python;

  # Transform lock into a Pyproject.nix build overlay.
  # This will create packages from the lock.
  overlay =
    pyfinal: _pyprev:
    lib.mapAttrs (
      name: lockpkg:
      # If package is a local package use a project loader from pyproject-nix.lib.project
      if lockpkg.src.type == "path" then
        (
          let
            project = pyproject-nix.project.loadPyprojectDynamic {
              projectRoot = lockpkg.src.path;
            };
          in
          pyfinal.callPackage (
            # Function called with callPackage
            {
              stdenv,
              pyprojectHook,
              resolveBuildSystem,
            }:
            # Call stdenv.mkDerivation with project
            stdenv.mkDerivation (
              # Render stdenv.mkDerivation arguments from project
              pyproject-nix.build.lib.renderers.mkDerivation
                {
                  inherit project environ;
                }
                {
                  inherit pyprojectHook resolveBuildSystem;
                }
            )
          ) { }
        )
      # If a package is a remote (pypi) package there is no ready made renderers to use.
      # You need to apply your own transformations.
      else if lockpkg.src.type == "pypi" then
        pyfinal.callPackage (
          {
            stdenv,
            fetchurl,
            pyprojectHook,
            resolveBuildSystem,
          }:
          stdenv.mkDerivation {
            pname = lockpkg.name;
            inherit (lockpkg) version;
            src = fetchurl lockpkg.src;

            nativeBuildInputs = [
              # Add hook responsible for configuring, building & installing.
              pyprojectHook
            ]
            # Build systems needs to be resolved since we don't propagate dependencies.
            # Otherwise dependencies of our build-system will be missing.
            ++ resolveBuildSystem lockpkg.build-system;

            # Dependencies go in passthru to avoid polluting runtime package.
            passthru = {
              inherit (lockpkg) dependencies optional-dependencies;
            };
          }
        ) { }
      else
        throw "Unhandled src type: ${lockpkg.src.type}" null
    ) lock;

  # Override set
  pythonSet = baseSet.overrideScope (
    _final: _prev: {
      # Override build platform dependencies
      #
      # Use this when overriding build-systems that need to run on the build platform.
      pythonPkgsBuildHost = overlay;

      # Override target platform packages.
      #
      # Use this to override packages for the target platform.
      pythonPkgsHostHost = overlay;
    }
  );

in
# Create a virtual environment containing our dependency specification
pythonSet.pythonPkgsHostHost.mkVirtualEnv "example-venv" {
  # Depend on package
  build = [ ];
}
