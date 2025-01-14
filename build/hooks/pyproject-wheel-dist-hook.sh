# Setup hook to move a prebuilt wheel into dist as expected by install hook
echo "Sourcing pyproject-wheel-dist-hook"

pyprojectWheelDist() {
  echo "Executing pyprojectWheelDist"
  runHook preBuild

  echo "Creating dist..."
  mkdir -p dist
  cp "$src" "dist/$(stripHash "$src")"

  runHook postBuild
  echo "Finished executing pyprojectWheelDist"
}

if [ -z "${dontUsePyprojectWheelDist-}" ] && [ -z "${buildPhase-}" ]; then
  echo "Using pyprojectWheelDist"
  buildPhase=pyprojectWheelDist
  dontUnpack=1
fi
