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

    wheels: list[Path] = [dist_file for dist_file in dist.iterdir() if dist_file.name.endswith(".whl")]

    # Verify that wheel is not containing store path
    if check_dist:
        for wheel in wheels:
            p = subprocess.run(
                [
                    "@ugrep@",
                    # quiet
                    "-q",
                    # zip
                    "-z",
                    "@store_dir@",
                    wheel,
                ]
            )
            if p.returncode == 0:
                raise ValueError(f"""
                Built whheel '{wheel.name}' contains a Nix store path reference.

                Wheel not usable for distribution.
                """)

    # Copy wheels to output
    out.mkdir()
    for wheel in wheels:
        shutil.copy(wheel, out.joinpath(wheel.name))


if __name__ == "__main__":
    main()
