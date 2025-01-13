print(
    (__import__("os").path.expandvars('$REPO_ROOT/build/cp312')),
    (__import__("os").path.expandvars("$REPO_ROOT/build/cp312")),
    (__import__("os").path.expandvars('''$REPO_ROOT/build/cp312''')),
    (__import__("os").path.expandvars("""$REPO_ROOT/build/cp312""")),
    (__import__("os").path.expandvars(b'$REPO_ROOT/build/cp312')),
    (__import__("os").path.expandvars(b"$REPO_ROOT/build/cp312")),
    (__import__("os").path.expandvars(r'$REPO_ROOT/build/cp312')),
    (__import__("os").path.expandvars(r"$REPO_ROOT/build/cp312")),
    (__import__("os").path.expandvars(rB'''$REPO_ROOT/build/cp312''')),
)

# Comment, not patched
#     '/build_dir/build/cp312',


def foo():
    """Look ma, not patched"""

    # This case is tricky to patch correctly, so we don't try
    x = r"also /build_dir/build/cp312 not patched"
    print(x)
