import contextlib
import unittest
from dataclasses import dataclass
from os.path import join as pjoin
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Union

from make_venv import (  # pyright: ignore[reportImplicitRelativeImport]
    FileCollisionError,
    FileMergeError,
    compare_paths,
    merge_inputs,
)


@dataclass
class File:
    contents: str


@dataclass
class Symlink:
    target: str


FileTree = Union[File, Symlink, dict[str, "FileTree"]]


def write_tree(out: Path, tree: FileTree):
    if isinstance(tree, File):
        with out.open(mode="w") as fd:
            fd.write(tree.contents)
    elif isinstance(tree, Symlink):
        out.symlink_to(tree.target)
    else:
        try:
            out.mkdir()
        except FileExistsError:
            pass
        for filename, node in tree.items():
            write_tree(out.joinpath(filename), node)


def TemporaryTree(tree: FileTree) -> TemporaryDirectory[str]:
    dir = TemporaryDirectory()
    write_tree(Path(dir.name), tree)
    return dir


class TestComparePaths(unittest.TestCase):
    def test_eq(self):
        contents = b"hello"

        with TemporaryDirectory() as dir:
            path = Path(dir)

            a = path.joinpath("a")
            with open(a, mode="wb") as fd:
                fd.write(contents)

            b = path.joinpath("b")
            with open(b, mode="wb") as fd:
                fd.write(contents)

            self.assertTrue(compare_paths([a, b]))

    def test_neq(self):
        with TemporaryDirectory() as dir:
            path = Path(dir)

            a = path.joinpath("a")
            with open(a, mode="wb") as fd:
                fd.write(b"hello")

            b = path.joinpath("b")
            with open(b, mode="wb") as fd:
                fd.write(b"goodbye")

            self.assertFalse(compare_paths([a, b]))


class TestMergeInputs(unittest.TestCase):
    def test_eq(self):
        """Test equal files"""
        tree: FileTree = {"hello.py": File("hello")}

        with contextlib.ExitStack() as stack:
            a = TemporaryTree(tree)
            stack.enter_context(a)

            b = TemporaryTree(tree)
            stack.enter_context(b)

            self.assertEqual(
                merge_inputs([Path(a.name), Path(b.name)]),
                {
                    "hello.py": Path(pjoin(a.name, "hello.py")),
                },
            )

    def test_neq(self):
        """Test non-equal files"""
        with contextlib.ExitStack() as stack:
            a = TemporaryTree({"hello.py": File("hello")})
            stack.enter_context(a)

            b = TemporaryTree({"hello.py": File("goodbye")})
            stack.enter_context(b)

            with self.assertRaises(FileCollisionError):
                merge_inputs([Path(a.name), Path(b.name)])

    def test_eq_nested(self):
        """Test equal files in a nested directory"""
        tree: FileTree = {
            "nested_dir": {
                "hello.py": File("hello"),
            },
        }

        with contextlib.ExitStack() as stack:
            a = TemporaryTree(tree)
            stack.enter_context(a)

            b = TemporaryTree(tree)
            stack.enter_context(b)

            self.assertEqual(
                merge_inputs([Path(a.name), Path(b.name)]),
                {
                    "nested_dir": {
                        "hello.py": Path(pjoin(a.name, "nested_dir", "hello.py")),
                    },
                },
            )

    def test_eq_sym(self):
        """Test symlinks pointing to the same location"""
        tree: FileTree = {"hello.py": Symlink("goodbye.py")}

        with contextlib.ExitStack() as stack:
            a = TemporaryTree(tree)
            stack.enter_context(a)

            b = TemporaryTree(tree)
            stack.enter_context(b)

            self.assertEqual(
                merge_inputs([Path(a.name), Path(b.name)]),
                {
                    "hello.py": Path(pjoin(a.name, "hello.py")),
                },
            )

    def test_eq_sym_content(self):
        """Test symlinks pointing to different locations but with same contents"""
        with contextlib.ExitStack() as stack:
            a = TemporaryTree(
                {
                    "hello.py": Symlink("hej.py"),
                    "hej.py": File("hello"),
                }
            )
            stack.enter_context(a)

            b = TemporaryTree(
                {
                    "hello.py": Symlink("allo.py"),
                    "allo.py": File("hello"),
                }
            )
            stack.enter_context(b)

            self.assertEqual(
                merge_inputs([Path(a.name), Path(b.name)]),
                {
                    "hello.py": Path(pjoin(a.name, "hello.py")),
                    "hej.py": Path(pjoin(a.name, "hej.py")),
                    "allo.py": Path(pjoin(b.name, "allo.py")),
                },
            )

    def test_ambiguous_sym(self):
        """Test symlinks with ambigious resolution"""
        with contextlib.ExitStack() as stack:
            a = TemporaryTree(
                {
                    "hello.py": Symlink("hej.py"),
                }
            )
            stack.enter_context(a)

            b = TemporaryTree(
                {
                    "hello.py": Symlink("allo.py"),
                }
            )
            stack.enter_context(b)

            with self.assertRaises(FileMergeError):
                merge_inputs([Path(a.name), Path(b.name)])


    def test_skip(self):
        """Test skipping files"""
        tree: FileTree = {"hello.py": File("hello")}

        with contextlib.ExitStack() as stack:
            a = TemporaryTree(tree)
            stack.enter_context(a)

            b = TemporaryTree(tree)
            stack.enter_context(b)

            self.assertEqual(
                merge_inputs([Path(a.name), Path(b.name)], skip_paths=["hello.py"]),
                {
                    "hello.py": None,
                },
            )

    def test_skip_wildcard(self):
        """Test skipping files"""
        tree: FileTree = {"hello.py": File("hello")}

        with contextlib.ExitStack() as stack:
            a = TemporaryTree(tree)
            stack.enter_context(a)

            b = TemporaryTree(tree)
            stack.enter_context(b)

            self.assertEqual(
                merge_inputs([Path(a.name), Path(b.name)], skip_paths=["*.py"]),
                {
                    "hello.py": None,
                },
            )


if __name__ == "__main__":
    unittest.main()
