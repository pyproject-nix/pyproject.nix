# Setup hook for installing built wheels into output
echo "Sourcing pyproject-install-dist-hook"

pyprojectInstallDistPhase() {
  echo "Executing pyprojectInstallDistPhase"
  runHook preInstall

  @pythonInterpreter@ @script@

  runHook postInstall
  echo "Finished executing pyprojectInstallDistPhase"
}

if [ -z "${dontUsePyprojectInstallDist-}" ] && [ -z "${installPhase-}" ]; then
  echo "Using pyprojectInstallDistPhase"
  installPhase=pyprojectInstallDistPhase
fi
