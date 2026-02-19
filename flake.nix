{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      inherit (nixpkgs) lib;

      pyproject-nix = import ./default.nix {
        inherit lib;
      };

      ciFlake =
        let
          lockFile = builtins.fromJSON (builtins.readFile ./ci/flake.lock);
          flake-compat-node = lockFile.nodes.${lockFile.nodes.root.inputs.flake-compat};
          flake-compat = builtins.fetchTarball {
            inherit (flake-compat-node.locked) url;
            sha256 = flake-compat-node.locked.narHash;
          };
        in
        import flake-compat {
          copySourceTreeToStore = false;
          src = ./ci;
        };

    in
    {
      githubActions = (import ciFlake.inputs.nix-github-actions).mkGithubMatrix {
        checks =
          let
            strip = lib.flip removeAttrs [
              # No need to run formatter check on multiple platforms
              "formatter"

              # Takes very long to build on Darwin and should have been adequately tested on Linux only.
              "build-make-venv-cross"
            ];

          in
          {
            inherit (self.checks) x86_64-linux;
            aarch64-darwin = strip self.checks.aarch64-darwin;
          };
      };

      inherit (pyproject-nix) lib build;

      templates =
        let
          root = ./templates;
          dirs = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir root));
        in
        lib.listToAttrs (
          map (
            dir:
            let
              path = root + "/${dir}";
              template = import (path + "/flake.nix");
            in
            lib.nameValuePair dir {
              inherit path;
              inherit (template) description;
            }
          ) dirs
        );

      # Expose unit tests for external discovery
      libTests =
        import ./lib/test.nix {
          inherit lib;
          pyproject = self.lib;
          pkgs = nixpkgs.legacyPackages.x86_64-linux;
        }
        // {
          build = import ./build/lib/test.nix {
            pyproject-nix = self;
            inherit lib;
            pkgs = nixpkgs.legacyPackages.x86_64-linux;
          };
        };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          mkShell' =
            { nix-unit }:
            pkgs.mkShell {
              packages = [
                nix-unit
                (pkgs.python3.withPackages (_ps: [ ]))
                pkgs.hivemind
                pkgs.reflex
                self.formatter.${system}
              ]
              ++ self.packages.${system}.doc.nativeBuildInputs;
            };

        in
        {
          nix = mkShell' { inherit (pkgs) nix-unit; };

          default = self.devShells.${system}.nix;
        }
      );

      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        (lib.mapAttrs' (name: drv: lib.nameValuePair "nixpkgs-${name}" drv) (
          pkgs.callPackages ./test { pyproject = self; }
        ))
        // (lib.mapAttrs' (name: drv: lib.nameValuePair "build-${name}" drv) (
          pkgs.callPackages ./build/checks { pyproject-nix = self; }
        ))
        // (lib.mapAttrs' (name: drv: lib.nameValuePair "build-hacks-${name}" drv) (
          pkgs.callPackages ./build/hacks/checks.nix {
            pyproject-nix = self;
          }
        ))
        // (lib.mapAttrs' (name: drv: lib.nameValuePair "build-util-${name}" drv) (
          pkgs.callPackages ./build/util/checks.nix {
            pyproject-nix = self;
          }
        ))
        // {
          formatter =
            pkgs.runCommand "fmt-check"
              {
                nativeBuildInputs = [ self.formatter.${system} ];
              }
              ''
                export HOME=$(mktemp -d)
                cp -r ${self} $(stripHash "${self}")
                chmod -R +w .
                cd source
                treefmt --fail-on-change
                touch $out
              '';

          typing =
            pkgs.runCommand "typing-check"
              {
                nativeBuildInputs = [
                  (pkgs.basedpyright.overrideAttrs (old: {
                    # Nixpkgs build of basedpyright is broken because of a dangling symlinks check
                    postInstall = old.postInstall + ''

                      find -L $out -type l -print -delete
                    '';
                  }))
                  pkgs.python3
                ];
              }
              ''
                cd ${self}
                basedpyright
                mkdir $out
              '';
        }
        // {
          # Run a smoke test on 22.11 (the oldest supported nixpkgs)
          # to ensure you can instantiate a package set with it
          #
          # While this older nixpkgs is supported we don't want to run the full gamut of tests because it would take too long.
          build-22_11-compat =
            let
              pkgs' = import ciFlake.inputs.nixpkgs-22_11 {
                inherit system;
                overlays = [
                  (_: _: {
                    # The pyproject.nix test harness inherits sources from pythonPackages
                    # and 22.11 versions fail to build for various reasons.
                    inherit (pkgs) python3Packages;

                    # Older uv versions lack important features, and 22.11 doesn't even contain uv.
                    # Users of older channels need to pass a more recent uv.
                    # Hint: Uv2nix provides a uv-bin package.
                    inherit (pkgs) uv;
                  })
                ];
              };

            in
            pkgs'.callPackage ./build/checks/smoke.nix {
              name = "build-22_11-compat";
              pyproject-nix = self;
            };
        }
      );

      formatter = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.callPackage ./treefmt.nix { }
      );

      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          doc = pkgs.callPackage ./doc {
            inherit self;
          };
        }
        // pkgs.callPackages pyproject-nix.packages { }
      );
    };
}
