{ pep440, ... }:
let
  inherit (pep440)
    parseVersion
    parseVersionCond
    parseVersionConds
    compareVersions
    comparators
    ;

in

{

  parseVersion = {
    testSimple = {
      expr = parseVersion "3.0.0";
      expected = {
        dev = null;
        epoch = 0;
        local = null;
        post = null;
        pre = null;
        release = [
          3
          0
          0
        ];
        str = "3.0.0";
      };
    };

    testSimplePost = {
      expr = parseVersion "3.0.0post2";
      expected = {
        dev = null;
        epoch = 0;
        local = null;
        post = {
          type = "post";
          value = 2;
        };
        pre = null;
        release = [
          3
          0
          0
        ];
        str = "3.0.0post2";
      };
    };

    testSimpleRc = {
      expr = parseVersion "3.0.0rc1";
      expected = {
        dev = null;
        epoch = 0;
        local = null;
        post = null;
        pre = {
          type = "rc";
          value = 1;
        };
        release = [
          3
          0
          0
        ];
        str = "3.0.0rc1";
      };
    };

    testSimpleRcNormalized = {
      expr = parseVersion "3.0.0pre1";
      expected = {
        dev = null;
        epoch = 0;
        local = null;
        post = null;
        pre = {
          type = "rc";
          value = 1;
        };
        release = [
          3
          0
          0
        ];
        str = "3.0.0pre1";
      };
    };

    testImplicitPost = {
      expr = parseVersion "3.0.0-1";
      expected = {
        dev = null;
        epoch = 0;
        local = null;
        post = {
          type = "post";
          value = 1;
        };
        pre = null;
        release = [
          3
          0
          0
        ];
        str = "3.0.0-1";
      };
    };

    testDev = {
      expr = parseVersion "1.2.0dev21";
      expected = {
        dev = {
          type = "dev";
          value = 21;
        };
        epoch = 0;
        local = null;
        post = null;
        pre = null;
        release = [
          1
          2
          0
        ];
        str = "1.2.0dev21";
      };
    };

    testDevDot = {
      expr = parseVersion "1.2.0.dev21";
      expected = {
        dev = {
          type = "dev";
          value = 21;
        };
        epoch = 0;
        local = null;
        post = null;
        pre = null;
        release = [
          1
          2
          0
        ];
        str = "1.2.0.dev21";
      };
    };

    testDevDash = {
      expr = parseVersion "1.2.0-dev21";
      expected = {
        dev = {
          type = "dev";
          value = 21;
        };
        epoch = 0;
        local = null;
        post = null;
        pre = null;
        release = [
          1
          2
          0
        ];
        str = "1.2.0-dev21";
      };
    };

    testLocal = {
      expr = parseVersion "1.2+4.3";
      expected = {
        dev = null;
        epoch = 0;
        local = "4.3";
        post = null;
        pre = null;
        release = [
          1
          2
        ];
        str = "1.2+4.3";
      };
    };

    testWildcard = {
      expr = parseVersion "3.2.*";
      expected = {
        dev = null;
        epoch = 0;
        local = null;
        post = null;
        pre = null;
        release = [
          3
          2
          "*"
        ];
        str = "3.2.*";
      };
    };

    testComplex = {
      expr = parseVersion "1.0b2.post345.dev456";
      expected = {
        dev = {
          type = "dev";
          value = 456;
        };
        epoch = 0;
        local = null;
        post = {
          type = "post";
          value = 345;
        };
        pre = {
          type = "b";
          value = 2;
        };
        release = [
          1
          0
        ];
        str = "1.0b2.post345.dev456";
      };
    };

    testEpoch = {
      expr = parseVersion "1!2.0";
      expected = {
        dev = null;
        epoch = 1;
        local = null;
        post = null;
        pre = null;
        release = [
          2
          0
        ];
        str = "1!2.0";
      };
    };
  };

  compareVersions = {
    testSimple = {
      expr = compareVersions (parseVersion "3.0.0") (parseVersion "3.0.0");
      expected = 0;
    };

    testSimpleRc = {
      expr = compareVersions (parseVersion "3.0.0") (parseVersion "3.0.0rc1");
      expected = 1;
    };

    testSimpleRcInv = {
      expr = compareVersions (parseVersion "3.0.0rc1") (parseVersion "3.0.0");
      expected = -1;
    };

    testSimplePost = {
      expr = compareVersions (parseVersion "3.0.0") (parseVersion "3.0.0post1");
      expected = -1;
    };

    testSimplePostInv = {
      expr = compareVersions (parseVersion "3.0.0post1") (parseVersion "3.0.0");
      expected = 1;
    };

    testSimpleDev = {
      expr = compareVersions (parseVersion "3.0.0dev3") (parseVersion "3.0.0dev2");
      expected = 1;
    };

    testSimpleDevInv = {
      expr = compareVersions (parseVersion "3.0.0dev2") (parseVersion "3.0.0dev3");
      expected = -1;
    };

    testSameVersionDifferentRc = {
      expr = compareVersions (parseVersion "2.3.1rc2") (parseVersion "2.3.1rc1");
      expected = 1;
    };

    testComplex = {
      expr = compareVersions (parseVersion "1.0b2.post345.dev456") (parseVersion "1.0b2.post345");
      expected = -1;
    };

    testEpoch = {
      expr = compareVersions (parseVersion "1.0") (parseVersion "1!2.0");
      expected = -1;
    };

    testEpochInv = {
      expr = compareVersions (parseVersion "1!2.0") (parseVersion "1.0");
      expected = 1;
    };

    testWildcard = {
      expr = compareVersions (parseVersion "1.0.0") (parseVersion "1.0.*");
      expected = 0;
    };

    testWildcardNotEq = {
      expr = compareVersions (parseVersion "1.2.0") (parseVersion "1.0.*");
      expected = 1;
    };
  };

  parseVersionCond = {
    testSimple = {
      expr = parseVersionCond ">=3.0.0rc1";
      expected = {
        op = ">=";
        version = {
          dev = null;
          epoch = 0;
          local = null;
          post = null;
          pre = {
            type = "rc";
            value = 1;
          };
          release = [
            3
            0
            0
          ];
          str = "3.0.0rc1";
        };
      };
    };

    testNoOp = {
      expr = parseVersionCond "*";
      expected = {
        op = "";
        version = {
          dev = null;
          epoch = 0;
          local = null;
          post = null;
          pre = null;
          release = [ "*" ];
          str = "*";
        };
      };
    };
  };

  parseVersionConds = rec {
    testSimple = {
      expr = parseVersionConds ">=3.0.0rc1,<=4.0";
      expected = [
        {
          op = ">=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = {
              type = "rc";
              value = 1;
            };
            release = [
              3
              0
              0
            ];
            str = "3.0.0rc1";
          };
        }
        {
          op = "<=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [
              4
              0
            ];
            str = "4.0";
          };
        }
      ];
    };

    testParen = {
      expr = parseVersionConds "(>=3.0.0rc1,<=4.0)";
      inherit (testSimple) expected;
    };
  };

  comparators = {
    testSimple = {
      expr = comparators."==" (parseVersion "3.0.0") (parseVersion "3.0.0");
      expected = true;
    };

    testSimpleRc = {
      expr = comparators.">" (parseVersion "3.0.0") (parseVersion "3.0.0rc1");
      expected = true;
    };

    testSimpleRcInv = {
      expr = comparators."<" (parseVersion "3.0.0rc1") (parseVersion "3.0.0");
      expected = true;
    };

    testSimplePost = {
      expr = comparators."<" (parseVersion "3.0.0") (parseVersion "3.0.0post1");
      expected = true;
    };

    testSimplePostInv = {
      expr = comparators.">" (parseVersion "3.0.0post1") (parseVersion "3.0.0");
      expected = true;
    };

    testSimpleDev = {
      expr = comparators."==" (parseVersion "3.0.0dev3") (parseVersion "3.0.0dev2");
      expected = false;
    };

    testSimpleDevInv = {
      expr = comparators."<" (parseVersion "3.0.0dev2") (parseVersion "3.0.0dev3");
      expected = true;
    };

    testSameVersionDifferentRc = {
      expr = comparators.">" (parseVersion "2.3.1rc2") (parseVersion "2.3.1rc1");
      expected = true;
    };

    testComplex = {
      expr = comparators."<" (parseVersion "1.0b2.post345.dev456") (parseVersion "1.0b2.post345");
      expected = true;
    };

    testEpoch = {
      expr = comparators."==" (parseVersion "1.0") (parseVersion "1!2.0");
      expected = false;
    };

    testEpochInv = {
      expr = comparators."==" (parseVersion "1!2.0") (parseVersion "1.0");
      expected = false;
    };

    testWildcard = {
      expr = comparators."==" (parseVersion "1.0.0") (parseVersion "1.0.*");
      expected = true;
    };

    testWildcardNotEq = {
      expr = comparators."!=" (parseVersion "1.2.0") (parseVersion "1.0.*");
      expected = true;
    };

    testCompatibleReleaseEq = {
      expr = comparators."~=" (parseVersion "2.2") (parseVersion "2.2");
      expected = true;
    };

    testCompatibleReleaseNeq = {
      expr = comparators."~=" (parseVersion "2.2.1") (parseVersion "2.1.1");
      expected = false;
    };
  };

}
