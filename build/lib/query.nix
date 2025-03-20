{ lib, ... }:

let
  inherit (lib)
    zipAttrsWith
    concatLists
    optional
    attrNames
    ;

in
{
  /**
    Query a package set for a dependency specification to pass to `mkVirtualEnv`.

    Returns a specification with _only_ the dependencies of packages, not the queried packages themselves.

    This is useful for example if you want to construct a virtualenv
    with development dependencies for a package, but without containing the package itself.

    # Example

    ```nix
    query.deps { } pythonSet {
      hello-world = [ "dev" ];
    }
    =>
    {
      urllib3 = [ ]; # From project.dependencies
      ruff = [ ]; # From the `dev` group
    }
    ```

    # Arguments

    customisations
    : Query customisations (whether to include project.dependencies or not)

    pythonSet
    : Python package set

    specification
    : Dependency specifications in the form used by mkVirtualEnv
  */
  deps =
    {
      dependencies ? true,
    }:
    pythonSet: spec:
    zipAttrsWith (_: concatLists) (
      map (
        name:
        let
          extras = spec.${name};
          drv = pythonSet.${name};
          optional-dependencies = drv.passthru.optional-dependencies or { };
          dependency-groups = drv.passthru.dependency-groups or { };
        in
        zipAttrsWith (_: concatLists) (
          optional dependencies (drv.passthru.dependencies or { })
          ++ map (e: optional-dependencies.${e} or { }) extras
          ++ map (e: dependency-groups.${e} or { }) extras
        )
      ) (attrNames spec)
    );

}
