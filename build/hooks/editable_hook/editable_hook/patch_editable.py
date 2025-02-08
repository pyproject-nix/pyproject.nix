import os.path
import re
from dataclasses import dataclass
from typing import Callable

import libcst as cst
from libcst import (
    Arg,
    Attribute,
    Call,
    CSTTransformer,
    Dot,
    LeftParen,
    Name,
    RightParen,
    SimpleString,
)


@dataclass
class PatchResult:
    code: str
    patched: bool


def make_call(str_repr: str):
    return Call(
        func=Attribute(
            Attribute(
                value=Call(
                    func=Name("__import__"),
                    args=[Arg(SimpleString('"os"'))],
                ),
                attr=Name("path"),
                dot=Dot(),
            ),
            Name("expandvars"),
            Dot(),
        ),
        args=[Arg(SimpleString(str_repr))],
        lpar=[LeftParen()],
        rpar=[RightParen()],
    )


class RewriteStrings(CSTTransformer):
    build_dir: str
    replacement: str

    # Indicate whether file was patched or not
    patched: bool = False

    def __init__(self, build_dir: str, replacement: str):
        self.build_dir = build_dir
        self.replacement = replacement
        super().__init__()

    def leave_SimpleString(self, original_node: SimpleString, updated_node: SimpleString):
        if original_node.raw_value.startswith(self.build_dir):
            m = re.match(r"[^'\"]*['\"]+", original_node.value)
            if m:
                self.patched = True
                prefix = m.group(0)
                return make_call(prefix + self.replacement + original_node.value[len(self.build_dir) + len(prefix) :])
        return updated_node


def patch_py(
    build_dir: str,
    replacement: str,
    code: str,
):
    tree = cst.parse_module(code)

    string_rewriter = RewriteStrings(build_dir, replacement)
    tree = tree.visit(string_rewriter)

    return PatchResult(tree.code, string_rewriter.patched)


def patch_pth(
    build_dir: str,
    replacement: str,
    code: str,
):
    lines: list[str] = []
    patched = False

    for line in code.splitlines():
        # Python code line, use Python patcher
        if line.startswith("import "):
            tree = cst.parse_module(line)
            string_rewriter = RewriteStrings(build_dir, replacement)
            lines.append(tree.visit(string_rewriter).code)
            if string_rewriter.patched:
                patched = True
        # Bare path, turn into Python line
        elif line.startswith(build_dir):
            lines.append(
                f'import sys; import os.path; sys.path.append(os.path.expandvars(("{replacement}{line[len(build_dir) :]}")))'
            )
            patched = True
        else:
            lines.append(line)

    return PatchResult("\n".join(lines) + "\n", patched)


def fixup(patcher: Callable[..., PatchResult], build_dir: str, replacement: str, path: str):
    with open(path) as fp:
        code = fp.read()

    patched = patcher(build_dir, replacement, code)
    if not patched.patched:
        return

    with open(path, "w") as fp:
        code = fp.write(patched.code)


def main():
    build_dir = os.getcwd()
    replacement = os.environ["EDITABLE_ROOT"]

    out = os.environ["out"]

    for root, _, files in os.walk(out):
        for filename in files:
            if filename.endswith(".py"):
                patcher = patch_py
            elif filename.endswith(".pth"):
                patcher = patch_pth
            else:
                continue

            fixup(patcher, build_dir, replacement, os.path.join(root, filename))


if __name__ == "__main__":
    main()
