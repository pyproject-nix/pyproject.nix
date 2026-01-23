{
  description = "Construct development shell from requirements.txt";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  inputs.pyproject-nix.url = "github:pyproject-nix/pyproject.nix";

  outputs =
    { nixpkgs, pyproject-nix, ... }:
    let
      # Load/parse requirements.txt
      project = pyproject-nix.lib.project.loadRequirementsTxt { projectRoot = ./.; };

      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      python = pkgs.python3;

      pythonEnv =
        # Assert that versions from nixpkgs matches what's described in requirements.txt
        # In projects that are overly strict about pinning it might be best to remove this assertion entirely.
        assert project.validators.validateVersionConstraints { inherit python; } == { };
        (
          # Render requirements.txt into a Python withPackages environment
          pkgs.python3.withPackages (project.renderers.withPackages { inherit python; })
        );

    in
    {
      devShells.x86_64-linux.default = pkgs.mkShell { packages = [ pythonEnv ]; };
    };
}
