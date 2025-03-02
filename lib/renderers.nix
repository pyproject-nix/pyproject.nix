{
  lib,
  pep508,
  pep440,
  pep621,
  renderers,
  ...
}:
let
  inherit (builtins)
    length
    attrNames
    attrValues
    head
    foldl'
    ;
  inherit (lib)
    optionalAttrs
    mapAttrs'
    filterAttrs
    concatMap
    nameValuePair
    isString
    ;

  # Group licenses by their SPDX IDs for easy lookup
  licensesBySpdxId = mapAttrs' (_: license: {
    name = license.spdxId;
    value = license;
  }) (filterAttrs (_: license: license ? spdxId) lib.licenses);

  getDependencies' =
    pythonPackages:
    concatMap (
      dep:
      let
        pkg = pythonPackages.${dep.name};
      in
      [ pkg ] ++ concatMap (extra: pkg.optional-dependencies.${extra} or [ ]) dep.extras
    );

in
{
  /*
    Renders a project as an argument that can be passed to withPackages

    Evaluates PEP-508 environment markers to select correct dependencies for the platform but does not validate version constraints.
    For validation see `lib.validators`.

    Type: withPackages :: AttrSet -> lambda

    Example:
      # withPackages (lib.project.loadPyproject { ... })
        «lambda @ «string»:1:1»
  */
  withPackages =
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project,
      # Python derivation
      python,
      # Nixpkgs Python package set
      pythonPackages ? python.pkgs,
      # Python extras (optionals) to enable
      extras ? [ ],
      # PEP-735 dependency groups to enable.
      groups ? [ ],
      # Extra withPackages function
      extraPackages ? _ps: [ ],
      # PEP-508 environment
      environ ? pep508.mkEnviron python,
    }:
    let
      filteredDeps = pep621.filterDependenciesByEnviron environ extras project.dependencies;
      getDependencies = getDependencies' pythonPackages;
    in
    ps:
    getDependencies filteredDeps.dependencies
    ++ concatMap (extra: getDependencies filteredDeps.extras.${extra}) extras
    ++ concatMap (group: getDependencies filteredDeps.groups.${group}) groups
    ++ getDependencies filteredDeps.build-systems
    ++ extraPackages ps
    ++ (
      if filteredDeps.build-systems != [ ] then
        [ ]

      else
        [
          ps.setuptools
          ps.wheel
        ]
    );
  # ++ concatMap (group: filteredDeps.extras.${group} or [ ]) extras);

  /*
    Renders a project as an argument that can be passed to buildPythonPackage/buildPythonApplication.

    Evaluates PEP-508 environment markers to select correct dependencies for the platform but does not validate version constraints.
    For validation see `lib.validators`.

    Type: buildPythonPackage :: AttrSet -> AttrSet

    Example:
      # buildPythonPackage { project = lib.project.loadPyproject ...; python = pkgs.python3;  }
        { pname = "blinker"; version = "1.3.3.7"; dependencies = [ ]; }
  */
  buildPythonPackage =
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project,
      # Python derivation
      python,
      # Nixpkgs Python package set
      pythonPackages ? python.pkgs,
      # Python extras (optional-dependencies) to enable.
      extras ? [ ],
      # PEP-735 dependency groups to enable.
      groups ? [ ],
      # Map a Python extras group name to a Nix attribute set like:
      # { dev = "checkInputs"; }
      # This is intended to be used with optionals such as test dependencies that you might
      # want to remap to checkInputs.
      extrasAttrMappings ? { },
      # Which package format to pass to buildPythonPackage
      # If the format is "wheel" PEP-518 build-systems are excluded from the build.
      format ? "pyproject",
      # PEP-508 environment
      environ ? pep508.mkEnviron python,
    #
    }:
    let
      filteredDeps = pep621.filterDependenciesByEnviron environ extras project.dependencies;

      pythonVersion = environ.python_full_version.value;

      getDependencies = getDependencies' pythonPackages;

      inherit (project) pyproject;

      optional-dependencies = lib.mapAttrs (_group: getDependencies) project.dependencies.extras;

      dependency-groups = lib.mapAttrs (_group: getDependencies) project.dependencies.groups;

    in
    foldl'
      (
        attrs: group:
        let
          attr = extrasAttrMappings.${group} or "dependencies";
        in
        if !extrasAttrMappings ? ${group} then
          attrs
        else
          attrs // { ${attr} = attrs.${attr} or [ ] ++ getDependencies filteredDeps.extras.${group}; }
      )
      (
        {
          pyproject = format == "pyproject";
          dependencies =
            getDependencies filteredDeps.dependencies
            ++ concatMap (group: optional-dependencies.${group} or [ ]) extras
            ++ concatMap (group: dependency-groups.${group} or [ ]) groups;
          inherit optional-dependencies;
          passthru = {
            inherit dependency-groups;
          };
          meta = renderers.meta { inherit project; };
        }
        // optionalAttrs (format != "pyproject") { inherit format; }
        // optionalAttrs (format != "wheel") {
          build-system =
            if filteredDeps.build-systems != [ ] then
              getDependencies filteredDeps.build-systems
            else
              [
                pythonPackages.setuptools
                pythonPackages.wheel
              ];
        }
        // optionalAttrs (pyproject ? project && pyproject.project ? name) {
          pname = pyproject.project.name;
        }
        // optionalAttrs (project.projectRoot != null) { src = project.projectRoot; }
        // optionalAttrs (pyproject ? project && pyproject.project ? version) {
          inherit (pyproject.project) version;
        }
        // optionalAttrs (project.requires-python != null) {
          disabled =
            !lib.all (spec: pep440.comparators.${spec.op} pythonVersion spec.version) project.requires-python;
        }
      )
      (attrNames filteredDeps.extras);

  /*
    Renders a project as an argument that can be passed to mkPythonEditablePackage.

    Evaluates PEP-508 environment markers to select correct dependencies for the platform but does not validate version constraints.
    For validation see `lib.validators`.

    Note for Nix Flake users:
    Flakes are copied to the store when using pure evaluation, meaning that the project root will point to a store directory.
    Either set root manually to a string using the returned attribute set, or evaluate using `--impure`.

    Type: mkPythonEditablePackage :: AttrSet -> AttrSet

    Example:
      # mkPythonEditablePackage { project = lib.project.loadPyproject ...; python = pkgs.python3;  }
        { pname = "blinker"; version = "1.3.3.7"; dependencies = [ ]; }
  */
  mkPythonEditablePackage =
    let
      cleanArgs = lib.flip removeAttrs [ "root" ];
    in
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project,
      # Editable root directory as a string
      root ? toString (
        # Prefer src layout if available
        if lib.pathExists (project.projectRoot + "/src") then
          (project.projectRoot + "/src")
        # Otherwise assume project root is editable root
        else
          project.projectRoot
      ),
      # Unknown args passed on verbatim to renderers.buildPythonPackage
      ...
    }@args:
    let
      # Render using buildPythonPackage
      attrs = renderers.buildPythonPackage (cleanArgs args);

      project' = project.pyproject.project;
    in
    # Reshape into mkPythonEditablePackage
    assert isString root && root != "";
    {
      inherit (attrs)
        dependencies
        optional-dependencies
        build-system
        meta
        ;
      inherit root;
    }
    // optionalAttrs (project' ? scripts) {
      inherit (project') scripts;
    }
    // optionalAttrs (project' ? gui-scripts) {
      inherit (project') gui-scripts;
    }
    // optionalAttrs (project' ? entry-points) {
      inherit (project') entry-points;
    }
    // optionalAttrs (attrs ? pname) {
      inherit (attrs) pname;
    }
    // optionalAttrs (attrs ? version) {
      inherit (attrs) version;
    }
    // optionalAttrs (args ? extrasAttrMappings && args.extrasAttrMappings != { }) {
      # Inject derivationArgs for additional functionality
      derivationArgs = lib.listToAttrs (
        map (attr: nameValuePair attr attrs.${attr}) (attrValues args.extrasAttrMappings)
      );
    };

  /*
    Renders a project as a meta attribute

    This is used internally in renderers.mkPythonPackages

    Type: meta :: AttrSet -> AttrSet
  */
  meta =
    { project }:
    let
      project' = project.pyproject.project or { };
      urls = project'.urls or { };
    in
    # Optional changelog
    optionalAttrs (urls ? changelog) { inherit (urls) changelog; }
    //
      # Optional description
      optionalAttrs (project' ? description) { inherit (project') description; }
    //
      # Optional license
      optionalAttrs (project' ? license.text) (
        assert !(project'.license ? file);
        {
          # From PEP-621:
          # "The text key has a string value which is the license of the project whose meaning is that of the License field from the core metadata.
          # These keys are mutually exclusive, so a tool MUST raise an error if the metadata specifies both keys."
          # Hence the assert above.
          license = licensesBySpdxId.${project'.license.text} or project'.license.text;
        }
      )
    //
      # Only set mainProgram if we only have one script, otherwise it's ambigious which one is main
      (
        let
          scriptNames = attrNames project'.scripts;
        in
        optionalAttrs (project' ? scripts && length scriptNames == 1) { mainProgram = head scriptNames; }
      );

}
