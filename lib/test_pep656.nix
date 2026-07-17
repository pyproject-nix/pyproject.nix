{ pep656, lib, ... }:
let
  inherit (pep656) muslLinuxTagCompatible;

  mockStdenvs =
    let
      mkMock = pname: version: _cpuName: {
        cc = {
          libc = {
            inherit pname version;
          };
        };
        targetPlatform = lib.systems.elaborate "x86_64-linux" // {
          libc = pname;
        };
      };
    in
    {
      x86_64-linux = {
        glibc_2_4 = mkMock "glibc" "2.4" "x86_64";
        glibc_2_5 = mkMock "glibc" "2.5" "x86_64";
        musl_1_2_3 = mkMock "musl" "1.2.3" "x86_64";
      };
      powerpc64le-linux.musl_1_2_3 = {
        cc.libc = {
          pname = "musl";
          version = "1.2.3";
        };
        targetPlatform = lib.systems.elaborate {
          system = "powerpc64le-linux";
          config = "powerpc64le-unknown-linux-musl";
        };
      };
    };

in
{
  muslLinuxTagCompatible = {
    testSimpleIncompatible = {
      expr =
        muslLinuxTagCompatible mockStdenvs.x86_64-linux.glibc_2_4.targetPlatform
          mockStdenvs.x86_64-linux.glibc_2_4.cc.libc
          "musllinux_1_1_x86_64";
      expected = false;
    };

    testManyLinux = {
      expr =
        muslLinuxTagCompatible mockStdenvs.x86_64-linux.musl_1_2_3.targetPlatform
          mockStdenvs.x86_64-linux.musl_1_2_3.cc.libc
          "manylinux1_x86_64";
      expectedError.type = "ThrownError";
      expectedError.msg = ".* is not a valid musllinux tag";
    };

    testSimpleCompatible = {
      expr =
        muslLinuxTagCompatible mockStdenvs.x86_64-linux.musl_1_2_3.targetPlatform
          mockStdenvs.x86_64-linux.musl_1_2_3.cc.libc
          "musllinux_1_1_x86_64";
      expected = true;
    };

    testSimpleArchIncompatible = {
      expr =
        muslLinuxTagCompatible mockStdenvs.x86_64-linux.musl_1_2_3.targetPlatform
          mockStdenvs.x86_64-linux.musl_1_2_3.cc.libc
          "musllinux_1_1_armv7l";
      expected = false;
    };

    testPpc64leCompatible = {
      expr =
        muslLinuxTagCompatible mockStdenvs.powerpc64le-linux.musl_1_2_3.targetPlatform
          mockStdenvs.powerpc64le-linux.musl_1_2_3.cc.libc
          "musllinux_1_2_ppc64le";
      expected = true;
    };

    testPpc64leArchIncompatible = {
      expr =
        muslLinuxTagCompatible mockStdenvs.powerpc64le-linux.musl_1_2_3.targetPlatform
          mockStdenvs.powerpc64le-linux.musl_1_2_3.cc.libc
          "musllinux_1_2_x86_64";
      expected = false;
    };
  };
}
