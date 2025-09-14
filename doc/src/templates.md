# Flake templates

Pyproject.nix offers a number of Flake templates to quickly get started with developing

To get started with any of the listed templates run (replace `name` with the template name):

## pyproject

Using nixpkgs for Python development based on a PEP-621 `pyproject.toml` file.
A quickstart & production version of [use-cases/pyproject](./use-cases/pyproject.html).

```
nix flake init --template github:pyproject-nix/pyproject.nix#pyproject
```

## requirements

Use a `requirements.txt` to create a Python environment using nixpkgs Python packages.
A quickstart & production version of [use-cases/requirements](./use-cases/requirements.html).

```
nix flake init --template github:pyproject-nix/pyproject.nix#requirements
```

## impure

Simple no frills best practices development shell to develop Python projects with Nix, but without using Nix tooling for Python packages.

Does not depend on `pyproject.nix`.

Uses `uv` for Python package management.

```
nix flake init --template github:pyproject-nix/pyproject.nix#impure
```
