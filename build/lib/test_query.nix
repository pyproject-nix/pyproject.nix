{
  pyproject-nix,
  ...
}:

let
  inherit (pyproject-nix.build.lib.query) deps;

  testpkg = {
    passthru = {
      dependencies = {
        dep-a = [ "extra-foo" ];
      };
      optional-dependencies = {
        extra-a = {
          dep-b = [ "extra-bar" ];
        };
        extra-b = {
          dep-b = [ "extra-baz" ];
        };
      };
      dependency-groups = {
        group-a = {
          dep-c = [ "extra-bar" ];
        };
        group-b = {
          dep-c = [ "extra-baz" ];
        };
      };
    };
  };

  pythonSet = {
    inherit testpkg;
  };

in

{
  deps = {
    testTrivial = {
      expr = deps { } pythonSet {
        testpkg = [ ];
      };
      expected = {
        dep-a = [ "extra-foo" ];
      };
    };

    testNoDeps = {
      expr = deps { dependencies = false; } testpkg {
        testpkg = [ ];
      };
      expected = { };
    };

    testExtras = {
      expr = deps { } pythonSet {
        testpkg = [
          "extra-a"
          "extra-b"
        ];
      };
      expected = {
        dep-a = [ "extra-foo" ];
        dep-b = [
          "extra-bar"
          "extra-baz"
        ];
      };
    };

    testGroups = {
      expr = deps { } pythonSet {
        testpkg = [
          "group-a"
          "group-b"
        ];
      };
      expected = {
        dep-a = [ "extra-foo" ];
        dep-c = [
          "extra-bar"
          "extra-baz"
        ];
      };
    };

    testMixed = {
      expr = deps { } pythonSet {
        testpkg = [
          "extra-a"
          "extra-b"
          "group-a"
          "group-b"
        ];
      };
      expected = {
        dep-a = [ "extra-foo" ];
        dep-b = [
          "extra-bar"
          "extra-baz"
        ];
        dep-c = [
          "extra-bar"
          "extra-baz"
        ];
      };
    };
  };
}
