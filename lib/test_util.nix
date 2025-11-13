{
  util,
  pep440,
  ...
}:
  {
    filterPythonInterpreters = let
      mkMockPython = {
        pname ? "python",
        version,
        pythonVersion ? version,
        implementation ? "cpython",
      }: (builtins.derivation {
        inherit pname version;
        name = pname + "-" + version;
        builder = "nope";
        inherit pythonVersion implementation;
        system = "builtin";
      }) // {
        passthru = {
          inherit pythonVersion;
        };
      };

      pythonInterpreters = {
        python310 = mkMockPython {
          version = "3.10";
        };
        python311 = mkMockPython {
          version = "3.11";
        };
        python312 = mkMockPython {
          version = "3.12";
        };
        python313 = mkMockPython {
          version = "3.13";
        };
      };
    in {
      testSimple = {
        expr = map toString (util.filterPythonInterpreters {
          requires = pep440.parseVersionConds ">=3.12";
          inherit pythonInterpreters;
        });
        expected = map toString [
          pythonInterpreters.python312
          pythonInterpreters.python313
        ];
      };
    };
  }
