#!/usr/bin/env python
import argparse
import contextlib
import fnmatch
import os.path
import shutil
import sys
from functools import lru_cache
from pathlib import Path
from stat import S_ISDIR, S_ISLNK, S_ISREG
from typing import Optional, Union
from venv import EnvBuilder

MergedInputs = Union[Path, None, dict[str, "MergedInputs"]]


EXECUTABLE = os.path.basename(sys.executable)


class ArgsNS(argparse.Namespace):
    out: str
    python: str
    deps: list[str]
    env: list[str]
    skip: list[str]
    ignore_collisions: list[str]

    def __init__(self):
        self.out = ""
        self.python = ""
        self.deps = []
        self.env = []
        self.skip = []
        self.ignore_collisions = []
        super().__init__()


arg_parser = argparse.ArgumentParser()
arg_parser.add_argument("out", help="Virtualenv output directory")
arg_parser.add_argument(
    "--python", help="Python to link virtualenv to", default=os.path.dirname(os.path.dirname(sys.executable))
)
arg_parser.add_argument("--env", action="append", help="Source dependencies from environment variable")
arg_parser.add_argument("--deps", action="append", help="Source dependencies from colon separated list")
arg_parser.add_argument("--skip", action="append", help="Skip linking path into venv")
arg_parser.add_argument(
    "--ignore-collisions", action="append", help="Ignore collisions for path, link the first path encountered"
)


class FileCollisionError(Exception):
    def __init__(self, inputs: list[Path]):
        err = f"""Two or more packages are trying to provide the same file with different contents

        Files: {' '.join((str(x) for x in inputs))}


        See https://pyproject-nix.github.io/pyproject.nix/build/packages.html for strategies for dealing with file collisions"""
        super().__init__(err)


class FileMergeError(Exception):
    pass


def compare_paths(paths: list[Path]) -> bool:
    if len(paths) < 2:
        return True

    with contextlib.ExitStack() as stack:
        fds = [stack.enter_context(open(path, mode="rb")) for path in paths]

        while True:
            content = fds[0].read(8192)

            if not all(fd.read(8192) == content for fd in fds[1:]):
                return False

            if not content:
                return True


def is_bytecode(path: Path) -> bool:
    # Bytecode files contain fully resolved file names, meaning that the byte code will always collide
    # even if the original sources are identical.
    # We can safely ignore collisions for bytecode because we check the original sources for equality.
    return "__pycache__" in path.parts and path.suffix == ".pyc"


@lru_cache()
def lstat(path: Path):
    return path.lstat()


def merge_inputs(
    inputs: list[Path],
    skip_paths: Optional[list[str]] = None,
    ignore_collisions: Optional[list[str]] = None,
) -> MergedInputs:
    """
    Merge multiple store paths
    """

    skip_paths = skip_paths or []
    ignore_collisions = ignore_collisions or []

    def recurse(inputs: list[Path], stack: tuple[str, ...]) -> MergedInputs:
        path_rel = "/".join(stack)

        # Check for skipped path
        if any(fnmatch.fnmatch(path_rel, pat) for pat in skip_paths):
            return None

        if not inputs:
            return {}

        if len(inputs) == 1:
            return inputs[0]

        if any(S_ISDIR(lstat(input).st_mode) for input in inputs):  # Directories
            entries: dict[str, list[Path]] = {}

            for input in inputs:
                for child in input.iterdir():
                    entries.setdefault(child.name, []).append(child)

            return {k: recurse(v, stack=(*stack, k)) for k, v in entries.items()}

        elif any(S_ISREG(lstat(input).st_mode) for input in inputs):  # Regular files
            if (
                not is_bytecode(inputs[0])
                and not compare_paths(inputs)
                and not any(fnmatch.fnmatch(path_rel, pat) for pat in ignore_collisions)
            ):
                raise FileCollisionError(inputs)

            # Return the first regular file from input list.
            for input in inputs:
                if S_ISREG(lstat(input).st_mode):
                    return input

        elif all(S_ISLNK(lstat(input).st_mode) for input in inputs):  # All symlinks
            # If every symlink resolves to the same path use it as the source
            fst = inputs[0].readlink()
            if all(input.readlink() == fst for input in inputs[1:]):
                return inputs[0]

            # Otherwise check if any of the paths resolve and try again.
            for i, input in enumerate(inputs):
                resolved = input.resolve()

                # If anything resolves to a directory use the resolved path and try again
                if resolved.is_dir():
                    new_inputs = inputs.copy()
                    new_inputs[i] = resolved
                    return recurse(new_inputs, stack)

                # If any file is a regular file treat the rest as such
                elif resolved.is_file():
                    if (
                        not is_bytecode(input)
                        and not compare_paths(inputs)
                        and not any(fnmatch.fnmatch(path_rel, pat) for pat in ignore_collisions)
                    ):
                        raise FileCollisionError(inputs)
                    return input

            raise FileMergeError(
                f"Input symlinks '{inputs}' do not resolve and symlink resolution is ambiguous. Unable to merge."
            )

        raise FileMergeError(f"Unsupported input file types for inputs '{inputs}'")  # This should never ever happen

    return recurse(inputs, ())


def write_regular(src: Path, dst: Path):
    if S_ISLNK(lstat(src).st_mode):
        shutil.copy(src, dst, follow_symlinks=False)
    else:
        dst.symlink_to(src)


def write_bin(
    python_bin: Path,
    out_bin: Path,
    src: Path,
    dst: Path,
):
    python_shebang = b"#!" + bytes(python_bin)
    out_shebang = b"#!" + bytes(out_bin)

    st_mode = lstat(src).st_mode

    # If the source is a symlink copy it
    if S_ISLNK(st_mode):
        shutil.copy(src, dst, follow_symlinks=False)
        return

    # If the source file has a Python shebang rewrite it
    with src.open(mode="rb") as src_fd:
        preamble = src_fd.read(len(python_shebang))
        if preamble == python_shebang:
            with dst.open(mode="wb") as dst_fd:
                dst_fd.write(out_shebang)
                shutil.copyfileobj(src_fd, dst_fd)
            dst.chmod(st_mode)  # Copy mode
            return

    # If the source file is any other regular file symlink it
    dst.symlink_to(src)


def write_venv_deps(
    python_bin: Path,
    out_root: Path,
    inputs: MergedInputs,
):
    out_bin = out_root.joinpath("bin")

    def recurse(root: Path, inputs: MergedInputs):
        if inputs is None:
            return

        if isinstance(inputs, Path):
            dst = root
            src = inputs

            # If the merged input is in the output already this write is a no-op
            if src.is_relative_to(out_root):
                return

            # If we're writing to bin use a writer that rewrites shebangs
            if dst.is_relative_to(out_bin):
                write_bin(python_bin, out_bin, src, dst)
                return

            # Writing a regular file
            write_regular(src, dst)
        else:
            root.mkdir(exist_ok=True)
            for name, child_inputs in inputs.items():
                path = root.joinpath(name)
                recurse(path, child_inputs)

    recurse(out_root, inputs)


def fixup_pyvenv(python_root: Path, out_root: Path) -> None:
    # The venv module writes a command line to pyvenv.cfg using sys.executable
    # This means that the output would contain a reference to build Python
    with open(out_root.joinpath("pyvenv.cfg"), "r") as pyvenv_f:
        pyvenv = pyvenv_f.read()

    # Replace build-time interpreter references with actual target Python
    pyvenv = pyvenv.replace(sys.prefix, str(python_root))

    # If the build Python is a cross Python env also replace the cross prefix
    pyvenv = pyvenv.replace(sys.base_prefix, str(python_root))

    with open(out_root.joinpath("pyvenv.cfg"), "w") as pyvenv_f:
        pyvenv_f.write(pyvenv)


def main():
    args = arg_parser.parse_args(namespace=ArgsNS)

    out_root = Path(args.out)
    python_root = Path(args.python)
    python_bin = python_root.joinpath("bin")

    dependencies: list[Path] = []  # List of dependency roots
    seen_roots: set[str] = set()  # Keep track of unique dependency roots

    # Populate dependencies from precisely passed options
    for dep_roots in args.deps or []:
        for dep_root in dep_roots.split(":"):
            if dep_root in seen_roots:
                continue
            seen_roots.add(dep_root)
            dependencies.append(Path(dep_root))

    # Populate dependencies from env
    for env_var in args.env or []:
        try:
            env_value = os.environ[env_var]
        except KeyError:
            continue

        for dep_root in env_value.split(":"):
            if dep_root in seen_roots:
                continue
            seen_roots.add(dep_root)
            dependencies.append(Path(dep_root))

    # Write virtualenv
    builder = EnvBuilder(symlinks=True, prompt=os.environ.get("name", "venv"))
    context = builder.ensure_directories(str(out_root))
    context.executable = str(python_bin.joinpath(EXECUTABLE))
    context.python_dir = str(python_bin)
    builder.setup_scripts(context)
    builder.setup_python(context)
    builder.create_configuration(context)
    fixup_pyvenv(python_root, out_root)

    skip_paths = [
        # Let other hooks manage nix-support
        "nix-support",
        *(args.skip or []),
    ]

    ignore_collisions = args.ignore_collisions or []

    # Merge created venv with inputs
    merged = merge_inputs([out_root, *dependencies], skip_paths, ignore_collisions)

    # Write merged dependencies to venv
    write_venv_deps(python_bin, out_root, merged)


if __name__ == "__main__":
    main()
