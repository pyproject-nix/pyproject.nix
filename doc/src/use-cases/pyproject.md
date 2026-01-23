# pyproject.toml

It's possible to develop [PEP-621](https://peps.python.org/pep-0621/) compliant Python projects without using _any_ Python package manager except Nix.

This example loads `pyproject.toml` to create an environment using [`python.withPackages`](https://nixos.org/manual/nixpkgs/stable/#user-guide) and a consumable package using `python.pkgs.buildPythonPackage`.

## flake.nix

```nix
{{#include ./pyproject/flake.nix}}
```

## pyproject.toml

```toml
{{#include ../../../templates/pyproject/pyproject.toml}}
```
