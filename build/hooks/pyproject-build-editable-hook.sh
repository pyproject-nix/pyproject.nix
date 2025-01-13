# Setup hook to use for PEP-621/setuptools builds
echo "Sourcing pyproject-build-hook"

pyprojectBuildEditablePhase() {
  echo "Executing pyprojectBuildEditablePhase"
  runHook preBuild

  echo "Creating a wheel..."
  env PYTHONPATH="${NIX_PYPROJECT_PYTHONPATH}:${PYTHONPATH}" @editableHook@/bin/build-editable

  runHook postBuild
  echo "Finished executing pyprojectBuildEditablePhase"
}

if [ -z "${dontUsePyprojectBuildEditable-}" ] && [ -z "${buildPhase-}" ]; then
  echo "Using pyprojectBuildEditablePhase"
  buildPhase=pyprojectBuildEditablePhase
fi
