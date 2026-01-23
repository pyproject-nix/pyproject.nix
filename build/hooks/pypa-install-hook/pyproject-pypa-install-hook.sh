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

  popd >/dev/null

  rm -f "$out/.lock"

  # If a dist output is defined also install the wheel build product in a separate dist output
  if [[ $dist != "" ]]; then
    @pythonInterpreter@ @installDistScript@
    rm -f "$dist/.lock"
  fi

  runHook postInstall
  echo "Finished executing pyprojectPypaInstallPhase"
}

if [ -z "${dontUsePyprojectInstall-}" ] && [ -z "${installPhase-}" ]; then
  echo "Using pyprojectPypaInstallPhase"
  installPhase=pyprojectPypaInstallPhase
fi
