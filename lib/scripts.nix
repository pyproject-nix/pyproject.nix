{
  lib,
  pep508,
  pep621,
  pep723,
  pypa,
  ...
}:

let
  inherit (pep723) parseScript;
  inherit (pypa) normalizePackageName;
  inherit (lib)
    isString
    isPath
    readFile
    fix
    concatMap
    removeSuffix
    ;
  inherit (builtins) baseNameOf;

in
fix (self: {

  /*
    Load a PEP-723 metadata script from file path or string.

    Example:
      # loadScript { script = ./with-inline-metadata.py; }
      {
        name = "with-inline-metadata";
        metadata = { ... }; # Contains dependencies and requires-python
        renderWithPackages = { python }: ...; # renderWithPackages with loaded script pre-applied
      }
  */
  loadScript =
    {
      name ?
        if isPath script then (removeSuffix ".py" (baseNameOf script)) else throw "Missing argument name",
      script,
    }:
    let
      script' =
        if isString script then
          script
        else if isPath script then
          readFile script
        else
          throw "Script must be passed as path or string";

    in
    fix (scriptSelf: {
      name = normalizePackageName name;
      script = script';
      metadata = parseScript script';
      renderWithPackages =
        {
          # Python interpreter
          python,
          # Customise environment using pep508.setEnviron
          environ ? { },
          # Override PEP-508 environment creation
          __environ ? pep508.setEnviron (pep508.mkEnviron python) environ,
        }:
        self.renderWithPackages {
          script = scriptSelf;
          environ = __environ;
          inherit python;
        };
    });

  /*
    Render a loaded PEP-723 script as a string with a shebang line pointing to a wrapped Nix store interpreter.

    Example:
      # Using renderWithPackages directly
      let
        script = loadScript { script = ./with-inline-metadata.py; };
      in pkgs.writeScript script.name (renderWithPackages { inherit script; python = pkgs.python3; })

      # Using script render function
      let
        script = loadScript { script = ./with-inline-metadata.py; };
      in pkgs.writeScript script.name (script.render { python = pkgs.python3; })
  */
  renderWithPackages =
    {
      # Script loaded using loadScript
      script,
      # Nixpkgs Python interpreter
      python,
      # Nixpkgs Python package set
      # Python extras (optional-dependencies) to enable.
      # PEP-508 environment
      environ ? pep508.mkEnviron python,
    }:
    let
      filteredDeps = pep621.filterDependenciesByEnviron environ [ ] {
        inherit (script.metadata) dependencies;
        extras = { };
        build-systems = [ ];
      };

      pythonEnv = python.withPackages (
        pythonPackages:
        concatMap (
          dep:
          let
            pkg = pythonPackages.${dep.name};
          in
          [ pkg ] ++ concatMap (extra: pkg.optional-dependencies.${extra} or [ ]) dep.extras
        ) filteredDeps.dependencies
      );
    in
    "#!${pythonEnv.interpreter}\n" + script.script;

})
