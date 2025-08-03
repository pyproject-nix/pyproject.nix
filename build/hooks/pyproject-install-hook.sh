# Setup hook for Pyproject installer.
echo "Sourcing pyproject-install-hook"

pyprojectInstallPhase() {
  echo "Executing pyprojectInstallPhase"
  runHook preInstall

  pushd dist >/dev/null

  for wheel in *.whl; do
    @uv@/bin/uv pip --offline --no-cache install --no-deps --link-mode=copy --python=@pythonInterpreter@ --system --prefix "$out" $uvPipInstallFlags "$wheel"
    echo "Successfully installed $wheel"
  done

  popd >/dev/null

  rm -f "$out/.lock"

  # If a dist output is defined also install the wheel build product in a separate dist output
  if [[ "$dist" != "" ]]; then
    @pythonInterpreter@ @installDistScript@
    rm -f "$dist/.lock"
  fi

  runHook postInstall
  echo "Finished executing pyprojectInstallPhase"
}

if [ -z "${dontUsePyprojectInstall-}" ] && [ -z "${installPhase-}" ]; then
  echo "Using pyprojectInstallPhase"
  installPhase=pyprojectInstallPhase
fi
