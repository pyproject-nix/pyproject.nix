{
  runCommand,
  lib,
  python,
  mkVirtualEnv,
}:

let
  env = mkVirtualEnv "editable-hook-env" (
    {
      libcst = [ ];
      pyproject-hooks = [ ];
    }
    // lib.optionalAttrs (python.pythonOlder "3.11") {
      tomli = [ ];
    }
  );

in
runCommand "editable-hook" { } ''
  mkdir -p $out/bin

  cat > $out/bin/build-editable << EOF
  #!${env}/bin/python
  EOF
  cat ${./editable_hook/build_editable.py} >> $out/bin/build-editable

  cat > $out/bin/patch-editable << EOF
  #!${env}/bin/python
  EOF
  cat ${./editable_hook/patch_editable.py} >> $out/bin/patch-editable

  chmod +x $out/bin/*
''
