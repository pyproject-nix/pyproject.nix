{
  stdenv,
  python3,
  lib,
}:
stdenv.mkDerivation {
  name = "build-editable";

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    echo '#!${python3.interpreter}' > $out/bin/build-editable
    cat ${./src/build_editable/__init__.py} >> $out/bin/build-editable
    chmod +x $out/bin/build-editable
    runHook postInstall
  '';

  meta = {
    license = lib.licenses.mit;
  };
}
