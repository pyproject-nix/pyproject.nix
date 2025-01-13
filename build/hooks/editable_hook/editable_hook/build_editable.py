import os
import sys
from pathlib import Path
from typing import Any

if sys.version_info >= (3, 11):
    import tomllib
else:
    import tomli as tomllib  # pyright: ignore[reportMissingImports]
import pyproject_hooks


def main():
    build_dir = Path(os.getcwd())
    dist = build_dir.joinpath("dist")

    with open(build_dir.joinpath("pyproject.toml"), "rb") as pyproject_file:
        pyproject: dict[str, Any] = tomllib.load(pyproject_file)  # pyright: ignore[reportUnknownMemberType,reportExplicitAny]

    # Get build backend with fallback behaviour
    # https://pip.pypa.io/en/stable/reference/build-system/pyproject-toml/#fallback-behaviour
    try:
        build_backend: str = pyproject["build-system"]["build-backend"]
    except KeyError:
        build_backend = "setuptools.build_meta:__legacy__"

    try:
        dist.mkdir()
    except FileExistsError:
        pass

    # Call editable build hooks using pyproject-hooks
    hook_caller = pyproject_hooks.BuildBackendHookCaller(
        source_dir=str(build_dir),
        build_backend=build_backend,
    )
    hook_caller.build_editable(str(dist))


if __name__ == "__main__":
    main()
