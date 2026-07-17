{
  lib,
  fixtures,
  poetry,
  ...
}:
let
  inherit (lib) importJSON;
  inherit (poetry)
    translatePoetryProject
    parseDependencies
    parseVersionCond
    parseVersionConds
    ;
in
{
  translatePoetryProject = {
    testProjectConversion = {
      expr = (translatePoetryProject fixtures."poetry.toml").project;
      expected = {
        authors = [
          {
            email = "sebastien@eustace.io";
            name = "Sébastien Eustace";
          }
        ];
        classifiers = [
          "Topic :: Software Development :: Build Tools"
          "Topic :: Software Development :: Libraries :: Python Modules"
        ];
        description = "Python dependency management and packaging made easy.";
        keywords = [
          "packaging"
          "dependency"
          "poetry"
        ];
        license = {
          text = "MIT";
        };
        scripts = {
          poetry = "poetry.console.application:main";
        };
        maintainers = [
          {
            email = "arun.neelicattu@gmail.com";
            name = "Arun Babu Neelicattu";
          }
          {
            email = "bjorn@neersighted.com";
            name = "Bjorn Neergaard";
          }
          {
            email = "branchevincent@gmail.com";
            name = "Branch Vincent";
          }
          {
            email = "github@accounts.brycedrennan.com";
            name = "Bryce Drennan";
          }
          {
            email = "danieleades@hotmail.com";
            name = "Daniel Eades";
          }
          {
            email = "radoering.poetry@gmail.com";
            name = "Randy Döring";
          }
          {
            email = "hello@stephsamson.com";
            name = "Steph Samson";
          }
          {
            email = "finswimmer77@gmail.com";
            name = "finswimmer";
          }
        ];
        name = "poetry";
        readme = "README.md";
        urls = {
          Documentation = "https://python-poetry.org/docs";
          Homepage = "https://python-poetry.org/";
          Repository = "https://github.com/python-poetry/poetry";
        };
        version = "1.4.2";
      };
    };
  };

  parseVersionCond = {
    testTilde = {
      expr = parseVersionCond "~3.2.1";
      expected = [
        {
          op = ">=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              3
              2
              1
            ];
            str = "3.2.1";
          };
        }
        {
          op = "<";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              3
              3
              0
            ];
            str = "3.3.0";
          };
        }
      ];
    };

    testTildeMinor = {
      expr = parseVersionCond "~1.2";
      expected = [
        {
          op = ">=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              1
              2
              0
            ];
            str = "1.2.0";
          };
        }
        {
          op = "<";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              1
              3
              0
            ];
            str = "1.3.0";
          };
        }
      ];
    };

    # Regression test: Check that ~= isn't parsed as ~
    testTildeEquals = {
      expr = parseVersionCond "~=3.2.1";
      expected = [
        {
          op = "~=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              3
              2
              1
            ];
            str = "3.2.1";
          };
        }
      ];
    };

    testCaret = {
      expr = parseVersionCond "^3.2.1";
      expected = [
        {
          op = ">=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              3
              2
              1
            ];
            str = "3.2.1";
          };
        }
        {
          op = "<";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              4
              0
              0
            ];
            str = "4.0.0";
          };
        }
      ];
    };
  };

  parseVersionConds = {
    testAll = {
      expr = parseVersionConds "^3.2.1,~3.2.1";
      expected = [
        {
          op = ">=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              3
              2
              1
            ];
            str = "3.2.1";
          };
        }
        {
          op = "<";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              4
              0
              0
            ];
            str = "4.0.0";
          };
        }
        {
          op = ">=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              3
              2
              1
            ];
            str = "3.2.1";
          };
        }
        {
          op = "<";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              3
              3
              0
            ];
            str = "3.3.0";
          };
        }
      ];
    };
  };

  parseDependencies = {
    testParseDeps = {
      expr = parseDependencies fixtures."poetry.toml";
      expected = importJSON ./expected/poetry.parseDependencies.testParseDeps.json;
    };
  };
}
