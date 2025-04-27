{
  lib,
  pypa,
  mocks,
  ...
}:
let
  inherit (pypa)
    normalizePackageName
    parsePythonTag
    parseABITag
    parseWheelFileName
    isWheelFileName
    isPythonTagCompatible
    isABITagCompatible
    isPlatformTagCompatible
    isWheelFileCompatible
    selectWheels
    isSdistFileName
    matchWheelFileName
    ;
  inherit (lib) mapAttrs';

in

{
  normalizePackageName =
    mapAttrs'
      (n: _: {
        name = "testNormalize${n}";
        value = {
          expr = normalizePackageName n;
          expected = "friendly-bard";
        };
      })
      {
        "friendly-bard" = { };
        "Friendly-Bard" = { };
        "FRIENDLY-BARD" = { };
        "friendly.bard" = { };
        "friendly_bard" = { };
        "friendly--bard" = { };
        "FrIeNdLy-._.-bArD" = { };
      };

  parsePythonTag = {
    testWithFlags = {
      expr = parsePythonTag "cp37";
      expected = {
        implementation = "cpython";
        version = "37";
      };
    };
  };

  parseABITag = {
    testWithFlags = {
      expr = parseABITag "cp37dmu";
      expected = {
        tag = "cp37dmu";
      };
    };

    testWithPypyFlags = {
      expr = parseABITag "pypy38_pp73";
      expected = {
        tag = "pypy38_pp73";
      };
    };
  };

  parseWheelFileName = {
    testSimple = {
      expr = parseWheelFileName "distribution-1.0-1-py27-none-any.whl";
      expected = {
        abiTag = {
          tag = "none";
        };
        buildTag = "1";
        distribution = "distribution";
        languageTags = [
          {
            implementation = "python";
            version = "27";
          }
        ];
        platformTags = [ "any" ];
        version = "1.0";
        filename = "distribution-1.0-1-py27-none-any.whl";
      };
    };

    testComplex = {
      expr = parseWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
      expected = {
        abiTag = {
          tag = "abi3";
        };
        buildTag = null;
        distribution = "cryptography";
        languageTags = [
          {
            implementation = "cpython";
            version = "37";
          }
        ];
        platformTags = [
          "manylinux_2_17_aarch64"
          "manylinux2014_aarch64"
        ];
        version = "41.0.1";
        filename = "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
      };
    };

    testMultipleLanguageTags = {
      expr = parseWheelFileName "Werkzeug-1.0.0-py2.py3-none-any.whl";
      expected = {
        abiTag = {
          tag = "none";
        };
        buildTag = null;
        distribution = "Werkzeug";
        languageTags = [
          {
            implementation = "python";
            version = "2";
          }
          {
            implementation = "python";
            version = "3";
          }
        ];
        platformTags = [ "any" ];
        version = "1.0.0";
        filename = "Werkzeug-1.0.0-py2.py3-none-any.whl";
      };
    };
  };

  matchWheelFileName = {
    testSimple = {
      expr = matchWheelFileName "distribution-1.0-1-py27-none-any.whl";
      expected = [
        "distribution"
        "1.0"
        "-1"
        "1"
        "py27"
        "none"
        "any"
      ];
    };

    testSimpleNoMatch = {
      expr = matchWheelFileName "distribution-1.0-1-py27-none-any.tar.gz";
      expected = null;
    };

    testComplex = {
      expr = matchWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
      expected = [
        "cryptography"
        "41.0.1"
        "cp37"
        "abi3"
        "manylinux_2_17_aarch64.manylinux2014_aarch64"
      ];
    };

    testComplexNoMatch = {
      expr = matchWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.zip";
      expected = null;
    };
  };

  isWheelFileName = {
    testSimple = {
      expr = isWheelFileName "distribution-1.0-1-py27-none-any.whl";
      expected = true;
    };

    testSimpleNoMatch = {
      expr = isWheelFileName "distribution-1.0-1-py27-none-any.tar.gz";
      expected = false;
    };

    testComplex = {
      expr = isWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
      expected = true;
    };

    testComplexNoMatch = {
      expr = isWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.zip";
      expected = false;
    };
  };

  isSdistFileName = {
    testSimpleZip = {
      expr = isSdistFileName "debugpy-1.6.7.zip";
      expected = true;
    };

    testSimpleTarGz = {
      expr = isSdistFileName "debugpy-1.6.7.tar.gz";
      expected = true;
    };

    testSimpleTarBz2 = {
      expr = isSdistFileName "debugpy-1.6.7.tar.bz2";
      expected = false;
    };

    testUniversalWheel = {
      expr = isSdistFileName "distribution-1.0-1-py27-none-any.whl";
      expected = false;
    };

    testWheel = {
      expr = isSdistFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
      expected = false;
    };
  };

  isPythonTagCompatible = {
    testPython = {
      expr = isPythonTagCompatible mocks.cpythonLinux38 (parsePythonTag "py3");
      expected = true;
    };

    testCpython = {
      expr = isPythonTagCompatible mocks.cpythonLinux38 (parsePythonTag "cp3");
      expected = true;
    };

    testCpythonOlder = {
      expr = isPythonTagCompatible mocks.cpythonLinux38 (parsePythonTag "cp37");
      expected = true;
    };

    testCpythonWithVersion = {
      expr = isPythonTagCompatible mocks.cpythonLinux38 (parsePythonTag "cp38");
      expected = true;
    };

    testCpythonWithVersionNoCompat = {
      expr = isPythonTagCompatible mocks.cpythonLinux38 (parsePythonTag "cp39");
      expected = false;
    };

    testPythonIncompatible = {
      expr = isPythonTagCompatible mocks.cpythonLinux38 (parsePythonTag "py2");
      expected = false;
    };

    testPypyTag = {
      expr = isPythonTagCompatible mocks.cpythonLinux38 (parsePythonTag "pp3");
      expected = false;
    };
  };

  isABITagCompatible = {
    testCompatible = {
      expr = isABITagCompatible mocks.cpythonLinux38 (parseABITag "cp38");
      expected = true;
    };

    testIncompatible = {
      expr = isABITagCompatible mocks.cpythonLinux38 (parseABITag "cp39");
      expected = false;
    };
  };

  isPlatformTagCompatible = {
    testCompatible = {
      expr =
        isPlatformTagCompatible mocks.cpythonLinux38.stdenv.targetPlatform
          mocks.cpythonLinux38.stdenv.cc.libc
          "manylinux_2_5_x86_64";
      expected = true;
    };

    testCompatible2 = {
      expr =
        isPlatformTagCompatible mocks.cpythonLinux38.stdenv.targetPlatform
          mocks.cpythonLinux38.stdenv.cc.libc
          "manylinux1_x86_64";
      expected = true;
    };

    testIncompatibleArch = {
      expr =
        isPlatformTagCompatible mocks.cpythonLinux38.stdenv.targetPlatform
          mocks.cpythonLinux38.stdenv.cc.libc
          "manylinux_2_5_armv7l";
      expected = false;
    };

    testIncompatibleLibc = {
      expr =
        isPlatformTagCompatible mocks.cpythonLinux38.stdenv.targetPlatform
          mocks.cpythonLinux38.stdenv.cc.libc
          "musllinux_1_1_x86_64";
      expected = false;
    };

    testMacos = {
      expr =
        isPlatformTagCompatible mocks.cpythonDarwin311.stdenv.targetPlatform
          mocks.cpythonDarwin311.stdenv.cc.libc
          "macosx_11_0_x86_64";
      expected = true;
    };

    testMacosIncomatibleArch = {
      expr =
        isPlatformTagCompatible mocks.cpythonDarwin311.stdenv.targetPlatform
          mocks.cpythonDarwin311.stdenv.cc.libc
          "macosx_11_0_arm64";
      expected = false;
    };

    testMacosIncomatibleSdk = {
      expr =
        isPlatformTagCompatible mocks.cpythonDarwin311.stdenv.targetPlatform
          mocks.cpythonDarwin311.stdenv.cc.libc
          "macosx_12_0_x86_64";
      expected = false;
    };

    testMacosUniversal2 = {
      expr =
        isPlatformTagCompatible mocks.cpythonDarwin311.stdenv.targetPlatform
          mocks.cpythonDarwin311.stdenv.cc.libc
          "macosx_11_0_universal2";
      expected = true;
    };
  };

  isWheelFileCompatible = {
    testIncompatible = {
      expr =
        isWheelFileCompatible mocks.cpythonLinux38.stdenv.targetPlatform mocks.cpythonLinux38.stdenv.cc.libc
          mocks.cpythonLinux38
          (
            parseWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
          );
      expected = false;
    };

    testCompatible = {
      expr =
        isWheelFileCompatible mocks.cpythonLinux38.stdenv.targetPlatform mocks.cpythonLinux38.stdenv.cc.libc
          mocks.cpythonLinux38
          (parseWheelFileName "cryptography-41.0.1-cp38-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl");
      expected = true;
    };
  };

  selectWheels =
    let
      mkTest =
        {
          input,
          output,
          python,
        }:
        {
          expr = map (wheel: wheel.filename) (
            selectWheels python.stdenv.targetPlatform python (map parseWheelFileName input)
          );
          expected = output;
        };

      zmqWheels = [
        "pyzmq-24.0.1-cp310-cp310-macosx_10_15_universal2.whl"
        "pyzmq-24.0.1-cp310-cp310-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-cp310-cp310-manylinux_2_17_i686.manylinux2014_i686.whl"
        "pyzmq-24.0.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
        "pyzmq-24.0.1-cp310-cp310-musllinux_1_1_aarch64.whl"
        "pyzmq-24.0.1-cp310-cp310-musllinux_1_1_i686.whl"
        "pyzmq-24.0.1-cp310-cp310-musllinux_1_1_x86_64.whl"
        "pyzmq-24.0.1-cp310-cp310-win32.whl"
        "pyzmq-24.0.1-cp310-cp310-win_amd64.whl"
        "pyzmq-24.0.1-cp311-cp311-macosx_10_15_universal2.whl"
        "pyzmq-24.0.1-cp311-cp311-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-cp311-cp311-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-cp311-cp311-manylinux_2_17_i686.manylinux2014_i686.whl"
        "pyzmq-24.0.1-cp311-cp311-manylinux_2_28_x86_64.whl"
        "pyzmq-24.0.1-cp311-cp311-musllinux_1_1_aarch64.whl"
        "pyzmq-24.0.1-cp311-cp311-musllinux_1_1_i686.whl"
        "pyzmq-24.0.1-cp311-cp311-musllinux_1_1_x86_64.whl"
        "pyzmq-24.0.1-cp311-cp311-win32.whl"
        "pyzmq-24.0.1-cp311-cp311-win_amd64.whl"
        "pyzmq-24.0.1-cp36-cp36m-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-cp36-cp36m-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-cp36-cp36m-manylinux_2_5_i686.manylinux1_i686.whl"
        "pyzmq-24.0.1-cp36-cp36m-manylinux_2_5_x86_64.manylinux1_x86_64.whl"
        "pyzmq-24.0.1-cp36-cp36m-musllinux_1_1_aarch64.whl"
        "pyzmq-24.0.1-cp36-cp36m-musllinux_1_1_i686.whl"
        "pyzmq-24.0.1-cp36-cp36m-musllinux_1_1_x86_64.whl"
        "pyzmq-24.0.1-cp36-cp36m-win32.whl"
        "pyzmq-24.0.1-cp36-cp36m-win_amd64.whl"
        "pyzmq-24.0.1-cp37-cp37m-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-cp37-cp37m-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-cp37-cp37m-manylinux_2_5_i686.manylinux1_i686.whl"
        "pyzmq-24.0.1-cp37-cp37m-manylinux_2_5_x86_64.manylinux1_x86_64.whl"
        "pyzmq-24.0.1-cp37-cp37m-musllinux_1_1_aarch64.whl"
        "pyzmq-24.0.1-cp37-cp37m-musllinux_1_1_i686.whl"
        "pyzmq-24.0.1-cp37-cp37m-musllinux_1_1_x86_64.whl"
        "pyzmq-24.0.1-cp37-cp37m-win32.whl"
        "pyzmq-24.0.1-cp37-cp37m-win_amd64.whl"
        "pyzmq-24.0.1-cp38-cp38-macosx_10_15_universal2.whl"
        "pyzmq-24.0.1-cp38-cp38-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-cp38-cp38-manylinux_2_12_i686.manylinux2010_i686.whl"
        "pyzmq-24.0.1-cp38-cp38-manylinux_2_12_x86_64.manylinux2010_x86_64.whl"
        "pyzmq-24.0.1-cp38-cp38-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-cp38-cp38-musllinux_1_1_aarch64.whl"
        "pyzmq-24.0.1-cp38-cp38-musllinux_1_1_i686.whl"
        "pyzmq-24.0.1-cp38-cp38-musllinux_1_1_x86_64.whl"
        "pyzmq-24.0.1-cp38-cp38-win32.whl"
        "pyzmq-24.0.1-cp38-cp38-win_amd64.whl"
        "pyzmq-24.0.1-cp39-cp39-macosx_10_15_universal2.whl"
        "pyzmq-24.0.1-cp39-cp39-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-cp39-cp39-manylinux_2_12_i686.manylinux2010_i686.whl"
        "pyzmq-24.0.1-cp39-cp39-manylinux_2_12_x86_64.manylinux2010_x86_64.whl"
        "pyzmq-24.0.1-cp39-cp39-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-cp39-cp39-musllinux_1_1_aarch64.whl"
        "pyzmq-24.0.1-cp39-cp39-musllinux_1_1_i686.whl"
        "pyzmq-24.0.1-cp39-cp39-musllinux_1_1_x86_64.whl"
        "pyzmq-24.0.1-cp39-cp39-win32.whl"
        "pyzmq-24.0.1-cp39-cp39-win_amd64.whl"
        "pyzmq-24.0.1-pp37-pypy37_pp73-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-pp37-pypy37_pp73-manylinux_2_12_i686.manylinux2010_i686.whl"
        "pyzmq-24.0.1-pp37-pypy37_pp73-manylinux_2_12_x86_64.manylinux2010_x86_64.whl"
        "pyzmq-24.0.1-pp37-pypy37_pp73-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-pp37-pypy37_pp73-win_amd64.whl"
        "pyzmq-24.0.1-pp38-pypy38_pp73-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-pp38-pypy38_pp73-manylinux_2_12_i686.manylinux2010_i686.whl"
        "pyzmq-24.0.1-pp38-pypy38_pp73-manylinux_2_12_x86_64.manylinux2010_x86_64.whl"
        "pyzmq-24.0.1-pp38-pypy38_pp73-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-pp38-pypy38_pp73-win_amd64.whl"
        "pyzmq-24.0.1-pp39-pypy39_pp73-macosx_10_9_x86_64.whl"
        "pyzmq-24.0.1-pp39-pypy39_pp73-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyzmq-24.0.1-pp39-pypy39_pp73-manylinux_2_17_i686.manylinux2014_i686.whl"
        "pyzmq-24.0.1-pp39-pypy39_pp73-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
        "pyzmq-24.0.1-pp39-pypy39_pp73-win_amd64.whl"
      ];

      pyarrowWheels = [
        "pyarrow-13.0.0-cp310-cp310-macosx_10_14_x86_64.whl"
        "pyarrow-13.0.0-cp310-cp310-macosx_11_0_arm64.whl"
        "pyarrow-13.0.0-cp310-cp310-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyarrow-13.0.0-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
        "pyarrow-13.0.0-cp310-cp310-manylinux_2_28_aarch64.whl"
        "pyarrow-13.0.0-cp310-cp310-manylinux_2_28_x86_64.whl"
        "pyarrow-13.0.0-cp310-cp310-win_amd64.whl"
        "pyarrow-13.0.0-cp311-cp311-macosx_10_14_x86_64.whl"
        "pyarrow-13.0.0-cp311-cp311-macosx_11_0_arm64.whl"
        "pyarrow-13.0.0-cp311-cp311-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyarrow-13.0.0-cp311-cp311-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
        "pyarrow-13.0.0-cp311-cp311-manylinux_2_28_aarch64.whl"
        "pyarrow-13.0.0-cp311-cp311-manylinux_2_28_x86_64.whl"
        "pyarrow-13.0.0-cp311-cp311-win_amd64.whl"
        "pyarrow-13.0.0-cp38-cp38-macosx_10_14_x86_64.whl"
        "pyarrow-13.0.0-cp38-cp38-macosx_11_0_arm64.whl"
        "pyarrow-13.0.0-cp38-cp38-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyarrow-13.0.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
        "pyarrow-13.0.0-cp38-cp38-manylinux_2_28_aarch64.whl"
        "pyarrow-13.0.0-cp38-cp38-manylinux_2_28_x86_64.whl"
        "pyarrow-13.0.0-cp38-cp38-win_amd64.whl"
        "pyarrow-13.0.0-cp39-cp39-macosx_10_14_x86_64.whl"
        "pyarrow-13.0.0-cp39-cp39-macosx_11_0_arm64.whl"
        "pyarrow-13.0.0-cp39-cp39-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
        "pyarrow-13.0.0-cp39-cp39-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
        "pyarrow-13.0.0-cp39-cp39-manylinux_2_28_aarch64.whl"
        "pyarrow-13.0.0-cp39-cp39-manylinux_2_28_x86_64.whl"
        "pyarrow-13.0.0-cp39-cp39-win_amd64.whl"
      ];

    in
    {
      test_selectWheel_platform_type_error = {
        expr = selectWheels "x86_64-linux" null null;
        expectedError.type = "ThrownError";
        expectedError.msg = "SelectWheel was called with wrong type for its first argument 'platform'";
      };
      testPyNoneAny = mkTest {
        input = [
          "distribution-1.0-1-py37-none-any.whl"
          "distribution-1.0-1-py38-none-any.whl"
        ];
        output = [
          "distribution-1.0-1-py38-none-any.whl"
          "distribution-1.0-1-py37-none-any.whl"
        ];
        python = mocks.cpythonLinux38;
      };

      testPyNoneAnyReverseInput = mkTest {
        input = [
          "distribution-1.0-1-py38-none-any.whl"
          "distribution-1.0-1-py37-none-any.whl"
        ];
        output = [
          "distribution-1.0-1-py38-none-any.whl"
          "distribution-1.0-1-py37-none-any.whl"
        ];
        python = mocks.cpythonLinux38;
      };

      testZmqCpythonLinux38 = mkTest {
        input = zmqWheels;
        output = [
          "pyzmq-24.0.1-cp38-cp38-manylinux_2_12_x86_64.manylinux2010_x86_64.whl"
        ];
        python = mocks.cpythonLinux38;
      };

      testZmqCPythonDarwin311 = mkTest {
        input = zmqWheels;
        output = [
          "pyzmq-24.0.1-cp311-cp311-macosx_10_15_universal2.whl"
          "pyzmq-24.0.1-cp311-cp311-macosx_10_9_x86_64.whl"
        ];
        python = mocks.cpythonDarwin311;
      };

      testZmqPypy39Linux = mkTest {
        input = zmqWheels;
        output = [
          "pyzmq-24.0.1-pp39-pypy39_pp73-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
        ];
        python = mocks.pypy39Linux;
      };

      testArrowCpythonLinux38 = mkTest {
        input = pyarrowWheels;
        output = [
          # TODO: Also sort by libc version, glibc 2.28 should come before 2.17
          "pyarrow-13.0.0-cp38-cp38-manylinux_2_17_x86_64.manylinux2014_x86_64.whl"
          "pyarrow-13.0.0-cp38-cp38-manylinux_2_28_x86_64.whl"
        ];
        python = mocks.cpythonLinux38;
      };

      testArrowCPythonDarwin311 = mkTest {
        input = pyarrowWheels;
        output = [
          "pyarrow-13.0.0-cp311-cp311-macosx_10_14_x86_64.whl"
        ];
        python = mocks.cpythonDarwin311;
      };

      testArrowPypy39Linux = mkTest {
        input = pyarrowWheels;
        output = [ ];
        python = mocks.pypy39Linux;
      };
    };

}
