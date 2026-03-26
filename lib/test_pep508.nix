{
  lib,
  pep508,
  mocks,
  ...
}:

let
  inherit (builtins) mapAttrs;
  inherit (lib) fix;
  inherit (pep508) setEnviron;

  testMarkers = {
    notInOp = "python_version >= \"3\" and platform_machine not in \"x86_64 X86_64 aarch64 AARCH64 ppc64le PPC64LE amd64 AMD64 win32 WIN32\"";
    inOp = "python_version >= \"3\" and platform_machine in \"x86_64 X86_64 aarch64 AARCH64 ppc64le PPC64LE amd64 AMD64 win32 WIN32\"";
    trivial = "python_version >= \"3\"";
    trivialWithSpaces = " python_version  >=  \"3\" ";

    singleTicked = "python_version >= '3'";
    doubleTicked = "python_version >= \"3\"";

    # Overriding precedence -> a and (b or c)
    # overridingPrecedence = "os_name=='a' and (os_name=='b' or os_name=='c')";
    overridingPrecedence = "os_name=='a' and (os_name=='b' or os_name=='c')";
    overridingPrecedenceWithSpace = " os_name=='a' and  (os_name=='b'     or    os_name=='c' )   ";

    nestedGroups = "((os_name=='b' or os_name=='c') or (os_name=='b' or os_name=='c'))";
  };

in
fix (self: {

  parseMarkers = {
    testTrivial = {
      expr = pep508.parseMarkers testMarkers.trivial;
      expected = {
        lhs = {
          type = "variable";
          value = "python_version";
        };
        op = ">=";
        rhs = {
          type = "version";
          value = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [ 3 ];
            str = "3";
          };
        };
        type = "compare";
      };
    };

    testTrivialWithSpaces = {
      expr = pep508.parseMarkers testMarkers.trivial;
      inherit (self.parseMarkers.testTrivial) expected;
    };

    testSingleTickString = {
      expr = pep508.parseMarkers testMarkers.singleTicked;
      expected = {
        lhs = {
          type = "variable";
          value = "python_version";
        };
        op = ">=";
        rhs = {
          type = "version";
          value = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [ 3 ];
            str = "3";
          };
        };
        type = "compare";
      };
    };
    testDoubleTickString = {
      expr = pep508.parseMarkers testMarkers.doubleTicked;
      inherit (self.parseMarkers.testSingleTickString) expected;
    };

    testOverridingPrecedence = {
      expr = pep508.parseMarkers testMarkers.overridingPrecedence;
      expected = {
        lhs = {
          lhs = {
            type = "variable";
            value = "os_name";
          };
          op = "==";
          rhs = {
            type = "string";
            value = "a";
          };
          type = "compare";
        };
        op = "and";
        rhs = {
          lhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "b";
            };
            type = "compare";
          };
          op = "or";
          rhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "c";
            };
            type = "compare";
          };
          type = "boolOp";
        };
        type = "boolOp";
      };
    };
    testOverridingPrecedenceWithSpace = {
      expr = pep508.parseMarkers testMarkers.overridingPrecedence;
      inherit (self.parseMarkers.testOverridingPrecedence) expected;
    };

    testNestedGroups = {
      expr = pep508.parseMarkers testMarkers.nestedGroups;
      expected = {
        lhs = {
          lhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "b";
            };
            type = "compare";
          };
          op = "or";
          rhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "c";
            };
            type = "compare";
          };
          type = "boolOp";
        };
        op = "or";
        rhs = {
          lhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "b";
            };
            type = "compare";
          };
          op = "or";
          rhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "c";
            };
            type = "compare";
          };
          type = "boolOp";
        };
        type = "boolOp";
      };
    };

    testNotInOperator = {
      expr = pep508.parseMarkers testMarkers.notInOp;
      expected = {
        lhs = {
          lhs = {
            type = "variable";
            value = "python_version";
          };
          op = ">=";
          rhs = {
            type = "version";
            value = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [ 3 ];
              str = "3";
            };
          };
          type = "compare";
        };
        op = "and";
        rhs = {
          lhs = {
            type = "variable";
            value = "platform_machine";
          };
          op = "not in";
          rhs = {
            type = "enum";
            value = [
              "x86_64"
              "X86_64"
              "aarch64"
              "AARCH64"
              "ppc64le"
              "PPC64LE"
              "amd64"
              "AMD64"
              "win32"
              "WIN32"
            ];
          };
          type = "boolOp";
        };
        type = "boolOp";
      };
    };

    testInOperator = {
      expr = pep508.parseMarkers testMarkers.inOp;
      expected = {
        lhs = {
          lhs = {
            type = "variable";
            value = "python_version";
          };
          op = ">=";
          rhs = {
            type = "version";
            value = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [ 3 ];
              str = "3";
            };
          };
          type = "compare";
        };
        op = "and";
        rhs = {
          lhs = {
            type = "variable";
            value = "platform_machine";
          };
          op = "in";
          rhs = {
            type = "enum";
            value = [
              "x86_64"
              "X86_64"
              "aarch64"
              "AARCH64"
              "ppc64le"
              "PPC64LE"
              "amd64"
              "AMD64"
              "win32"
              "WIN32"
            ];
          };
          type = "boolOp";
        };
        type = "boolOp";
      };
    };
  };

  parseString = mapAttrs (_: case: case // { expr = pep508.parseString case.input; }) {
    testSimple = {
      input = "blinker";
      expected = {
        name = "blinker";
        conditions = [ ];
        extras = [ ];
        markers = null;
        url = null;
      };
    };

    testVersioned = {
      input = "rich>=12.3.0";
      expected = {
        name = "rich";
        conditions = [
          {
            op = ">=";
            version = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [
                12
                3
                0
              ];
              str = "12.3.0";
            };
          }
        ];
        extras = [ ];
        markers = null;
        url = null;
      };
    };

    testExtras = {
      input = "mkdocstrings[python]";
      expected = {
        name = "mkdocstrings";
        conditions = [ ];
        extras = [ "python" ];
        markers = null;
        url = null;
      };
    };

    testVersionedWithDoubleConditions = {
      input = "packaging>=20.9,!=22.0";
      expected = {
        name = "packaging";
        conditions = [
          {
            op = ">=";
            version = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [
                20
                9
              ];
              str = "20.9";
            };
          }
          {
            op = "!=";
            version = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [
                22
                0
              ];
              str = "22.0";
            };
          }
        ];
        extras = [ ];
        markers = null;
        url = null;
      };
    };

    testVersionedWithExtras = {
      input = "cachecontrol[filecache]>=0.13.0";
      expected = {
        name = "cachecontrol";
        conditions = [
          {
            op = ">=";
            version = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [
                0
                13
                0
              ];
              str = "0.13.0";
            };
          }
        ];
        extras = [ "filecache" ];
        markers = null;
        url = null;
      };
    };

    testVersionedWithMarker = {
      input = "tomli>=1.1.0; python_version < \"3.11\"";
      expected = {
        conditions = [
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
                1
                0
              ];
              str = "1.1.0";
            };
          }
        ];
        markers = {
          lhs = {
            type = "variable";
            value = "python_version";
          };
          op = "<";
          rhs = {
            type = "version";
            value = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [
                3
                11
              ];
              str = "3.11";
            };
          };
          type = "compare";
        };
        name = "tomli";
        extras = [ ];
        url = null;
      };
    };

    testNameWithURL = {
      input = "name@http://foo.com";
      expected = {
        name = "name";
        conditions = [ ];
        extras = [ ];
        markers = null;
        url = "http://foo.com";
      };
    };

    testDottedNames = {
      input = "A.B-C_D";
      expected = {
        name = "a-b-c-d";
        conditions = [ ];
        extras = [ ];
        markers = null;
        url = null;
      };
    };

    testCompleteExample = {
      input = "name [fred,bar] @ http://foo.com ; python_version=='2.7'";
      expected = {
        conditions = [ ];
        markers = {
          lhs = {
            type = "variable";
            value = "python_version";
          };
          op = "==";
          rhs = {
            type = "version";
            value = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [
                2
                7
              ];
              str = "2.7";
            };
          };
          type = "compare";
        };
        name = "name";
        extras = [
          "fred"
          "bar"
        ];
        url = "http://foo.com";
      };
    };

    testBareURL = {
      input = "http://wxpython.org/Phoenix/snapshot-builds/wxPython_Phoenix-3.0.3.dev1820+49a8884-cp34-none-win_amd64.whl";
      expected = {
        name = null;
        conditions = [ ];
        extras = [ ];
        markers = null;
        url = "http://wxpython.org/Phoenix/snapshot-builds/wxPython_Phoenix-3.0.3.dev1820+49a8884-cp34-none-win_amd64.whl";
      };
    };

    testBareLocalPath = {
      input = "./downloads/numpy-1.9.2-cp34-none-win32.whl";
      expected = {
        name = null;
        conditions = [ ];
        extras = [ ];
        markers = null;
        url = "./downloads/numpy-1.9.2-cp34-none-win32.whl";
      };
    };

    testDoubleMarkers = {
      input = "name; os_name=='a' or os_name=='b'";
      expected = {
        conditions = [ ];
        markers = {
          lhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "a";
            };
            type = "compare";
          };
          op = "or";
          rhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "b";
            };
            type = "compare";
          };
          type = "boolOp";
        };
        name = "name";
        extras = [ ];
        url = null;
      };
    };

    testDoubleMarkersWithExtras = {
      input = "name[quux, strange];python_version<'2.7' and platform_version=='2'";
      expected = {
        conditions = [ ];
        markers = {
          lhs = {
            lhs = {
              type = "variable";
              value = "python_version";
            };
            op = "<";
            rhs = {
              type = "version";
              value = {
                dev = null;
                epoch = 0;
                local = null;
                post = null;
                pre = null;
                release = [
                  2
                  7
                ];
                str = "2.7";
              };
            };
            type = "compare";
          };
          op = "and";
          rhs = {
            lhs = {
              type = "variable";
              value = "platform_version";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "2";
            };
            type = "compare";
          };
          type = "boolOp";
        };
        name = "name";
        extras = [
          "quux"
          "strange"
        ];
        url = null;
      };
    };

    testExprGroups = {
      # Should parse as (a and b) or c
      input = "name; os_name=='a' and os_name=='b' or os_name=='c'";
      expected = {
        conditions = [ ];
        markers = {
          lhs = {
            lhs = {
              lhs = {
                type = "variable";
                value = "os_name";
              };
              op = "==";
              rhs = {
                type = "string";
                value = "a";
              };
              type = "compare";
            };
            op = "and";
            rhs = {
              lhs = {
                type = "variable";
                value = "os_name";
              };
              op = "==";
              rhs = {
                type = "string";
                value = "b";
              };
              type = "compare";
            };
            type = "boolOp";
          };
          op = "or";
          rhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "c";
            };
            type = "compare";
          };
          type = "boolOp";
        };
        name = "name";
        extras = [ ];
        url = null;
      };
    };

    testExprGroupsInt = {
      # Overriding precedence -> a and (b or c)
      input = "name; os_name=='a' and (os_name=='b' or os_name=='c')";
      expected = {
        conditions = [ ];
        markers = {
          lhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "a";
            };
            type = "compare";
          };
          op = "and";
          rhs = {
            lhs = {
              lhs = {
                type = "variable";
                value = "os_name";
              };
              op = "==";
              rhs = {
                type = "string";
                value = "b";
              };
              type = "compare";
            };
            op = "or";
            rhs = {
              lhs = {
                type = "variable";
                value = "os_name";
              };
              op = "==";
              rhs = {
                type = "string";
                value = "c";
              };
              type = "compare";
            };
            type = "boolOp";
          };
          type = "boolOp";
        };
        name = "name";
        extras = [ ];
        url = null;
      };
    };

    testExprGroupsTail = {
      # should parse as a or (b and c)
      input = "name; os_name=='a' or os_name=='b' and os_name=='c'";
      expected = {
        conditions = [ ];
        markers = {
          lhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "a";
            };
            type = "compare";
          };
          op = "or";
          rhs = {
            lhs = {
              lhs = {
                type = "variable";
                value = "os_name";
              };
              op = "==";
              rhs = {
                type = "string";
                value = "b";
              };
              type = "compare";
            };
            op = "and";
            rhs = {
              lhs = {
                type = "variable";
                value = "os_name";
              };
              op = "==";
              rhs = {
                type = "string";
                value = "c";
              };
              type = "compare";
            };
            type = "boolOp";
          };
          type = "boolOp";
        };
        name = "name";
        extras = [ ];
        url = null;
      };
    };

    testExprGroupsHead = {
      # Overriding precedence -> (a or b) and c
      input = "name; (os_name=='a' or os_name=='b') and os_name=='c'";
      expected = {
        conditions = [ ];
        markers = {
          lhs = {
            lhs = {
              lhs = {
                type = "variable";
                value = "os_name";
              };
              op = "==";
              rhs = {
                type = "string";
                value = "a";
              };
              type = "compare";
            };
            op = "or";
            rhs = {
              lhs = {
                type = "variable";
                value = "os_name";
              };
              op = "==";
              rhs = {
                type = "string";
                value = "b";
              };
              type = "compare";
            };
            type = "boolOp";
          };
          op = "and";
          rhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "c";
            };
            type = "compare";
          };
          type = "boolOp";
        };
        name = "name";
        extras = [ ];
        url = null;
      };
    };
  };

  mkEnviron =
    mapAttrs
      (name: case: {
        expr = pep508.mkEnviron case;
        expected = lib.importJSON ./expected/pep508.mkEnviron.${name}.json;
      })
      {
        testPython38Linux = mocks.cpythonLinux38;
        testPython311Darwin = mocks.cpythonDarwin311;
        testPython311DarwinAarch64 = mocks.cpythonDarwin311Aarch64;
        testPypy3Linux = mocks.pypy39Linux;
      };

  setEnviron =
    let
      environ = pep508.mkEnviron mocks.cpythonLinux38;
    in
    {
      testSetPlatformReleaseValidVersion = {
        expr = {
          inherit (setEnviron environ { platform_release = "5.10.65"; }) platform_release;
        };
        expected = {
          platform_release = {
            type = "platform_release";
            value = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [
                5
                10
                65
              ];
              str = "5.10.65";
            };
          };
        };
      };

      testSetPlatformReleaseInvalidVersion = {
        expr = {
          inherit (setEnviron environ { platform_release = "5.10.65-1025-azure"; }) platform_release;
        };
        expected = {
          platform_release = {
            type = "platform_release";
            value = "5.10.65-1025-azure";
          };
        };
      };

      testSetVersion = {
        expr = {
          inherit (setEnviron environ { implementation_version = "1.0.0"; }) implementation_version;
        };
        expected = {
          implementation_version = {
            type = "version";
            value = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [
                1
                0
                0
              ];
              str = "1.0.0";
            };
          };
        };
      };

      testSetExtraString = {
        expr = {
          inherit (setEnviron environ { extra = "foo"; }) extra;
        };
        expected = {
          extra = {
            type = "extra";
            value = "foo";
          };
        };
      };

      testSetExtraList = {
        expr = {
          inherit (setEnviron environ { extra = [ "foo" ]; }) extra;
        };
        expected = {
          extra = {
            type = "extra";
            value = [ "foo" ];
          };
        };
      };
    };

  evalMarkers =
    mapAttrs (_: case: case // { expr = pep508.evalMarkers case.input.environ case.input.markers; })
      {
        testTrivial = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected;
            inherit (self.parseString.testVersionedWithMarker.expected) markers;
          };
          expected = true;
        };

        testDoubleMarkers = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected;
            inherit (self.parseString.testDoubleMarkersWithExtras.expected) markers;
          };
          expected = false;
        };

        testMarkerWithExtra = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected // {
              extra = {
                type = "extra";
                value = "socks";
              };
            };
            markers = pep508.parseMarkers "extra == 'socks'";
          };
          expected = true;
        };

        testMarkerWithExtraNe = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected // {
              extra = {
                type = "extra";
                value = "socks";
              };
            };
            markers = pep508.parseMarkers "extra != 'socks'";
          };
          expected = false;
        };

        testMarkerWithMultipleExtra = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected // {
              extra = {
                type = "extra";
                value = [ "socks" ];
              };
            };
            markers = pep508.parseMarkers "extra == 'socks'";
          };
          expected = true;
        };

        testMarkerWithoutExtra = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected // {
              extra = {
                type = "extra";
                value = "pants";
              };
            };
            markers = pep508.parseMarkers "extra == 'socks'";
          };
          expected = false;
        };

        testMarkerWithoutMultipleExtra = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected // {
              extra = {
                type = "extra";
                value = [ "pants" ];
              };
            };
            markers = pep508.parseMarkers "extra == 'socks'";
          };
          expected = false;
        };

        testPlatformRelease = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected;
            markers = pep508.parseMarkers "platform_release >= '20.0'";
          };
          expected = false;
        };

        testPlatformReleaseInvalidPep440 = {
          input = {
            environ = self.mkEnviron.testPython38Linux.expected;
            markers = pep508.parseMarkers "platform_release >= '6.5.0-1025-azure'";
          };
          expected = false;
        };

      };
})
