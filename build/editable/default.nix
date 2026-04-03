{
  stdenv,
  python3,
  python3Packages,
  lib,
}:
let
  # If Python < 3.11 it doesn't have builtin TOML support
  # Hack it in by using the nixpkgs tomli package
  toml-hack = if python3.pythonOlder "3.11" then ''
    cat >> $out/bin/build-editable <<EOF
    import sys
    sys.path.append('${python3Packages.tomli}/${python3Packages.python.sitePackages}')
    EOF
  '' else "";

in
stdenv.mkDerivation {
  name = "build-editable";

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    echo '#!${python3.interpreter}' > $out/bin/build-editable
    ${toml-hack}
    cat ${./src/build_editable/__init__.py} >> $out/bin/build-editable
    chmod +x $out/bin/build-editable
    runHook postInstall
  '';

  meta = {
    license = lib.licenses.mit;
  };
}
