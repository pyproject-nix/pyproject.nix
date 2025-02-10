# Setup hook for Pyproject installer.
echo "Sourcing pyproject-pypa-install-hook"

pyprojectPypaInstallPhase() {
  echo "Executing pyprojectPypaInstallPhase"
  runHook preInstall

  pushd dist >/dev/null

  for wheel in *.whl; do
    env PYTHONPATH=$PYTHONPATH:@installer@/@pythonSitePackages@ @pythonInterpreter@ @wrapper@ --prefix "$out" "$wheel"
    echo "Successfully installed $wheel"
  done

  rm -f "$out/.lock"

  popd >/dev/null

  runHook postInstall
  echo "Finished executing pyprojectPypaInstallPhase"
}

if [ -z "${dontUsePyprojectInstall-}" ] && [ -z "${installPhase-}" ]; then
  echo "Using pyprojectPypaInstallPhase"
  installPhase=pyprojectPypaInstallPhase
fi
