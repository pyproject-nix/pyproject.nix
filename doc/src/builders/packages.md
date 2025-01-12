# packages

`pyproject.nix`'s base package set only contains the scaffolding for a Python package set, but no actual Python packages.

## Creating a base package set

``` nix
# Returns a scope with base packages.
pkgs.callPackage pyproject-nix.build.packages {
  python = interpreter;
}
```

## Build-system packages

For package managers that lack the ability to solve build-system dependencies `pyproject.nix` maintains a [base package set](https://github.com/pyproject-nix/build-system-pkgs).
This set is much smaller and more narrow in scope than nixpkgs, its purpose is only to package [build-system](https://peps.python.org/pep-0518/) dependencies, which are missing from Python package manager lock files, so needs to be supplemented from elsewhere.

## Overriding scope

See the [nixpkgs documentation](https://nixos.org/manual/nixpkgs/stable/#function-library-lib.customisation.makeScope).

