# Usage

While the nixpkgs Python infrastructure is built mainly for manual packaging, `pyproject.nix`'s builders are mainly targeted at lock file consumers like [uv2nix](https://github.com/pyproject-nix/uv2nix).

This example shows the essence of implementing a lock file converter in pure Nix using `pyproject.nix`.
A real world implementation is more complex. To see a lock file converter built according to `pyproject.nix` best practices see [uv2nix](https://github.com/pyproject-nix/uv2nix).

## example.nix

```nix
{{#include ./minimal-lock.nix}}
```

## Nixpkgs compatibility

`Pyproject.nix` builders support nixpkgs `>=22.11`, but with some important caveats.
The `pyproject.nix` build hooks require a more recent version of `uv`(`>=0.5.7`) on older channels, which needs to be added via a nixpkgs overlay like:
```nix
import nixpkgs {
    overlays = [
      (final: prev: {
        uv = inputs.uv2nix.packages.${system}.uv-bin;
      })
    ];
}
```
