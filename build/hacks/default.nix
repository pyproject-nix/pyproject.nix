{ pkgs, lib }:

let
  inherit (pkgs) stdenv;
  inherit (lib) isDerivation isAttrs;

in
{
  /**
    Use a package output built by Nixpkgs Python infrastructure.

    Adapts a package by:
    - Stripping dependency propagation
    - Throwing away shell script wrapping
    - Filtering out sys.path dependency injection

    This adaptation will of course break anything depending on other packages by `$PATH`, as these are injected by wrappers.

    # Example

    ```nix
    nixpkgsPrebuilt {
      from = pkgs.python3Packages.torchWithoutCuda;
      prev = prev.torch;
    }
    =>
    «derivation /nix/store/3864g3951bkbkq5nrld5yd8jxq7ss72y-torch-2.4.1.drv»
    ```

    # Type

    ```
    nixpkgsPrebuilt :: AttrSet -> derivation
    ```

    # Arguments

    from
    : Prebuilt package to transform output from

    prev
    : Previous pyproject.nix package to take passthru from
  */
  nixpkgsPrebuilt =
    {
      # Take build results from package
      # Example: pkgs.python3Packages.torchWithoutCuda
      from,
      # Previous package to take passthru from
      prev ? {
        passthru = { };
      },
      # Disable ABI compatibility warnings
      quiet ? false,
    }:
    assert isDerivation from;
    assert isAttrs prev; # Allow prev to be a simple attrset
    let
      pyprojectHook = lib.findFirst (
        input: input.name == "pyproject-hook"
      ) (throw "Pyproject hook not found in ${prev.drvPath}") prev.nativeBuildInputs;

      nixpkgsPython = from.pythonModule;
      # Allow to skip prev argument in cases like https://github.com/pyproject-nix/pyproject.nix/issues/267
      python = if prev ? nativeBuildInputs then pyprojectHook.passthru.python else null;

    in
    lib.throwIf (python != null && nixpkgsPython.pythonVersion != python.pythonVersion)
      "Mismatching Python versions for ${from.drvPath} & ${prev.drvPath or "<no-drv>"}: ${nixpkgsPython.pythonVersion} != ${python.pythonVersion}"
      lib.warnIf
      (!quiet && python != null && nixpkgsPython != python)
      "Mismatching Python derivations for ${from.drvPath} & ${prev.drvPath or "<no-drv>"} ${nixpkgsPython} != ${python}, beware of ABI compatibility issues"
      (
        stdenv.mkDerivation {
          inherit (from) pname version;
          inherit (prev) passthru;

          nativeBuildInputs = [
            nixpkgsPython.pythonOnBuildForHost
          ];

          dontUnpack = true;
          dontConfigure = true;
          dontBuild = true;
          dontFixup = true;

          installPhase = ''
            python3 ${./write-nixpkgs-prebuilt.py} --store ${builtins.storeDir} ${from} "$out"
          '';
        }
      );

  /**
    Build a Cargo (Rust) package using rustPlatform.importCargoLock to fetch Rust dependencies.

    Uses IFD (import-from-derivation) on non-local packages.

    # Example

    ```nix
    importCargoLock {
      prev = prev.cryptography;
      # Lock file relative to source root
      lockFile = "src/rust/Cargo.lock";
    }
    =>
    «derivation /nix/store/g3z1zlmc0sqpd6d5ccfrx3c4w4nv5dzr-cryptography-43.0.0.drv»
    ```

    # Type

    ```
    importCargoLock :: AttrSet -> derivation
    ```

    # Arguments

    prev
    : Previous pyproject.nix package

    importCargoLockArgs
    : Arguments passed directly to `rustPlatform.importCargoLock` function

    cargoRoot
    : Path to Cargo source root

    lockFile
    : Path to Cargo.lock (defaults to `${cargoRoot}/Cargo.lock`)

    doUnpack
    : Whether to unpack sources using an intermediate derivation

    unpackDerivationArgs
    : Arguments passed directly to intermediate unpacker derivation (unused for path sources)

    cargo
    : cargo derivation

    rustc
    : rustc derivation

    pkg-config
    : pkg-config derivation
  */
  importCargoLock =
    {
      prev,
      importCargoLockArgs ? { },
      unpackDerivationArgs ? { },
      cargoRoot ? ".",
      lockFile ? "${cargoRoot}/Cargo.lock",
      cargo ? pkgs.cargo,
      rustc ? pkgs.rustc,
      pkg-config ? pkgs.pkg-config,
      doUnpack ? !lib.isPath prev.src,
    }:
    let
      # Ensure package is unpacked, not an archive.
      src =
        if !doUnpack then
          prev.src
        else
          stdenv.mkDerivation (
            unpackDerivationArgs
            // {
              name = prev.src.name + "-unpacked";
              inherit (prev) src;
              dontConfigure = true;
              dontBuild = true;
              dontFixup = true;
              preferLocalBuild = true;
              installPhase = ''
                cp -a . $out
              '';
            }
          );

    in
    assert isDerivation prev;
    prev.overrideAttrs (old: {
      inherit cargoRoot src;
      cargoDeps = pkgs.rustPlatform.importCargoLock (
        {
          lockFile = "${src}/${lockFile}";
        }
        // importCargoLockArgs
      );
      nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
        pkgs.rustPlatform.cargoSetupHook
        pkg-config
        cargo
        rustc
      ];
    });
}
