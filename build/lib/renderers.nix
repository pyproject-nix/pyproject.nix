{ lib, pyproject-nix, ... }:

let
  inherit (lib)
    optionalAttrs
    mapAttrs
    concatMap
    groupBy
    isString
    assertMsg
    hasPrefix
    optionalString
    inPureEvalMode
    unique
    ;
  inherit (pyproject-nix.lib.renderers) meta;
  inherit (pyproject-nix.lib) pep621;
  inherit (builtins) storeDir;

  # Make a dependency specification attrset from a list of dependencies
  mkSpec =
    dependencies: mapAttrs (_: concatMap (dep: dep.extras)) (groupBy (dep: dep.name) dependencies);

in
{

  /*
    Renders a project as an argument that can be passed to stdenv.mkDerivation.

    Evaluates PEP-508 environment markers to select correct dependencies for the platform but does not validate version constraints.

    Type: mkDerivation :: AttrSet -> AttrSet
  */
  mkDerivation =
    {
      # Loaded pyproject.nix project
      project,
      # PEP-508 environment
      environ,
      # Extras to enable (markers only, `optional-dependencies` are not enabled by default)
      extras ? [ ],
    }:
    let
      inherit (project) pyproject;

      filteredDeps = pep621.filterDependenciesByEnviron environ extras project.dependencies;

    in
    { pyprojectHook, resolveBuildSystem }:
    {
      passthru = {
        dependencies = mkSpec filteredDeps.dependencies;
        optional-dependencies = mapAttrs (_: mkSpec) filteredDeps.extras;
        dependency-groups = mapAttrs (_: mkSpec) filteredDeps.groups;
      };

      nativeBuildInputs = [
        pyprojectHook
      ] ++ resolveBuildSystem (mkSpec filteredDeps.build-systems);

      meta = meta {
        inherit project;
      };
    }
    // optionalAttrs (pyproject.project ? name) { pname = pyproject.project.name; }
    // optionalAttrs (pyproject.project ? version) { inherit (pyproject.project) version; }
    // optionalAttrs (!pyproject.project ? version && pyproject.project ? name) {
      inherit (pyproject.project) name;
    }
    // optionalAttrs (project.projectRoot != null) { src = project.projectRoot; };

 /*
   Renders a project as an argument that can be passed to stdenv.mkDerivation.

   Evaluates PEP-508 environment markers to select correct dependencies for the platform but does not validate version constraints.

   Note: This API is unstable and subject to change.

   Type: mkDerivation :: AttrSet -> AttrSet
 */
  mkDerivationEditable =
    {
      # Loaded pyproject.nix project
      project,
      # PEP-508 environment
      environ,
      # Extras to enable (markers only, `optional-dependencies` are not enabled by default)
      extras ? [ ],
      # Editable root directory as a string
      root ? project.projectRoot,
    }:
    assert isString root;
    assert assertMsg (!hasPrefix storeDir root) ''
      Editable root was passed as a Nix store path string.

      ${optionalString inPureEvalMode ''
        This is most likely because you are using Flakes, and are automatically inferring the editable root from projectRoot.
        Flakes are copied to the Nix store on evaluation. This can temporarily be worked around using --impure.
      ''}

      Pass editable root either as a string pointing to an absolute path non-store path, or use environment variables for relative paths.
    '';
    let
      inherit (project) pyproject;

      filteredDeps = pep621.filterDependenciesByEnviron environ extras project.dependencies;
      depSpec = mkSpec filteredDeps.dependencies;
      buildSpec = mkSpec filteredDeps.build-systems;

    in
    { pyprojectEditableHook, resolveBuildSystem }:
    {
      passthru = {
        # Merge runtime dependenies with build systems
        dependencies =
          depSpec
          // mapAttrs (name: extras: unique ((depSpec.${name} or [ ]) ++ extras)) buildSpec;
        optional-dependencies = mapAttrs (_: mkSpec) filteredDeps.extras;
        dependency-groups = mapAttrs (_: mkSpec) filteredDeps.groups;
      };

      env.EDITABLE_ROOT = root;

      nativeBuildInputs = [
        pyprojectEditableHook
      ] ++ resolveBuildSystem buildSpec;

      meta = meta {
        inherit project;
      };
    }
    // optionalAttrs (pyproject.project ? name) { pname = pyproject.project.name; }
    // optionalAttrs (pyproject.project ? version) { inherit (pyproject.project) version; }
    // optionalAttrs (!pyproject.project ? version && pyproject.project ? name) {
      inherit (pyproject.project) name;
    }
    // optionalAttrs (project.projectRoot != null) { src = project.projectRoot; };

}
