# overriding packages

## Problem description

Lock file consumers can only work with what it has, and important metadata is notably absent from all current package managers.

Take a [uv](https://docs.astral.sh/uv/) lock file entry for `pyzmq` as an example:
``` toml
[[package]]
name = "pyzmq"
version = "26.2.0"
source = { registry = "https://pypi.org/simple" }
dependencies = [
    { name = "cffi", marker = "implementation_name == 'pypy'" },
]
sdist = { url = "https://files.pythonhosted.org/packages/fd/05/bed626b9f7bb2322cdbbf7b4bd8f54b1b617b0d2ab2d3547d6e39428a48e/pyzmq-26.2.0.tar.gz", hash = "sha256:070672c258581c8e4f640b5159297580a9974b026043bd4ab0470be9ed324f1f", size = 271975 }
wheels = [
    { url = "https://files.pythonhosted.org/packages/28/2f/78a766c8913ad62b28581777ac4ede50c6d9f249d39c2963e279524a1bbe/pyzmq-26.2.0-cp312-cp312-macosx_10_15_universal2.whl", hash = "sha256:ded0fc7d90fe93ae0b18059930086c51e640cdd3baebdc783a695c77f123dcd9", size = 1343105 },
    # More binary wheels removed for brevity
]
```

And contrast it with a minimal manually package example to build the same package:
``` nix
{ stdenv, pyprojectHook, fetchurl }:
stdenv.mkDerivation {
  pname = "pyzmq";
  version = "26.2.0";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/fd/05/bed626b9f7bb2322cdbbf7b4bd8f54b1b617b0d2ab2d3547d6e39428a48e/pyzmq-26.2.0.tar.gz";
    hash = "sha256:070672c258581c8e4f640b5159297580a9974b026043bd4ab0470be9ed324f1f";
  };

  dontUseCmakeConfigure = true;

  buildInputs = [ zeromq ];

  nativeBuildInputs = [ pyprojectHook ] ++ resolveBuildSystem ({
    cmake = [];
    ninja = [];
    packaging = [];
    pathspec = [];
    scikit-build-core = [];
  } // if python.isPyPy then { cffi = []; } else { cython = []; });

  passthru.dependencies = lib.optionalAttrs python.isPyPy { cffi = []; };
}
```

Notably absent from `uv.lock` are:

- Native libraries

When building binary wheels `pyproject.nix` uses [https://nixos.org/manual/nixpkgs/stable/#setup-hook-autopatchelfhook](autoPatchelfHook).
This patches RPATH's of wheels with native libraries, but those must be present at build time.

- [PEP-517](https://peps.python.org/pep-0517/) build systems

Uv, like most Python package managers, installs binary wheels by default, and its solver doesn't take into account bootstrapping dependencies.
When building from an sdist instead of a wheel build systems will need to be added.

## Fixups

### Basic usage

### Wheels
When overriding a binary wheel, only runtime dependencies needs to be added. The `build-system.requires` section isn't relevant.

``` nix
{ pkgs, pyproject-nix }:
let
  pythonSet = pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  };

  pyprojectOverrides = final: prev: {
    pyzmq = prev.pyzmq.overrideAttrs(old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.zeromq ];
  });

in
  pythonSet.overrideScope pyprojectOverrides
```

### Sdist
When building from sources, both runtime dependencies and `build-system.requires` are important.

``` nix
{ pkgs, pyproject-nix }:
let
  pythonSet = pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  };

  pyprojectOverrides = final: prev: {
    pyzmq = prev.pyzmq.overrideAttrs(old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.zeromq ];
      dontUseCmakeConfigure = true;
      nativeBuildInputs = (old.nativeBuildInputs or []) ++ final.resolveBuildSystem ({
        cmake = [];
        ninja = [];
        packaging = [];
        pathspec = [];
        scikit-build-core = [];
      } // if python.isPyPy then { cffi = []; } else { cython = []; });
    });
  };

in
  pythonSet.overrideScope pyprojectOverrides
```

### Cross compilation

If cross compiling, build fixups might need to be applied to the build platform as well as the target platform.

When native compiling `pythonPkgsBuildHost` is aliased to the main set, meaning that overrides automatically apply to both.
When cross compiling `pythonPkgsBuildHost` is a Python set created for the _build host_.

``` nix
{ pkgs, pyproject-nix }:
let
  pythonSet = pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  };

  pyprojectOverrides = final: prev: {
    pyzmq = prev.pyzmq.overrideAttrs(old: {
      buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.zeromq ];
  });

  pyprojectCrossOverrides = lib.composeExtensions (_final: prev: {
    pythonPkgsBuildHost = prev.pythonPkgsBuildHost.overrideScope overlay;
  }) overlay;


in
  pythonSet.overrideScope pyprojectCrossOverrides
```

When not cross compiling `pythonPkgsBuildHost` is aliased to the main Python set, so overrides will apply to both automatically.

#### Dealing with common problems

For utility functions to deal with some common packaging issues see [hacks](./hacks.html).
