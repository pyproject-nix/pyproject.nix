{ pkgs, lib }:

let
  inherit (pkgs) stdenv;
  inherit (lib) isDerivation isAttrs listToAttrs;
  inherit (builtins)
    concatMap
    elem
    attrNames
    mapAttrs
    isFunction
    isList
    typeOf
    filter
    ;

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

  /**
    Create a nixpkgs Python (buildPythonPackage) compatible package from a pyproject.nix build package.

    Adapts a package by:
    - Activating a wheel output, if not already enabled
    - Create a package using generated wheel as input

    Note: toNixpkgs is still experimental and subject to change.

    # Example

    ```nix
    toNixpkgs {
      inherit pythonSet;
      packages = [ "requests" ];
    }
    =>
    «lambda @ /nix/store/f05hjk9fh1m5py5j1ixzly07p4lla56x-source/build/hacks/default.nix:263:5»
    ```

    # Type

    ```
    nixpkgsPrebuilt :: AttrSet -> derivation
    ```

    # Arguments

    pythonSet
    : Pyproject.nix build Python package set

    packages
    : List/predicate of overlay member packages
  */
  toNixpkgs =
    let
      # Always filter out when generating set
      wellKnown = [
        "python"
        "pkgs"
        "stdenv"
        "pythonPkgsBuildHost"
        "resolveBuildSystem"
        "resolveVirtualEnv"
        "mkVirtualEnv"
        "hooks"
      ];
    in
    {
      pythonSet,
      packages ? null,
    }:
    let
      packages' =
        if (packages == null || isFunction packages) then
          (
            let
              hookNames = attrNames pythonSet.hooks;
              predicate = if packages == null then (_: true) else packages;
            in
            filter (name: !elem name wellKnown && !elem name hookNames && predicate name) (attrNames pythonSet)
          )
        else if isList packages then
          packages
        else
          throw "Unhandled packages type: ${typeOf packages}";

      # Ensure wheel artifacts are created for all packages we are generating from
      pythonSet' = pythonSet.overrideScope (
        _final: prev:
        listToAttrs (
          map (
            name:
            let
              drv = prev.${name};
            in
            {
              inherit name;
              value =
                if elem "dist" (drv.outputs or [ ]) then
                  drv
                else
                  drv.overrideAttrs (old: {
                    outputs = (old.outputs or [ "out" ]) ++ [ "dist" ];
                  });
            }
          ) packages'
        )
      );
    in
    pythonPackagesFinal: _pythonPackagesPrev:
    let
      inherit (pythonPackagesFinal) buildPythonPackage pkgs;
      inherit (pkgs) autoPatchelfHook;
    in
    listToAttrs (
      map (
        name:
        let
          from = pythonSet'.${name};
          dependencies = from.passthru.dependencies or { };
          optional-dependencies = from.passthru.optional-dependencies or { };
        in
        {
          inherit name;
          value = buildPythonPackage {
            inherit (from) pname version;
            src = from.dist;

            format = "wheel";
            dontBuild = true;

            # Default wheelUnpackPhase assumes we are passing a single wheel, but we are passing a dist dir
            unpackPhase = ''
              runHook preUnpack
              mkdir dist
              cp ${from.dist}/* dist/
              # runHook postUnpack # Calls find...?
            '';

            # Include any buildInputs from build for autoPatchelfHook
            buildInputs = from.buildInputs or [ ];

            nativeBuildInputs = lib.optional stdenv.isLinux [
              autoPatchelfHook
            ];

            propagatedBuildInputs = concatMap (
              name:
              let
                pkg = pythonPackagesFinal.${name};
                extras = dependencies.${name};
              in
              [ pkg ]
              ++ concatMap (
                extra:
                # Note: The fallback or [ ] is because nixpkgs often lacks optional-dependencies metadata.
                pkg.optional-dependencies.${extra} or [ ]
              ) extras
            ) (attrNames dependencies);

            passthru = {
              optional-dependencies = mapAttrs (
                name: dependencies:
                concatMap (
                  name:
                  let
                    pkg = pythonPackagesFinal.${name};
                    extras = dependencies.${name};
                  in
                  [ pkg ] ++ concatMap (extra: pkg.optional-dependencies.${extra} or [ ]) extras
                ) (attrNames dependencies)
              ) optional-dependencies;
            };

            # Note: PEP-735 dependency groups are dropped as nixpkgs lacks support.
          };
        }
      ) packages'
    );
}
