{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable-small";
  };

  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      npins = import ./npins;

      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
      inherit (nixpkgs) lib;

    in
    {
      githubActions = (import npins.nix-github-actions).mkGithubMatrix {
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

      # Note: This build infrastructure is experimental.
      build = import ./build {
        pyproject-nix = self;
        inherit lib;
      };

      lib = import ./lib { inherit lib; };

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
                pkgs.npins
              ] ++ self.packages.${system}.doc.nativeBuildInputs;
            };

        in
        {
          nix = mkShell' { inherit (pkgs) nix-unit; };

          lix = mkShell' {
            nix-unit =
              let
                lix = pkgs.lixVersions.latest;
              in
              (pkgs.nix-unit.override {
                # Hacky overriding :)
                nixVersions = lib.mapAttrs (_n: _v: lix) pkgs.nixVersions;
                # nix = pkgs.lixVersions.latest;
              }).overrideAttrs
                (_old: {
                  pname = "lix-unit";
                  name = "lix-unit-${lix.version}";
                  inherit (lix) version;
                  src = npins.lix-unit;
                });
          };

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
                  pkgs.basedpyright
                  pkgs.python3
                ];
              }
              ''
                cd ${self}
                basedpyright
                mkdir $out
              '';
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
      );
    };
}
