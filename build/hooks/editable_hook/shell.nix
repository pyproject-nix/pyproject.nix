let
  pkgs = import <nixpkgs> { };

  python = pkgs.python3;

  # Quick-n-dirty
  pythonEnv =
    (python.withPackages (ps: [
      ps.libcst
      ps.pyproject-hooks
      ps.flit-core
    ])).override
      {
        postBuild = ''
          cat > $out/pyvenv.cfg <<EOF
          home = ${python}/bin
          include-system-site-packages = false
          EOF
        '';
      };

in
pkgs.mkShell {
  packages = [
    pythonEnv
  ];
}
