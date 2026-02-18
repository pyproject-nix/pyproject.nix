# Setup hook to use for PEP-621/setuptools builds
echo "Sourcing pyproject-configure-hook"

pyprojectConfigurePhase() {
  echo "Executing pyprojectConfigurePhase"
  runHook preConfigure

  # Undo any Python dependency propagation leaking into build, and set it to our interpreters PYTHONPATH
  #
  # In case of cross compilation this variable will contain two entries:
  # One for the native Python and one for the cross built, so the native can load sysconfig
  # information from the cross compiled Python.
  export PYTHONPATH=@pythonPath@

  # Compile bytecode by default.
  if [ -z "${UV_COMPILE_BYTECODE-}" ]; then
    export UV_COMPILE_BYTECODE=1
  fi

  # Disable bytecode compilation timeout for more reliable builds on very loaded systems
  if [ -z "${UV_COMPILE_BYTECODE_TIMEOUT-}" ]; then
    export UV_COMPILE_BYTECODE_TIMEOUT=0
  fi

  # Opt out of uv-specific installer metadata that causes non-reproducible builds.
  if [ -z "${UV_NO_INSTALLER_METADATA-}" ]; then
    export UV_NO_INSTALLER_METADATA=1
  fi

  # Don't load uv config from pyproject.toml & such.
  # Loading config might cause uv-specific behaviour defined in tool.uv such as
  # find-links to fail at build time.0984dhbb
  if [ -z "${UV_NO_CONFIG-}" ]; then
    export UV_NO_CONFIG=1
  fi

  # Cmake has it's setup hook in the main package, which opts in to nixpkgs
  # cmake build behaviour
  if [ -z "${dontUseCmakeConfigure-}" ]; then
    export dontUseCmakeConfigure=true
  fi

  runHook postConfigure
  echo "Finished executing pyprojectConfigurePhase"
}

if [ -z "${dontUsePyprojectConfigure-}" ] && [ -z "${configurePhase-}" ]; then
  echo "Using pyprojectConfiguredPhase"
  configurePhase=pyprojectConfigurePhase
fi
