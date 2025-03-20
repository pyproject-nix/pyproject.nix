# Setup hook to use for PEP-621/setuptools builds
echo "Sourcing pyproject-build-hook"

pyprojectBuildPhase() {
  echo "Executing pyprojectBuildPhase"
  runHook preBuild

  local buildType="${uvBuildType-wheel}"

  echo "Creating a distribution..."
  if [ "${buildType}" != "wheel" ] && [ "${buildType}" != "sdist" ]; then
    echo "Build type '${buildType}' is unknown" >>/dev/stderr
    false
  fi
  env PYTHONPATH="${NIX_PYPROJECT_PYTHONPATH}:${PYTHONPATH}" @uv@/bin/uv build -v --no-cache --python=@pythonInterpreter@ --offline --no-build-isolation --out-dir dist/ "--${buildType}" $uvBuildFlags

  runHook postBuild
  echo "Finished executing pyprojectBuildPhase"
}

if [ -z "${dontUsePyprojectBuild-}" ] && [ -z "${buildPhase-}" ]; then
  echo "Using pyprojectBuildPhase"
  buildPhase=pyprojectBuildPhase
fi
