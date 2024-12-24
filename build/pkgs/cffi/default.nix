{
  stdenv,
  python,
  python3Packages,
  pyprojectHook,
  resolveBuildSystem,
  pkg-config,
  libffi,
  lib,
}:
stdenv.mkDerivation (
  {
    inherit (python3Packages.cffi)
      pname
      version
      src
      meta
      patches
      ;

    env = {
      inherit (python3Packages.cffi) NIX_CFLAGS_COMPILE;
    };

    buildInputs = [ libffi ];

    nativeBuildInputs =
      [
        pyprojectHook
        pkg-config
        python
      ]
      ++ resolveBuildSystem {
        setuptools = [ ];
      };
  }
  // lib.optionalAttrs (python3Packages.cffi ? postPatch) {
    inherit (python3Packages.cffi) postPatch;
  }
)
