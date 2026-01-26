{ stdenv, lib, cargo, rustc, rustPlatform }:
stdenv.mkDerivation (finalAttrs: {
  pname = "link-ctypes";
  version = "0.1.0";

  src = ./.;

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-ZojwpEDkQWgXh7aduK1bETZo7C0LGbSsPRA91CpV8zI=";
  };

  cargoBuildType = "release";

  nativeBuildInputs = [
    cargo
    rustPlatform.cargoSetupHook
    rustPlatform.cargoBuildHook
    rustPlatform.cargoInstallHook
    rustc
  ];

  meta = {
    license = lib.licenses.mit;
    mainProgram = "link-ctypes";
    platforms = lib.platforms.all;
  };
})
