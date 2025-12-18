{ stdenv, makeSetupHook, callPackage }:
let
  link-ctypes = callPackage ./link-ctypes { };
in
makeSetupHook {
  name = "pyproject-link-ctypes-hook";
  substitutions = {
    linkCtypes = link-ctypes;
    linkCtypesFlags =
      if stdenv.isDarwin then "--mode darwin"
      else "--mode posix";
  };
} ./link-ctypes-hook.sh
