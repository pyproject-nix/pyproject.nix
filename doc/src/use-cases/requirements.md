# requirements.txt

Many projects comes without proper packaging and use [`requirements.txt`](https://pip.pypa.io/en/stable/reference/requirements-file-format/) files to declare their dependencies.

This example loads `requirements.txt` to create an environment using [`python.withPackages`](https://nixos.org/manual/nixpkgs/stable/#user-guide) with packages from nixpkgs.

## flake.nix

```nix
{{#include ./requirements/flake.nix}}
```
