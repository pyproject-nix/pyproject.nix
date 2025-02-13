#!/usr/bin/env python
import os
import shutil
import subprocess
from pathlib import Path


def main():
    cwd = Path(os.getcwd())
    dist = cwd.joinpath("dist")

    out = Path(os.environ["out"])

    check_dist: bool
    try:
        check_dist = not bool(os.environ["dontUsePyprojectInstallDistCheck"])
    except KeyError:
        check_dist = True

    dists: list[Path] = list(dist.iterdir())

    # Verify that wheel is not containing store path
    if check_dist:
        for dist in dists:
            p = subprocess.run(
                [
                    "@ugrep@",
                    # quiet
                    "-q",
                    # zip
                    "-z",
                    "@store_dir@",
                    dist,
                ]
            )
            if p.returncode == 0:
                raise ValueError(f"""
                Built distribution '{dist.name}' contains a Nix store path reference.

                Distribution not usable.
                """)

    # Copy dists to output
    out.mkdir()
    for wheel in dists:
        shutil.copy(wheel, out.joinpath(wheel.name))


if __name__ == "__main__":
    main()
