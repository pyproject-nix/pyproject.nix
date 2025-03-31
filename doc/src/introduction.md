# Introduction

## What is pyproject.nix

Pyproject.nix is a collection of Nix utilities to work with Python project metadata in [Nix](https://nixos.org/).
It mainly targets [PEP-621](https://peps.python.org/pep-0621/) compliant `pyproject.toml` files and data formats, but also implement support for other & legacy formats such as [Poetry](https://python-poetry.org/) & `requirements.txt`.

Pyproject.nix aims to be a swiss army knife of simple customizable utilities that works either together with the [nixpkgs Python infrastructure](https://nixos.org/manual/nixpkgs/stable/#python), or [our own build infrastructure](./build.md).

## Foreword

This documentation only helps you to get started with `pyproject.nix`.
As it's a toolkit with many use cases not every use case can be documented fully.

First and foremost `pyproject.nix` is a _Python metadata toolkit_, and not a 2nix tool.

This documentation is centered around packaging Python applications & managing development environments.
For other use cases see the reference documentation.

## Concepts

`pyproject.nix` introduces a few high level abstract concepts.
The best way to get started is to understand these concepts and how they fit together.

### [Project](./lib/project.md)

A `project` attribute set is a high-level representation of a project that includes:

- The parsed `pyproject.toml` file
- Parsed dependencies
- Project root directory

It can can be loaded from many different sources:

- PEP-621 `pyproject.toml`
- PEP-621 `pyproject.toml` with PDM extensions
- Poetry `pyproject.toml`
- `requirements.txt`

### [Validators](./lib/validators.md)

Validators work on dependency constraints as defined in a `project` and offers validation for them.
This can be useful to check that a package set is compliant with the specification.

### [Renderers](./lib/renderers.md)

A `renderer` takes a `project` together with a Python interpreter derivation and renders it into a form understood by various pieces of Python infrastructure.

For example: The `buildPythonPackage` renderer returns an attribute set that can be passed to either nixpkgs function `buildPythonPackage` or `buildPythonApplication`.

There might be information missing from what a renderer returned depending on what can be computed from the `project`.
If any attributes are missing you can manually merge your own attribute set with what the renderer returned.

## Tying it together

For a concrete example use see [Use cases -> pyproject.toml](./use-cases/pyproject.md).
