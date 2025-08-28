{
  pyproject-nix,
  lib,
  pkgs,
}:

{
  renderers = import ./test_renderers.nix { inherit pkgs lib pyproject-nix; };
  query = import ./test_query.nix { inherit pkgs lib pyproject-nix; };
  hacks = import ../hacks/tests.nix { inherit pkgs lib pyproject-nix; };
}
