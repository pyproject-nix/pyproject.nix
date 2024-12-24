# Build

<div class="warning">
The pyproject.nix build infrastructure is mainly targeted at python2nix authors, and is being used in uv2nix.
</div>

Pyproject.nix can be used with nixpkgs `buildPythonPackage`/`packageOverrides`/`withPackages`, but also implements it's own build infrastructure that fixes many structural problems with the nixpkgs implementation.

## Problems with nixpkgs Python builders

Nixpkgs Python infrastucture relies on [dependency propagation](https://nixos.org/manual/nixpkgs/unstable/#ssec-stdenv-dependencies-propagated).
The propagation mechanism works through making dependencies available to the builder at build-time, and recording their Nix store paths in `$out/nix-support/propagated-build-inputs`.
[Setup hooks](https://nixos.org/manual/nixpkgs/unstable/#ssec-setup-hooks) are then used to add these packages to `$PYTHONPATH` for discovery by the Python interpreter which adds everything from `$PYTHONPATH` to `sys.path` at startup.

Propagation causes several issues downstream.

### `$PYTHONPATH` leaking into unrelated builds

Consider the following development shell using nixpkgs Python builders:
``` nix
let
  pkgs = import <nixpkgs> { };
  pythonEnv = pkgs.python3.withPackages(ps: [ ps.requests ]);
in pkgs.mkShell {
  packages = [
    pkgs.remarshal
    pythonEnv
  ];
}
```

Any Python package, such as `remarshal`, will have their dependencies leaking into `$PYTHONPATH`, making undeclared dependencies available to the Python interpreter.
Making matters even worse: Any dependency on `$PYTHONPATH` takes precedence over virtualenv installed dependencies!

### Infinite recursions

Nix dependency graphs are required to be a [DAG](https://en.wikipedia.org/wiki/Directed_acyclic_graph), but Python dependencies can be cyclic.
Dependency propagation is inherently incompatible with cyclic dependencies.
In nixpkgs propagation isssues are commonly worked around by patching packages in various ways.

### Binary wrapping

Nixpkgs Python builders uses wrappers for Python executables in `bin/`, these set environment variables `NIX_PYTHONPATH` & friends
These environment variables are picked up by the interpreter using a [sitecustomize.py](https://docs.python.org/3/library/site.html#module-sitecustomize) in the system `site-packages` directory.

Any Python programs executing another child Python interpreter using `sys.executable` will have it's modules lost on import, as `sys.executable` isn't pointing to the environment created by `withPackages`.

### Extraneous rebuilds

Because `buildPythonPackage` uses propagation runtime dependencies of a package are required to be present at build time.

In Python builds runtime dependencies are not actually required to be present.
Making runtime dependencies available at build-time results in derivation hashes changing much more frequently than they have to.

## Solution presented by pyproject.nix's builders

The solution is to decouple the runtime dependency graph from the build time one, by putting runtime dependencies in [passthru](https://nixos.org/manual/nixpkgs/unstable/#chap-passthru):
``` nix
stdenv.mkDerivation {
  pname = "setuptools-scm";
  version = "8.1.0";
  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/4f/a4/00a9ac1b555294710d4a68d2ce8dfdf39d72aa4d769a7395d05218d88a42/setuptools_scm-8.1.0.tar.gz";
    hash = "";
  };

  passthru = {
    dependencies = {
      packaging = [ ];
      setuptools = [ ];
    };

    optional-dependencies = {
      toml = { toml = [ ]; };
      rich = { rich = [ ]; };
    };
  };

  nativeBuildInputs = [
    pyprojectHook
  ] ++ resolveBuildSystem (
    {
      setuptools = [ ];
    }
  );
}
```

### Resolving

Because runtime dependencies are not propagated every package needs to resolve the runtime dependencies of their build-system's.

Additionally packages can't simply be consumed, but must be aggregated into a virtual environment to be useful:
``` nix
{ pyproject-nix, pkgs }:

let
  python = pkgs.python312;

  # Inject your own packages on top with overrideScope
  pythonSet = pkgs.callPackage pyproject-nix.build.packages {
    inherit python;
  };

in pythonSet.pythonPkgsHostHost.mkVirtualEnv "test-venv" {
  build = [ ];
}
```

### Cyclic dependencies

Cyclic dependencies are supported thanks to the resolver returning a flat list of required Python packages.
For performance reasons two solvers are implemented:

- One that does not support cyclic dependencies
  A much more performant resolver used by resolveBuildSystem and has all known build-systems memoized.

- One that does support cyclic dependencies
  Used to resolve virtual environments

It's possible to override the resolver used entirely, so even though cyclic build-system's are not supported by default, it can be done with overrides.

### Less rebuilds

As the runtime dependency graph is decoupled from the build time one derivation hashes change far less frequently.

An additional benefit is improved build scheduling:
Because the dependency graph is much flatter than a `buildPythonPackage` based one derivations can be more efficiently scheduled in parallel.

### Use virtualenvs

Instead of binary wrappers & environment variables `pyproject.nix`'s builders use standard Python virtual environments.
