echo "Sourcing pyproject-make-venv-hook"

pyprojectMakeVenv() {
  echo "Executing pyprojectMakeVenv"
  runHook preInstall

  set -f
  @pythonInterpreter@ @makeVenvScript@ --python @python@ "$out" --env "NIX_PYPROJECT_DEPS" $mkVirtualenvFlags
  set +f

  runHook postInstall
  echo "Finished executing pyprojectMakeVenv"
}

if [ -z "${dontUsePyprojectMakeVenv-}" ] && [ -z "${installPhase-}" ]; then
  echo "Using pyprojectMakeVenv"
  installPhase=pyprojectMakeVenv
fi
