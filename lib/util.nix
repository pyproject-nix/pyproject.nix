{
  pep440,
  lib,
  ...
}:
let
  inherit (builtins) all attrValues sort;
  inherit (lib) filterAttrs hasSuffix mapAttrs;
in
{
  /**
    Filter Python interpreter derivations from an attribute set based on
    python-requires constraints. Returns list of interpreter derivations
    sorted by version descending.

    # Example:
    ```nix
    util.filterPythonInterpreters {
      requires = pep440.parseVersionConds ">=3.12";
      inherit (pkgs) pythonInterpreters;
    }
    ->
    [
      «derivation /nix/store/fvac8j3h7sxqfaw7hllr9cllns34pgcm-python3-3.14.0.drv»
      «derivation /nix/store/6p8y1zwm68kksdrad12ybn7lrvvpgwc5-python3-3.13.8.drv»
      «derivation /nix/store/5iwwrbr1dh1yc63gmz1alsk1d96jgfjy-python3-3.12.11.drv»
    ]
    ```
  */

  filterPythonInterpreters =
    {
      requires-python,
      pythonInterpreters,
      pre ? false,
      implementation ? "cpython",
    }:
    map (attrs: attrs.drv) (
      sort (a: b: pep440.compareVersions a.version b.version == 1) (
        attrValues (
          filterAttrs
            (
              name: attrs:
              let
                inherit (attrs) drv version;
              in
              name != "override"
              && name != "overrideDerivation"
              # Filter prebuilt pypy derivations & python3Minimal
              && !(hasSuffix "prebuilt" name || hasSuffix "Minimal" name)
              && (drv.implementation or "") == implementation
              && (pre || version.pre == null)
              && all (cond: pep440.comparators.${cond.op} version cond.version) requires-python
            )
            (
              mapAttrs (_name: drv: {
                inherit drv;
                version = pep440.parseVersion drv.version;
              }) pythonInterpreters
            )
        )
      )
    );

}
