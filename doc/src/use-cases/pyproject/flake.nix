{
  description = "A basic flake using pyproject.toml project metadata";

  inputs.pyproject-nix.url = "github:pyproject-nix/pyproject.nix";
  inputs.pyproject-nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    { nixpkgs, pyproject-nix, ... }:
    let
      # Loads pyproject.toml into a high-level project representation
      # Do you notice how this is not tied to any `system` attribute or package sets?
      # That is because `project` refers to a pure data representation.
      project = pyproject-nix.lib.project.loadPyproject {
        # Read & unmarshal pyproject.toml relative to this project root.
        # projectRoot is also used to set `src` for renderers such as buildPythonPackage.
        projectRoot = ./.;
      };

      # This example is only using x86_64-linux
      pkgs = nixpkgs.legacyPackages.x86_64-linux;

      # We are using the default nixpkgs Python3 interpreter & package set.
      #
      # This means that you are purposefully ignoring:
      # - Version bounds
      # - Dependency sources (meaning local path dependencies won't resolve to the local path)
      #
      # To use packages from local sources see "Overriding Python packages" in the nixpkgs manual:
      # https://nixos.org/manual/nixpkgs/stable/#reference
      #
      # Or use an overlay generator such as uv2nix:
      # https://github.com/pyproject-nix/uv2nix
      python = pkgs.python3;

    in
    {
      # Create a development shell containing dependencies from `pyproject.toml`
      devShells.x86_64-linux.default =
        let
          # Returns a function that can be passed to `python.withPackages`
          arg = project.renderers.withPackages { inherit python; };

          # Returns a wrapped environment (virtualenv like) with all our packages
          pythonEnv = python.withPackages arg;

        in
        # Create a devShell like normal.
        pkgs.mkShell { packages = [ pythonEnv ]; };

      # Build our package using `buildPythonPackage
      packages.x86_64-linux.default =
        let
          # Returns an attribute set that can be passed to `buildPythonPackage`.
          attrs = project.renderers.buildPythonPackage { inherit python; };
        in
        # Pass attributes to buildPythonPackage.
        # Here is a good spot to add on any missing or custom attributes.
        python.pkgs.buildPythonPackage (attrs // { env.CUSTOM_ENVVAR = "hello"; });
    };
}
