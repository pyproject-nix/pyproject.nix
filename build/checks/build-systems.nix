{
  lib,
}:
let
  overlay' =
    final: _prev:
    lib.mapAttrs (_name: pkg: final.callPackage pkg { }) {
      build =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
          python,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.build)
            pname
            version
            src
            meta
            ;

          passthru.dependencies = {
            packaging = [ ];
            pyproject-hooks = [ ];
          }
          // lib.optionalAttrs (python.pythonOlder "3.11") {
            tomli = [ ];
          };

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
            pyproject-hooks = [ ];
          };
        };

      calver =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.calver)
            pname
            version
            src
            meta
            postPatch
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            setuptools = [ ];
          };
        };

      cffi =
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

            nativeBuildInputs = [
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
        );

      pyproject-hooks =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          flit-core,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.pyproject-hooks)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      pycparser =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.pycparser)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem { };
        };

      flit-core =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.flit-core)
            pname
            version
            src
            meta
            patches
            ;
          postPatch = python3Packages.flit-core.postPatch or null;
          sourceRoot = python3Packages.flit-core.sourceRoot or null;
          nativeBuildInputs = [
            pyprojectHook
          ];
        };

      semantic-version =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.semantic-version)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            setuptools = [ ];
          };
        };

      editables =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.editables)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      hatchling =
        {
          stdenv,
          lib,
          python,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation (finalAttrs: {
          inherit (python3Packages.hatchling)
            pname
            version
            src
            meta
            ;

          passthru.dependencies = {
            packaging = [ ];
            pathspec = [ ];
            pluggy = [ ];
            trove-classifiers = [ ];
            editables = [ ];
          }
          // lib.optionalAttrs (python.pythonOlder "3.11") {
            tomli = [ ];
          };

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem finalAttrs.passthru.dependencies;
        });

      pathspec =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.pathspec)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      pluggy =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
          setuptools-scm,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.pluggy)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            setuptools-scm = [ ];
          };
        };

      tomli =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.tomli)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      tomli-w =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.tomli-w)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      typing-extensions =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.typing-extensions)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      trove-classifiers =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.trove-classifiers)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            setuptools = [ ];
            calver = [ ];
          };
        };

      installer =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.installer)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      setuptools =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.setuptools)
            pname
            version
            src
            meta
            patches
            preBuild # Skips windows files
            ;

          passthru.dependencies.wheel = [ ];

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      pip =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.pip)
            pname
            version
            src
            meta
            postPatch
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            setuptools = [ ];
            wheel = [ ];
          };
        };

      wheel =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.wheel)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      maturin =
        {
          stdenv,
          pkgs,
          rustPlatform,
          cargo,
          rustc,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (pkgs.maturin)
            pname
            version
            cargoDeps
            src
            meta
            ;

          nativeBuildInputs = [
            rustPlatform.cargoSetupHook
            pyprojectHook
            cargo
            rustc
          ]
          ++ resolveBuildSystem {
            setuptools = [ ];
            wheel = [ ];
            # tomli = [ ];
            setuptools-rust = [ ];
          };
        };

      setuptools-scm =
        {
          stdenv,
          lib,
          python,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.setuptools-scm)
            pname
            version
            src
            meta
            setupHook
            ;

          passthru = {
            dependencies = {
              packaging = [ ];
              setuptools = [ ];
            }
            // lib.optionalAttrs (python.pythonOlder "3.11") {
              tomli = [ ];
            }
            // lib.optionalAttrs (python.pythonOlder "3.10") {
              typing-extensions = [ ];
            };

            optional-dependencies = {
              toml = {
                tomli = [ ];
              };
              rich = {
                rich = [ ];
              };
            };
          };

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem (
            {
              setuptools = [ ];
            }
            // lib.optionalAttrs (python.pythonOlder "3.11") {
              tomli = [ ];
            }
          );
        };

      setuptools-rust =
        {
          stdenv,
          lib,
          python,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.setuptools-rust)
            pname
            version
            src
            meta
            ;

          passthru.dependencies = {
            semantic-version = [ ];
            setuptools = [ ];
            typing-extensions = [ ];
          }
          // lib.optionalAttrs (python.pythonOlder "3.11") {
            tomli = [ ];
          };

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            setuptools = [ ];
            setuptools-scm = [ ];
          };
        };

      packaging =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.packaging)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            flit-core = [ ];
          };
        };

      libcst =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
          rustPlatform,
          cargo,
          rustc,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.libcst)
            name
            pname
            src
            version
            cargoDeps
            cargoRoot
            ;
          passthru.dependencies = {
            pyyaml = [ ];
          };
          nativeBuildInputs = [
            pyprojectHook
            rustPlatform.cargoSetupHook
            cargo
            rustc
          ]
          ++ resolveBuildSystem {
            setuptools = [ ];
            setuptools-rust = [ ];
          };
        };

      pyyaml =
        {
          stdenv,
          python3Packages,
          pyprojectHook,
          resolveBuildSystem,
        }:
        stdenv.mkDerivation {
          inherit (python3Packages.pyyaml)
            pname
            version
            src
            meta
            ;

          nativeBuildInputs = [
            pyprojectHook
          ]
          ++ resolveBuildSystem {
            setuptools = [ ];
          };
        };
    };

  crossOverlay = lib.composeExtensions (_final: prev: {
    pythonPkgsBuildHost = prev.pythonPkgsBuildHost.overrideScope overlay';
  }) overlay';

in
final: prev:
if prev.stdenv.buildPlatform != prev.stdenv.hostPlatform then
  crossOverlay final prev
else
  overlay' final prev
