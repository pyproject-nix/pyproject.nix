# Build editable Python wheels

## Rationale

- Producing editable wheels for installation into a custom prefix (the Nix store)

Within Nix we build each Python package in isolation and install them into their own Nix store prefixes (a requirement for per-package incremental builds).
For example the requests package in one of my projects is installed into `/nix/store/xhd2c62gj3b5ikwbpsp5kzyb88jc56g5-requests-2.32.3`.
This directory contains only the installed files from requests, and not their dependencies.

In the case of editable packages that means we have to produce a wheel to be able to run `uv pip install --prefix /nix/store/...` on it.

This package is used by [pyprojectEditableHook](https://pyproject-nix.github.io/pyproject.nix/build/hooks.html#function-library-build.packages.hooks.pyprojectEditableHook).

- Re-triggering of build system side effects

Because a [pyproject.nix build](https://pyproject-nix.github.io/pyproject.nix/build.html) produced virtual environment lives in the Nix store and th __ any side effects have been discarded.

Using this tool you can forcibly re-trigger build-system side effects such as running a `cython` build or bootstrapping `meson-python`'s import hooks.
