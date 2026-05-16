{
  description = "Flake using pyproject.toml metadata";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
    pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    nixpkgs,
    pyproject-nix,
    ...
  }: let
    inherit (nixpkgs) lib;

    wrapDefault = x: {default = x;};

    forAllSystems = f:
      lib.genAttrs lib.systems.flakeExposed (system:
        f nixpkgs.legacyPackages.${system});

    project = pyproject-nix.lib.project.loadPyproject {
      projectRoot = ./.;
    };

    pythonAttr = "python3";
  in {
    devShells = forAllSystems (pkgs: let
      python = pkgs.${pythonAttr};
      pythonEnv = python.withPackages (project.renderers.withPackages {inherit python;});
    in
      wrapDefault (pkgs.mkShell {packages = [pythonEnv];}));

    packages = forAllSystems (pkgs: let
      python = pkgs.${pythonAttr};
    in
      wrapDefault (python.pkgs.buildPythonPackage
        (project.renderers.buildPythonPackage {inherit python;})));
  };
}
