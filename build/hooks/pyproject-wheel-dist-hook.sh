# Setup hook to move a prebuilt wheel into dist as expected by install hook
echo "Sourcing pyproject-wheel-dist-hook"

pyprojectWheelDist() {
  echo "Executing pyprojectWheelDist"
  runHook preBuild

  echo "Creating dist..."
  if [ -d "$src" ]; then
    ln -s "$src" dist
  else
    mkdir -p dist
    ln -s "$src" "dist/$(stripHash "$src")"
  fi

  runHook postBuild
  echo "Finished executing pyprojectWheelDist"
}

if [ -z "${dontUsePyprojectWheelDist-}" ] && [ -z "${buildPhase-}" ]; then
  echo "Using pyprojectWheelDist"
  buildPhase=pyprojectWheelDist
  dontUnpack=1
fi
