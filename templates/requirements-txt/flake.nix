{
  description = "Construct development shell from requirements.txt";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  inputs.pyproject-nix.url = "github:pyproject-nix/pyproject.nix";

  outputs =
    { nixpkgs, pyproject-nix, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;

      project = pyproject-nix.lib.project.loadRequirementsTxt { projectRoot = ./.; };

      pythonAttr = "python3";
    in
    {
      devShells = forAllSystems (system: {
        default =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            python = pkgs.${pythonAttr};
            pythonEnv =
              assert project.validators.validateVersionConstraints { inherit python; } == { };
              (python.withPackages (project.renderers.withPackages { inherit python; }));
          in
          pkgs.mkShell { packages = [ pythonEnv ]; };
      });
    };
}
