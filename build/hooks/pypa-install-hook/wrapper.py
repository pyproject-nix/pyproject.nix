#!/usr/bin/env python3
import os
import sys


def main():
    """
    Provides compatibility with uv env vars when using pypa/installer.
    Ideally uv should also be used for cross installs, but for now it's not compatible.
    """
    compile_bytecode = bool(os.environ.get("UV_COMPILE_BYTECODE", False))

    args = sys.argv[1:]
    if compile_bytecode:
        args.insert(0, "1")
        args.insert(0, "--compile-bytecode")

    os.execv(sys.executable, [sys.executable, "-m", "installer", *args])


if __name__ == "__main__":
    main()
