import argparse
import subprocess
import sys
import tempfile
from collections.abc import Generator
from contextlib import contextmanager
from pathlib import Path
from textwrap import dedent
from typing import Any, Union, cast

# Backwards compat with old Python for sandbox builds.
if sys.version_info >= (3, 11):
    import tomllib  # pyright: ignore[reportUnreachable]
else:
    import tomli as tomllib  # pyright: ignore[reportMissingImports]


class BuildError(Exception):
    pass


class ArgsNS(argparse.Namespace):
    python: str  # pyright: ignore[reportUninitializedInstanceVariable]
    dist: str  # pyright: ignore[reportUninitializedInstanceVariable]
    verbose: str  # pyright: ignore[reportUninitializedInstanceVariable]


arg_parser = argparse.ArgumentParser(description="Build editables according PEP-660")
arg_parser.add_argument(
    "--python",
    help="Build Python interpreter",
    default="python",
)
arg_parser.add_argument(
    "--dist",
    help="Write build results to dist directory",
    default=None,
)
arg_parser.add_argument("-v", "--verbose", action="store_true")


@contextmanager
def dist_dir(arg: Union[str, None]) -> Generator[Path]:
    """Return a uniform looking context manager for dist path"""
    if arg is None:
        tmp_dir = tempfile.TemporaryDirectory()
        try:
            yield Path(tmp_dir.name)
        finally:
            tmp_dir.cleanup()
    else:
        try:
            path = Path(arg)
            path.mkdir(exist_ok=True)
            yield path
        finally:
            pass


def main():
    args = arg_parser.parse_args(namespace=ArgsNS)
    cwd = Path.cwd()

    with open(cwd.joinpath("pyproject.toml"), "rb") as pyproject_file:
        pyproject: dict[str, Any] = tomllib.load(pyproject_file)  # pyright: ignore[reportUnknownMemberType,reportExplicitAny,reportUnknownVariableType]

    # Get build backend with fallback behaviour
    # https://pip.pypa.io/en/stable/reference/build-system/pyproject-toml/#fallback-behaviour
    build_backend: str
    try:
        build_backend = pyproject["build-system"]["build-backend"]  # pyright: ignore[reportUnknownVariableType]
    except KeyError:
        build_backend = "setuptools.build_meta:__legacy__"

    print("Building editable...")
    if args.verbose:
        print(
            dedent(f"""
        Using Python: {args.python}
        Build backend: {build_backend}
        """).strip()
        )

    with dist_dir(args.dist) as dist:
        proc = subprocess.Popen(args.python, stdin=subprocess.PIPE)

        try:
            backend_module, backend_attr = cast(str, build_backend).split(":", 1)
        except ValueError:
            backend_module = cast(str, build_backend)
            backend_attr = ""

        proc.communicate(
            input=dedent(f"""
        import importlib
        backend = importlib.import_module("{backend_module}")
        if "{backend_attr}" != "":
            backend = getattr(backend, "{backend_attr}")
        backend.build_editable("{dist}")
        """).encode()
        )

        returncode = proc.wait()
        if returncode != 0:
            sys.exit(returncode)

        build_results: list[str] = []
        for child in dist.iterdir():
            build_results.append(child.name)

        if not build_results:
            raise BuildError("Build produced no wheels!")
        else:
            if args.verbose:
                print("Done building...")
                print("Build produced results:")
                for result in build_results:
                    print(result)


if __name__ == "__main__":
    main()
