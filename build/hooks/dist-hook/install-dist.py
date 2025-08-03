#!/usr/bin/env python
import os
import re
import shutil
import subprocess
from pathlib import Path

NIX_B32 = "0123456789abcdfghijklmnpqrsvwxyz"  # Nix has a bespoke base32 alphabet
STORE_DIR = "@store_dir@"
STORE_PREFIX = re.escape(STORE_DIR + "/") + ("[%s]{32}" % NIX_B32)


def main():
    cwd = Path(os.getcwd())
    dist = cwd.joinpath("dist")

    # Support installing dist into a separate "dist" output, which is preferred if it's defined.
    try:
        out = Path(os.environ["dist"])
    except KeyError:
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
                    # Perl regex syntax
                    "-P",
                    STORE_PREFIX,
                    dist,
                ]
            )
            if p.returncode == 0:
                raise ValueError(f"""
                Built distribution '{dist.name}' contains a Nix store path reference.
                Built distributable might not be suited for distribution.

                Note that the wheel Nix store path scanner doesn't just pick up on build inputs,
                but also picks up on any documentation strings and such that happens to be in the package.
                This will sometimes result in false positives.

                To skip output store path scanning override this build and add:
                dontUsePyprojectInstallDistCheck = true;
                """)

    # Copy dists to output
    out.mkdir()
    for wheel in dists:
        shutil.copy(wheel, out.joinpath(wheel.name))


if __name__ == "__main__":
    main()
