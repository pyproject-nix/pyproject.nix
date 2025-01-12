# Hacking

This document outlines hacking on `pyproject.nix` itself, and lays out its project structure.

## Getting started

To start hacking run `nix develop -c hivemind` to run the project in watch mode.

This will start up two processes:

- A [Nix-unit](https://github.com/adisbladis/nix-unit) test runner
- A [documentation server](https://rust-lang.github.io/mdBook/) available at http://localhost:3000

## Project structure & testing

All Nix code lives in `lib/`. Each file has an implementation and a test suite.
The attribute path to a an attribute `parseVersion` in `lib/pep440.nix` would be `lib.pep440.parseVersion`.

A function in `lib/test.nix` maps over the public interface of the library and the test suite to generate coverage tests, ensuring that every exported symbol has at least one test covering it.

Integration tests meaning tests that perform environment constructions & builds lives in `test/` and are exposed through Flake checks.

The manual you are reading right now is built from the `doc/` directory.
To edit a specific page see the "Edit this page on GitHub" link in the footer for each respective page.

## Running tests

- Run the entire unit test suite
  `$ nix-unit --flake .#libTests`

- Run unit tests for an individual function
  `$ nix-unit --flake .#libTests.pep440.parseVersion`

- Run integration tests
  `$ nix flake check`

## Formatter

Before submitting a PR format the code with `nix fmt` and ensure Flake checks pass with `nix flake check`.
